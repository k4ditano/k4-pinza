//  El selector de color, redondo y sin diálogo.
//
//  Antes esto abría el ColorDialog del sistema: una ventana aparte, con el
//  aspecto de otro programa, que te tapa el dibujo justo cuando estás
//  mirándolo para decidir el color. Aquí el color se elige encima de la
//  paleta, sin perder de vista lo que estás pintando.
//
//  El anillo es el TONO y el cuadro de dentro la saturación y el brillo, que
//  es el reparto de siempre y por eso no hay que explicarlo. Debajo van el
//  hexadecimal —para pegar un color de fuera— y el alfa, que aquí no es un
//  adorno: el pincel pinta con el alfa del color, así que es la única forma de
//  dar una pasada translúcida.
//
//  Ni un ImageData en todo el fichero: el anillo son trescientos sesenta
//  trazos de arco y el cuadro dos degradados. createImageData envenena el
//  motor (hallazgo 4 de la cata) y un selector se repinta cada vez que mueves
//  el ratón.

import QtQuick
import "../core" as C
import "../core/pixeles.js" as P

Item {
    id: raiz

    /** El color de trabajo, [r,g,b,a]. Se le da con `pon()`, no por enlace. */
    signal cambiado(var c)

    property real tono: 0        // 0..360
    property real sat: 0         // 0..1
    property real val: 1         // 0..1
    property int alfa: 255

    //  Mientras se recibe un color de fuera no se avisa de vuelta, o el panel
    //  y el selector se estarían corrigiendo el uno al otro sin parar.
    property bool _callado: false

    readonly property var color: P.deHsv(tono, sat, val, alfa)
    readonly property string hex: P.aHex(color)

    /**
     * Colocar el selector en un color.
     *
     * Un gris no tiene tono, y un negro tampoco tiene saturación: si se
     * leyeran tal cual, elegir el negro te devolvería la rueda al rojo y
     * perderías el sitio. Así que de un color apagado sólo se toma lo que de
     * verdad lleva dentro.
     */
    function pon(c) {
        if (!c) return
        const h = P.aHsv(c)
        _callado = true
        if (h[1] > 0.004 && h[2] > 0.004) tono = h[0]
        if (h[2] > 0.004) sat = h[1]
        val = h[2]
        alfa = c[3] === undefined ? 255 : c[3]
        _callado = false
    }

    //  El color se calcula aquí en vez de leer la propiedad enlazada: QML no
    //  promete que el enlace se haya rehecho cuando corre el manejador del
    //  cambio, y con el alfa se notaba —mover el alfa avisaba con el color de
    //  antes y el pincel seguía pintando opaco.
    function _avisa() { if (!_callado) cambiado(P.deHsv(tono, sat, val, alfa)) }
    onTonoChanged: { cuadro.requestPaint(); _avisa() }
    onSatChanged: _avisa()
    onValChanged: _avisa()
    onAlfaChanged: _avisa()

    // ── la geometría ─────────────────────────────────────────────
    readonly property int lado: Math.max(120, Math.min(width, 200))
    readonly property real radio: lado / 2
    readonly property real grosor: Math.max(13, lado * 0.10)
    readonly property real radioDentro: radio - grosor
    //  El cuadro va inscrito en el círculo de dentro, con un pelo de aire.
    readonly property real ladoCuadro: Math.floor(radioDentro * 1.414 - 6)

    implicitHeight: lado + 6 + pie.implicitHeight

    Item {
        id: rueda
        width: raiz.lado
        height: raiz.lado
        anchors.horizontalCenter: parent.horizontalCenter

        // ── el anillo del tono ───────────────────────────────────
        Canvas {
            id: anillo
            anchors.fill: parent
            renderTarget: Canvas.Image
            onPaint: {
                const g = getContext("2d")
                g.clearRect(0, 0, width, height)
                const cx = raiz.radio, cy = raiz.radio
                const r = raiz.radio - raiz.grosor / 2
                g.lineWidth = raiz.grosor
                //  Cuñas de un grado y medio: solapan lo justo para que no se
                //  vean costuras entre una y la siguiente.
                for (let i = 0; i < 360; i++) {
                    const a0 = i * Math.PI / 180
                    const c = P.deHsv(i, 1, 1, 255)
                    g.strokeStyle = P.aHex(c)
                    g.beginPath()
                    g.arc(cx, cy, r, a0, a0 + 0.026)
                    g.stroke()
                }
            }
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        //  El anillo no cambia nunca, así que se pinta una vez. Lo que se mueve
        //  es esta marca.
        Rectangle {
            width: raiz.grosor - 4
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: "#FFFFFF"
            x: raiz.radio + Math.cos(raiz.tono * Math.PI / 180) * (raiz.radio - raiz.grosor / 2) - width / 2
            y: raiz.radio + Math.sin(raiz.tono * Math.PI / 180) * (raiz.radio - raiz.grosor / 2) - height / 2
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: "#40000000"
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: (m) => coge(m)
            onPositionChanged: (m) => { if (pressed) coge(m) }
            function coge(m) {
                const dx = m.x - raiz.radio, dy = m.y - raiz.radio
                const d = Math.sqrt(dx * dx + dy * dy)
                //  Sólo el anillo: dentro está el cuadro, y arrastrar desde el
                //  cuadro hacia fuera no debe cambiarte el tono de golpe.
                if (d < raiz.radioDentro - 2) return
                raiz.tono = ((Math.atan2(dy, dx) * 180 / Math.PI) % 360 + 360) % 360
            }
        }

        // ── el cuadro de saturación y brillo ─────────────────────
        Item {
            width: raiz.ladoCuadro
            height: raiz.ladoCuadro
            anchors.centerIn: parent

            Canvas {
                id: cuadro
                anchors.fill: parent
                renderTarget: Canvas.Image
                onPaint: {
                    const g = getContext("2d")
                    g.clearRect(0, 0, width, height)
                    g.fillStyle = P.aHex(P.deHsv(raiz.tono, 1, 1, 255))
                    g.fillRect(0, 0, width, height)
                    //  de blanco a nada por la izquierda: eso es la saturación
                    const gs = g.createLinearGradient(0, 0, width, 0)
                    gs.addColorStop(0, "#FFFFFF")
                    gs.addColorStop(1, "rgba(255,255,255,0)")
                    g.fillStyle = gs
                    g.fillRect(0, 0, width, height)
                    //  y de nada a negro hacia abajo: eso es el brillo
                    const gv = g.createLinearGradient(0, 0, 0, height)
                    gv.addColorStop(0, "rgba(0,0,0,0)")
                    gv.addColorStop(1, "#000000")
                    g.fillStyle = gv
                    g.fillRect(0, 0, width, height)
                }
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }

            Rectangle {
                width: 11; height: 11; radius: 5.5
                color: "transparent"
                border.width: 2
                border.color: raiz.val > 0.55 && raiz.sat < 0.6 ? "#202020" : "#FFFFFF"
                x: raiz.sat * parent.width - width / 2
                y: (1 - raiz.val) * parent.height - height / 2
            }

            MouseArea {
                anchors.fill: parent
                onPressed: (m) => coge(m)
                onPositionChanged: (m) => { if (pressed) coge(m) }
                function coge(m) {
                    raiz.sat = Math.max(0, Math.min(1, m.x / width))
                    raiz.val = Math.max(0, Math.min(1, 1 - m.y / height))
                }
            }
        }
    }

    // ── el hexadecimal y el alfa ─────────────────────────────────
    Column {
        id: pie
        anchors.top: rueda.bottom
        anchors.topMargin: 6
        width: parent.width
        spacing: 3

        Row {
            width: parent.width
            spacing: 5

            Rectangle {
                width: 22; height: 22; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: raiz.hex
                border.width: 1
                border.color: C.Tema.borde
            }

            C.Campo {
                width: parent.width - 27
                anchors.verticalCenter: parent.verticalCenter
                valor: raiz.hex
                onCambiado: (v) => {
                    //  Sólo cuando está entero: si no, teclear "#c0" te saltaría
                    //  la rueda a un color a medio escribir en cada pulsación.
                    const m = v.match(/^#?([0-9a-fA-F]{6})$/)
                    if (!m) return
                    const c = P.deHex("#" + m[1])
                    //  Teclear un hex cambia el color, no el alfa: el que
                    //  tuvieras puesto se respeta.
                    raiz.pon([c[0], c[1], c[2], raiz.alfa])
                    raiz.cambiado(raiz.color)
                }
            }
        }

        C.Desliz {
            width: parent.width
            etiqueta: "alfa"
            anchoEtiqueta: 34
            minimo: 0; maximo: 255; paso: 1; decimales: 0
            valor: raiz.alfa
            onCambiado: (v) => raiz.alfa = Math.round(v)
        }
    }
}

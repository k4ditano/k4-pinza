//  La muestra: el dibujo a tamaño real, flotando sobre el lienzo.
//
//  Dibujando estás siempre a ×8 o a ×16, y a ese aumento cualquier cosa parece
//  bien: los contornos se leen, las sombras se separan, todo respira. A tamaño
//  real la mitad de eso desaparece. Sin verlo mientras dibujas te enteras al
//  exportar, que es tarde.
//
//  Va encima del lienzo y no en el panel lateral a propósito: tiene que estar
//  al lado de lo que miras, no a treinta centímetros. Y se arrastra, porque el
//  único sitio bueno depende de lo que estés dibujando.

import QtQuick
import "../core" as C
import "../core/pixeles.js" as P
import "../servicios" as S

Rectangle {
    id: raiz
    visible: S.Ajustes.muestra && S.Documento.abierto
    color: C.Tema.superficie
    border.width: 1
    border.color: C.Tema.borde
    radius: C.Tema.radio
    opacity: raton.containsMouse || arrastre.active ? 1 : 0.9
    Behavior on opacity { NumberAnimation { duration: 120 } }

    readonly property int aw: S.Documento.ancho
    readonly property int ah: S.Documento.alto
    readonly property int hueco: 10

    /**
     * Qué aumentos caben.
     *
     * Se quiere ×1 siempre —es el que importa— y ×2 y ×3 si sobra sitio. Un
     * tileset de 432 de ancho sólo enseña el ×1, y está bien: nadie mira una
     * hoja de baldosas al triple.
     *
     * NO es un enlace. Era `readonly property var` colgando de `rev`, y eso
     * devuelve un ARRAY NUEVO cada vez que cambia cualquier cosa del documento:
     * el Repeater veía otro modelo, destruía sus tres delegados y creaba tres
     * Canvas nuevos — en cada trazo, en cada cambio de fotograma. Cambiar de
     * acción pasó de 32 ms a más de tres segundos por eso. Ahora sólo se
     * reasigna cuando el resultado es de verdad distinto.
     */
    property var escalas: [1]

    function recalculaEscalas() {
        if (!S.Documento.abierto) { if (escalas.length !== 1 || escalas[0] !== 1) escalas = [1]; return }
        const cabeAncho = Math.max(120, (parent ? parent.width : 400) - 60)
        const cabeAlto = Math.max(90, (parent ? parent.height : 300) - 120)
        const sirve = []
        let usado = 0
        for (const e of [1, 2, 3]) {
            const w = aw * e, h = ah * e
            if (sirve.length && (usado + hueco + w > cabeAncho || h > cabeAlto)) break
            usado += (sirve.length ? hueco : 0) + w
            sirve.push(e)
        }
        if (sirve.join() !== escalas.join()) escalas = sirve
    }

    onAwChanged: recalculaEscalas()
    onAhChanged: recalculaEscalas()
    Component.onCompleted: recalculaEscalas()
    Connections {
        target: raiz.parent
        function onWidthChanged() { raiz.recalculaEscalas() }
        function onHeightChanged() { raiz.recalculaEscalas() }
    }

    readonly property int anchoUtil: {
        let w = 0
        for (let i = 0; i < escalas.length; i++) w += (i ? hueco : 0) + aw * escalas[i]
        return w
    }
    readonly property int altoUtil: ah * escalas[escalas.length - 1]

    implicitWidth: Math.max(96, anchoUtil + 16)
    implicitHeight: altoUtil + 30

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeAllCursor
        drag.target: raiz
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.maximumX: parent ? Math.max(0, raiz.parent.width - raiz.width) : 0
        drag.minimumY: 0
        drag.maximumY: parent ? Math.max(0, raiz.parent.height - raiz.height) : 0
        property alias active: raton.drag.active
    }
    QtObject { id: arrastre; readonly property bool active: raton.drag.active }

    // ── la fila de tamaños ───────────────────────────────────────
    Row {
        id: fila
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: raiz.hueco

        Repeater {
            model: raiz.escalas

            Item {
                readonly property int esc: modelData
                width: raiz.aw * esc
                height: raiz.altoUtil
                
                Item {
                    width: raiz.aw * parent.esc
                    height: raiz.ah * parent.esc
                    anchors.bottom: parent.bottom

                    //  El ajedrez, en cuadros de pantalla y no de sprite: a
                    //  tamaño real un damero por píxel sería ruido puro.
                    Canvas {
                        anchors.fill: parent
                        renderStrategy: Canvas.Cooperative
                        onPaint: {
                            const g = getContext("2d")
                            const t = 6
                            g.fillStyle = C.Tema.ajedrezA
                            g.fillRect(0, 0, width, height)
                            g.fillStyle = C.Tema.ajedrezB
                            for (let y = 0; y < height; y += t) for (let x = 0; x < width; x += t)
                                if (((x / t) + (y / t)) % 2 === 1) g.fillRect(x, y, t, t)
                        }
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                    }

                    Canvas {
                        id: pieza
                        property var caja: ({ img: null })
                        width: raiz.aw
                        height: raiz.ah
                        transformOrigin: Item.TopLeft
                        scale: parent.parent.esc
                        smooth: false
                        renderStrategy: Canvas.Cooperative
                        renderTarget: Canvas.Image

                        onPaint: {
                            if (!S.Documento.abierto) return
                            const g = getContext("2d")
                            g.clearRect(0, 0, width, height)
                            const b = S.Documento.compuesto()
                            if (!b || b.w !== width || b.h !== height) return
                            const img = P.lienzoImg(pieza.caja, g, b.w, b.h)
                            P.vuelcaZona(img, b, 0, 0, b.w, b.h)
                            // origen sucio en (0,0), que es la única forma que pinta
                            g.putImageData(img, 0, 0, 0, 0, b.w, b.h)
                        }
                        Connections {
                            target: S.Documento
                            function onRevPixelesChanged() { pieza.requestPaint() }
                            function onRevChanged() { pieza.requestPaint() }
                        }
                        Component.onCompleted: requestPaint()
                    }
                }
            }
        }
    }

    // ── el pie: los aumentos y el tamaño de verdad ──────────────
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        spacing: 6

        Text {
            text: raiz.escalas.map((e) => "×" + e).join("  ")
            font.family: C.Tema.tipoMono
            font.pixelSize: 9
            color: C.Tema.apagado
        }
        Item { width: Math.max(0, parent.width - 110); height: 1 }
        Text {
            text: raiz.aw + "×" + raiz.ah
            font.family: C.Tema.tipoMono
            font.pixelSize: 9
            color: C.Tema.tenue
        }
        C.Icono {
            glifo: C.Tema.i.cerrar
            font.pixelSize: 10
            color: cerrarRaton.containsMouse ? C.Tema.acento : C.Tema.apagado
            MouseArea {
                id: cerrarRaton
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: S.Ajustes.muestra = false
            }
        }
    }
}

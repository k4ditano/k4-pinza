//  El compás.
//
//  El tercer eje, hecho un mando. Ocho casillas —o cuatro, o una— en la
//  disposición geográfica que les toca, así que la fila 0 de una hoja PMD es
//  la de abajo y no hay que acordarse de nada. Quien dice qué flecha lleva
//  cada orientación es el CONTRATO, no esta vista: si mañana un pack numera
//  sus caras al revés, aquí no se toca una línea.
//
//  El candado del centro es el enlace de espejo: con él puesto, dibujar el
//  este genera el oeste volteado. Es la mitad del trabajo de cada hoja.

import QtQuick
import "../core" as C
import "../servicios" as S

Rectangle {
    id: raiz
    visible: S.Documento.abierto && S.Documento.nOrientaciones > 1 && S.Ajustes.compas

    readonly property var con: S.Documento.d ? S.Documento.d.contrato : null
    readonly property int n: S.Documento.nOrientaciones

    /** La casilla de la rejilla 3×3 donde va cada flecha. */
    readonly property var sitios: ({
        "↑": [1, 0], "↗": [2, 0], "→": [2, 1], "↘": [2, 2],
        "↓": [1, 2], "↙": [0, 2], "←": [0, 1], "↖": [0, 0], "·": [1, 1]
    })

    /**
     * ¿Se puede montar la rosa de los vientos, o hay que caer a una fila?
     *
     * Un documento puede tener orientaciones que el contrato no describe —una
     * hoja troceada de fuera, un proyecto viejo, un pack ajeno— y entonces
     * todas traen la misma flecha y se apilan en la misma casilla: el compás
     * se quedaba con un solo botón y las demás caras eran inalcanzables. Si
     * las flechas no son todas distintas, se dibujan en fila y ya está.
     */
    readonly property bool geografico: {
        S.Documento.rev
        const vistas = {}
        for (let i = 0; i < n; i++) {
            const f = S.Packs.orientacion(con, S.Documento.etiquetaOrientacion(i)).flecha
            if (!sitios[f] || vistas[f]) return false
            vistas[f] = 1
        }
        return true
    }

    function sitioDe(i, flecha) {
        if (geografico) return sitios[flecha] || [1, 1]
        // en fila, de tres en tres, para no salirse por la derecha
        return [i % 3, Math.floor(i / 3)]
    }

    readonly property int filas: geografico ? 3 : Math.ceil(n / 3)
    implicitWidth: 3 * 26 + 8
    implicitHeight: filas * 26 + 8
    radius: C.Tema.radio
    color: C.Tema.superficie
    border.width: 1
    border.color: C.Tema.borde
    opacity: raton.containsMouse ? 1 : 0.88
    Behavior on opacity { NumberAnimation { duration: 120 } }

    MouseArea { id: raton; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

    Repeater {
        model: raiz.n
        Rectangle {
            readonly property var info: S.Packs.orientacion(raiz.con, S.Documento.etiquetaOrientacion(index))
            readonly property var sitio: raiz.sitioDe(index, info.flecha)
            readonly property bool actual: S.Documento.orientacion === index
            //  Si esa cara está en blanco. Se calcula a mano y no en un
            //  enlace: preguntarlo por enlace obliga a componer las ocho caras
            //  en cada repintado, y además `compuesto()` toca su caché, con lo
            //  que el enlace acababa dependiendo de sí mismo.
            property bool vacia: true
            function mira() {
                const b = S.Documento.compuesto(S.Documento.fotograma, index)
                if (!b) { vacia = true; return }
                for (let i = 3; i < b.d.length; i += 4) if (b.d[i] !== 0) { vacia = false; return }
                vacia = true
            }
            Component.onCompleted: mira()
            Connections {
                target: S.Documento
                function onRevPixelesChanged() { mira() }
                function onRevChanged() { mira() }
            }

            x: 4 + sitio[0] * 26
            y: 4 + sitio[1] * 26
            width: 25; height: 25
            radius: 3
            color: actual ? C.Tema.acentoTenue : celdaRaton.containsMouse ? C.Tema.alta : "transparent"
            border.width: actual ? 1 : 0
            border.color: C.Tema.acento

            Text {
                anchors.centerIn: parent
                //  Sin rosa de los vientos, la etiqueta dice más que una
                //  flecha que sería la misma en todas.
                text: raiz.geografico ? parent.info.flecha
                                      : String(parent.info.titulo).substring(0, 3)
                font.family: raiz.geografico ? C.Tema.tipo : C.Tema.tipoMono
                font.pixelSize: raiz.geografico ? 14 : 9
                color: parent.actual ? C.Tema.acento
                     : parent.vacia ? C.Tema.apagado : C.Tema.tinta
            }
            // un punto abajo si esa cara todavía está en blanco
            Rectangle {
                visible: parent.vacia && !parent.actual
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                anchors.horizontalCenter: parent.horizontalCenter
                width: 3; height: 3; radius: 1.5
                color: C.Tema.apagado
            }

            MouseArea {
                id: celdaRaton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: S.Documento.orientacion = index
            }
            C.Pista { texto: parent.info.titulo; mostrar: celdaRaton.containsMouse; lado: Qt.AlignTop }
        }
    }

    // ── el enlace de espejo, en el centro ────────────────────────
    C.Boton {
        anchors.centerIn: parent
        width: 24; height: 24
        implicitHeight: 24
        visible: raiz.geografico && S.Ordenes.parejaEspejo() >= 0
        icono: C.Tema.i.espejo
        pista: "generar esta cara volteando " +
               S.Documento.etiquetaOrientacion(S.Ordenes.parejaEspejo())
        onPulsado: S.Ordenes.ejecuta("espejoOrientacion")
    }
}

//  El rótulo, pintado donde nada lo recorta.
//
//  Va colgado de la raíz de la escena con un z altísimo, porque su trabajo es
//  precisamente salirse de la caja que lo pidió. Se coloca solo para no salirse
//  de la ventana: un rótulo cortado por el borde no vale para nada.

import QtQuick
import "../core" as C
import "../servicios" as S

Item {
    id: raiz
    anchors.fill: parent
    z: 10000
    visible: S.Globo.visible

    Rectangle {
        id: caja
        color: C.Tema.alta
        border.color: C.Tema.borde
        border.width: 1
        radius: 3
        width: rot.implicitWidth + 16
        height: rot.implicitHeight + 9
        opacity: S.Globo.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }

        x: Math.max(4, Math.min(raiz.width - width - 4, S.Globo.x - width / 2))
        y: S.Globo.lado === Qt.AlignTop ? Math.max(4, S.Globo.y - height - 6)
                                        : Math.min(raiz.height - height - 4, S.Globo.y + 6)

        Text {
            id: rot
            anchors.centerIn: parent
            text: S.Globo.texto
            font.family: C.Tema.tipo
            font.pixelSize: C.Tema.letraChica
            color: C.Tema.tinta
        }
    }
}

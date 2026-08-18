//  El rótulo que sale al pasar por encima.
//
//  Flota por encima de todo con un z alto porque si no lo tapa el panel de al
//  lado, que es exactamente cuando hace falta leerlo.

import QtQuick
import "." as C

Item {
    id: raiz
    property string texto: ""
    property bool mostrar: false
    property int lado: Qt.AlignBottom
    anchors.fill: parent
    z: 9999

    Rectangle {
        id: globo
        visible: raiz.mostrar && raiz.texto.length > 0
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
        color: C.Tema.alta
        border.color: C.Tema.borde
        border.width: 1
        radius: 3
        width: rot.implicitWidth + 14
        height: rot.implicitHeight + 8
        x: Math.round(parent.width / 2 - width / 2)
        y: raiz.lado === Qt.AlignBottom ? parent.height + 6 : -height - 6
        parent: raiz

        Text {
            id: rot
            anchors.centerIn: parent
            text: raiz.texto
            font.family: C.Tema.tipo
            font.pixelSize: C.Tema.letraChica
            color: C.Tema.tinta
        }
    }
}

//  Sí o no.
import QtQuick
import "." as C

Item {
    id: raiz
    property string etiqueta: ""
    property bool valor: false
    signal cambiado(bool v)

    implicitHeight: 22
    implicitWidth: 180

    Text {
        anchors.left: parent.left
        anchors.right: mando.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: raiz.etiqueta
        font.family: C.Tema.tipo
        font.pixelSize: C.Tema.letra
        color: raiz.valor ? C.Tema.tinta : C.Tema.tenue
        elide: Text.ElideRight
    }

    Rectangle {
        id: mando
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 16; radius: 8
        color: raiz.valor ? C.Tema.acento : C.Tema.borde
        Behavior on color { ColorAnimation { duration: 110 } }

        Rectangle {
            width: 12; height: 12; radius: 6
            y: 2
            x: raiz.valor ? parent.width - width - 2 : 2
            color: raiz.valor ? C.Tema.fondo : C.Tema.tenue
            Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: raiz.cambiado(!raiz.valor)
    }
}

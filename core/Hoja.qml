//  Una hoja: un panel que se pliega contra un borde.
//
//  No hay ni un diálogo modal en todo el programa. Redimensionar, exportar,
//  crear una capa: todo pasa en hojas que dejan el lienzo a la vista y
//  siguiendo vivo, porque la mitad de esas decisiones sólo se pueden tomar
//  mirando el dibujo.

import QtQuick
import "." as C

Rectangle {
    id: raiz
    property string titulo: ""
    property string icono: ""
    property bool plegable: true
    property bool plegada: false
    default property alias contenido: caja.data

    color: C.Tema.superficie
    implicitHeight: cabeza.height + (plegada ? 0 : caja.implicitHeight + 12)
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    Item {
        id: cabeza
        width: parent.width
        height: raiz.titulo ? 28 : 0
        visible: !!raiz.titulo

        C.Icono {
            id: ic
            glifo: raiz.icono
            visible: !!raiz.icono
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: C.Tema.tenue
            font.pixelSize: 13
        }
        C.Rotulo {
            text: raiz.titulo
            anchors.left: raiz.icono ? ic.right : parent.left
            anchors.leftMargin: raiz.icono ? 7 : 10
            anchors.verticalCenter: parent.verticalCenter
        }
        C.Icono {
            glifo: raiz.plegada ? C.Tema.i.flecha : C.Tema.i.abajo
            visible: raiz.plegable
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: C.Tema.apagado
            font.pixelSize: 12
        }
        MouseArea {
            anchors.fill: parent
            enabled: raiz.plegable
            cursorShape: Qt.PointingHandCursor
            onClicked: raiz.plegada = !raiz.plegada
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: C.Tema.bordeSuave
            visible: !raiz.plegada
        }
    }

    Column {
        id: caja
        anchors.top: cabeza.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 6
        opacity: raiz.plegada ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }
}

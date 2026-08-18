//  El historial, visible.
//
//  Deshacer a ciegas obliga a contar pasos hacia atrás. Aquí está la pila
//  entera y se salta a cualquier punto de un clic; lo que quede por delante
//  sigue ahí hasta que dibujes otra cosa, que es cuando de verdad se pierde.

import QtQuick
import "../core" as C
import "../servicios" as S

C.Hoja {
    id: raiz
    titulo: "historial"
    icono: C.Tema.i.historial

    Column {
        width: parent.width
        spacing: 2

        Rectangle {
            width: parent.width
            height: 22
            radius: 3
            color: S.Historial.actual === -1 ? C.Tema.acentoTenue : "transparent"
            Text {
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "el principio"
                font.family: C.Tema.tipo; font.pixelSize: C.Tema.letra
                font.italic: true
                color: S.Historial.actual === -1 ? C.Tema.acento : C.Tema.tenue
            }
            MouseArea { anchors.fill: parent; onClicked: S.Historial.vaA(-1) }
        }

        Repeater {
            model: S.Historial.rev, S.Historial.pasos

            Rectangle {
                readonly property bool aplicado: index <= S.Historial.actual
                width: parent.width
                height: 22
                radius: 3
                color: index === S.Historial.actual ? C.Tema.acentoTenue
                     : pasoRaton.containsMouse ? C.Tema.alta : "transparent"
                opacity: aplicado ? 1 : 0.42

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.right: num.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: S.Historial.nombreDe(index)
                    font.family: C.Tema.tipo; font.pixelSize: C.Tema.letra
                    color: index === S.Historial.actual ? C.Tema.acento : C.Tema.tinta
                    elide: Text.ElideRight
                }
                Text {
                    id: num
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: index + 1
                    font.family: C.Tema.tipoMono; font.pixelSize: 9
                    color: C.Tema.apagado
                }
                MouseArea {
                    id: pasoRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: S.Historial.vaA(index)
                }
            }
        }

        Text {
            visible: S.Historial.pasos === 0
            text: "nada que deshacer todavía"
            font.family: C.Tema.tipo; font.pixelSize: C.Tema.letraChica
            color: C.Tema.apagado
        }
    }
}

//  Las acciones de la criatura, siempre a la vista.
//
//  Una criatura son ocho dibujos distintos y todos se llaman igual. Sin esto,
//  después de importar te quedas mirando un lienzo sin saber cuál de las ocho
//  estás viendo ni cómo llegar a las otras — que era exactamente el caso.
//
//  Enseña en cuál estás, cuáles tienen algo dibujado, y se salta de una a otra
//  de un clic. Cambiar de acción guarda antes la que dejas.

import QtQuick
import "../core" as C
import "../servicios" as S

C.Hoja {
    id: raiz
    titulo: S.Especie.rev, "acciones de " + S.Especie.nombre
    icono: C.Tema.i.juego

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: S.Especie.rev, S.Especie.acciones

            Rectangle {
                readonly property var info: S.Especie.d ? S.Especie.d.acciones[modelData.id] : null
                readonly property bool actual: S.Especie.accion === modelData.id

                width: parent.width
                height: info ? 26 : 0
                visible: !!info
                radius: 3
                color: actual ? C.Tema.acentoTenue
                     : accRaton.containsMouse ? C.Tema.alta : "transparent"
                border.width: actual ? 1 : 0
                border.color: C.Tema.acento

                //  Un punto: verde si ya tiene dibujo, hueco si está en blanco.
                //  De un vistazo se ve lo que falta por hacer.
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: parent.info && parent.info.hecha ? C.Tema.bien : "transparent"
                    border.width: parent.info && parent.info.hecha ? 0 : 1
                    border.color: C.Tema.borde
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.id
                    font.family: C.Tema.tipo
                    font.pixelSize: C.Tema.letra
                    font.weight: parent.actual ? Font.DemiBold : Font.Normal
                    color: parent.actual ? C.Tema.acento : C.Tema.tinta
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.info ? parent.info.fotogramas + " fot" : ""
                    font.family: C.Tema.tipoMono
                    font.pixelSize: 9
                    color: C.Tema.apagado
                }

                MouseArea {
                    id: accRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: S.Especie.editaAccion(modelData.id, null)
                }
                C.Pista {
                    texto: modelData.titulo + (parent.info
                           ? "   " + parent.info.ancho + "×" + parent.info.alto : "")
                    mostrar: accRaton.containsMouse
                    lado: Qt.AlignTop
                }
            }
        }

        Item { width: 1; height: 4 }
        Row {
            spacing: 2
            C.Boton { texto: "‹"; relleno: 9; implicitHeight: 22
                      pista: "acción anterior   Alt+←"
                      onPulsado: S.Especie.saltaAccion(-1) }
            C.Boton { texto: "›"; relleno: 9; implicitHeight: 22
                      pista: "acción siguiente   Alt+→"
                      onPulsado: S.Especie.saltaAccion(1) }
            C.Boton { icono: C.Tema.i.exportar; width: 26; implicitHeight: 22
                      pista: "exportar la especie entera al juego"
                      onPulsado: S.Ordenes.ejecuta("especieExportar") }
            C.Boton { icono: C.Tema.i.engranaje; width: 26; implicitHeight: 22
                      pista: "la ficha de la especie"
                      onPulsado: S.Ordenes.ejecuta("especie") }
        }
    }
}

//  La paleta de comandos.
//
//  Sustituye a la barra de menús entera. Se busca por trozos sueltos —"vol h"
//  encuentra "Voltear en horizontal"— porque el sentido de esto es no tener que
//  recordar dónde vive cada cosa ni cómo empieza su nombre.
//
//  Sólo enseña lo que se puede hacer AHORA: si no hay dos capas, "fusionar con
//  la de abajo" no aparece. Un menú lleno de opciones grises es una lista de
//  cosas que no puedes hacer.

import QtQuick
import "../core" as C
import "../servicios" as S

Item {
    id: raiz
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    z: 900

    property bool abierta: false
    property var resultados: []
    property int elegido: 0

    onAbiertaChanged: {
        opacity = abierta ? 1 : 0
        if (abierta) {
            entrada.text = ""
            refresca()
            entrada.forceActiveFocus()
        }
    }
    Behavior on opacity { NumberAnimation { duration: 110 } }

    function refresca() {
        resultados = S.Ordenes.busca(entrada.text)
        elegido = 0
    }
    function lanza() {
        if (!resultados.length) return
        const o = resultados[Math.max(0, Math.min(elegido, resultados.length - 1))]
        abierta = false
        Qt.callLater(() => S.Ordenes.ejecuta(o.id))
    }

    Rectangle {
        anchors.fill: parent
        color: C.Tema.oscuro ? "#B0000000" : "#70000000"
        MouseArea { anchors.fill: parent; onClicked: raiz.abierta = false }
    }

    Rectangle {
        width: Math.min(560, parent.width - 60)
        height: Math.min(420, 54 + lista.contentHeight + 10)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        radius: 6
        color: C.Tema.superficie
        border.width: 1
        border.color: C.Tema.borde

        // ── la caja de buscar ────────────────────────────────────
        Item {
            id: cabeza
            width: parent.width
            height: 44

            C.Icono {
                id: lupa
                glifo: C.Tema.i.lupa
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: C.Tema.tenue
                font.pixelSize: 16
            }
            TextInput {
                id: entrada
                anchors.left: lupa.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                verticalAlignment: TextInput.AlignVCenter
                font.family: C.Tema.tipo
                font.pixelSize: 16
                color: C.Tema.tinta
                selectionColor: C.Tema.acento
                selectByMouse: true
                onTextChanged: raiz.refresca()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !entrada.text
                    text: "qué quieres hacer"
                    font: entrada.font
                    color: C.Tema.apagado
                }

                Keys.onDownPressed: raiz.elegido = Math.min(raiz.resultados.length - 1, raiz.elegido + 1)
                Keys.onUpPressed: raiz.elegido = Math.max(0, raiz.elegido - 1)
                Keys.onReturnPressed: raiz.lanza()
                Keys.onEnterPressed: raiz.lanza()
                Keys.onEscapePressed: raiz.abierta = false
                Keys.onTabPressed: raiz.elegido = (raiz.elegido + 1) % Math.max(1, raiz.resultados.length)
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: C.Tema.borde
            }
        }

        ListView {
            id: lista
            anchors.top: cabeza.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 5
            clip: true
            model: raiz.resultados
            currentIndex: raiz.elegido
            highlightMoveDuration: 60

            delegate: Rectangle {
                width: lista.width
                height: 30
                radius: 3
                color: index === raiz.elegido ? C.Tema.acentoTenue
                     : itemRaton.containsMouse ? C.Tema.alta : "transparent"

                C.Icono {
                    id: ic
                    glifo: modelData.icono ? C.Tema.i[modelData.icono] : ""
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    color: index === raiz.elegido ? C.Tema.acento : C.Tema.tenue
                    font.pixelSize: 13
                }
                Text {
                    anchors.left: ic.right
                    anchors.leftMargin: 8
                    anchors.right: grupo.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.titulo
                    font.family: C.Tema.tipo
                    font.pixelSize: C.Tema.letraGrande
                    color: index === raiz.elegido ? C.Tema.acento : C.Tema.tinta
                    elide: Text.ElideRight
                }
                Row {
                    id: grupo
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        text: modelData.grupo
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: C.Tema.tipo
                        font.pixelSize: 10
                        color: C.Tema.apagado
                    }
                    Rectangle {
                        visible: !!modelData.atajo
                        anchors.verticalCenter: parent.verticalCenter
                        width: atajo.implicitWidth + 10
                        height: 16
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: C.Tema.borde
                        Text {
                            id: atajo
                            anchors.centerIn: parent
                            text: modelData.atajo || ""
                            font.family: C.Tema.tipoMono
                            font.pixelSize: 9
                            color: C.Tema.tenue
                        }
                    }
                }

                MouseArea {
                    id: itemRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: raiz.elegido = index
                    onClicked: raiz.lanza()
                }
            }
        }
    }
}

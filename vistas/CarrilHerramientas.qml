//  El carril de herramientas.
//
//  Agrupadas por lo que hacen, con una raya entre grupos. La tabla vive en
//  servicios/Herramientas.qml para que el carril y la barra de opciones no
//  puedan discrepar.

import QtQuick
import "../core" as C
import "../servicios" as S

Rectangle {
    id: raiz

    color: C.Tema.superficie
    Rectangle {
        anchors.right: parent.right
        width: 1; height: parent.height
        color: C.Tema.borde
    }
    Flickable {
        anchors.fill: parent
        anchors.topMargin: 6
        contentHeight: pila.implicitHeight
        clip: true
        Column {
            id: pila
            width: parent.width
            spacing: 2
            Repeater {
                model: S.Herramientas.grupos
                Column {
                    width: pila.width
                    spacing: 2
                    Repeater {
                        model: modelData
                        C.Boton {
                            icono: C.Tema.i[modelData.ico]
                            activo: S.Pinceles.herramienta === modelData.id
                            pista: modelData.nombre + (modelData.tecla ? "   " + modelData.tecla : "")
                            width: C.Tema.carril - 8
                            x: 4
                            implicitHeight: 30
                            onPulsado: S.Pinceles.elige(modelData.id)
                        }
                    }
                    Rectangle {
                        width: parent.width - 16; x: 8; height: 1
                        color: C.Tema.bordeSuave
                        visible: index < S.Herramientas.grupos.length - 1
                    }
                }
            }
        }
    }
}

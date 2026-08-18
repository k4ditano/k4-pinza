//  Elegir entre pocas cosas: botones en fila, no un desplegable.
//
//  Con menos de cinco opciones un desplegable esconde información que cabía en
//  pantalla y cuesta dos clics en vez de uno. Con más, se despliega.

import QtQuick
import "." as C

Item {
    id: raiz
    property string etiqueta: ""
    property var opciones: []          // [{id, titulo}] o ["a","b"]
    property string valor: ""
    property int anchoEtiqueta: 76
    signal cambiado(string v)

    readonly property var _lista: opciones.map((o) => typeof o === "string" ? { id: o, titulo: o } : o)
    readonly property bool _desplegar: _lista.length > 4

    implicitHeight: 24
    //  El ancho sale de lo que hay dentro, no de un número puesto a ojo.
    //  Con 180 fijos, una fila de botones más ancha se salía por debajo del
    //  siguiente elemento y los dos textos se pintaban encima — se veía
    //  «y todas las orientacitodas las capas».
    implicitWidth: _desplegar ? 200
                 : (raiz.etiqueta ? raiz.anchoEtiqueta : 0) + fila.implicitWidth

    Text {
        id: et
        text: raiz.etiqueta
        visible: !!raiz.etiqueta
        width: raiz.anchoEtiqueta
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        font.family: C.Tema.tipo
        font.pixelSize: C.Tema.letra
        color: C.Tema.tenue
        elide: Text.ElideRight
    }

    Row {
        id: fila
        visible: !raiz._desplegar
        anchors.left: raiz.etiqueta ? et.right : parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater {
            model: raiz._desplegar ? [] : raiz._lista
            C.Boton {
                texto: modelData.titulo
                activo: modelData.id === raiz.valor
                relleno: 7
                implicitHeight: 22
                onPulsado: raiz.cambiado(modelData.id)
            }
        }
    }

    // desplegable, para cuando son muchas
    Rectangle {
        id: caja
        visible: raiz._desplegar
        anchors.left: raiz.etiqueta ? et.right : parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        radius: 3
        color: C.Tema.fondo
        border.width: 1
        border.color: lista.visible ? C.Tema.acento : C.Tema.borde

        Text {
            anchors.left: parent.left; anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: {
                for (let i = 0; i < raiz._lista.length; i++)
                    if (raiz._lista[i].id === raiz.valor) return raiz._lista[i].titulo
                return raiz.valor
            }
            font.family: C.Tema.tipo
            font.pixelSize: C.Tema.letra
            color: C.Tema.tinta
        }
        C.Icono {
            glifo: C.Tema.i.abajo
            anchors.right: parent.right; anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            color: C.Tema.apagado
            font.pixelSize: 12
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: lista.visible = !lista.visible
        }
    }

    Rectangle {
        id: lista
        visible: false
        z: 500
        parent: raiz
        anchors.top: caja.bottom
        anchors.left: caja.left
        anchors.right: caja.right
        height: Math.min(240, col.implicitHeight + 8)
        color: C.Tema.alta
        border.width: 1
        border.color: C.Tema.borde
        radius: 3
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 4
            contentHeight: col.implicitHeight
            Column {
                id: col
                width: parent.width
                Repeater {
                    model: raiz._lista
                    Rectangle {
                        width: col.width; height: 22
                        color: filaRaton.containsMouse ? C.Tema.superficie : "transparent"
                        radius: 2
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.titulo
                            font.family: C.Tema.tipo
                            font.pixelSize: C.Tema.letra
                            color: modelData.id === raiz.valor ? C.Tema.acento : C.Tema.tinta
                        }
                        MouseArea {
                            id: filaRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { raiz.cambiado(modelData.id); lista.visible = false }
                        }
                    }
                }
            }
        }
    }
}

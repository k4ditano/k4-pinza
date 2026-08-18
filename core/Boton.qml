//  El botón de la casa.
//
//  Tres formas de decir lo mismo: texto, icono o los dos. `activo` es lo que
//  está seleccionado ahora mismo y es lo único que se lleva el acento — el
//  resto de la interfaz es gris a propósito, para que el arte sea lo único con
//  color en la pantalla.

import QtQuick
import "." as C

Rectangle {
    id: raiz

    property string texto: ""
    property string icono: ""
    property bool activo: false
    property bool tenue: false
    property bool peligro: false
    property string pista: ""
    property int relleno: 8
    signal pulsado()
    signal pulsadoDerecho()

    implicitWidth: Math.max(icono && !texto ? C.Tema.fila : 0,
                            fila.implicitWidth + relleno * 2)
    implicitHeight: C.Tema.fila
    radius: C.Tema.radio
    color: activo ? C.Tema.acentoTenue
         : raton.containsMouse ? C.Tema.alta : "transparent"
    border.width: activo ? 1 : 0
    border.color: C.Tema.acento
    opacity: tenue ? 0.45 : 1

    Row {
        id: fila
        anchors.centerIn: parent
        spacing: raiz.texto && raiz.icono ? 6 : 0
        C.Icono {
            glifo: raiz.icono
            visible: !!raiz.icono
            anchors.verticalCenter: parent.verticalCenter
            color: raiz.peligro ? C.Tema.mal : raiz.activo ? C.Tema.acento : C.Tema.tinta
        }
        Text {
            text: raiz.texto
            visible: !!raiz.texto
            anchors.verticalCenter: parent.verticalCenter
            font.family: C.Tema.tipo
            font.pixelSize: C.Tema.letra
            color: raiz.peligro ? C.Tema.mal : raiz.activo ? C.Tema.acento : C.Tema.tinta
        }
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => m.button === Qt.RightButton ? raiz.pulsadoDerecho() : raiz.pulsado()
    }

    C.Pista { texto: raiz.pista; mostrar: raton.containsMouse && !!raiz.pista }
}

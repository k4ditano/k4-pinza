//  Lo que sale cuando el programa está haciendo algo que tarda.
//
//  Importar una criatura son ocho proyectos y quinientas celdas: sin nada que
//  lo diga, la ventana se queda igual unos segundos y no sabes si va, si se ha
//  colgado o si no llegaste a pulsar. Cualquiera de las tres conclusiones es
//  mala y la última hace que pulses otra vez.
//
//  Aparece con RETARDO a propósito. Guardar un icono de 24×24 tarda cincuenta
//  milisegundos, y un parpadeo de rueda en cada guardado cansa más que
//  informar. Si algo se resuelve rápido, no se enseña nada.

import QtQuick
import "../core" as C
import "../servicios" as S

Item {
    id: raiz
    anchors.fill: parent
    z: 700
    visible: opacity > 0
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 130 } }

    //  Quién manda: la especie sabe de la tarea larga y el proyecto de cada
    //  paso suyo, así que la de fuera gana para no ir cambiando de rótulo.
    readonly property string faena: S.Especie.estado !== "" ? S.Especie.estado
                                  : S.Proyecto.estado !== "" ? S.Proyecto.estado
                                  : S.Especie.catalogoLeyendo ? "leyendo el catálogo"
                                  : ""
    readonly property real avance: S.Especie.estado !== "" ? S.Especie.progreso
                                 : S.Proyecto.estado !== "" ? S.Proyecto.progreso : 0
    readonly property bool haciendoAlgo: faena !== ""

    Timer {
        id: espera
        interval: 220
        onTriggered: if (raiz.haciendoAlgo) raiz.opacity = 1
    }
    onHaciendoAlgoChanged: {
        if (haciendoAlgo) espera.restart()
        else { espera.stop(); opacity = 0 }
    }

    //  Y si algo se atasca, deja de tragarse los clics.
    //
    //  Una pantalla de carga que no se va es peor que un fallo: no puedes ni
    //  guardar lo que tenías. Pasado el minuto se sigue enseñando la rueda
    //  —algo está pasando— pero se devuelve el control.
    property bool atascado: false
    Timer {
        id: paciencia
        interval: 60000
        onTriggered: raiz.atascado = true
    }
    onOpacityChanged: {
        if (opacity > 0) paciencia.restart()
        else { paciencia.stop(); atascado = false }
    }

    //  Se traga los clics mientras dura: pulsar cosas a mitad de una carga es
    //  cómo se encadenan operaciones que no deberían encadenarse.
    MouseArea {
        anchors.fill: parent
        enabled: raiz.opacity > 0 && !raiz.atascado
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        cursorShape: Qt.BusyCursor
        onWheel: (w) => w.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        color: C.Tema.oscuro ? "#66000000" : "#44000000"
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.max(200, cuerpo.implicitWidth + 40)
        height: cuerpo.implicitHeight + 32
        radius: 5
        color: C.Tema.superficie
        border.width: 1
        border.color: C.Tema.borde

        Column {
            id: cuerpo
            anchors.centerIn: parent
            spacing: 10

            C.Girito { anchors.horizontalCenter: parent.horizontalCenter }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: raiz.faena
                font.family: C.Tema.tipo
                font.pixelSize: C.Tema.letraGrande
                color: C.Tema.tinta
            }

            //  La barra sólo si hay algo que contar. Una barra que no avanza
            //  es peor que ninguna: parece que se ha parado.
            Rectangle {
                visible: raiz.avance > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: 170; height: 4
                radius: 2
                color: C.Tema.borde
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, raiz.avance))
                    height: parent.height
                    radius: parent.radius
                    color: C.Tema.acento
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }
            Text {
                visible: raiz.avance > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(raiz.avance * 100) + "%"
                font.family: C.Tema.tipoMono
                font.pixelSize: C.Tema.letraChica
                color: C.Tema.tenue
            }
            Text {
                visible: raiz.atascado
                anchors.horizontalCenter: parent.horizontalCenter
                width: 190
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "esto está tardando más de la cuenta; puedes seguir usando el programa"
                font.family: C.Tema.tipo
                font.pixelSize: C.Tema.letraChica
                color: C.Tema.aviso
            }
        }
    }
}

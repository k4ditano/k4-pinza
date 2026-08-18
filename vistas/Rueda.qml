//  La rueda de herramientas.
//
//  Botón derecho sostenido sobre el lienzo y las ocho herramientas más usadas
//  salen ALREDEDOR DEL CURSOR. Sueltas encima de una y la eliges. El ratón no
//  viaja: en un editor de píxeles cambias de herramienta cada pocos segundos, y
//  ese viaje de ida y vuelta al carril es, sumado, la mayor parte del recorrido
//  del día.

import QtQuick
import "../core" as C
import "../servicios" as S

Item {
    id: raiz
    anchors.fill: parent
    visible: abierta
    z: 850

    property bool abierta: false
    property real centroX: 0
    property real centroY: 0
    property int resaltado: -1
    readonly property real radio: 62

    readonly property var opciones: [
        { id: "lapiz", ico: "lapiz", nombre: "lápiz" },
        { id: "goma", ico: "goma", nombre: "goma" },
        { id: "cubo", ico: "cubo", nombre: "cubo" },
        { id: "sombreado", ico: "sombreado", nombre: "sombreado" },
        { id: "marco", ico: "marco", nombre: "marco" },
        { id: "varita", ico: "varita", nombre: "varita" },
        { id: "mover", ico: "mover", nombre: "mover" },
        { id: "linea", ico: "linea", nombre: "línea" }
    ]

    function abre(x, y) {
        centroX = x; centroY = y
        resaltado = -1
        abierta = true
    }

    /** Qué sector cae bajo el cursor. Fuera del centro muerto, siempre uno. */
    function apunta(x, y) {
        const dx = x - centroX, dy = y - centroY
        const d = Math.sqrt(dx * dx + dy * dy)
        if (d < 22) { resaltado = -1; return }        // centro muerto: cancelar
        let a = Math.atan2(dy, dx) * 180 / Math.PI + 90
        if (a < 0) a += 360
        resaltado = Math.floor(((a + 22.5) % 360) / 45)
    }

    function suelta() {
        if (resaltado >= 0 && resaltado < opciones.length)
            S.Pinceles.elige(opciones[resaltado].id)
        abierta = false
    }

    Rectangle {
        anchors.fill: parent
        color: "#40000000"
    }

    Repeater {
        model: raiz.opciones
        Rectangle {
            readonly property real ang: (index * 45 - 90) * Math.PI / 180
            x: raiz.centroX + Math.cos(ang) * raiz.radio - width / 2
            y: raiz.centroY + Math.sin(ang) * raiz.radio - height / 2
            width: 40; height: 40
            radius: 20
            color: raiz.resaltado === index ? C.Tema.acento : C.Tema.superficie
            border.width: 1
            border.color: raiz.resaltado === index ? C.Tema.acento
                        : S.Pinceles.herramienta === modelData.id ? C.Tema.acento2 : C.Tema.borde
            scale: raiz.resaltado === index ? 1.14 : 1
            Behavior on scale { NumberAnimation { duration: 70 } }

            C.Icono {
                anchors.centerIn: parent
                glifo: C.Tema.i[modelData.ico]
                font.pixelSize: 17
                color: raiz.resaltado === index ? C.Tema.fondo : C.Tema.tinta
            }
        }
    }

    // el nombre de lo que vas a elegir, en el centro
    Text {
        x: raiz.centroX - width / 2
        y: raiz.centroY - height / 2
        width: 90
        horizontalAlignment: Text.AlignHCenter
        text: raiz.resaltado >= 0 ? raiz.opciones[raiz.resaltado].nombre : ""
        font.family: C.Tema.tipo
        font.pixelSize: C.Tema.letra
        font.weight: Font.DemiBold
        color: C.Tema.acento
    }
}

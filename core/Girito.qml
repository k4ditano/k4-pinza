//  Un anillo de píxeles dando vueltas: «estoy en ello».
//
//  Ocho cuadrados y una fase que corre: nada de arcos suavizados, que en un
//  editor de pixel art desentonarían. Se para solo cuando no se ve, para no
//  gastar un repintado por fotograma en algo que nadie mira.

import QtQuick
import "." as C

Item {
    id: raiz
    property color color: C.Tema.acento
    property int lado: 4
    property real radio: 9

    implicitWidth: (radio + lado) * 2
    implicitHeight: implicitWidth

    property real fase: 0
    NumberAnimation on fase {
        from: 0; to: 8
        duration: 760
        loops: Animation.Infinite
        running: raiz.visible
    }

    Repeater {
        model: 8
        Rectangle {
            width: raiz.lado; height: raiz.lado
            x: raiz.width / 2 + Math.cos(index * Math.PI / 4) * raiz.radio - raiz.lado / 2
            y: raiz.height / 2 + Math.sin(index * Math.PI / 4) * raiz.radio - raiz.lado / 2
            color: raiz.color
            opacity: {
                const d = ((index - Math.floor(raiz.fase)) % 8 + 8) % 8
                return 1 - (d / 8) * 0.88
            }
        }
    }
}

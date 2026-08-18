//  La previa en juego.
//
//  Lo que importa no es cómo se ve el sprite al 800 % de zoom: es cómo se ve
//  donde va a vivir. Esto lo anima a ×1, ×2 y ×3 sobre un suelo, con su sombra
//  y —si el contrato lo pide— con las medidas que el juego saca de los píxeles
//  dibujadas encima.
//
//  Esas medidas son la parte que de verdad hace falta ver: crabh lee de la
//  imagen dónde apoyan los pies y cuánto mide la silueta, y de ahí salen el
//  radio de colisión y la altura a la que se pinta. Tres filas vacías de más
//  cambian dónde pisa el bicho, y en el lienzo eso no se nota.

import QtQuick
import "../core" as C
import "../core/pixeles.js" as P
import "../servicios" as S

C.Hoja {
    id: raiz
    titulo: "previa en juego"
    icono: C.Tema.i.juego

    //  Se recalcula al cambiar los píxeles, no por enlace: `compuesto()`
    //  escribe su caché, y un enlace que lo llame acaba dependiendo de lo que
    //  él mismo acaba de escribir. Qt lo cazaba como bucle y el efecto real
    //  era que el lienzo dejaba de repintarse.
    property var sil: null
    function mide() {
        sil = S.Documento.abierto ? P.silueta(S.Documento.compuesto()) : null
    }
    //  Con retardo: medir la silueta recorre el dibujo entero, y durante la
    //  reproducción eso cae en cada fotograma.
    Timer { id: posa; interval: 120; onTriggered: raiz.mide() }
    Component.onCompleted: mide()
    Connections {
        target: S.Documento
        function onRevPixelesChanged() { posa.restart() }
        function onRevChanged() { posa.restart() }
    }

    Column {
        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width
            height: 96
            radius: 3
            color: "#3E5410"          // un verde de suelo, no el fondo del editor
            clip: true

            // unas motas, para que se vea el tamaño real contra algo
            Canvas {
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                onPaint: {
                    const g = getContext("2d")
                    g.clearRect(0, 0, width, height)
                    g.fillStyle = "#4A6318"
                    for (let i = 0; i < 90; i++) {
                        const x = (i * 37) % width, y = (i * 53) % height
                        g.fillRect(x, y, 2, 2)
                    }
                }
                Component.onCompleted: requestPaint()
            }

            Row {
                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    model: [1, 2, 3]
                    Item {
                        readonly property int esc: modelData
                        width: S.Documento.ancho * esc
                        height: 80
                        anchors.verticalCenter: parent.verticalCenter

                        // la sombra, a los pies
                        Rectangle {
                            visible: raiz.sil !== null
                            width: raiz.sil ? raiz.sil.base * 2 * esc : 0
                            height: Math.max(2, width * 0.42)
                            radius: height / 2
                            color: "#40000000"
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: pieza.y + pieza.height - (raiz.sil ? raiz.sil.pieBajo * esc : 0) - height / 2
                        }

                        Canvas {
                            id: pieza
                            width: S.Documento.ancho
                            height: S.Documento.alto
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: (80 - S.Documento.alto * esc) / 2
                            transformOrigin: Item.Top
                            scale: esc
                            smooth: false
                            renderStrategy: Canvas.Cooperative
                            renderTarget: Canvas.Image

                            onPaint: {
                                if (!S.Documento.abierto) return
                                const g = getContext("2d")
                                g.clearRect(0, 0, width, height)
                                const b = S.Documento.compuesto(S.Documento.fotograma,
                                                                S.Documento.orientacion)
                                if (!b) return
                                const img = g.createImageData(b.w, b.h)
                                for (let i = 0; i < b.d.length; i++) img.data[i] = b.d[i]
                                g.putImageData(img, 0, 0, 0, 0, b.w, b.h)
                            }
                            Connections {
                                target: S.Documento
                                function onRevPixelesChanged() { pieza.requestPaint() }
                                function onRevChanged() { pieza.requestPaint() }
                            }
                        }

                        Text {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "×" + esc
                            font.family: C.Tema.tipoMono
                            font.pixelSize: 9
                            color: "#A0FFFFFF"
                        }
                    }
                }
            }
        }

        // ── las medidas que el juego saca de los píxeles ─────────
        Grid {
            width: parent.width
            columns: 2
            rowSpacing: 1
            columnSpacing: 4
            visible: raiz.sil !== null

            Text { text: "pie bajo"; width: 78
                   font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue }
            Text { text: raiz.sil ? raiz.sil.pieBajo + " px vacíos" : ""
                   font.family: C.Tema.tipoMono; font.pixelSize: 10
                   color: raiz.sil && raiz.sil.pieBajo > 4 ? C.Tema.aviso : C.Tema.tinta }

            Text { text: "medio ancho"; width: 78
                   font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue }
            Text { text: raiz.sil ? raiz.sil.medioAncho.toFixed(1) + " px" : ""
                   font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta }

            Text { text: "radio de base"; width: 78
                   font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue }
            Text { text: raiz.sil ? raiz.sil.base.toFixed(1) + " px" : ""
                   font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta }

            Text { text: "ocupa"; width: 78
                   font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue }
            Text { text: raiz.sil && raiz.sil.limites
                         ? raiz.sil.limites.w + "×" + raiz.sil.limites.h + " de "
                           + S.Documento.ancho + "×" + S.Documento.alto : "nada dibujado"
                   font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta }
        }

        Text {
            width: parent.width
            visible: raiz.sil !== null && raiz.sil.pieBajo > 4
            text: "hay " + (raiz.sil ? raiz.sil.pieBajo : 0)
                  + " filas vacías bajo la figura: en el juego pisará ahí arriba"
            wrapMode: Text.WordWrap
            font.family: C.Tema.tipo
            font.pixelSize: 10
            color: C.Tema.aviso
        }

        C.Interruptor {
            width: parent.width
            etiqueta: "medidas sobre el lienzo"
            valor: S.Ajustes.medidasSilueta
            onCambiado: (v) => S.Ajustes.medidasSilueta = v
        }
    }
}

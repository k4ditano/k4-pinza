//  El mapa de prueba.
//
//  Un tileset no se juzga mirando la hoja: se juzga viéndolo repartido por un
//  campo, que es donde salen las costuras y donde se ve que la flor que parecía
//  bonita, puesta cada tres casillas, convierte el prado en una alfombra.
//
//  El reparto NO está inventado. Es el que hace crabh en src/render/terrain.ts,
//  copiado a propósito: sólo se consideran las celdas totalmente opacas y que no
//  sean blancas —los bloques traen separadores en blanco—, se ordenan por
//  varianza de luminancia, el 40 % más plano es suelo base y el resto son
//  variantes que se salpican. Si aquí se ve bien, allí se ve bien; si aquí sale
//  una alfombra, allí también.

import QtQuick
import "../core" as C
import "../core/pixeles.js" as P
import "../servicios" as S

C.Hoja {
    id: raiz
    titulo: "mapa de prueba"
    icono: C.Tema.i.baldosa

    readonly property var con: S.Documento.d ? S.Documento.d.contrato : null
    readonly property int lado: con && con.rejilla ? con.rejilla.ancho : 24
    property int semilla: 7

    /** El bloque de suelo que declara el contrato, o el último si no lo dice. */
    readonly property var bloqueSuelo: {
        if (!con || !con.bloques || !con.bloques.length) return null
        for (let i = 0; i < con.bloques.length; i++)
            if (con.bloques[i].titulo === "suelo") return con.bloques[i]
        return con.bloques[con.bloques.length - 1]
    }

    property var base: []
    property var variantes: []

    /**
     * Clasifica las celdas del bloque de suelo, igual que el juego.
     *
     * Una celda que no está entera opaca es un borde de autotile, y estamparla
     * suelta deja un cuadrado del terreno de otro flotando en medio del campo.
     * Una casi blanca es un separador del bloque. Ninguna de las dos sirve como
     * suelo, y por eso se descartan antes de puntuar.
     */
    function clasifica() {
        base = []; variantes = []
        if (!S.Documento.abierto || !bloqueSuelo) return
        const b = S.Documento.compuesto()
        if (!b) return
        const puntuadas = []
        const filas = Math.floor(b.h / lado)

        for (let fila = 0; fila < filas; fila++)
        for (let col = bloqueSuelo.desde; col <= bloqueSuelo.hasta; col++) {
            const cel = P.recorte(b, col * lado, fila * lado, lado, lado)
            let opacos = 0, blancos = 0, suma = 0, sumaCuad = 0
            const n = lado * lado
            for (let i = 0; i < n; i++) {
                const r = cel.d[i*4], g = cel.d[i*4+1], az = cel.d[i*4+2], a = cel.d[i*4+3]
                if (a > 250) opacos++
                if (r > 245 && g > 245 && az > 245) blancos++
                const l = 0.299 * r + 0.587 * g + 0.114 * az
                suma += l; sumaCuad += l * l
            }
            if (opacos !== n || blancos >= n * 0.9) continue
            const media = suma / n
            puntuadas.push({ celda: cel, varianza: sumaCuad / n - media * media })
        }

        if (!puntuadas.length) return
        puntuadas.sort((x, y) => x.varianza - y.varianza)
        const corte = Math.max(1, Math.ceil(puntuadas.length * 0.4))
        base = puntuadas.slice(0, corte).map((x) => x.celda)
        variantes = puntuadas.slice(corte).map((x) => x.celda)
    }

    Timer { id: espera; interval: 300; onTriggered: { raiz.clasifica(); campo.requestPaint() } }
    Component.onCompleted: espera.start()
    Connections {
        target: S.Documento
        function onRevPixelesChanged() { espera.restart() }
        function onRevChanged() { espera.restart() }
    }

    Column {
        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width
            height: 132
            radius: 3
            color: C.Tema.fondo
            clip: true

            Canvas {
                id: campo
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                renderTarget: Canvas.Image

                onPaint: {
                    const g = getContext("2d")
                    g.clearRect(0, 0, width, height)
                    if (!raiz.base.length) return

                    const cols = Math.ceil(width / raiz.lado) + 1
                    const filas = Math.ceil(height / raiz.lado) + 1
                    const img = g.createImageData(raiz.lado, raiz.lado)

                    for (let y = 0; y < filas; y++) for (let x = 0; x < cols; x++) {
                        // Un hash y no un aleatorio: el mapa tiene que ser el
                        // mismo cada vez que se repinta, o mirarlo mientras
                        // dibujas sería un parpadeo constante.
                        let h = (x * 374761393 + y * 668265263 + raiz.semilla * 2654435761) | 0
                        h = (h ^ (h >>> 13)) * 1274126177 | 0
                        h = (h ^ (h >>> 16)) >>> 0

                        const salpica = raiz.variantes.length && (h % 11) === 0
                        const lista = salpica ? raiz.variantes : raiz.base
                        const cel = lista[h % lista.length]
                        for (let i = 0; i < cel.d.length; i++) img.data[i] = cel.d[i]
                        // la de siete, como en todas partes
                        g.putImageData(img, x * raiz.lado, y * raiz.lado,
                                       0, 0, raiz.lado, raiz.lado)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !raiz.base.length
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: raiz.bloqueSuelo
                      ? "ninguna casilla del bloque de suelo vale todavía: tienen que estar\nenteras opacas y no ser blancas"
                      : "este documento no declara bloques de tileset"
                font.family: C.Tema.tipo
                font.pixelSize: 10
                color: C.Tema.apagado
            }
        }

        Row {
            width: parent.width
            spacing: 8
            Text {
                text: raiz.base.length + " base"
                font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.bien
            }
            Text {
                text: raiz.variantes.length + " variantes"
                font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.acento
            }
            Item { width: parent.width - 190; height: 1 }
            C.Boton {
                icono: C.Tema.i.girar
                width: 22; implicitHeight: 20
                pista: "otro reparto"
                onPulsado: { raiz.semilla++; campo.requestPaint() }
            }
        }

        Text {
            width: parent.width
            text: "el 40 % de casillas más planas se usa como suelo y el resto se salpica, "
                  + "que es exactamente lo que hace el juego"
            wrapMode: Text.WordWrap
            font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
        }
    }
}

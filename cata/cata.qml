//  Fase 0 — la cata.
//
//  Ocho cosas que PARECÍAN que iban a funcionar. Dos no lo hacían, y por eso
//  esto existe: los dos hallazgos de abajo son la razón de que el lienzo esté
//  escrito como está, así que la cata se queda como prueba permanente. Si
//  algún día Qt arregla lo suyo, esto lo dirá antes de que nos enteremos por
//  un sprite corrupto.
//
//      QT_QPA_PLATFORM=offscreen qs -p cata/cata.qml
//
//  HALLAZGO 1 · putImageData(img, x, y) NO HACE NADA. Se traga los píxeles
//  sin quejarse. La forma de siete argumentos —putImageData(img, x, y, 0, 0,
//  w, h)— sí funciona. Todo el motor de pintado usa esa y sólo esa.
//
//  HALLAZGO 1b · Y en la de siete, el ORIGEN SUCIO TIENE QUE SER (0,0).
//  Pasarle el lienzo entero con un rectángulo sucio en (10,10) tampoco pinta
//  nada, otra vez sin quejarse. Lo único que vale es recortar un ImageData del
//  tamaño de la zona sucia y colocarlo con dx,dy. Esto costó caro: el lienzo
//  repintaba por zona sucia, así que un trazo no se veía nunca y aparecía de
//  golpe y desplazado cuando algo forzaba un repintado entero. "Dibujo y sale
//  al lado".
//
//  HALLAZGO 2 · Canvas.save(ruta) devuelve false y no escribe nada, con
//  cualquier estrategia y cualquier forma de ruta. toDataURL() sí funciona,
//  así que exportar es toDataURL -> base64 -> la forja escribe el fichero.

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: raiz

    property int hechas: 0
    property int rotas: 0
    readonly property int total: 11

    function ck(que, bien, detalle) {
        if (!bien) rotas++
        console.log((bien ? " ok  " : "FALLO") + "  " + que + (detalle ? "   ── " + detalle : ""))
        hechas++
        if (hechas >= total) fin.restart()
    }

    Timer {
        id: fin
        interval: 300
        onTriggered: {
            console.log(rotas ? "\n" + rotas + " FALLOS de " + raiz.total
                              : "\nla cata pasa entera (" + raiz.total + ")")
            Qt.exit(rotas ? 1 : 0)
        }
    }
    Timer {
        interval: 20000; running: true
        onTriggered: { console.log("\nTIEMPO AGOTADO con " + raiz.hechas + "/" + raiz.total); Qt.exit(1) }
    }

    FloatingWindow {
        implicitWidth: 200; implicitHeight: 120
        visible: true

        Canvas {
            id: lienzo
            width: 24; height: 24
            renderStrategy: Canvas.Immediate
            renderTarget: Canvas.Image
            property bool ya: false

            onPaint: {
                if (ya) return
                ya = true
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, 24, 24)

                raiz.ck("1 · el motor de QML trae Uint8ClampedArray",
                        typeof Uint8ClampedArray === "function"
                        && new Uint8ClampedArray(4).length === 4)

                const img = ctx.createImageData(24, 24)
                raiz.ck("2 · createImageData da un búfer del tamaño pedido",
                        img.width === 24 && img.height === 24 && img.data.length === 24 * 24 * 4,
                        img.width + "x" + img.height + " · " + img.data.length + " bytes")

                for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++) {
                    const i = (y * 24 + x) * 4
                    img.data[i] = 214; img.data[i + 1] = 108; img.data[i + 2] = 52
                    img.data[i + 3] = (x < 12) ? 255 : 0
                }

                // Lo que NO funciona, comprobado para que no se nos olvide.
                const testigo = ctx.createImageData(2, 2)
                for (let i = 0; i < 16; i += 4) {
                    testigo.data[i] = 1; testigo.data[i+1] = 2; testigo.data[i+2] = 3; testigo.data[i+3] = 255
                }
                ctx.putImageData(testigo, 0, 0)
                const t = ctx.getImageData(0, 0, 1, 1).data
                raiz.ck("3 · putImageData de 3 argumentos sigue sin hacer nada (hallazgo 1)",
                        !(t[0] === 1 && t[1] === 2 && t[2] === 3),
                        t[0] === 1 ? "¡lo han arreglado! se puede simplificar el lienzo" : "confirmado, se usa la de 7")

                ctx.putImageData(img, 0, 0, 0, 0, 24, 24)
                const izq = ctx.getImageData(3, 3, 1, 1).data
                const der = ctx.getImageData(20, 3, 1, 1).data
                raiz.ck("4 · putImageData de 7 argumentos pinta el lienzo entero",
                        izq[0] === 214 && izq[1] === 108 && izq[2] === 52 && izq[3] === 255,
                        "rgba(" + izq[0] + "," + izq[1] + "," + izq[2] + "," + izq[3] + ")")
                raiz.ck("5 · el alfa cero sobrevive a la ida y vuelta",
                        der[3] === 0, "alfa=" + der[3])

                const parche = ctx.createImageData(4, 4)
                for (let i = 0; i < 64; i += 4) {
                    parche.data[i] = 118; parche.data[i+1] = 193; parche.data[i+2] = 56; parche.data[i+3] = 255
                }
                ctx.putImageData(parche, 16, 16, 0, 0, 4, 4)
                const q = ctx.getImageData(17, 17, 1, 1).data
                raiz.ck("6 · un parche pequeño cae donde se le dice (el caso de un trazo)",
                        q[0] === 118 && q[1] === 193 && q[2] === 56, "en (17,17)")

                // Lo de arriba, comprobado al revés: la forma que NO vale.
                ctx.clearRect(0, 0, 24, 24)
                const entero = ctx.createImageData(24, 24)
                const k = (10 * 24 + 10) * 4
                entero.data[k] = 255; entero.data[k+3] = 255
                ctx.putImageData(entero, 0, 0, 10, 10, 1, 1)
                raiz.ck("7 · el origen sucio distinto de (0,0) sigue sin pintar (hallazgo 1b)",
                        ctx.getImageData(10, 10, 1, 1).data[3] === 0,
                        ctx.getImageData(10, 10, 1, 1).data[3] === 0
                            ? "confirmado, hay que recortar la zona sucia"
                            : "¡lo han arreglado! el lienzo se puede simplificar")

                // y la que sí: un recorte pequeño colocado en su sitio
                ctx.clearRect(0, 0, 24, 24)
                const trozo = ctx.createImageData(2, 2)
                for (let i = 0; i < 4; i++) { trozo.data[i*4+1] = 255; trozo.data[i*4+3] = 255 }
                ctx.putImageData(trozo, 9, 13, 0, 0, 2, 2)
                const puesto = ctx.getImageData(9, 13, 1, 1).data
                const alLado = ctx.getImageData(8, 13, 1, 1).data
                raiz.ck("8 · un recorte colocado con dx,dy sí cae donde se le dice",
                        puesto[1] === 255 && alLado[3] === 0,
                        "en (9,13) alfa " + puesto[3] + ", en (8,13) alfa " + alLado[3])

                raiz.ck("9 · Canvas.save() sigue sin escribir nada (hallazgo 2)",
                        save("/tmp/pinza-cata-save.png") === false,
                        "si esto falla, save() ya vale y exportar se simplifica")

                salida.url = toDataURL("image/png")
                escribir.running = true
            }
            Component.onCompleted: requestPaint()
        }

        ShaderEffectSource {
            id: fuente
            sourceItem: lienzo
            live: true; smooth: false; hideSource: true
            width: 24; height: 24
            Component.onCompleted: raiz.ck("10 · ShaderEffectSource escala sin suavizar",
                                           !smooth && sourceItem === lienzo)
        }
    }

    QtObject { id: salida; property string url: "" }

    Process {
        id: escribir
        command: ["python3", "-c",
            "import sys,base64,struct\n" +
            "b=base64.b64decode(sys.stdin.read().split(',',1)[1])\n" +
            "w,h=struct.unpack('>II',b[16:24])\n" +
            "print('%d %d %d'%(w,h,b[25]))"]
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim().split(" ")
                raiz.ck("11 · toDataURL da un PNG RGBA del tamaño exacto (así se exporta)",
                        t[0] === "24" && t[1] === "24" && t[2] === "6",
                        t[0] + "x" + t[1] + " tipo de color " + t[2])
            }
        }
        onRunningChanged: if (running) { write(salida.url); write("\n"); stdinEnabled = false }
    }

    PersistentProperties {
        id: memoria
        reloadableId: "cata"
        property int veces: 0
    }
    Component.onCompleted: {
        // Sin esto, guardar un .qml mientras dibujas se lleva el dibujo.
        memoria.veces = memoria.veces + 1
    }
}

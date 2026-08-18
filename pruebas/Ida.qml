//  La ida y la vuelta enteras.
//
//  Dibujar -> guardar -> abrir -> exportar, y comprobar con los píxeles en la
//  mano que nada se perdió por el camino. Es la prueba que de verdad importa:
//  todo lo demás puede estar bien y si el PNG que sale no es el que se ve, no
//  sirve de nada.
//
//  Necesita ventana porque el Exportador tiene un Canvas, y un Canvas fuera de
//  la escena nunca llega a pintar.

import QtQuick
import Quickshell
import Quickshell.Io
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property string tmp: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-prueba"
    readonly property string proyecto: tmp + "/Bicho.pinza"

    FloatingWindow {
        implicitWidth: 300; implicitHeight: 200
        visible: true
        V.Exportador { id: exportador }
        Component.onCompleted: { S.Proyecto.exportador = exportador; arranca.start() }
    }

    Timer { id: arranca; interval: 300; onTriggered: raiz.paso1() }

    property var huellaOriginal: null

    // ── 1 · dibujar algo con capas, fotogramas y orientaciones ───
    function paso1() {
        S.Documento.nuevo({ nombre: "Bicho", ancho: 16, alto: 16,
                            fotogramas: 2, orientaciones: ["S", "E"] })
        const c0 = S.Documento.capa(0)
        S.Documento.añadeCapa("brillo")
        const c1 = S.Documento.capa(1)
        c1.opacidad = 0.5
        c1.modo = "trama"

        // un cuerpo distinto en cada (fotograma, orientación)
        for (let f = 0; f < 2; f++) for (let d = 0; d < 2; d++) {
            const b = S.Documento.celda(c0.id, f, d, true)
            for (let y = 4 + f; y < 12; y++) for (let x = 3 + d * 2; x < 12; x++)
                P.pon(b, x, y, [214 - f * 40, 108, 52 + d * 60, 255])
        }
        const br = S.Documento.celda(c1.id, 0, 0, true)
        for (let x = 3; x < 12; x++) P.pon(br, x, 4, [255, 255, 255, 255])

        S.Documento.ponDuracion(0, 8)
        S.Documento.ponDuracion(1, 12)
        S.Documento.ponCampo("family", "fire")
        S.Documento.cambiaPixeles(null)

        huellaOriginal = P.clonar(S.Documento.compuesto(0, 0))
        ck("hay algo dibujado", !P.vacio(huellaOriginal))

        S.Forja.creaCarpeta(tmp, () => S.Proyecto.guarda(proyecto, (bien) => {
            ck("guardar dice que sí", bien === true)
            paso2()
        }))
    }

    // ── 2 · los ficheros están donde deben ──────────────────────
    function paso2() {
        S.Forja.lista_(proyecto + "/celdas", "*.png", (r) => {
            ck("hay un PNG por celda propia", r.bien && r.ficheros.length === 8,
               (r.ficheros || []).length + " ficheros")
            const nombres = (r.ficheros || []).map((f) => f.nombre).sort()
            ck("los nombres dicen capa, fotograma y orientación",
               nombres.length > 0 && /^c\d+\.\d+\.\d+\.png$/.test(nombres[0]), nombres[0])
            S.Forja.leeTexto(proyecto + "/proyecto.json", (t) => {
                let m = null
                try { m = JSON.parse(t.texto) } catch (e) {}
                ck("el proyecto.json es legible", m !== null)
                ck("y guarda los tres ejes",
                   m && m.capas.length === 2 && m.fotogramas.length === 2
                   && m.orientaciones.length === 2)
                ck("y las duraciones en tics", m && m.fotogramas[1].duracion === 12,
                   m ? m.fotogramas[1].duracion : "?")
                ck("y los campos del contrato", m && m.campos.family === "fire")
                paso3()
            })
        })
    }

    // ── 3 · cerrar del todo y volver a abrir ────────────────────
    function paso3() {
        S.Documento.cerrar()
        S.Historial.limpia()
        ck("cerrado", !S.Documento.abierto)
        S.Proyecto.abre(proyecto, (bien) => {
            ck("abrir dice que sí", bien === true)
            ck("vuelven las dos capas", S.Documento.nCapas === 2, S.Documento.nCapas)
            ck("vuelven los dos fotogramas", S.Documento.nFotogramas === 2)
            ck("vuelven las dos orientaciones", S.Documento.nOrientaciones === 2)
            ck("vuelve la opacidad de la capa", S.Documento.capa(1).opacidad === 0.5)
            ck("vuelve el modo de fusión", S.Documento.capa(1).modo === "trama")
            ck("vuelven las duraciones", S.Documento.duracion(1) === 12)
            ck("vuelve el nombre", S.Documento.nombre === "Bicho")

            const ahora = S.Documento.compuesto(0, 0)
            let iguales = 0, distintos = 0
            for (let i = 0; i < ahora.d.length; i += 4) {
                const mismo = ahora.d[i] === huellaOriginal.d[i]
                           && ahora.d[i+1] === huellaOriginal.d[i+1]
                           && ahora.d[i+2] === huellaOriginal.d[i+2]
                           && ahora.d[i+3] === huellaOriginal.d[i+3]
                if (mismo) iguales++; else distintos++
            }
            ck("y los PÍXELES son exactamente los mismos", distintos === 0,
               distintos + " píxeles distintos de " + (iguales + distintos))

            // que las otras celdas también volvieron, no sólo la primera
            const otra = S.Documento.compuesto(1, 1)
            ck("la celda del segundo fotograma y la otra cara también vuelve",
               !P.vacio(otra) && P.lee(otra, 6, 6)[2] === 112, P.lee(otra, 6, 6).join())
            paso4()
        })
    }

    // ── 4 · exportar como hoja y comprobar el PNG de fuera ──────
    function paso4() {
        S.Documento.d.contrato = {
            salida: { modo: "hoja", disposicion: "orientaciones-en-filas",
                      carpeta: "", patron: "{nombre}.{fotogramas}.png" }
        }
        S.Proyecto.exporta({ carpeta: tmp, manifiesto: false }, (escritos) => {
            ck("exportar escribe un fichero", escritos.length === 1, escritos.join())
            ck("y el nombre lleva los fotogramas dentro",
               escritos[0].indexOf("Bicho.2.png") > 0, escritos[0])
            comprueba.running = true
        })
    }

    // Se mira desde FUERA, con Pillow: que la hoja mida columnas×filas y que
    // el píxel de cada celda sea el que se dibujó.
    Process {
        id: comprueba
        command: ["python3", "-c",
            "import sys\n" +
            "from PIL import Image\n" +
            "im = Image.open(sys.argv[1]).convert('RGBA')\n" +
            "print(im.size[0], im.size[1], *im.getpixel((6,6)), *im.getpixel((22,22)))",
            raiz.tmp + "/Bicho.2.png"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\s+/).map(Number)
                raiz.ck("la hoja mide 2 columnas × 2 filas de 16",
                        v[0] === 32 && v[1] === 32, v[0] + "×" + v[1])
                raiz.ck("la celda (0,0) tiene su color",
                        v[2] === 214 && v[4] === 52, v.slice(2, 6).join(","))
                raiz.ck("la celda (1,1) tiene el suyo, distinto",
                        v[6] === 174 && v[8] === 112, v.slice(6, 10).join(","))
                fin.start()
            }
        }
    }

    Timer { id: fin; interval: 200; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\nla ida y la vuelta pasan enteras")
        Qt.exit(raiz.malas ? 1 : 0) } }
    Timer { interval: 40000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

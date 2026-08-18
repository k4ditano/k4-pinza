//  La integración con crabh, de verdad.
//
//  Se exporta con cada perfil del pack y se comprueba desde FUERA que salió lo
//  que el juego espera: el nombre del fichero, la rejilla de la hoja, la
//  entrada del manifiesto y el AnimData.xml. Es la parte que hoy se hace a mano
//  después de exportar, y por tanto la que más falta hace comprobar.
//
//  Contra una copia en /run, nunca contra el repositorio de verdad.

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

    readonly property string base: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-crabh"

    FloatingWindow {
        implicitWidth: 300; implicitHeight: 200
        visible: true
        V.Exportador { id: exportador }
        Component.onCompleted: S.Proyecto.exportador = exportador
    }

    Connections {
        target: S.Packs
        function onCargadosCambiaron() { arranca.start() }
    }
    Timer { id: arranca; interval: 200; onTriggered: raiz.paso1() }

    function pinta(w, h, color) {
        const b = S.Documento.celdaActiva(true)
        for (let y = 2; y < h - 2; y++) for (let x = 2; x < w - 2; x++) P.pon(b, x, y, color)
        S.Documento.cambiaPixeles(null)
    }

    // ── 1 · un mueble de cuatro caras ───────────────────────────
    function paso1() {
        S.Packs.elige("crabh")
        S.Packs.apunta("crabh", base)
        ck("el pack de crabh está y se le puede reapuntar la raíz",
           S.Packs.activoId === "crabh" && S.Proyecto.raizPack() === base, S.Proyecto.raizPack())

        const con = S.Packs.contrato("objeto")
        S.Documento.nuevo(S.Packs.paraDocumento(con, { nombre: "Prueba_Banco" }))
        S.Documento.ponCampo("family", "ground")
        S.Documento.ponCampo("desc", "un banco de prueba")
        S.Documento.ponHuella(1, 2)
        ck("el mueble nace con cuatro orientaciones", S.Documento.nOrientaciones === 4)
        ck("y con la rejilla de casilla del contrato",
           S.Ajustes.casillaAncho === 16, S.Ajustes.casillaAncho)

        for (let d = 0; d < 4; d++) {
            S.Documento.orientacion = d
            pinta(32, 32, [90 + d * 40, 120, 70, 255])
        }
        S.Documento.orientacion = 0

        S.Proyecto.exporta({}, (escritos) => {
            ck("exporta un PNG por orientación", escritos.length === 4, escritos.length + " ficheros")
            const nombres = escritos.map((e) => e.split("/").pop()).sort()
            ck("con el sufijo de cada cara",
               nombres.join(" ") === "Prueba_Banco_E.png Prueba_Banco_N.png Prueba_Banco_S.png Prueba_Banco_W.png",
               nombres.join(" "))
            ck("en la carpeta que dice el contrato",
               escritos[0].indexOf(base + "/assets/object/") === 0, escritos[0])
            Qt.callLater(paso2)
        })
    }

    // ── 2 · el manifiesto ───────────────────────────────────────
    function paso2() {
        S.Forja.leeTexto(base + "/assets/authored.json", (r) => {
            let m = null
            try { m = JSON.parse(r.texto) } catch (e) {}
            ck("el manifiesto existe y es JSON legible", m !== null)
            const e = m ? m.entries.filter((x) => x.name === "Prueba_Banco")[0] : null
            ck("y tiene la entrada del mueble", !!e)
            ck("con su kind", e && e.kind === "object", e ? e.kind : "?")
            ck("con la ruta relativa, como el resto del fichero",
               e && e.path === "object/Prueba_Banco_S.png", e ? e.path : "?")
            ck("con el lado", e && e.side === 32, e ? e.side : "?")
            ck("y con los campos que pide el contrato",
               e && e.family === "ground" && e.desc === "un banco de prueba")
            paso3()
        })
    }

    // ── 3 · un efecto de ocho fotogramas ────────────────────────
    function paso3() {
        const con = S.Packs.contrato("vfx")
        S.Documento.nuevo(S.Packs.paraDocumento(con, { nombre: "Prueba_Chispa", fotogramas: 8 }))
        S.Documento.ponCampo("family", "electric")
        ck("el efecto nace con ocho fotogramas", S.Documento.nFotogramas === 8)
        for (let f = 0; f < 8; f++) {
            S.Documento.fotograma = f
            pinta(48, 48, [239, 212, 9, 255])
        }
        S.Proyecto.exporta({}, (escritos) => {
            ck("el efecto sale en una sola hoja", escritos.length === 1, escritos.join())
            ck("y el número de fotogramas VA EN EL NOMBRE, que es de donde el juego saca la rejilla",
               escritos[0].split("/").pop() === "Prueba_Chispa.8.png", escritos[0].split("/").pop())
            miraHoja.command = ["python3", "-c", raiz.guionHoja, escritos[0], "8", "1", "48"]
            miraHoja.running = true
        })
    }

    readonly property string guionHoja:
        "import sys\n" +
        "from PIL import Image\n" +
        "im = Image.open(sys.argv[1])\n" +
        "cols, filas, lado = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])\n" +
        "print(im.size[0] == cols*lado and im.size[1] == filas*lado, im.size[0], im.size[1])"

    Process {
        id: miraHoja
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\s+/)
                raiz.ck("la hoja del efecto mide 8 columnas de 48",
                        v[0] === "True", v[1] + "×" + v[2])
                raiz.paso4()
            }
        }
    }

    // ── 4 · una criatura PMD con su AnimData ────────────────────
    function paso4() {
        const con = S.Packs.contrato("pmd")
        S.Documento.nuevo(S.Packs.paraDocumento(con, { nombre: "Prueba_Bicho", fotogramas: 4 }))
        S.Documento.ponCampo("accion", "Walk")
        S.Documento.ponCampo("hitFrame", 2)
        S.Documento.ponCampo("shadowSize", 2)
        ck("la criatura nace con las ocho filas de PMD", S.Documento.nOrientaciones === 8)
        ck("y en el orden que lee el juego",
           S.Documento.etiquetaOrientacion(0) === "Down"
           && S.Documento.etiquetaOrientacion(2) === "Right"
           && S.Documento.etiquetaOrientacion(7) === "DownLeft")

        S.Documento.ponDuracion(0, 5); S.Documento.ponDuracion(1, 7)
        S.Documento.ponDuracion(2, 5); S.Documento.ponDuracion(3, 9)
        for (let f = 0; f < 4; f++) for (let d = 0; d < 8; d++) {
            S.Documento.fotograma = f; S.Documento.orientacion = d
            pinta(40, 40, [200, 100 + d * 8, 60, 255])
        }

        S.Proyecto.exporta({}, (escritos) => {
            ck("la criatura sale en una hoja con el nombre de su acción",
               escritos.length === 1 && escritos[0].split("/").pop() === "Walk-Anim.png",
               escritos[0].split("/").pop())
            ck("en la carpeta de la especie",
               escritos[0].indexOf("/assets/species/Prueba_Bicho/") > 0, escritos[0])
            miraPmd.command = ["python3", "-c", raiz.guionHoja, escritos[0], "4", "8", "40"]
            miraPmd.running = true
        })
    }

    Process {
        id: miraPmd
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\s+/)
                raiz.ck("la hoja PMD es 4 columnas × 8 filas de 40",
                        v[0] === "True", v[1] + "×" + v[2])
                Qt.callLater(raiz.paso5)
            }
        }
    }

    // ── 5 · el AnimData.xml ─────────────────────────────────────
    function paso5() {
        S.Forja.leeTexto(base + "/assets/species/Prueba_Bicho/AnimData.xml", (r) => {
            const x = r.texto || ""
            ck("el AnimData.xml se escribe solo", x.length > 0)
            ck("con el nombre de la acción", x.indexOf("<Name>Walk</Name>") > 0)
            ck("con el tamaño de fotograma",
               x.indexOf("<FrameWidth>40</FrameWidth>") > 0 && x.indexOf("<FrameHeight>40</FrameHeight>") > 0)
            ck("con el fotograma de golpe", x.indexOf("<HitFrame>2</HitFrame>") > 0)
            ck("con el tamaño de sombra", x.indexOf("<ShadowSize>2</ShadowSize>") > 0)
            // las duraciones van en TICS tal cual, sin convertir a nada
            const dur = (x.match(/<Duration>(\d+)<\/Duration>/g) || [])
                        .map((s) => s.replace(/\D/g, "")).join(",")
            ck("y con las cuatro duraciones en tics, sin convertir", dur === "5,7,5,9", dur)

            // exportar dos veces no duplica la entrada del manifiesto
            S.Proyecto.exporta({}, () => Qt.callLater(paso6))
        })
    }

    function paso6() {
        S.Forja.leeTexto(base + "/assets/authored.json", (r) => {
            let m = null
            try { m = JSON.parse(r.texto) } catch (e) {}
            const cuantos = m ? m.entries.filter((x) => x.name === "Prueba_Chispa").length : -1
            ck("exportar dos veces no duplica la entrada del manifiesto", cuantos === 1, cuantos)
            const orden = m ? m.entries.map((x) => x.kind + "/" + x.name) : []
            ck("y el manifiesto queda ordenado", orden.join(" ") === orden.slice().sort().join(" "),
               orden.join(" "))
            fin.start()
        })
    }

    Timer { id: fin; interval: 200; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\ncrabh: la salida es la que el juego espera")
        Qt.exit(raiz.malas ? 1 : 0) } }
    Timer { interval: 60000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

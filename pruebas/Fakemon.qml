//  Una criatura nueva desde cero, y los efectos de sus ataques.
//
//  Lo que se comprueba de la plantilla en blanco no es que se cree —eso es
//  fácil— sino que nazca con la geometría PUESTA: cada acción con su tamaño,
//  sus fotogramas y sus duraciones en tics, y las ocho filas en su orden. Si
//  eso hay que teclearlo, la plantilla no sirve de nada.
//
//  Y de los ataques, que el NOMBRE del fichero salga bien: el juego saca de él
//  la rejilla, así que «Nombre.8.png» y «Nombre.Dir8.png» se leen distinto y
//  equivocarse no da error, da un efecto que se reproduce a trozos.

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

    readonly property string base: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-fake"

    FloatingWindow {
        implicitWidth: 300; implicitHeight: 200
        visible: true
        V.Exportador { id: ex }
        Component.onCompleted: { S.Proyecto.exportador = ex; S.Especie.exportador = ex }
    }

    Connections {
        target: S.Packs
        function onCargadosCambiaron() { arranca.start() }
    }
    Timer { id: arranca; interval: 200; onTriggered: raiz.paso1() }
    Connections {
        target: S.Especie
        function onFalla(q, m) { console.log("   (falla " + q + ": " + m + ")") }
    }

    function pinta(w, h, color) {
        const b = S.Documento.celdaActiva(true)
        for (let y = 2; y < h - 2; y++) for (let x = 2; x < w - 2; x++) P.pon(b, x, y, color)
        S.Documento.cambiaPixeles(null)
    }

    // ── 1 · una criatura en blanco ──────────────────────────────
    function paso1() {
        S.Packs.elige("crabh")
        S.Packs.apunta("crabh", base)

        S.Especie.nueva({ nombre: "Cangrejito", dex: 10500, role: "crab", shadowSize: 2 })
        ck("nace con las ocho acciones", Object.keys(S.Especie.d.acciones).length === 8,
           Object.keys(S.Especie.d.acciones).join(" "))

        //  Lo importante: que la geometría venga puesta, no en blanco
        const at = S.Especie.d.acciones.Attack
        ck("Attack nace con su tamaño, sus fotogramas y su duración",
           at.ancho === 48 && at.fotogramas === 4 && at.duraciones.join() === "6,6,6,6",
           at.ancho + "×" + at.alto + " · " + at.fotogramas + " fot · " + at.duraciones.join())
        ck("y con sus fotogramas de golpe y embestida ya marcados",
           at.hitFrame === 1 && at.rushFrame === 0 && at.returnFrame === 2,
           "golpe " + at.hitFrame + " embestida " + at.rushFrame + " retorno " + at.returnFrame)
        const sl = S.Especie.d.acciones.Sleep
        ck("y dormir dura mucho más que atacar, como debe",
           sl.duraciones[0] > at.duraciones[0] * 4, sl.duraciones.join())
        ck("ninguna está hecha todavía",
           Object.keys(S.Especie.d.acciones).every((k) => !S.Especie.d.acciones[k].hecha))

        S.Especie.guarda(base + "/Cangrejito.especie", (bien) => {
            ck("la especie se guarda", bien === true)
            paso2()
        })
    }

    // ── 2 · dibujar una acción y exportar ───────────────────────
    function paso2() {
        S.Especie.editaAccion("Attack", (bien) => {
            ck("una acción en blanco se abre lista para dibujar", bien === true)
            ck("con el lienzo del tamaño que dice su ficha",
               S.Documento.ancho === 48 && S.Documento.alto === 48,
               S.Documento.ancho + "×" + S.Documento.alto)
            ck("con las ocho filas en el orden de PMD",
               S.Documento.nOrientaciones === 8
               && S.Documento.etiquetaOrientacion(0) === "Down"
               && S.Documento.etiquetaOrientacion(4) === "Up")
            ck("y con las duraciones ya en tics",
               S.Documento.duracion(0) === 6 && S.Documento.nFotogramas === 4)
            ck("el fotograma de golpe llega al documento",
               S.Documento.campo("hitFrame") === 1, S.Documento.campo("hitFrame"))
            ck("y sabe de qué especie es", S.Especie.accion === "Attack")

            // dibujar en las ocho, para que la hoja salga entera
            const capa = S.Documento.capa(0)
            for (let d = 0; d < 8; d++) for (let f = 0; f < 4; f++) {
                const b = S.Documento.celda(capa.id, f, d, true)
                for (let y = 10; y < 38; y++) for (let x = 10 + d; x < 38; x++)
                    P.pon(b, x, y, [200, 100 + d * 6, 60, 255])
            }
            S.Documento.cambiaPixeles(null)
            S.Proyecto.guarda(null, () => {
                S.Especie.recogeDelDocumento()
                ck("y al recogerla, la ficha se entera de que ya está hecha",
                   S.Especie.d.acciones.Attack.hecha === true)
                S.Especie.exporta(() => { miraCriatura.running = true })
            })
        })
    }

    Process {
        id: miraCriatura
        command: ["python3", "-c",
            "import sys, os, json, re\n" +
            "from PIL import Image\n" +
            "c = os.path.join(sys.argv[1], 'assets/species/Cangrejito')\n" +
            "x = open(os.path.join(c, 'AnimData.xml')).read()\n" +
            "im = Image.open(os.path.join(c, 'Attack-Anim.png'))\n" +
            "f = json.load(open(os.path.join(sys.argv[1], 'assets/species/Cangrejito.json')))\n" +
            "print(json.dumps({'hoja': list(im.size), 'sombra': int(re.search(r'<ShadowSize>(.)</ShadowSize>', x).group(1)),\n" +
            "  'golpe': int(re.search(r'<HitFrame>(.)</HitFrame>', x).group(1)),\n" +
            "  'rol': f['role'], 'dex': f['dex']}))", raiz.base]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null
                try { r = JSON.parse(text.trim()) } catch (e) {}
                if (!r) { raiz.ck("la criatura nueva sale a fichero", false, text.trim().slice(0, 200)); raiz.paso3(); return }
                raiz.ck("la hoja de Attack es 4 columnas × 8 filas de 48",
                        r.hoja[0] === 192 && r.hoja[1] === 384, r.hoja.join("×"))
                raiz.ck("con el fotograma de golpe en el XML", r.golpe === 1, r.golpe)
                raiz.ck("y la sombra que le pusimos", r.sombra === 2, r.sombra)
                raiz.ck("la ficha conserva el papel y el dex",
                        r.rol === "crab" && r.dex === 10500, r.rol + " " + r.dex)
                raiz.paso3()
            }
        }
    }

    // ── 3 · un efecto de ataque, en tira ────────────────────────
    function paso3() {
        S.Especie.cierra()
        const con = S.Packs.contrato("ataque")
        ck("el pack trae un perfil para los efectos de ataque", con !== null)
        ck("con el sitio y el nombre que el juego espera",
           con && con.salida.carpeta === "assets/vfx", con ? con.salida.carpeta : "?")

        S.Documento.nuevo(S.Packs.paraDocumento(con, { nombre: "Mordisco_Feroz", fotogramas: 8 }))
        S.Documento.ponCampo("family", "dark")
        S.Documento.ponCampo("movimiento", "bite")
        ck("un efecto nace con ocho fotogramas y una sola orientación",
           S.Documento.nFotogramas === 8 && S.Documento.nOrientaciones === 1)
        for (let f = 0; f < 8; f++) { S.Documento.fotograma = f; pinta(48, 48, [66, 66, 132, 255]) }

        S.Proyecto.exporta({}, (escritos) => {
            ck("sale un fichero", escritos.length === 1, escritos.join())
            ck("y el número de fotogramas va en el NOMBRE, que es de donde el juego saca la rejilla",
               escritos[0].split("/").pop() === "Mordisco_Feroz.8.png",
               escritos[0].split("/").pop())
            paso4()
        })
    }

    // ── 4 · y otro que apunta, con sus ocho direcciones ─────────
    function paso4() {
        const con = S.Packs.contrato("ataque")
        S.Documento.nuevo(S.Packs.paraDocumento(con, {
            nombre: "Rayo_Guiado", fotogramas: 4,
            orientaciones: ["Down","DownRight","Right","UpRight","Up","UpLeft","Left","DownLeft"]
        }))
        S.Documento.ponCampo("family", "electric")
        for (let d = 0; d < 8; d++) for (let f = 0; f < 4; f++) {
            S.Documento.orientacion = d; S.Documento.fotograma = f
            pinta(48, 48, [239, 212, 9, 255])
        }
        S.Proyecto.exporta({}, (escritos) => {
            ck("un efecto que apunta sale con el nombre de direcciones",
               escritos[0].split("/").pop() === "Rayo_Guiado.Dir8.png",
               escritos[0].split("/").pop())
            miraEfectos.running = true
        })
    }

    Process {
        id: miraEfectos
        command: ["python3", "-c",
            "import sys, os, json\n" +
            "from PIL import Image\n" +
            "v = os.path.join(sys.argv[1], 'assets/vfx')\n" +
            "a = Image.open(os.path.join(v, 'Mordisco_Feroz.8.png'))\n" +
            "b = Image.open(os.path.join(v, 'Rayo_Guiado.Dir8.png'))\n" +
            "m = json.load(open(os.path.join(sys.argv[1], 'assets/authored.json')))\n" +
            "e = {x['name']: x for x in m['entries']}\n" +
            "print(json.dumps({'tira': list(a.size), 'dirs': list(b.size),\n" +
            "  'manif': sorted(e.keys()),\n" +
            "  'mordisco': {k: e['Mordisco_Feroz'].get(k) for k in ('kind','frames','family','movimiento','path')}}))",
            raiz.base]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null
                try { r = JSON.parse(text.trim()) } catch (e) {}
                if (!r) { raiz.ck("los efectos salen a fichero", false, text.trim().slice(0, 200)); fin.start(); return }
                raiz.ck("la tira son 8 columnas de 48 en una fila",
                        r.tira[0] === 384 && r.tira[1] === 48, r.tira.join("×"))
                raiz.ck("y el que apunta son 4 columnas por 8 filas",
                        r.dirs[0] === 192 && r.dirs[1] === 384, r.dirs.join("×"))
                raiz.ck("los dos quedan dados de alta en el manifiesto",
                        r.manif.indexOf("Mordisco_Feroz") >= 0 && r.manif.indexOf("Rayo_Guiado") >= 0,
                        r.manif.join(" "))
                raiz.ck("con su tipo, su movimiento y su ruta relativa",
                        r.mordisco.kind === "vfx" && r.mordisco.family === "dark"
                        && r.mordisco.movimiento === "bite"
                        && r.mordisco.path === "vfx/Mordisco_Feroz.8.png",
                        JSON.stringify(r.mordisco))
                fin.start()
            }
        }
    }

    Timer { id: fin; interval: 200; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS"
                               : "\nuna criatura desde cero y sus ataques salen enteros")
        Qt.exit(raiz.malas ? 1 : 0) } }
    Timer { interval: 120000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

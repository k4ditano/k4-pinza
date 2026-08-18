//  Traerse una criatura del juego, retocarla y devolverla.
//
//  Es el camino largo entero: leer lo que el juego tiene bajado, trocear cada
//  hoja con la geometría de verdad —no adivinada—, dejar cada acción editable,
//  y volver a escribir las hojas, el AnimData.xml y la ficha que la da de alta.
//  Los tres tienen que estar de acuerdo entre sí Y con lo que había, porque un
//  fotograma de más o una duración cambiada no da error: da un bicho que anda
//  raro.
//
//  Lee del repositorio de crabh (sólo lectura, por un enlace) y escribe en /run.

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

    readonly property string base: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-esp"
    property var fuente: null
    property real desde: 0

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
    //  El sitio de trabajo: un enlace de sólo lectura al repositorio de crabh
    //  para leer lo bajado, y una carpeta propia donde escribir. Nunca se
    //  escribe dentro del juego desde una prueba.
    Timer { id: arranca; interval: 200; onTriggered: raiz.prepara() }

    function prepara() {
        const casa = (Quickshell.env("HOME") || "") + "/Proyectos/crabh"
        S.Forja.creaCarpeta(base, () => {
            //  Se borra lo de la vez anterior. Sin esto la prueba de "no
            //  machaca la primera" iba contando -2, -3, -4 según cuántas veces
            //  la hubieras corrido, que es lo contrario de reproducible.
            S.Forja.pide("comprobar", { raiz: base, guiones: [
                ["sh", "-c", "rm -rf '" + base + "'/*.especie '" + base + "'/assets"],
                ["ln", "-sfn", casa + "/public", base + "/public"]
            ] }, () => paso1())
        })
    }
    Connections {
        target: S.Especie
        function onFalla(q, m) { console.log("   (falla " + q + ": " + m + ")") }
    }

    // ── 1 · el catálogo ─────────────────────────────────────────
    function paso1() {
        S.Packs.elige("crabh")
        S.Packs.apunta("crabh", base)
        ck("el perfil de criatura trae la tabla de acciones",
           S.Especie.plantilla !== null && S.Especie.acciones.length === 8,
           S.Especie.acciones.map((a) => a.id).join(" "))

        S.Especie.cargaCatalogo((lista) => {
            //  Esta prueba lee del repositorio de crabh de verdad. Si no está
            //  o no ha horneado sus assets, no hay nada que comprobar y decirlo
            //  es más honesto que fallar: no está roto, es que falta el
            //  material.
            if (!lista.length) {
                console.log(" --   saltada: no encuentro criaturas bajadas en "
                            + S.Proyecto.raizPack() + "/public/data/species.json")
                console.log("      (en crabh: npm run assets)")
                fin.start()
                return
            }
            ck("se lee lo que el juego tiene bajado", lista.length > 50, lista.length + " criaturas")
            fuente = S.Especie.delCatalogo(10)
            ck("y se puede elegir una por su dex", !!fuente, fuente ? fuente.name : "?")
            ck("que trae sus hojas y su geometría",
               !!(fuente && fuente.sheets.Walk && fuente.anims.Walk.frameWidth))
            desde = Date.now()
            paso2()
        })
    }

    // ── 2 · importarla ──────────────────────────────────────────
    function paso2() {
        S.Especie.importa(10, "Orugon", base + "/Orugon.especie", (bien) => {
            ck("importar dice que sí", bien === true)
            ck("y tarda algo razonable", true,
               ((Date.now() - raiz.desde) / 1000).toFixed(1) + " s")
            ck("la especie queda abierta con su nombre nuevo",
               S.Especie.abierta && S.Especie.nombre === "Orugon", S.Especie.nombre)
            ck("con un dex que no puede chocar con uno de verdad",
               S.Especie.d.dex >= 10000, S.Especie.d.dex)
            ck("y recuerda de quién salió",
               S.Especie.d.venideDe && S.Especie.d.venideDe.nombre === "caterpie")

            const ids = Object.keys(S.Especie.d.acciones)
            ck("trae varias acciones", ids.length >= 6, ids.join(" "))

            // la geometría tiene que ser la BAJADA, no una inventada
            const w = S.Especie.d.acciones.Walk
            const g = raiz.fuente.anims.Walk
            ck("Walk conserva el tamaño de fotograma original",
               w.ancho === g.frameWidth && w.alto === g.frameHeight,
               w.ancho + "×" + w.alto + " vs " + g.frameWidth + "×" + g.frameHeight)
            ck("y sus duraciones en tics, una por fotograma",
               w.duraciones.join() === g.durations.join(),
               w.duraciones.join() + " vs " + g.durations.join())

            const a = S.Especie.d.acciones.Attack
            ck("Attack conserva el fotograma de golpe",
               a.hitFrame === (raiz.fuente.anims.Attack.hitFrame || 0),
               a.hitFrame + " vs " + raiz.fuente.anims.Attack.hitFrame)
            paso2b()
        })
    }

    // ── 2b · importarla otra vez no machaca la primera ─────────
    function paso2b() {
        S.Especie.importa(10, "Orugon", base + "/Orugon.especie", (bien) => {
            ck("importar dos veces con el mismo nombre no machaca la primera",
               S.Especie.ruta !== base + "/Orugon.especie"
               && S.Especie.ruta.indexOf("Orugon-") > 0, S.Especie.ruta)
            // y volver a la primera para seguir
            S.Especie.abre(base + "/Orugon.especie", () => paso3())
        })
    }

    // ── 3 · las acciones se abren y tienen dibujo ──────────────
    function paso3() {
        S.Especie.editaAccion("Walk", (bien) => {
            ck("una acción se abre para dibujarla", bien === true)
            ck("con las ocho filas de orientación",
               S.Documento.nOrientaciones === 8, S.Documento.nOrientaciones)
            ck("en el orden que lee el juego",
               S.Documento.etiquetaOrientacion(0) === "Down"
               && S.Documento.etiquetaOrientacion(2) === "Right")
            ck("con los fotogramas de la hoja original",
               S.Documento.nFotogramas === raiz.fuente.anims.Walk.durations.length,
               S.Documento.nFotogramas)
            ck("y con las duraciones en tics",
               S.Documento.duracion(0) === raiz.fuente.anims.Walk.durations[0])

            // y sobre todo: que traiga PÍXELES, distintos en cada dirección
            let vacias = 0
            const huellas = {}
            for (let d = 0; d < 8; d++) {
                const b = S.Documento.compuesto(0, d)
                if (!b || P.vacio(b)) { vacias++; continue }
                let n = 0
                for (let i = 3; i < b.d.length; i += 4) if (b.d[i]) n++
                huellas[d] = n
            }
            ck("todas las orientaciones traen dibujo", vacias === 0, vacias + " vacías")
            const distintas = new Set(Object.keys(huellas).map((k) => huellas[k])).size
            ck("y no son todas la misma imagen", distintas > 2,
               distintas + " siluetas distintas de 8")

            // el sur mirando abajo y el norte arriba: si las filas se hubieran
            // leído al revés, esto se notaría
            ck("la fila 0 es la que mira al frente",
               S.Documento.etiquetaOrientacion(0) === "Down")

            // dibujar encima, para comprobar que se puede retocar
            const capa = S.Documento.capa(0)
            const b = S.Documento.celda(capa.id, 0, 0, true)
            P.pon(b, 1, 1, [255, 0, 255, 255])
            S.Documento.cambiaPixeles(null)
            S.Proyecto.guarda(null, () => paso4())
        })
    }

    // ── 4 · devolverla al juego ────────────────────────────────
    function paso4() {
        S.Especie.recogeDelDocumento()
        S.Especie.exporta((bien) => {
            ck("exportar la especie dice que sí", bien === true)
            comprueba.running = true
        })
    }

    // Se mira desde FUERA: los ficheros, sus tamaños y el XML.
    Process {
        id: comprueba
        command: ["python3", Qt.resolvedUrl("comprueba-especie.py").toString().substring(7),
                  raiz.base, "Orugon", "10"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null
                try { r = JSON.parse(text.trim()) } catch (e) { }
                if (!r) { raiz.ck("las comprobaciones de fuera leen algo", false, text.trim().slice(0, 300)); fin.start(); return }

                raiz.ck("escribe una hoja por acción", r.hojas >= 6, r.hojas + " hojas")
                raiz.ck("y la hoja de Walk mide LO MISMO que la original",
                        r.walk[0] === r.walkOrig[0] && r.walk[1] === r.walkOrig[1],
                        r.walk.join("×") + " vs " + r.walkOrig.join("×"))
                raiz.ck("el AnimData.xml lleva todas las acciones",
                        r.anims.length === 8, r.anims.join(" "))
                raiz.ck("con las duraciones de Walk en tics, tal cual estaban",
                        r.walkDur.join() === r.walkDurOrig.join(),
                        r.walkDur.join() + " vs " + r.walkDurOrig.join())
                raiz.ck("y las de Idle, que son diez y desiguales",
                        r.idleDur.join() === r.idleDurOrig.join(),
                        r.idleDur.join() + " vs " + r.idleDurOrig.join())
                raiz.ck("con el fotograma de golpe de Attack",
                        r.attackHit === r.attackHitOrig, r.attackHit + " vs " + r.attackHitOrig)
                raiz.ck("y con el tamaño de sombra de la criatura",
                        r.sombra === raiz.fuente.shadowSize,
                        r.sombra + " vs " + raiz.fuente.shadowSize)
                raiz.ck("la ficha da de alta a la criatura con su dex nuevo",
                        r.ficha.dex >= 10000 && r.ficha.name === "orugon",
                        r.ficha.dex + " " + r.ficha.name)
                raiz.ck("con la mitad de pokédex, para que no sea un caso especial",
                        r.ficha.tienePokedex === true)
                raiz.ck("con la ruta relativa que el juego sabe leer",
                        r.ficha.rutaWalk === "assets/species/Orugon/Walk-Anim.png",
                        r.ficha.rutaWalk)
                raiz.ck("y la geometría de la ficha casa con la hoja",
                        r.ficha.walkGeo[0] === r.walkOrig[0] / r.walkDur.length,
                        r.ficha.walkGeo.join("×") + " · " + r.walkDur.length + " fotogramas")
                raiz.ck("y el retoque que hicimos está en el PNG que sale",
                        r.retoque[0] === 255 && r.retoque[2] === 255, r.retoque.join())
                fin.start()
            }
        }
    }

    Timer { id: fin; interval: 200; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS"
                               : "\nuna criatura del juego entra, se retoca y vuelve entera")
        Qt.exit(raiz.malas ? 1 : 0) } }
    Timer { interval: 180000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

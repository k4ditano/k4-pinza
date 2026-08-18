//  Que cuando no se puede leer el catálogo, se diga.
//
//  Esta prueba existe por un fallo concreto: una raíz de pack apuntada a una
//  carpeta que ya no existía dejaba la lista de criaturas en «leyendo…» para
//  siempre. Fallar está bien; fallar sin decir nada, y encima pareciendo que
//  vas lento, no.

import QtQuick
import Quickshell
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property string tmp: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-cat"
    readonly property string casa: (Quickshell.env("HOME") || "") + "/Proyectos/crabh"
    property int descartes: 0

    FloatingWindow {
        implicitWidth: 200; implicitHeight: 100
        visible: true
        V.Exportador { id: ex }
        Component.onCompleted: S.Proyecto.exportador = ex
    }
    Connections {
        target: S.Packs
        function onCargadosCambiaron() { arranca.start() }
        function onRaizDescartada(pack, ruta) { raiz.descartes++ }
    }
    Timer { id: arranca; interval: 200; onTriggered: raiz.paso1() }

    // ── 1 · una raíz que existe pero no tiene el juego ──────────
    function paso1() {
        S.Packs.elige("crabh")
        S.Forja.creaCarpeta(tmp, () => {
            S.Packs.apunta("crabh", tmp)
            S.Especie.olvidaCatalogo()
            S.Especie.cargaCatalogo(() => {
                ck("una carpeta sin el juego no se queda leyendo para siempre",
                   !S.Especie.catalogoLeyendo)
                ck("y dice qué fichero no encuentra",
                   S.Especie.catalogoError.indexOf("species.json") > 0,
                   S.Especie.catalogoError)
                ck("sin dar el catálogo por bueno", !S.Especie.catalogoListo)
                paso2()
            })
        })
    }

    // ── 2 · una raíz que ya no existe se descarta sola ──────────
    function paso2() {
        S.Packs.apunta("crabh", tmp + "/esto-no-existe")
        ck("se puede apuntar a cualquier sitio",
           S.Proyecto.raizPack().indexOf("esto-no-existe") > 0)
        S.Packs.elige("crabh")        // al elegir el pack se revisa
        espera.start()
    }

    Timer { id: espera; interval: 600; onTriggered: {
        raiz.ck("una raíz que ya no existe se tira sola", raiz.descartes >= 1, raiz.descartes)
        raiz.ck("y se vuelve a la que trae el pack",
                S.Proyecto.raizPack().indexOf("esto-no-existe") < 0, S.Proyecto.raizPack())
        raiz.paso3()
    } }

    // ── 3 · apuntando bien, va ──────────────────────────────────
    function paso3() {
        S.Packs.apunta("crabh", casa)
        S.Especie.olvidaCatalogo()
        ck("olvidar el catálogo borra también la queja", S.Especie.catalogoError === "")
        S.Especie.cargaCatalogo((lista) => {
            if (!lista.length) {
                console.log(" --   saltada la mitad buena: no hay criaturas bajadas en " + casa)
                fin.start(); return
            }
            ck("apuntando a la carpeta buena, el catálogo carga", S.Especie.catalogoListo,
               lista.length + " criaturas")
            ck("y no queda ninguna queja", S.Especie.catalogoError === "")
            fin.start()
        })
    }

    Timer { id: fin; interval: 200; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\nel catálogo dice lo que le pasa")
        Qt.exit(raiz.malas ? 1 : 0) } }
    Timer { interval: 30000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

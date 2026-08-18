//  Un color cambiado en toda la criatura, no sólo en la acción que miras.
//
//  El alcance de la herramienta llegaba hasta las ocho caras y todos los
//  fotogramas — pero eso sigue siendo UNA acción, porque cada acción es un
//  documento aparte. Recolorear un bicho entero eran ocho pasadas, y basta
//  fallar una para que cambie de color al echar a andar.
//
//  Lo que se comprueba aquí es el disco, no la pantalla: las otras acciones se
//  tocan sin abrirlas —abrirlas haría parpadear el lienzo ocho veces— así que
//  la única forma de saber que ha pasado algo es volver a leer sus PNG.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property string base: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-recolor2"
    readonly property var rojo: [200, 40, 40, 255]
    readonly property var verde: [40, 190, 70, 255]

    FloatingWindow {
        implicitWidth: 400; implicitHeight: 300
        visible: true
        V.Exportador { id: ex }
        V.Lienzo { id: lienzo; anchors.fill: parent }
        Component.onCompleted: { S.Proyecto.exportador = ex; S.Especie.exportador = ex }
    }
    Connections {
        target: S.Packs
        function onCargadosCambiaron() { arranca.start() }
    }
    Timer { id: arranca; interval: 250; onTriggered: raiz.prepara() }

    function pinta(color) {
        const b = S.Documento.celdaActiva(true)
        for (let y = 2; y < S.Documento.alto - 2; y++)
            for (let x = 2; x < S.Documento.ancho - 2; x++) P.pon(b, x, y, color)
        S.Documento.cambiaPixeles(null)
    }

    function prepara() {
        S.Forja.creaCarpeta(base, () => {
            S.Forja.pide("comprobar", { raiz: base, guiones: [
                ["sh", "-c", "rm -rf '" + base + "'/*.especie"]
            ] }, () => {
                S.Packs.elige("crabh")
                S.Packs.apunta("crabh", base)
                S.Especie.nueva({ nombre: "Tinte", dex: 10901 })
                S.Especie.guarda(base + "/Tinte.especie", () => paso1())
            })
        })
    }

    //  Dos acciones con el mismo rojo dentro.
    function paso1() {
        S.Especie.editaAccion("Idle", () => {
            raiz.pinta(raiz.rojo)
            S.Especie.editaAccion("Walk", () => {
                raiz.pinta(raiz.rojo)
                S.Especie.editaAccion("Idle", () => {
                    ck("dos acciones dibujadas con el mismo color",
                       S.Documento.abierto && !P.vacio(S.Documento.compuesto(0, 0)))
                    paso2()
                })
            })
        })
    }

    //  Y ahora el cambio, desde Idle, con alcance de criatura entera.
    function paso2() {
        S.Pinceles.alcanceColor = "acciones"
        S.Pinceles.todasLasCapas = true
        lienzo.sustituyeEnTodo(raiz.rojo, raiz.verde, 10)
        espera.start()
    }

    Timer { id: espera; interval: 3500; onTriggered: raiz.comprueba() }

    function comprueba() {
        //  Idle es la que estaba delante: ésa va por el camino de siempre.
        const b = S.Documento.compuesto(0, 0)
        const c = P.lee(b, S.Documento.ancho / 2, S.Documento.alto / 2)
        ck("la acción que tenías delante queda cambiada",
           P.distancia(c, raiz.verde) < 12, c.join(","))

        //  Walk no se abrió en ningún momento: hay que ir al PNG. El id de su
        //  capa no tiene por qué ser c1 —los ids no se reinician entre
        //  documentos—, así que sale de su propio proyecto.json.
        S.Forja.leeTexto(base + "/Tinte.especie/Walk.pinza/proyecto.json", (rp) => {
        let mp = null
        try { mp = JSON.parse(rp.texto) } catch (e) {}
        if (!mp) { ck("se puede leer el proyecto.json de Walk", false); fin.start(); return }
        const png = base + "/Tinte.especie/Walk.pinza/celdas/" + mp.capas[0].id + ".0.0.png"
        ex.dePng(png, (w) => {
            if (!w) { ck("se puede leer la celda de Walk desde el disco", false, png); fin.start(); return }
            const d = P.lee(w, w.w / 2, w.h / 2)
            ck("y la que NO tenías delante también, en el disco",
               P.distancia(d, raiz.verde) < 12, d.join(","))
            ck("sin tocar el alfa de lo que estaba vacío",
               P.lee(w, 0, 0)[3] === 0)

            //  Y que la ficha sigue entera: recolorear no puede descuadrar la
            //  geometría de una acción que ni se abrió.
            ck("y su proyecto.json sigue describiendo un documento",
               S.Documento.esDocumento(mp),
               mp.ancho + "x" + mp.alto + " · " + mp.fotogramas.length + " fot")
            fin.start()
        })
        })
    }

    Connections {
        target: S.Especie
        function onFalla(q, m) { console.log("   (falla " + q + ": " + m + ")") }
    }
    Timer { id: fin; interval: 250; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "")
        Qt.exit(raiz.malas ? 1 : 0)
    } }
    Timer { interval: 80000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

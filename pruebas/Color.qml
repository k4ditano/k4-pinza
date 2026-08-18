//  Elegir un color, y tener tonos con los que trabajar.
//
//  Dos quejas de la misma sesión: las rampas traían tres tonos —que valen para
//  enseñar una rampa, no para sombrear con ella— y cambiar el color de arriba
//  abría el diálogo del sistema, una ventana ajena que te tapa el dibujo justo
//  cuando lo estás mirando para decidir.
//
//  Así que esto comprueba las dos cosas: que la paleta de arranque llega con
//  tonos de sobra y que se pueden meter más sin perder los que había, y que la
//  rueda de color da la vuelta entera —color adentro, color afuera— y mueve de
//  verdad el color con el que se pinta.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    FloatingWindow {
        implicitWidth: 300; implicitHeight: 760
        visible: true
        V.PanelPaleta { id: panel; width: 232 }
        Component.onCompleted: arranca.start()
    }

    Timer { id: arranca; interval: 700; onTriggered: raiz.mira() }

    function mira() {
        // ── la paleta de arranque ────────────────────────────────
        const r = S.Paleta.rampas
        ck("la paleta de arranque trae varias rampas", r.length >= 6, r.length + " rampas")
        ck("y ninguna se queda en tres tonos",
           r.every((x) => x.colores.length >= 8),
           r.map((x) => x.colores.length).join(" "))
        ck("cada rampa va de oscuro a claro",
           r.every((x) => x.colores.every((c, i) => i === 0 || P.luma(c) >= P.luma(x.colores[i - 1]))))

        // ── meter más tonos sin perder los de antes ──────────────
        S.Paleta.cargaRampas([{ nombre: "corta", colores: ["#301810", "#A85030", "#F0C090"] }])
        const antes = S.Paleta.rampas[0].colores.slice()
        const n = S.Paleta.ampliaRampa(0, 9)
        const ahora = S.Paleta.rampas[0].colores
        ck("rellenar una rampa de tres deja nueve tonos", n === 9 && ahora.length === 9, n + "")
        ck("y los extremos siguen siendo los que había",
           P.distancia(ahora[0], antes[0]) < 3 && P.distancia(ahora[8], antes[2]) < 3,
           P.aHex(ahora[0]) + " … " + P.aHex(ahora[8]))
        ck("pedir menos tonos no borra ninguno",
           S.Paleta.ampliaRampa(0, 4) === 9)

        // ── una rampa entera desde un color ──────────────────────
        const cuantas = S.Paleta.rampas.length
        S.Paleta.rampaDesde(P.deHex("#3A80C8"), 7)
        const nueva = S.Paleta.rampas[S.Paleta.rampas.length - 1]
        ck("una rampa nueva sale con sus sombras y sus luces",
           S.Paleta.rampas.length === cuantas + 1 && nueva.colores.length === 7,
           nueva.colores.map(P.aHex).join(" "))
        ck("y queda activa para seguir tocándola",
           S.Paleta.rampaActiva === S.Paleta.rampas.length - 1)

        // ── la rueda ─────────────────────────────────────────────
        //  Se busca dentro del panel: si el selector no estuviera montado,
        //  esto fallaría, que es exactamente lo que hay que detectar.
        const rueda = buscaRueda(panel)
        ck("el panel de color monta la rueda, no un diálogo aparte", rueda !== null)
        if (!rueda) { fin.start(); return }

        panel.abre(1)
        ck("pulsar el pozo del primario abre la rueda", panel.cual === 1)

        const naranja = P.deHex("#D66C34")
        rueda.pon(naranja)
        ck("colocar la rueda en un color y leerlo devuelve el mismo",
           P.distancia(rueda.color, naranja) < 3, rueda.hex)

        //  Un gris no tiene tono: si lo leyera tal cual, la rueda se iría al
        //  rojo y perderías el sitio.
        const tonoAntes = rueda.tono
        rueda.pon(P.deHex("#808080"))
        ck("un neutro no le roba el tono a la rueda",
           Math.abs(rueda.tono - tonoAntes) < 0.5,
           Math.round(rueda.tono) + "° seguía siendo " + Math.round(tonoAntes) + "°")
        ck("pero sí le cambia la saturación", rueda.sat < 0.02, rueda.sat.toFixed(3))

        //  Y que mover la rueda mueve el color con el que se pinta.
        rueda.pon(naranja)
        const primarioAntes = S.Paleta.primarioHex
        rueda.tono = (rueda.tono + 120) % 360
        ck("girar el tono cambia el color de pintar",
           S.Paleta.primarioHex !== primarioAntes,
           primarioAntes + " → " + S.Paleta.primarioHex)
        ck("y el que sale es el que enseña la rueda",
           S.Paleta.primarioHex === rueda.hex, S.Paleta.primarioHex + " / " + rueda.hex)

        rueda.alfa = 128
        ck("el alfa también llega al color de pintar",
           Math.round(S.Paleta.primario[3]) === 128, S.Paleta.primario[3] + "")

        //  Al revés: coger un color por otro sitio tiene que mover la rueda.
        S.Paleta.ponPrimario(P.deHex("#3A80C8"))
        ck("y coger un color por fuera arrastra la rueda con él",
           rueda.hex.toLowerCase() === "#3a80c8", rueda.hex)

        panel.abre(1)
        ck("volver a pulsar el pozo la cierra", panel.cual === 0)

        fin.start()
    }

    /** El selector, esté a la profundidad que esté dentro del panel. */
    function buscaRueda(it) {
        if (!it) return null
        if (it.tono !== undefined && it.sat !== undefined && it.alfa !== undefined) return it
        const hijos = it.children || []
        for (let i = 0; i < hijos.length; i++) {
            const r = buscaRueda(hijos[i])
            if (r) return r
        }
        return null
    }

    Timer { id: fin; interval: 150; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "")
        Qt.exit(raiz.malas ? 1 : 0)
    } }
    Timer { interval: 40000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

pragma Singleton

//  El color.
//
//  La unidad de trabajo es la RAMPA, no la casilla suelta. Un pixel artist no
//  piensa "este verde" sino "la sombra, el cuerpo y el brillo de este verde", y
//  organizarlo así es lo que hace posible la tinta de sombreado: pintar con
//  ella mueve cada píxel un paso a lo largo de SU rampa en vez de aplastarlo
//  con un color plano.
//
//  Aquí no hay ningún límite de colores. Un pack puede traer una guía —crabh
//  la trae— pero es informativa y se puede apagar: el medidor te dice dónde
//  estás, nunca te impide llegar.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P

Singleton {
    id: pal

    // ── los dos colores ──────────────────────────────────────────
    property var primario: [44, 55, 57, 255]
    property var secundario: [255, 255, 255, 255]
    property int rev: 0

    readonly property string primarioHex: rev, P.aHex(primario)
    readonly property string secundarioHex: rev, P.aHex(secundario)

    function ponPrimario(c) { primario = c.slice(); rev++ }
    function ponSecundario(c) { secundario = c.slice(); rev++ }
    function intercambia() { const t = primario; primario = secundario; secundario = t; rev++ }

    // ── rampas ───────────────────────────────────────────────────
    //  [{ nombre, colores: [[r,g,b,a], ...] }]  de oscuro a claro
    property var rampas: []
    property int rampaActiva: 0
    property int pasoActivo: 1

    /** Todos los colores de todas las rampas, aplanados. */
    readonly property var colores: {
        rev
        const out = []
        for (let i = 0; i < rampas.length; i++)
            for (let j = 0; j < rampas[i].colores.length; j++) out.push(rampas[i].colores[j])
        return out
    }

    function cargaRampas(lista) {
        const out = []
        for (let i = 0; i < lista.length; i++) {
            const r = lista[i]
            out.push({
                nombre: r.nombre,
                colores: r.colores.map((c) => typeof c === "string" ? P.deHex(c) : c.slice())
            })
        }
        rampas = out
        rampaActiva = Math.min(rampaActiva, Math.max(0, out.length - 1))
        rev++
    }

    /**
     * La paleta de un pack, con los huecos cubiertos.
     *
     * Los packs traen rampas de tres tonos porque es la referencia del juego —
     * crabh saca las suyas de su style.json— y con tres no se puede sombrear:
     * entre el cuerpo y la sombra hay un salto que a mano se cubre a ojo. Se
     * cargan tal cual y luego se rellenan, así que los colores del pack siguen
     * estando todos y en su sitio; lo que se añade va entre medias.
     *
     * No lo hace `cargaRampas` porque ése es también el camino de un .gpl o de
     * la paleta sacada de un dibujo, y ahí inventar tonos sería mentir sobre
     * lo que tiene la imagen.
     */
    function cargaRampasDePack(lista, minimo) {
        cargaRampas(lista)
        ampliaTodas(minimo || 9)
    }

    function añadeRampa(nombre, colores) {
        const r = rampas.slice()
        r.push({ nombre: nombre || "rampa " + (r.length + 1),
                 colores: (colores || [primario]).map((c) => c.slice()) })
        rampas = r; rampaActiva = r.length - 1; rev++
    }

    function borraRampa(i) {
        const r = rampas.slice(); r.splice(i, 1)
        rampas = r; rampaActiva = Math.max(0, Math.min(rampaActiva, r.length - 1)); rev++
    }

    function añadeColor(i, c) {
        const r = rampas.slice()
        if (!r[i]) return
        r[i].colores = r[i].colores.concat([c.slice()])
        rampas = r; rev++
    }

    function quitaColor(i, j) {
        const r = rampas.slice()
        if (!r[i]) return
        const cc = r[i].colores.slice(); cc.splice(j, 1)
        r[i].colores = cc
        rampas = r; rev++
    }

    /**
     * Más tonos en una rampa, sin perder los que tenía.
     *
     * Los packs traen rampas de tres tonos porque es lo que el juego usa como
     * referencia, y con tres no se puede sombrear nada: entre el cuerpo y la
     * sombra hay un salto que a mano se cubre a ojo. Esto lo rellena
     * interpolando, así que la rampa sigue siendo la misma con los huecos
     * puestos.
     */
    function ampliaRampa(i, n) {
        const r = rampas.slice()
        if (!r[i]) return 0
        r[i] = { nombre: r[i].nombre, colores: P.ampliaRampa(r[i].colores, n) }
        rampas = r; rev++
        return r[i].colores.length
    }

    /** Lo mismo para todas de una vez. */
    function ampliaTodas(n) {
        const r = rampas.map((x) => ({ nombre: x.nombre,
                                       colores: P.ampliaRampa(x.colores, n) }))
        rampas = r; rev++
        return r.length
    }

    /**
     * Una rampa nueva a partir de un color, con sus sombras y sus luces.
     *
     * Una rampa de un solo color no sirve para nada —ni para sombrear, ni para
     * la tinta de degradado—, así que del primario sale la rampa entera.
     */
    function rampaDesde(c, n, nombre) {
        const r = rampas.slice()
        r.push({ nombre: nombre || "rampa " + (r.length + 1),
                 colores: P.rampaDesde(c, n || 5) })
        rampas = r; rampaActiva = r.length - 1; rev++
        return r[r.length - 1].colores.length
    }

    function ponColor(i, j, c) {
        const r = rampas.slice()
        if (!r[i] || !r[i].colores[j]) return
        const cc = r[i].colores.slice(); cc[j] = c.slice()
        r[i].colores = cc
        rampas = r; rev++
    }

    /**
     * El vecino de un color dentro de su rampa.
     *
     * Busca en TODAS las rampas el color más parecido, y devuelve el que está
     * `paso` posiciones más allá. Si no se parece a nada por debajo de la
     * tolerancia devuelve null y la tinta de sombreado no toca ese píxel — que
     * es lo correcto: sombrear un color que no es de la paleta sería inventar.
     */
    function vecinoEnRampa(c, paso, tolerancia) {
        const tol = tolerancia === undefined ? 40 : tolerancia
        let mejorR = -1, mejorJ = -1, mejorD = tol
        for (let i = 0; i < rampas.length; i++) for (let j = 0; j < rampas[i].colores.length; j++) {
            const d = P.distancia([c[0], c[1], c[2], 255],
                                  [rampas[i].colores[j][0], rampas[i].colores[j][1],
                                   rampas[i].colores[j][2], 255])
            if (d < mejorD) { mejorD = d; mejorR = i; mejorJ = j }
        }
        if (mejorR < 0) return null
        const cc = rampas[mejorR].colores
        const k = Math.max(0, Math.min(cc.length - 1, mejorJ + paso))
        return [cc[k][0], cc[k][1], cc[k][2], c[3]]
    }

    // ── guía del pack, siempre informativa ───────────────────────
    property var guia: null     // {colores, saturacion, luminancia, aviso} o null

    /** Cómo va el documento contra la guía. Nunca prohíbe nada. */
    function mide(buf) {
        if (!buf) return null
        const m = P.medidas(buf)
        const cols = P.coloresDe(buf).length
        return {
            colores: cols, saturacion: m.saturacion, luminancia: m.luminancia,
            pixeles: m.pixeles,
            coloresFuera: guia && guia.colores ? cols > guia.colores : false,
            saturacionFuera: guia && guia.saturacion
                             ? Math.abs(m.saturacion - guia.saturacion) > 0.18 : false,
            luminanciaFuera: guia && guia.luminancia
                             ? Math.abs(m.luminancia - guia.luminancia) > 35 : false
        }
    }

    // ── formatos de paleta ───────────────────────────────────────

    /** GIMP .gpl, que es el que entiende todo el mundo. */
    function aGpl(nombre) {
        let s = "GIMP Palette\nName: " + (nombre || "pinza") + "\nColumns: 8\n#\n"
        for (let i = 0; i < rampas.length; i++) {
            for (let j = 0; j < rampas[i].colores.length; j++) {
                const c = rampas[i].colores[j]
                s += ("  " + Math.round(c[0])).slice(-3) + " "
                   + ("  " + Math.round(c[1])).slice(-3) + " "
                   + ("  " + Math.round(c[2])).slice(-3) + "\t"
                   + rampas[i].nombre + " " + (j + 1) + "\n"
            }
        }
        return s
    }

    function deGpl(texto) {
        const lineas = texto.split("\n")
        const cols = []
        for (let i = 0; i < lineas.length; i++) {
            const l = lineas[i].trim()
            if (!l || l[0] === "#" || l.indexOf(":") > 0 && l.indexOf("\t") < 0
                && !/^\d/.test(l)) continue
            const p = l.split(/\s+/)
            if (p.length < 3) continue
            const r = parseInt(p[0]), g = parseInt(p[1]), b = parseInt(p[2])
            if (isNaN(r) || isNaN(g) || isNaN(b)) continue
            cols.push([r, g, b, 255])
        }
        if (cols.length) cargaRampas([{ nombre: "importada", colores: cols }])
        return cols.length
    }

    /** Una lista de hexes por línea, que es lo que sueltan Lospec y compañía. */
    function deHexes(texto) {
        const cols = []
        const m = texto.match(/#?[0-9a-fA-F]{6}/g) || []
        for (let i = 0; i < m.length; i++) cols.push(P.deHex(m[i]))
        if (cols.length) cargaRampas([{ nombre: "importada", colores: cols }])
        return cols.length
    }

    /**
     * Saca la paleta de una imagen y la parte en rampas por tono.
     *
     * Sirve para heredar el color de un boceto, de un render o de un sprite
     * ajeno sin teclear veinte hexes a mano.
     */
    function desdeBufer(buf, n) {
        const lista = P.reduce(buf, n || 16)
        if (!lista.length) return 0
        // agrupar por tono, y dentro de cada grupo ordenar por luminosidad:
        // eso es una rampa, y sale sola
        const grupos = {}
        for (let i = 0; i < lista.length; i++) {
            const h = P.aHsv(lista[i])
            const k = h[1] < 0.12 ? "gris" : String(Math.round(h[0] / 30) * 30)
            ;(grupos[k] = grupos[k] || []).push(lista[i])
        }
        const out = []
        const claves = Object.keys(grupos)
        for (let i = 0; i < claves.length; i++) {
            const g = grupos[claves[i]].sort((a, b) => P.luma(a) - P.luma(b))
            out.push({ nombre: claves[i] === "gris" ? "neutros" : claves[i] + "°", colores: g })
        }
        cargaRampas(out)
        return lista.length
    }

    //  La paleta de arranque: nueve tonos por rampa, no tres.
    //
    //  Tres tonos valen para enseñar una rampa, no para pintar con ella. Los
    //  anclas son los de siempre y el resto sale de interpolar, así que sigue
    //  leyéndose igual pero se puede sombrear sin saltos.
    Component.onCompleted: if (!rampas.length) {
        cargaRampas([
            { nombre: "neutros", colores: ["#000000", "#3A3A44", "#6B6B78", "#A8A8B4", "#E8E8F0", "#FFFFFF"] },
            { nombre: "cálidos", colores: ["#5A2010", "#9C3A18", "#D66C34", "#F0A860", "#F8D8A8"] },
            { nombre: "fríos",   colores: ["#10284A", "#1E4C86", "#3A80C8", "#78B4E8", "#C0E0F8"] },
            { nombre: "verdes",  colores: ["#12301A", "#245C2E", "#3F9648", "#7BC96A", "#C4EBA4"] },
            { nombre: "piel",    colores: ["#4A2018", "#8C4030", "#C87858", "#EAAA88", "#F8DCC0"] },
            { nombre: "morados", colores: ["#221038", "#452668", "#7048A8", "#A882D8", "#D8C4F0"] }
        ])
        ampliaTodas(9)
    }
}

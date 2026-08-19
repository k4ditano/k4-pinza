.pragma library

.import "pixeles.js" as P

//  Dibujar por descripción, no por píxeles.
//
//  Esto existe por una razón concreta: un modelo de lenguaje escribiendo una
//  rejilla de píxeles a mano falla en la coherencia vertical —cuando escribe la
//  fila 12 tiene que acordarse de lo que puso en la 11, y entre las dos hay
//  treinta y dos símbolos— y además no puede releer lo que escribió. En cambio
//  «una elipse centrada en (16,10) de radios 7×6» es una frase corta, se ve si
//  está mal, y se corrige cambiando un número.
//
//  Así que aquí no se ponen píxeles: se declaran MASAS, se unen en una
//  silueta, y el sombreado sale de una REGLA —una dirección de luz y una
//  rampa—. Es exactamente lo que hace `tools/icono.py` con el icono del
//  programa, sacado de sus 32×32 y puesto sobre cualquier dibujo.
//
//  Todo se apoya en `pixeles.js`. Aquí no hay un segundo motor: las máscaras
//  son booleanas y el único sitio que escribe color son `pinta` y `sombrea`,
//  que van por `P.pon`. Lo que salga de aquí es un búfer normal y corriente
//  que el resto del programa no distingue de uno pintado a mano.


// ═══════════════════════════════════════════════════════════════
// máscaras
// ═══════════════════════════════════════════════════════════════
//
//  Una máscara es {w, h, m:Uint8Array} con 0 o 1 por píxel. Se trabaja en
//  booleano y no en color hasta el final a propósito: unir dos masas, crecer
//  una silueta o medir su profundidad son preguntas de forma, y mezclarlas con
//  el color obliga a decidir dos cosas a la vez y a equivocarse en las dos.

function mascara(w, h) {
    return { w: w, h: h, m: new Uint8Array(w * h) }
}

function clona(k) {
    const r = mascara(k.w, k.h)
    r.m.set(k.m)
    return r
}

function en(k, x, y) {
    if (x < 0 || y < 0 || x >= k.w || y >= k.h) return 0
    return k.m[y * k.w + x]
}

function marca(k, x, y, v) {
    if (x < 0 || y < 0 || x >= k.w || y >= k.h) return
    k.m[y * k.w + x] = v === undefined ? 1 : (v ? 1 : 0)
}

function cuantos(k) {
    let n = 0
    for (let i = 0; i < k.m.length; i++) if (k.m[i]) n++
    return n
}

/** El alfa de un búfer, como máscara. Para retocar lo que ya está dibujado. */
function deBuffer(b, umbral) {
    const u = umbral === undefined ? 8 : umbral
    const k = mascara(b.w, b.h)
    for (let i = 0; i < b.w * b.h; i++) k.m[i] = b.d[i * 4 + 3] > u ? 1 : 0
    return k
}

/**
 * Una máscara escrita a mano, en texto.
 *
 * Es la puerta de atrás deliberada: para un icono de 16×16 la silueta dibujada
 * carácter a carácter sale mejor que cualquier composición de elipses, y sigue
 * siendo la parte en la que acertar es fácil. El sombreado lo pone la regla
 * igual, que es donde se gana el tiempo.
 *
 *     F.deTexto(["..##..",
 *                ".####.",
 *                "######"])
 *
 * Cualquier carácter que no sea espacio ni punto cuenta como dentro.
 */
function deTexto(filas, w, h) {
    const an = w || filas.reduce((a, f) => Math.max(a, f.length), 0)
    const al = h || filas.length
    const k = mascara(an, al)
    for (let y = 0; y < Math.min(al, filas.length); y++) {
        const f = filas[y]
        for (let x = 0; x < Math.min(an, f.length); x++) {
            const c = f[x]
            if (c !== " " && c !== "." && c !== "_") k.m[y * an + x] = 1
        }
    }
    return k
}

// ── masas ──────────────────────────────────────────────────────
//
//  Cada una devuelve una máscara del tamaño pedido. Se declaran en
//  coordenadas continuas (centro y radios, no esquinas) porque es como se
//  piensa una figura y porque así un ajuste de medio píxel es un número
//  distinto y no una reescritura.

function elipse(w, h, cx, cy, rx, ry) {
    const k = mascara(w, h)
    if (rx <= 0 || ry <= 0) return k
    const x0 = Math.max(0, Math.floor(cx - rx)), x1 = Math.min(w - 1, Math.ceil(cx + rx))
    const y0 = Math.max(0, Math.floor(cy - ry)), y1 = Math.min(h - 1, Math.ceil(cy + ry))
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
        const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry
        if (dx * dx + dy * dy <= 1) k.m[y * w + x] = 1
    }
    return k
}

function disco(w, h, cx, cy, r) { return elipse(w, h, cx, cy, r, r) }

function rect(w, h, x, y, an, al, redondeo) {
    const k = mascara(w, h)
    const r = Math.max(0, Math.min(redondeo || 0, Math.min(an, al) / 2))
    for (let j = Math.max(0, Math.floor(y)); j < Math.min(h, Math.ceil(y + al)); j++)
        for (let i = Math.max(0, Math.floor(x)); i < Math.min(w, Math.ceil(x + an)); i++) {
            if (r > 0) {
                //  Esquinas redondeadas: sólo se comprueba la distancia al
                //  centro del arco cuando el píxel cae en la esquina, que es
                //  lo que evita morder los lados rectos.
                const px = i + 0.5, py = j + 0.5
                const qx = px < x + r ? x + r : (px > x + an - r ? x + an - r : px)
                const qy = py < y + r ? y + r : (py > y + al - r ? y + al - r : py)
                const dx = px - qx, dy = py - qy
                if (dx * dx + dy * dy > r * r) continue
            }
            k.m[j * w + i] = 1
        }
    return k
}

/**
 * Una cápsula: el segmento (x0,y0)-(x1,y1) engordado a radio r.
 *
 * Es la masa más útil de todas y por eso está: un brazo, una pata, una rama y
 * un tentáculo son todos esto, y encadenar tres cápsulas describe un cuerpo
 * entero sin tocar un solo píxel.
 */
function capsula(w, h, x0, y0, x1, y1, r) {
    const k = mascara(w, h)
    const vx = x1 - x0, vy = y1 - y0
    const largo2 = vx * vx + vy * vy
    const bx0 = Math.max(0, Math.floor(Math.min(x0, x1) - r))
    const bx1 = Math.min(w - 1, Math.ceil(Math.max(x0, x1) + r))
    const by0 = Math.max(0, Math.floor(Math.min(y0, y1) - r))
    const by1 = Math.min(h - 1, Math.ceil(Math.max(y0, y1) + r))
    for (let y = by0; y <= by1; y++) for (let x = bx0; x <= bx1; x++) {
        const px = x + 0.5 - x0, py = y + 0.5 - y0
        let t = largo2 === 0 ? 0 : (px * vx + py * vy) / largo2
        t = t < 0 ? 0 : (t > 1 ? 1 : t)
        const dx = px - vx * t, dy = py - vy * t
        if (dx * dx + dy * dy <= r * r) k.m[y * w + x] = 1
    }
    return k
}

/** Un polígono cerrado, por regla par-impar. `pts` son [[x,y],...]. */
function poligono(w, h, pts) {
    const k = mascara(w, h)
    if (!pts || pts.length < 3) return k
    for (let y = 0; y < h; y++) {
        const py = y + 0.5
        const cortes = []
        for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
            const yi = pts[i][1], yj = pts[j][1]
            if ((yi > py) === (yj > py)) continue
            cortes.push(pts[i][0] + (py - yi) / (yj - yi) * (pts[j][0] - pts[i][0]))
        }
        cortes.sort((a, b) => a - b)
        for (let c = 0; c + 1 < cortes.length; c += 2)
            for (let x = Math.max(0, Math.ceil(cortes[c] - 0.5)); x < Math.min(w, Math.ceil(cortes[c + 1] - 0.5)); x++)
                k.m[y * w + x] = 1
    }
    return k
}

// ── álgebra de máscaras ────────────────────────────────────────

function une() {
    const a = arguments[0]
    const r = clona(a)
    for (let i = 1; i < arguments.length; i++) {
        const b = arguments[i]
        if (!b) continue
        for (let j = 0; j < r.m.length && j < b.m.length; j++) if (b.m[j]) r.m[j] = 1
    }
    return r
}

function resta(a, b) {
    const r = clona(a)
    for (let j = 0; j < r.m.length && j < b.m.length; j++) if (b.m[j]) r.m[j] = 0
    return r
}

function corta(a, b) {
    const r = clona(a)
    for (let j = 0; j < r.m.length; j++) if (!(j < b.m.length && b.m[j])) r.m[j] = 0
    return r
}

function mueve(k, dx, dy) {
    const r = mascara(k.w, k.h)
    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++)
        if (k.m[y * k.w + x]) marca(r, x + Math.round(dx), y + Math.round(dy))
    return r
}

/** Espeja sobre un eje vertical. Sin `eje`, sobre el centro del lienzo. */
function espeja(k, eje) {
    const e = eje === undefined ? k.w / 2 : eje
    const r = mascara(k.w, k.h)
    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++)
        if (k.m[y * k.w + x]) marca(r, Math.round(2 * e - 1 - x), y)
    return r
}

/** La máscara más su espejo: media figura dibujada, figura entera. */
function simetrica(k, eje) { return une(k, espeja(k, eje)) }

function crece(k, n) {
    let r = clona(k)
    for (let paso = 0; paso < (n || 1); paso++) {
        const s = clona(r)
        for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++) {
            if (r.m[y * r.w + x]) continue
            if (en(r, x-1, y) || en(r, x+1, y) || en(r, x, y-1) || en(r, x, y+1))
                s.m[y * r.w + x] = 1
        }
        r = s
    }
    return r
}

function encoge(k, n) {
    let r = clona(k)
    for (let paso = 0; paso < (n || 1); paso++) {
        const s = clona(r)
        for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++) {
            if (!r.m[y * r.w + x]) continue
            if (!en(r, x-1, y) || !en(r, x+1, y) || !en(r, x, y-1) || !en(r, x, y+1))
                s.m[y * r.w + x] = 0
        }
        r = s
    }
    return r
}

/** El anillo exterior de la silueta, un píxel de grosor. */
function borde(k) { return resta(k, encoge(k, 1)) }

function limites(k) {
    let x0 = k.w, y0 = k.h, x1 = -1, y1 = -1
    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++) {
        if (!k.m[y * k.w + x]) continue
        if (x < x0) x0 = x
        if (x > x1) x1 = x
        if (y < y0) y0 = y
        if (y > y1) y1 = y
    }
    return x1 < x0 ? null : { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }
}

/** Centra la máscara en el lienzo, o la apoya abajo si `apoya`. */
function centra(k, apoya) {
    const l = limites(k)
    if (!l) return clona(k)
    const dx = Math.round((k.w - l.w) / 2 - l.x)
    const dy = apoya ? (k.h - (l.y + l.h)) : Math.round((k.h - l.h) / 2 - l.y)
    return mueve(k, dx, dy)
}

// ═══════════════════════════════════════════════════════════════
// la regla de luz
// ═══════════════════════════════════════════════════════════════

const RUMBOS = {
    "N":  [0, -1],       "S":  [0, 1],       "E":  [1, 0],        "O":  [-1, 0],
    "NE": [0.7071, -0.7071], "NO": [-0.7071, -0.7071],
    "SE": [0.7071, 0.7071],  "SO": [-0.7071, 0.7071]
}

function _luz(l) {
    if (!l) return RUMBOS["NO"]
    if (typeof l === "string") {
        const v = RUMBOS[l.toUpperCase()]
        return v ? v : RUMBOS["NO"]
    }
    const n = Math.hypot(l[0], l[1]) || 1
    return [l[0] / n, l[1] / n]
}

/**
 * La normal aparente de cada píxel de la silueta.
 *
 * No sale del gradiente de un mapa de distancias, que a 32×32 es puro ruido:
 * sale de dónde está la MASA alrededor. Para cada píxel se mira un disco de
 * radio `grosor` y se calcula el centro de gravedad de lo que hay dentro de la
 * silueta; el vector que va del píxel a ese centro apunta hacia dentro, así
 * que la normal exterior es el mismo vector cambiado de signo.
 *
 * Tiene dos propiedades que son justo lo que hace falta y que el gradiente no
 * da: en mitad de una masa el centro de gravedad cae encima del propio píxel,
 * el vector se queda en nada y el color no se toca —el interior es color
 * base—; y la LONGITUD del vector mide cuánto de borde es el píxel, así que
 * sirve de peso sin calcular nada más. Un borde recto da 0.42 de radio, que es
 * el centro de gravedad de un semicírculo, y por eso se normaliza por ahí.
 */
function normales(k, grosor) {
    const R = Math.max(1, Math.round(grosor || 3))
    const disc = []
    for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++)
        if (dx * dx + dy * dy <= R * R) disc.push([dx, dy])

    const nx = new Float32Array(k.w * k.h)
    const ny = new Float32Array(k.w * k.h)
    const fu = new Float32Array(k.w * k.h)

    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++) {
        const i = y * k.w + x
        if (!k.m[i]) continue
        let sx = 0, sy = 0, n = 0
        for (let d = 0; d < disc.length; d++) {
            //  Fuera del lienzo cuenta como fuera de la figura: si no, una
            //  silueta pegada al borde se cree que sigue y sale sin sombrear
            //  justo por donde el dibujo se corta.
            if (!en(k, x + disc[d][0], y + disc[d][1])) continue
            sx += disc[d][0]; sy += disc[d][1]; n++
        }
        if (!n) continue
        const vx = (sx / n) / R, vy = (sy / n) / R   // hacia dentro, en radios
        const largo = Math.hypot(vx, vy)
        if (largo < 1e-4) continue
        nx[i] = -vx / largo
        ny[i] = -vy / largo
        fu[i] = Math.min(1, largo / 0.42)
    }
    return { nx: nx, ny: ny, fuerza: fu }
}

// ═══════════════════════════════════════════════════════════════
// pintar
// ═══════════════════════════════════════════════════════════════

function _color(c) { return typeof c === "string" ? P.deHex(c) : c }

/** Rellena la máscara de un color plano. */
function pinta(b, k, color) {
    const c = _color(color)
    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++)
        if (k.m[y * k.w + x]) P.pon(b, x, y, c)
    return b
}

/** Borra lo que cubre la máscara. */
function borra(b, k) {
    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++)
        if (k.m[y * k.w + x]) P.pon(b, x, y, [0, 0, 0, 0])
    return b
}

/**
 * Sombrea una silueta con una rampa y una dirección de luz.
 *
 * La rampa va de oscuro a claro, que es como se guardan en el programa. El
 * paso base es el del medio salvo que se diga otro, y el sombreado mueve cada
 * píxel ARRIBA O ABAJO POR LA RAMPA en vez de echarle gris encima — que es la
 * misma decisión que toma la tinta de sombreado del editor, y la razón de que
 * un sprite sombreado así siga teniendo los colores del juego y no una nube de
 * tonos intermedios.
 *
 * `amplitud` es cuántos escalones se permite subir o bajar; con 1 sale un
 * sombreado plano de tres tonos, que es lo que quiere casi todo sprite
 * pequeño, y con 2 uno de cinco.
 */
function sombrea(b, k, o) {
    o = o || {}
    const rampa = (o.rampa || []).map(_color)
    if (rampa.length < 2) return b
    const luz = _luz(o.luz)
    const amplitud = o.amplitud === undefined ? 1 : o.amplitud
    const base = o.base === undefined ? Math.floor((rampa.length - 1) / 2) : o.base
    const n = normales(k, o.grosor)

    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++) {
        const i = y * k.w + x
        if (!k.m[i]) continue
        const nl = n.nx[i] * luz[0] + n.ny[i] * luz[1]
        let paso = Math.round(nl * n.fuerza[i] * amplitud)
        if (paso > amplitud) paso = amplitud
        if (paso < -amplitud) paso = -amplitud
        const idx = Math.max(0, Math.min(rampa.length - 1, base + paso))
        P.pon(b, x, y, rampa[idx])
    }
    return b
}

/** El contorno, por dentro de la silueta. Es lo que la despega del fondo. */
function perfila(b, k, color) {
    return pinta(b, borde(k), color)
}

/**
 * Una masa entera de una sola llamada: relleno, sombreado y contorno.
 *
 * Existe porque es la secuencia que se repite en cada parte de cada figura, y
 * escrita a mano son tres líneas en las que es fácil olvidarse del contorno o
 * ponerlo antes de sombrear —y entonces el sombreado se lo come—.
 */
function cuerpo(b, k, o) {
    o = o || {}
    const rampa = (o.rampa || []).map(_color)
    if (!rampa.length) return b
    pinta(b, k, rampa[o.base === undefined ? Math.floor((rampa.length - 1) / 2) : o.base])
    if (rampa.length >= 2) sombrea(b, k, o)
    if (o.contorno !== false) perfila(b, k, o.contorno ? _color(o.contorno) : rampa[0])
    return b
}

// ═══════════════════════════════════════════════════════════════
// rampas
// ═══════════════════════════════════════════════════════════════

/**
 * Una rampa a partir de un color, hacia sombra y hacia luz.
 *
 * La sombra gira el tono hacia el azul y sube la saturación; la luz lo gira
 * hacia el amarillo y la baja. No es un capricho: bajar la luminancia sin más
 * da una rampa gris y muerta, y el giro de tono es lo que separa un sombreado
 * de pixel art de un degradado de programa de dibujo.
 */
function rampa(c, n, giro) {
    const base = _color(c)
    const pasos = Math.max(3, n || 5)
    const g = giro === undefined ? 18 : giro
    const hsv = P.aHsv(base)
    const out = []
    const mitad = Math.floor(pasos / 2)
    for (let i = 0; i < pasos; i++) {
        const t = (i - mitad) / mitad              // -1 sombra .. +1 luz
        //  hacia el azul por abajo, hacia el amarillo por arriba
        let tono = hsv[0] - g * Math.abs(t) * (t < 0 ? 1 : -1)
        tono = ((tono % 360) + 360) % 360
        const sat = Math.max(0, Math.min(1, hsv[1] + (t < 0 ? 0.12 : -0.14) * Math.abs(t)))
        const val = Math.max(0, Math.min(1, hsv[2] + t * 0.34))
        const c = P.deHsv(tono, sat, val, base[3])
        out.push([Math.round(c[0]), Math.round(c[1]), Math.round(c[2]), Math.round(c[3])])
    }
    return out
}


// ═══════════════════════════════════════════════════════════════
// leer un dibujo
// ═══════════════════════════════════════════════════════════════

const ALFABETO = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

/**
 * Un búfer como rejilla de caracteres, con su leyenda.
 *
 * Es la forma de ENSEÑARLE un dibujo a algo que no tiene ojos. Un PNG en
 * base64 no le dice nada a un modelo de lenguaje y un volcado de hexadecimales
 * son cuatro mil símbolos para un sprite de 32×32; esto son mil, se lee de un
 * vistazo y —lo que importa— es editable: se puede señalar «la fila 12
 * columna 7 sobra» y que la frase signifique algo.
 *
 * Los caracteres se reparten por frecuencia para que el color que más manda
 * sea la `a`, y el punto es siempre lo transparente.
 */
function aTexto(b, tope) {
    const cols = P.coloresDe(b, tope || ALFABETO.length)
    const clave = {}
    const leyenda = {}
    for (let i = 0; i < cols.length; i++) {
        const c = cols[i].color
        clave[c[0] + "," + c[1] + "," + c[2]] = ALFABETO[i]
        leyenda[ALFABETO[i]] = P.aHex(c)
    }
    const filas = []
    let sobran = 0
    for (let y = 0; y < b.h; y++) {
        let f = ""
        for (let x = 0; x < b.w; x++) {
            const i = (y * b.w + x) * 4
            if (b.d[i + 3] < 8) { f += "."; continue }
            const ch = clave[b.d[i] + "," + b.d[i + 1] + "," + b.d[i + 2]]
            if (ch) f += ch
            else { f += "?"; sobran++ }
        }
        filas.push(f)
    }
    return { ancho: b.w, alto: b.h, filas: filas, leyenda: leyenda,
             sinNombre: sobran }
}

/** El camino de vuelta: una rejilla de caracteres a un búfer. */
function deTextoColor(filas, leyenda, w, h) {
    const an = w || filas.reduce((a, f) => Math.max(a, f.length), 0)
    const al = h || filas.length
    const b = P.nuevo(an, al)
    for (let y = 0; y < Math.min(al, filas.length); y++)
        for (let x = 0; x < Math.min(an, filas[y].length); x++) {
            const c = leyenda[filas[y][x]]
            if (c) P.pon(b, x, y, typeof c === "string" ? P.deHex(c) : c)
        }
    return b
}

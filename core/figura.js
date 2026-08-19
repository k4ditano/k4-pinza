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

// ═══════════════════════════════════════════════════════════════
// medir un dibujo
// ═══════════════════════════════════════════════════════════════
//
//  Lo que hace útil una referencia no es verla: es sacarle los números. Una
//  cresta que mide cinco píxeles y se echa atrás treinta grados se pone en un
//  aparejo de una vez; mirándola se pone a la séptima. Todo lo de aquí abajo
//  existe para convertir un dibujo en parámetros.

/** El centro de masa de una máscara, en píxeles del lienzo. */
function centro(k) {
    let sx = 0, sy = 0, n = 0
    for (let y = 0; y < k.h; y++) for (let x = 0; x < k.w; x++)
        if (k.m[y * k.w + x]) { sx += x; sy += y; n++ }
    return n ? { x: sx / n, y: sy / n, n: n } : null
}

/**
 * El perfil de una silueta: por cada franja de altura, dónde empieza y dónde
 * acaba, en fracción de su propia caja.
 *
 * Está remuestreado a un número fijo de franjas y normalizado por la caja a
 * propósito: así el perfil de un sprite de 96 y el de uno de 40 se pueden
 * comparar número a número. Es la huella de las PROPORCIONES, que es lo único
 * que se quiere de una referencia — el tamaño y la posición dan igual.
 */
function perfil(k, franjas) {
    const n = franjas || 16
    const l = limites(k)
    const out = []
    if (!l) return out
    for (let i = 0; i < n; i++) {
        const y0 = l.y + Math.floor(i * l.h / n)
        const y1 = l.y + Math.max(y0 + 1 - l.y, Math.floor((i + 1) * l.h / n))
        let a = k.w, b = -1, c = 0
        for (let y = y0; y < Math.min(l.y + l.h, y1); y++)
            for (let x = l.x; x < l.x + l.w; x++)
                if (k.m[y * k.w + x]) { if (x < a) a = x; if (x > b) b = x; c++ }
        out.push(b < a ? { izq: 0, der: 0, ancho: 0, lleno: 0 }
                       : { izq: +((a - l.x) / l.w).toFixed(3),
                           der: +((b - l.x + 1) / l.w).toFixed(3),
                           ancho: +((b - a + 1) / l.w).toFixed(3),
                           lleno: +(c / ((y1 - y0) * l.w)).toFixed(3) })
    }
    return out
}

/** Cuánto se parece una silueta a su propio espejo. 1 es simétrica exacta. */
function simetria(k) {
    const l = limites(k)
    if (!l) return 0
    let igual = 0, total = 0
    for (let y = l.y; y < l.y + l.h; y++) for (let x = l.x; x < l.x + l.w; x++) {
        const e = l.x + l.w - 1 - (x - l.x)
        const a = k.m[y * k.w + x], b = en(k, e, y)
        if (a || b) { total++; if (a && b) igual++ }
    }
    return total ? +(igual / total).toFixed(3) : 0
}

/**
 * Reescala una máscara por vecino más próximo hasta que su silueta mida
 * `alto` de alta, y la centra en (cx, cy) de un lienzo de w×h.
 *
 * El escalado es UNIFORME a propósito. Estirar cada silueta hasta llenar la
 * misma caja parece lo cómodo y es justo lo que no se quiere: una figura alta
 * y estrecha y una baja y ancha salen idénticas después de estirarlas, y la
 * proporción —que es la mitad de lo que se le pide a una referencia— se pierde
 * por el camino.
 */
function reescala(k, alto, w, h, cx, cy) {
    const l = limites(k)
    const r = mascara(w, h)
    if (!l || !l.h) return r
    const f = alto / l.h
    const nw = Math.max(1, Math.round(l.w * f)), nh = Math.max(1, Math.round(alto))
    const x0 = Math.round(cx - nw / 2), y0 = Math.round(cy - nh / 2)
    for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
        const sx = l.x + Math.min(l.w - 1, Math.floor(x / f))
        const sy = l.y + Math.min(l.h - 1, Math.floor(y / f))
        if (k.m[sy * k.w + sx]) marca(r, x0 + x, y0 + y)
    }
    return r
}

/**
 * Cuánto se solapan dos siluetas, con la segunda reescalada a la caja de la
 * primera y probando desplazamientos.
 *
 * Devuelve la unión partido la intersección, que es la medida estándar y va
 * de 0 a 1. Esto es lo que convierte «se parece» en un número, y con un
 * número se puede BUSCAR: mover un parámetro del aparejo, volver a medir, y
 * quedarse con el que sube. Sin esto, ajustar es opinar.
 */
function solape(a, b, margen) {
    const la = limites(a), lb = limites(b)
    if (!la || !lb) return { iou: 0, dx: 0, dy: 0, relacion: null }
    const bb = reescala(b, la.h, a.w, a.h, la.x + la.w / 2, la.y + la.h / 2)
    const m = margen === undefined ? 3 : margen
    let mejor = { iou: 0, dx: 0, dy: 0 }
    for (let dy = -m; dy <= m; dy++) for (let dx = -m; dx <= m; dx++) {
        let inter = 0, union = 0
        for (let y = 0; y < a.h; y++) for (let x = 0; x < a.w; x++) {
            const p = a.m[y * a.w + x], q = en(bb, x - dx, y - dy)
            if (p || q) { union++; if (p && q) inter++ }
        }
        const iou = union ? inter / union : 0
        if (iou > mejor.iou) mejor = { iou: +iou.toFixed(4), dx: dx, dy: dy }
    }
    //  La relación de aspecto de cada una, para que un desacuerdo de anchura
    //  se pueda leer como un número y no sólo como un solape más bajo.
    mejor.relacion = { a: +(la.w / la.h).toFixed(3), b: +(lb.w / lb.h).toFixed(3) }
    return mejor
}

/**
 * Los colores de un dibujo, agrupados en rampas por tono.
 *
 * Un sprite no trae su paleta ordenada: trae una lista de colores. Agruparlos
 * por tono y ordenar cada grupo por luminancia es lo que devuelve las RAMPAS
 * con las que se dibujó, y una rampa es sustituible — que es todo el asunto de
 * hacer una variante. Los grises van aparte porque no tienen tono, y meterlos
 * con cualquiera arrastraría la rampa entera hacia el neutro.
 */
function rampasDe(b, tope) {
    const cols = coloresPorPeso(b, tope || 48)
    const grupos = []
    const grises = []
    //  El tono es un ÁNGULO y se promedia como un ángulo: sumando senos y
    //  cosenos. Hacerlo como un número normal parece que funciona hasta que
    //  entra un rojo —que está a la vez en 350 y en 10— y la media sale en
    //  120, en pleno verde. Entonces el grupo deja de atraer a los suyos y
    //  empieza a robar a otros. Lo peor es que dependía del ORDEN de llegada
    //  de los colores, así que salía distinto en cada motor de JavaScript.
    const gr = (g) => {
        const t = Math.atan2(g.sy, g.sx) * 180 / Math.PI
        return (t % 360 + 360) % 360
    }
    for (let i = 0; i < cols.length; i++) {
        const c = cols[i].color
        const hsv = P.aHsv(c)
        if (hsv[1] < 0.14) { grises.push(cols[i]); continue }
        const rad = hsv[0] * Math.PI / 180
        let mejorG = -1, mejorD = 46
        for (let g = 0; g < grupos.length; g++) {
            const d = Math.abs(gr(grupos[g]) - hsv[0])
            const dd = Math.min(d, 360 - d)
            if (dd < mejorD) { mejorD = dd; mejorG = g }
        }
        if (mejorG < 0) grupos.push({ sx: 0, sy: 0, cols: [] })
        const g = grupos[mejorG < 0 ? grupos.length - 1 : mejorG]
        g.cols.push(cols[i])
        g.sx += Math.cos(rad); g.sy += Math.sin(rad)
    }
    if (grises.length) grupos.push({ sx: 0, sy: 0, gris: true, cols: grises })
    return grupos.map((g) => ({
        tono: g.gris ? null : Math.round(gr(g)) % 360,
        pixeles: g.cols.reduce((a, x) => a + x.veces, 0),
        colores: g.cols.sort((x, y) => P.luma(x.color) - P.luma(y.color))
                       .map((x) => P.aHex(x.color))
    })).sort((a, b2) => b2.pixeles - a.pixeles)
}

function coloresPorPeso(b, tope) { return P.coloresDe(b, tope) }

/** Todo lo medible de un búfer, de una llamada. */
function analiza(b, franjas) {
    const k = deBuffer(b)
    const l = limites(k)
    const c = centro(k)
    const m = P.medidas(b)
    const sil = P.silueta(b)
    const val = [0, 0, 0, 0, 0, 0, 0, 0]
    for (let i = 0; i < b.w * b.h; i++) {
        if (b.d[i * 4 + 3] < 8) continue
        val[Math.min(7, Math.floor(P.luma([b.d[i*4], b.d[i*4+1], b.d[i*4+2]]) / 32))]++
    }
    return {
        lienzo: { ancho: b.w, alto: b.h },
        limites: l,
        pixeles: c ? c.n : 0,
        densidad: l ? +(c.n / (l.w * l.h)).toFixed(3) : 0,
        //  El centro de masa dentro de su propia caja: dice si el bicho pesa
        //  arriba o abajo, que es media proporción.
        centro: l && c ? { x: +((c.x - l.x) / l.w).toFixed(3),
                           y: +((c.y - l.y) / l.h).toFixed(3) } : null,
        simetria: simetria(k),
        silueta: { pieBajo: sil.pieBajo, medioAncho: sil.medioAncho, base: +sil.base.toFixed(2) },
        saturacion: +m.saturacion.toFixed(3),
        luminancia: +m.luminancia.toFixed(1),
        valores: val,
        perfil: perfil(k, franjas || 16),
        //  Antes de tocar un dibujo hay que saber qué es contorno. Va aquí y
        //  no en una llamada aparte porque quien mide para hacer una variante
        //  lo necesita SIEMPRE, y lo que no se pide por defecto se olvida.
        contorno: contornoDe(b),
        rampas: rampasDe(b)
    }
}

/**
 * Qué colores forman el CONTORNO, y no por su color sino por dónde están.
 *
 * Hacía falta porque adivinarlo por el color es adivinar. Agrupando la paleta
 * por tono, el negro del contorno y el blanco de un brillo caen los dos en «los
 * neutros», y separarlos por luminancia parece que funciona hasta que un bicho
 * tiene el contorno marrón oscuro o el fondo de un ojo casi negro. Entonces un
 * recolor se lleva por delante el contorno sin enterarse, que es la forma más
 * rápida de que una variante deje de pertenecer a su juego: en un pack con
 * contorno negro, un solo bicho con el contorno teñido canta desde lejos.
 *
 * El contorno no es un color: es una POSICIÓN. Son los píxeles opacos con
 * algún vecino transparente, y eso se mide.
 *
 * Por cada color se devuelven dos fracciones que contestan preguntas
 * distintas y hacen falta las dos:
 *   `delAnillo`  cuánto del contorno es este color — alto significa «este
 *                color ES el contorno».
 *   `suyoFuera`  cuánto de este color está en el contorno — bajo significa
 *                que además se usa por dentro, como el negro de un ojo.
 */
function contornoDe(b) {
    const k = deBuffer(b)
    const anillo = borde(k)
    const total = cuantos(anillo)
    const cuenta = {}, dentro = {}
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
        const i = y * b.w + x
        if (b.d[i * 4 + 3] < 8) continue
        const key = P.aHex([b.d[i*4], b.d[i*4+1], b.d[i*4+2], 255])
        dentro[key] = (dentro[key] || 0) + 1
        if (anillo.m[i]) cuenta[key] = (cuenta[key] || 0) + 1
    }
    const lista = Object.keys(cuenta).map((h) => ({
        color: h,
        pixeles: cuenta[h],
        delAnillo: total ? +(cuenta[h] / total).toFixed(3) : 0,
        suyoFuera: +(cuenta[h] / dentro[h]).toFixed(3)
    })).sort((a, b2) => b2.delAnillo - a.delAnillo)

    //  «El contorno» son el color que más manda en el anillo y los que le
    //  hagan sombra de verdad — no los que hagan falta para llegar a un
    //  porcentaje.
    //
    //  Acumulando hasta cubrir el 90 % parecía razonable y era una trampa: en
    //  un sprite pequeño casi todo el dibujo está a un píxel del borde, así
    //  que colores del CUERPO entran en el anillo con un 20 % cada uno y se
    //  colaban como contorno. Y un color protegido por error es un color que
    //  el recolor no toca: media variante sin recolorear y ninguna queja.
    //
    //  Un contorno de dos tonos —matizado por el lado de la luz— sí existe y
    //  hay que admitirlo, pero entonces los dos pesan parecido. Un tercero al
    //  20 % contra un primero al 60 % no es la otra mitad de un contorno: es
    //  otra cosa.
    const son = []
    let acumulado = 0
    for (let i = 0; i < lista.length; i++) {
        if (i > 0 && lista[i].delAnillo < lista[0].delAnillo * 0.5) break
        if (lista[i].delAnillo < 0.08) break
        son.push(lista[i].color)
        acumulado += lista[i].delAnillo
    }
    return { pixeles: total, colores: son, cubren: +acumulado.toFixed(3),
             //  Cuánto manda el primero. Bajo quiere decir que este dibujo no
             //  tiene un contorno claro, y que quien vaya a recolorear haría
             //  bien en mirarlo antes de fiarse.
             manda: lista.length ? lista[0].delAnillo : 0,
             todos: lista }
}

/**
 * Todas las celdas en un mosaico, para medirlas de una vez.
 *
 * Medir el compuesto que tienes delante es medir UNA celda, y un color que
 * sólo sale en otro fotograma o en otra cara no entra en lo que midas. Con eso
 * un recolor deja sin tocar lo que no llegó a ver, y no se queja nadie: el
 * bicho cambia de color al girarse y te enteras jugando.
 *
 * El hueco entre celdas no es un margen bonito. Pegadas, dos siluetas vecinas
 * se tocan y sus bordes dejan de tener vecino transparente — y entonces el
 * contorno, que se detecta por posición, se detecta mal justo donde se juntan.
 */
function mosaico(cels, w, h, hueco) {
    const g = hueco === undefined ? 2 : hueco
    if (!cels || !cels.length) return P.nuevo(1, 1)
    const cols = Math.max(1, Math.ceil(Math.sqrt(cels.length)))
    const filas = Math.ceil(cels.length / cols)
    const an = w + g, al = h + g
    const m = P.nuevo(cols * an, filas * al)
    for (let i = 0; i < cels.length; i++) {
        if (!cels[i]) continue
        P.vuelca(m, cels[i], (i % cols) * an + Math.floor(g / 2),
                             Math.floor(i / cols) * al + Math.floor(g / 2))
    }
    return m
}

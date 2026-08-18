.pragma library

//  El motor de píxeles. Funciones puras: nada de aquí sabe que existe una
//  interfaz, y por eso todo esto se puede probar sin abrir una ventana.
//
//  Un BÚFER es { w, h, d } donde d es un Uint8ClampedArray de w*h*4 en RGBA
//  NO premultiplicado. Es la única representación que hay en todo el
//  programa: las capas son búferes, el portapapeles es un búfer, un pincel a
//  medida es un búfer y lo que se exporta sale de un búfer.

// ═══════════════════════════════════════════════════════════════
// búferes
// ═══════════════════════════════════════════════════════════════

function nuevo(w, h) {
    return { w: w, h: h, d: new Uint8ClampedArray(w * h * 4) }
}

function clonar(b) {
    return { w: b.w, h: b.h, d: new Uint8ClampedArray(b.d) }
}

function vacio(b) {
    for (let i = 3; i < b.d.length; i += 4) if (b.d[i] !== 0) return false
    return true
}

function dentro(b, x, y) { return x >= 0 && y >= 0 && x < b.w && y < b.h }

function lee(b, x, y) {
    if (!dentro(b, x, y)) return [0, 0, 0, 0]
    const i = (y * b.w + x) * 4
    return [b.d[i], b.d[i + 1], b.d[i + 2], b.d[i + 3]]
}

/** Escribe crudo, sin mezclar. Es lo que quiere la goma y el pegado. */
function pon(b, x, y, c) {
    if (!dentro(b, x, y)) return
    const i = (y * b.w + x) * 4
    b.d[i] = c[0]; b.d[i + 1] = c[1]; b.d[i + 2] = c[2]; b.d[i + 3] = c[3]
}

/**
 * Escribe mezclando por alfa (source-over).
 *
 * `alfaBloqueado` es el "lock transparent pixels" de toda la vida: sólo pinta
 * donde ya había algo. Es la diferencia entre sombrear dentro de una silueta
 * y salirse por todas partes, así que vive aquí abajo y no en cada herramienta.
 */
function mezcla(b, x, y, c, alfaBloqueado) {
    if (!dentro(b, x, y)) return
    const i = (y * b.w + x) * 4
    const da = b.d[i + 3]
    if (alfaBloqueado && da === 0) return
    const sa = c[3] / 255
    if (sa <= 0) return
    if (sa >= 1 && !alfaBloqueado) {
        b.d[i] = c[0]; b.d[i + 1] = c[1]; b.d[i + 2] = c[2]; b.d[i + 3] = 255
        return
    }
    const dab = da / 255
    const oa = sa + dab * (1 - sa)
    if (oa <= 0) { b.d[i + 3] = 0; return }
    b.d[i]     = (c[0] * sa + b.d[i]     * dab * (1 - sa)) / oa
    b.d[i + 1] = (c[1] * sa + b.d[i + 1] * dab * (1 - sa)) / oa
    b.d[i + 2] = (c[2] * sa + b.d[i + 2] * dab * (1 - sa)) / oa
    b.d[i + 3] = alfaBloqueado ? da : oa * 255
}

/** Recorta un rectángulo a un búfer nuevo. */
function recorte(b, x, y, w, h) {
    const r = nuevo(w, h)
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
        const s = ((y + j) * b.w + (x + i)) * 4
        const t = (j * w + i) * 4
        if (!dentro(b, x + i, y + j)) continue
        r.d[t] = b.d[s]; r.d[t+1] = b.d[s+1]; r.d[t+2] = b.d[s+2]; r.d[t+3] = b.d[s+3]
    }
    return r
}

/**
 * Vuelca un recorte RESPETANDO lo que ya había.
 *
 * Los píxeles transparentes del recorte no borran nada. Es la diferencia entre
 * pegar algo encima de un dibujo y pegarlo dentro de un agujero rectangular del
 * tamaño del recorte: `vuelca` hace lo segundo, que es lo que quiere deshacer y
 * lo que NO quiere nadie pegando.
 */
function estampa(b, r, x, y, alfaBloqueado) {
    for (let j = 0; j < r.h; j++) for (let i = 0; i < r.w; i++) {
        const c = lee(r, i, j)
        if (c[3] === 0) continue
        mezcla(b, x + i, y + j, c, alfaBloqueado)
    }
}

/** Vuelca un recorte encima, crudo. Es lo que usa deshacer. */
function vuelca(b, r, x, y) {
    for (let j = 0; j < r.h; j++) for (let i = 0; i < r.w; i++) {
        if (!dentro(b, x + i, y + j)) continue
        const s = (j * r.w + i) * 4
        const t = ((y + j) * b.w + (x + i)) * 4
        b.d[t] = r.d[s]; b.d[t+1] = r.d[s+1]; b.d[t+2] = r.d[s+2]; b.d[t+3] = r.d[s+3]
    }
}

// ═══════════════════════════════════════════════════════════════
// color
// ═══════════════════════════════════════════════════════════════

function deHex(h) {
    h = String(h).replace("#", "")
    if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2]
    if (h.length === 6) h += "ff"
    return [parseInt(h.substr(0,2),16), parseInt(h.substr(2,2),16),
            parseInt(h.substr(4,2),16), parseInt(h.substr(6,2),16)]
}

function aHex(c) {
    const p = (n) => ("0" + Math.round(n).toString(16)).slice(-2)
    return "#" + p(c[0]) + p(c[1]) + p(c[2])
}

function aHexA(c) {
    const p = (n) => ("0" + Math.round(n).toString(16)).slice(-2)
    return "#" + p(c[0]) + p(c[1]) + p(c[2]) + p(c[3] === undefined ? 255 : c[3])
}

function aHsv(c) {
    const r = c[0]/255, g = c[1]/255, b = c[2]/255
    const mx = Math.max(r,g,b), mn = Math.min(r,g,b), d = mx - mn
    let h = 0
    if (d) {
        if (mx === r) h = ((g - b) / d) % 6
        else if (mx === g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h *= 60; if (h < 0) h += 360
    }
    return [h, mx ? d / mx : 0, mx]
}

function deHsv(h, s, v, a) {
    h = ((h % 360) + 360) % 360
    const c = v * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = v - c
    let r = 0, g = 0, b = 0
    if (h < 60) { r = c; g = x } else if (h < 120) { r = x; g = c }
    else if (h < 180) { g = c; b = x } else if (h < 240) { g = x; b = c }
    else if (h < 300) { r = x; b = c } else { r = c; b = x }
    return [(r+m)*255, (g+m)*255, (b+m)*255, a === undefined ? 255 : a]
}

/** Luma perceptual, la misma fórmula que usa el juego para medir contraste. */
function luma(c) { return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] }

function distancia(a, b) {
    const dr = a[0]-b[0], dg = a[1]-b[1], db = a[2]-b[2], da = a[3]-b[3]
    return Math.sqrt(dr*dr + dg*dg + db*db + da*da)
}

// ═══════════════════════════════════════════════════════════════
// modos de fusión
// ═══════════════════════════════════════════════════════════════

var MODOS = ["normal", "multiplicar", "trama", "superponer", "oscurecer", "aclarar",
             "sobreexponer", "subexponer", "luz-fuerte", "luz-suave", "diferencia",
             "exclusion", "sumar", "restar", "tono", "saturacion", "color", "luminosidad"]

function _f(modo, s, d) {
    switch (modo) {
    case "multiplicar":  return s * d / 255
    case "trama":        return 255 - (255 - s) * (255 - d) / 255
    case "superponer":   return d < 128 ? 2 * s * d / 255 : 255 - 2 * (255 - s) * (255 - d) / 255
    case "oscurecer":    return Math.min(s, d)
    case "aclarar":      return Math.max(s, d)
    case "sobreexponer": return s >= 255 ? 255 : Math.min(255, d * 255 / (255 - s))
    case "subexponer":   return s <= 0 ? 0 : 255 - Math.min(255, (255 - d) * 255 / s)
    case "luz-fuerte":   return s < 128 ? 2 * s * d / 255 : 255 - 2 * (255 - s) * (255 - d) / 255
    case "luz-suave": {
        const cs = s / 255, cd = d / 255
        const r = cs <= 0.5 ? cd - (1 - 2 * cs) * cd * (1 - cd)
                            : cd + (2 * cs - 1) * ((cd <= 0.25
                                ? ((16 * cd - 12) * cd + 4) * cd : Math.sqrt(cd)) - cd)
        return r * 255
    }
    case "diferencia":   return Math.abs(s - d)
    case "exclusion":    return s + d - 2 * s * d / 255
    case "sumar":        return Math.min(255, s + d)
    case "restar":       return Math.max(0, d - s)
    default:             return s
    }
}

/** Los cuatro modos de componente HSL van juntos porque tocan los tres canales. */
function _hsl(modo, s, d) {
    const hs = aHsv(s), hd = aHsv(d)
    switch (modo) {
    case "tono":         return deHsv(hs[0], hd[1], hd[2], 255)
    case "saturacion":   return deHsv(hd[0], hs[1], hd[2], 255)
    case "color":        return deHsv(hs[0], hs[1], hd[2], 255)
    case "luminosidad":  return deHsv(hd[0], hd[1], hs[2], 255)
    }
    return s
}

/**
 * Compone `arriba` sobre `abajo` en el sitio, con modo y opacidad.
 *
 * `abajo` se modifica; `arriba` no se toca. El recorte opcional evita
 * recomponer todo el lienzo por un trazo de tres píxeles, que es lo que hace
 * que dibujar se sienta instantáneo en vez de pastoso.
 */
function compon(abajo, arriba, modo, opacidad, rx, ry, rw, rh) {
    const x0 = rx === undefined ? 0 : Math.max(0, rx)
    const y0 = ry === undefined ? 0 : Math.max(0, ry)
    const x1 = rw === undefined ? abajo.w : Math.min(abajo.w, x0 + rw)
    const y1 = rh === undefined ? abajo.h : Math.min(abajo.h, y0 + rh)
    const esHsl = modo === "tono" || modo === "saturacion" || modo === "color" || modo === "luminosidad"

    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
        const i = (y * abajo.w + x) * 4
        const sa = arriba.d[i + 3] / 255 * opacidad
        if (sa <= 0) continue
        const da = abajo.d[i + 3] / 255

        let s = [arriba.d[i], arriba.d[i+1], arriba.d[i+2]]
        if (modo !== "normal" && da > 0) {
            const d = [abajo.d[i], abajo.d[i+1], abajo.d[i+2]]
            s = esHsl ? _hsl(modo, s, d)
                      : [_f(modo, s[0], d[0]), _f(modo, s[1], d[1]), _f(modo, s[2], d[2])]
        }

        const oa = sa + da * (1 - sa)
        if (oa <= 0) { abajo.d[i + 3] = 0; continue }
        abajo.d[i]     = (s[0] * sa + abajo.d[i]     * da * (1 - sa)) / oa
        abajo.d[i + 1] = (s[1] * sa + abajo.d[i + 1] * da * (1 - sa)) / oa
        abajo.d[i + 2] = (s[2] * sa + abajo.d[i + 2] * da * (1 - sa)) / oa
        abajo.d[i + 3] = oa * 255
    }
}

// ═══════════════════════════════════════════════════════════════
// formas
// ═══════════════════════════════════════════════════════════════

/** Bresenham. Devuelve los puntos; quien llama decide qué pinta en ellos. */
function linea(x0, y0, x1, y1) {
    const pts = []
    let dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0)
    let sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1
    let err = dx + dy
    for (;;) {
        pts.push([x0, y0])
        if (x0 === x1 && y0 === y1) break
        const e2 = 2 * err
        if (e2 >= dy) { err += dy; x0 += sx }
        if (e2 <= dx) { err += dx; y0 += sy }
    }
    return pts
}

/**
 * Quita las esquinas dobles de un trazo.
 *
 * Un trazo a mano alzada deja pares de píxeles en diagonal que en pixel art
 * se ven como un bulto. El "trazo perfecto" borra el píxel del medio cuando
 * tres seguidos hacen un codo. Es la diferencia entre una línea dibujada y
 * una línea que parece dibujada por un ratón.
 */
function perfecciona(pts) {
    if (pts.length < 3) return pts.slice()
    const out = [pts[0]]
    for (let i = 1; i < pts.length - 1; i++) {
        const a = out[out.length - 1], b = pts[i], c = pts[i + 1]
        const codo = (a[0] !== c[0]) && (a[1] !== c[1])
                  && (Math.abs(a[0] - c[0]) === 1) && (Math.abs(a[1] - c[1]) === 1)
                  && ((b[0] === a[0] && b[1] === c[1]) || (b[1] === a[1] && b[0] === c[0]))
        if (!codo) out.push(b)
    }
    out.push(pts[pts.length - 1])
    return out
}

function rectangulo(x0, y0, x1, y1, relleno) {
    const ax = Math.min(x0, x1), bx = Math.max(x0, x1)
    const ay = Math.min(y0, y1), by = Math.max(y0, y1)
    const pts = []
    if (relleno) {
        for (let y = ay; y <= by; y++) for (let x = ax; x <= bx; x++) pts.push([x, y])
    } else {
        for (let x = ax; x <= bx; x++) { pts.push([x, ay]); pts.push([x, by]) }
        for (let y = ay + 1; y < by; y++) { pts.push([ax, y]); pts.push([bx, y]) }
    }
    return pts
}

/** Elipse de punto medio, encajada en el rectángulo dado. */
function elipse(x0, y0, x1, y1, relleno) {
    const ax = Math.min(x0, x1), bx = Math.max(x0, x1)
    const ay = Math.min(y0, y1), by = Math.max(y0, y1)
    const w = bx - ax + 1, h = by - ay + 1
    const cx = (ax + bx) / 2, cy = (ay + by) / 2
    const rx = w / 2, ry = h / 2
    const pts = []
    const dentroDe = (x, y) => {
        const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry
        return dx * dx + dy * dy <= 1
    }
    for (let y = ay; y <= by; y++) for (let x = ax; x <= bx; x++) {
        if (!dentroDe(x, y)) continue
        if (relleno) { pts.push([x, y]); continue }
        // borde: dentro con algún vecino fuera
        if (!dentroDe(x-1,y) || !dentroDe(x+1,y) || !dentroDe(x,y-1) || !dentroDe(x,y+1))
            pts.push([x, y])
    }
    return pts
}

/** Un disco de radio r centrado en (0,0), que es la punta de un pincel. */
function punta(radio, cuadrada) {
    const pts = []
    const r = Math.max(0, radio - 1)
    for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) {
        if (cuadrada || radio <= 1 || (x * x + y * y) <= r * r + r * 0.5) pts.push([x, y])
    }
    return pts
}

// ═══════════════════════════════════════════════════════════════
// inundación y selección por color
// ═══════════════════════════════════════════════════════════════

/**
 * Relleno por inundación con tolerancia.
 *
 * Devuelve una máscara Uint8Array, no pinta: así el mismo recorrido sirve
 * para el cubo, para la varita mágica y para la selección por color, que son
 * la misma pregunta hecha tres veces.
 */
function inunda(b, x, y, tolerancia, ocho, limite) {
    const m = new Uint8Array(b.w * b.h)
    if (!dentro(b, x, y)) return m
    const origen = lee(b, x, y)
    const pila = [x + y * b.w]
    m[x + y * b.w] = 1
    const vecinos = ocho ? [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]
                         : [[1,0],[-1,0],[0,1],[0,-1]]
    while (pila.length) {
        const p = pila.pop()
        const px = p % b.w, py = (p - px) / b.w
        for (let k = 0; k < vecinos.length; k++) {
            const nx = px + vecinos[k][0], ny = py + vecinos[k][1]
            if (!dentro(b, nx, ny)) continue
            const n = nx + ny * b.w
            if (m[n]) continue
            if (limite && !limite[n]) continue
            if (distancia(lee(b, nx, ny), origen) > tolerancia) continue
            m[n] = 1
            pila.push(n)
        }
    }
    return m
}

/** Todo el lienzo que se parezca a este color, contiguo o no. */
function porColor(b, x, y, tolerancia) {
    const m = new Uint8Array(b.w * b.h)
    const origen = lee(b, x, y)
    for (let i = 0; i < b.w * b.h; i++) {
        const c = [b.d[i*4], b.d[i*4+1], b.d[i*4+2], b.d[i*4+3]]
        if (distancia(c, origen) <= tolerancia) m[i] = 1
    }
    return m
}

/** La silueta de la capa, para "seleccionar desde el alfa". */
function porAlfa(b, umbral) {
    const m = new Uint8Array(b.w * b.h)
    const u = umbral === undefined ? 0 : umbral
    for (let i = 0; i < b.w * b.h; i++) if (b.d[i*4+3] > u) m[i] = 1
    return m
}

// ═══════════════════════════════════════════════════════════════
// transformaciones
// ═══════════════════════════════════════════════════════════════

function volteaH(b) {
    const r = nuevo(b.w, b.h)
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) pon(r, b.w - 1 - x, y, lee(b, x, y))
    return r
}

function volteaV(b) {
    const r = nuevo(b.w, b.h)
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) pon(r, x, b.h - 1 - y, lee(b, x, y))
    return r
}

/** Cuartos de vuelta en sentido horario. */
function gira90(b, veces) {
    let r = clonar(b)
    const n = ((veces % 4) + 4) % 4
    for (let k = 0; k < n; k++) {
        const s = nuevo(r.h, r.w)
        for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++)
            pon(s, r.h - 1 - y, x, lee(r, x, y))
        r = s
    }
    return r
}

function escalaVecino(b, w, h) {
    const r = nuevo(w, h)
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++)
        pon(r, x, y, lee(b, Math.min(b.w - 1, Math.floor(x * b.w / w)),
                            Math.min(b.h - 1, Math.floor(y * b.h / h))))
    return r
}

/**
 * Escalado tipo RotSprite: se agranda ×8 decidiendo cada subpíxel por
 * mayoría de sus vecinos, y se vuelve a bajar. Sale mucho más limpio que el
 * vecino cercano a secas cuando el factor no es entero, que es casi siempre.
 */
function escalaSuave(b, w, h) {
    const g = 8
    const grande = nuevo(b.w * g, b.h * g)
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
        const c = lee(b, x, y)
        for (let j = 0; j < g; j++) for (let i = 0; i < g; i++) {
            // esquina redondeada si los dos vecinos de ese lado coinciden
            let usa = c
            const hx = i < g / 2 ? -1 : 1, hy = j < g / 2 ? -1 : 1
            const a = lee(b, x + hx, y), d = lee(b, x, y + hy)
            const borde = (i < g/4 || i >= g*3/4) && (j < g/4 || j >= g*3/4)
            if (borde && distancia(a, d) < 24 && distancia(a, c) > 48) usa = a
            pon(grande, x * g + i, y * g + j, usa)
        }
    }
    return escalaVecino(grande, w, h)
}

/** Sesgado horizontal/vertical en píxeles enteros. */
function sesga(b, sx, sy) {
    const w = b.w + Math.abs(Math.round(sx * b.h))
    const h = b.h + Math.abs(Math.round(sy * b.w))
    const r = nuevo(w, h)
    const ox = sx < 0 ? Math.abs(Math.round(sx * b.h)) : 0
    const oy = sy < 0 ? Math.abs(Math.round(sy * b.w)) : 0
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++)
        pon(r, ox + x + Math.round(sx * y), oy + y + Math.round(sy * x), lee(b, x, y))
    return r
}

/** Desplaza envolviendo. Es lo que necesita una baldosa para mover la costura. */
function desplaza(b, dx, dy) {
    const r = nuevo(b.w, b.h)
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++)
        pon(r, ((x + dx) % b.w + b.w) % b.w, ((y + dy) % b.h + b.h) % b.h, lee(b, x, y))
    return r
}

/** El rectángulo que ocupa lo dibujado. Null si no hay nada. */
function limites(b, umbral) {
    const u = umbral === undefined ? 0 : umbral
    let x0 = b.w, y0 = b.h, x1 = -1, y1 = -1
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
        if (b.d[(y * b.w + x) * 4 + 3] <= u) continue
        if (x < x0) x0 = x; if (x > x1) x1 = x
        if (y < y0) y0 = y; if (y > y1) y1 = y
    }
    return x1 < x0 ? null : { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }
}

/**
 * Las medidas que el juego saca del dibujo y no del recuadro.
 *
 * crabh mide `footPad` (filas vacías por debajo, que apoyan los pies en el
 * suelo) y la mitad de la silueta (de donde sale el radio de colisión) leyendo
 * los píxeles. Dejar tres filas de más cambia dónde pisa el bicho sin que se
 * vea nada raro en el editor, así que el editor tiene que enseñarlo.
 */
function silueta(b) {
    const l = limites(b, 8)
    if (!l) return { pieBajo: 0, medioAncho: b.w / 2, limites: null, base: b.w / 2 }
    // el radio de base sale del tercio inferior: una copa no es algo con lo
    // que chocas, un tronco sí
    const desde = Math.max(0, b.h - Math.round(b.h / 3))
    let bx0 = b.w, bx1 = -1
    for (let y = desde; y < b.h; y++) for (let x = 0; x < b.w; x++) {
        if (b.d[(y * b.w + x) * 4 + 3] < 128) continue
        if (x < bx0) bx0 = x; if (x > bx1) bx1 = x
    }
    return {
        pieBajo: b.h - 1 - (l.y + l.h - 1),
        medioAncho: l.w / 2,
        base: bx1 < bx0 ? l.w / 2 : ((bx1 - bx0 + 1) / 2) * 0.85,
        limites: l
    }
}

// ═══════════════════════════════════════════════════════════════
// paleta
// ═══════════════════════════════════════════════════════════════

/** Los colores que hay de verdad, por frecuencia. Ignora lo transparente. */
function coloresDe(b, tope) {
    const cuenta = {}
    for (let i = 0; i < b.w * b.h; i++) {
        if (b.d[i*4+3] < 8) continue
        const k = b.d[i*4] + "," + b.d[i*4+1] + "," + b.d[i*4+2]
        cuenta[k] = (cuenta[k] || 0) + 1
    }
    const lista = Object.keys(cuenta).map((k) => {
        const p = k.split(",").map(Number)
        return { color: [p[0], p[1], p[2], 255], veces: cuenta[k] }
    })
    lista.sort((a, b2) => b2.veces - a.veces)
    return tope ? lista.slice(0, tope) : lista
}

/** Media de saturación y luminancia — informativo, nunca una prohibición. */
function medidas(b) {
    let n = 0, s = 0, l = 0
    for (let i = 0; i < b.w * b.h; i++) {
        if (b.d[i*4+3] < 8) continue
        const c = [b.d[i*4], b.d[i*4+1], b.d[i*4+2]]
        s += aHsv(c)[1]; l += luma(c); n++
    }
    return n ? { saturacion: s / n, luminancia: l / n, pixeles: n }
             : { saturacion: 0, luminancia: 0, pixeles: 0 }
}

/** Al color más cercano de la lista dada. */
function acerca(c, paleta) {
    let mejor = c, d = Infinity
    for (let i = 0; i < paleta.length; i++) {
        const e = distancia(c, paleta[i])
        if (e < d) { d = e; mejor = paleta[i] }
    }
    return [mejor[0], mejor[1], mejor[2], c[3]]
}

function cuantiza(b, paleta) {
    const r = clonar(b)
    for (let i = 0; i < b.w * b.h; i++) {
        if (r.d[i*4+3] < 8) continue
        const c = acerca([r.d[i*4], r.d[i*4+1], r.d[i*4+2], 255], paleta)
        r.d[i*4] = c[0]; r.d[i*4+1] = c[1]; r.d[i*4+2] = c[2]
    }
    return r
}

/**
 * Reduce a N colores por corte mediano.
 *
 * Se usa para extraer una paleta de una imagen que viene de fuera —un boceto,
 * un render, un rip— no para castigar lo que dibujas. Aquí no hay límites
 * impuestos: el número lo pides tú.
 */
function reduce(b, n) {
    let cajas = [coloresDe(b).map((e) => e.color)]
    if (!cajas[0].length) return []
    while (cajas.length < n) {
        let mejor = -1, rango = -1, eje = 0
        for (let i = 0; i < cajas.length; i++) {
            if (cajas[i].length < 2) continue
            for (let k = 0; k < 3; k++) {
                let lo = 255, hi = 0
                for (let j = 0; j < cajas[i].length; j++) {
                    const v = cajas[i][j][k]
                    if (v < lo) lo = v; if (v > hi) hi = v
                }
                if (hi - lo > rango) { rango = hi - lo; mejor = i; eje = k }
            }
        }
        if (mejor < 0) break
        const caja = cajas[mejor].slice().sort((p, q) => p[eje] - q[eje])
        const mitad = Math.floor(caja.length / 2)
        cajas.splice(mejor, 1, caja.slice(0, mitad), caja.slice(mitad))
    }
    return cajas.filter((c) => c.length).map((caja) => {
        let r = 0, g = 0, bl = 0
        for (let i = 0; i < caja.length; i++) { r += caja[i][0]; g += caja[i][1]; bl += caja[i][2] }
        return [Math.round(r/caja.length), Math.round(g/caja.length), Math.round(bl/caja.length), 255]
    })
}

/** Ordena una paleta de forma que se pueda leer. */
function ordena(lista, por) {
    const c = lista.slice()
    if (por === "luma") c.sort((a, b) => luma(a) - luma(b))
    else if (por === "saturacion") c.sort((a, b) => aHsv(a)[1] - aHsv(b)[1])
    else c.sort((a, b) => { const x = aHsv(a), y = aHsv(b); return x[0] - y[0] || x[2] - y[2] })
    return c
}

// ═══════════════════════════════════════════════════════════════
// tramado
// ═══════════════════════════════════════════════════════════════

var TRAMAS = {
    "solido":   [[1,1],[1,1]],
    "50":       [[1,0],[0,1]],
    "25":       [[1,0],[0,0]],
    "75":       [[1,1],[0,1]],
    "lineas-h": [[1,1],[0,0]],
    "lineas-v": [[1,0],[1,0]],
    "bayer":    [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]
}

/** ¿Pinta este píxel, con esta trama y esta proporción? */
function trama(nombre, x, y, proporcion) {
    const t = TRAMAS[nombre] || TRAMAS["solido"]
    const n = t.length
    if (nombre === "bayer") return (t[y % n][x % n] / (n * n)) < (proporcion === undefined ? 1 : proporcion)
    return t[y % n][x % t[0].length] === 1
}

// ═══════════════════════════════════════════════════════════════
// filtros
// ═══════════════════════════════════════════════════════════════

/** Contorno de un píxel alrededor de lo dibujado. */
function contornea(b, color, ocho, dentroFuera) {
    const r = clonar(b)
    const vec = ocho ? [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]
                     : [[1,0],[-1,0],[0,1],[0,-1]]
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
        const a = b.d[(y*b.w+x)*4+3]
        if (dentroFuera === "dentro" ? a <= 8 : a > 8) continue
        for (let k = 0; k < vec.length; k++) {
            const nx = x + vec[k][0], ny = y + vec[k][1]
            const na = dentro(b, nx, ny) ? b.d[(ny*b.w+nx)*4+3] : 0
            if (dentroFuera === "dentro" ? na > 8 : na <= 8) continue
            pon(r, x, y, color); break
        }
    }
    return r
}

function sustituye(b, viejo, nuevoColor, tolerancia) {
    const r = clonar(b)
    for (let i = 0; i < b.w * b.h; i++) {
        const c = [r.d[i*4], r.d[i*4+1], r.d[i*4+2], r.d[i*4+3]]
        if (distancia(c, viejo) > tolerancia) continue
        r.d[i*4] = nuevoColor[0]; r.d[i*4+1] = nuevoColor[1]
        r.d[i*4+2] = nuevoColor[2]; r.d[i*4+3] = nuevoColor[3]
    }
    return r
}

/** Ajustes de tono/saturación/luminosidad sobre lo que hay. */
function ajusta(b, dh, ds, dv, mascara) {
    const r = clonar(b)
    for (let i = 0; i < b.w * b.h; i++) {
        if (r.d[i*4+3] < 8) continue
        if (mascara && !mascara[i]) continue
        const h = aHsv([r.d[i*4], r.d[i*4+1], r.d[i*4+2]])
        const c = deHsv(h[0] + dh, Math.max(0, Math.min(1, h[1] * (1 + ds))),
                        Math.max(0, Math.min(1, h[2] * (1 + dv))), r.d[i*4+3])
        r.d[i*4] = c[0]; r.d[i*4+1] = c[1]; r.d[i*4+2] = c[2]
    }
    return r
}

// ═══════════════════════════════════════════════════════════════
// base64
// ═══════════════════════════════════════════════════════════════

var _B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
var _B64INV = null

/**
 * Base64 a un búfer RGBA.
 *
 * El motor de QML no trae atob, así que se decodifica a mano. Es el camino por
 * el que entran las imágenes: la forja las lee con Pillow y las manda por aquí,
 * porque leerlas con el Canvas depende de que estén cargadas justo cuando toca
 * pintar y al arrancar no lo están — devolvía capas vacías sin dar ningún error.
 */
function deBase64(texto, w, h) {
    if (!_B64INV) {
        _B64INV = new Int16Array(128)
        for (let i = 0; i < 128; i++) _B64INV[i] = -1
        for (let i = 0; i < 64; i++) _B64INV[_B64.charCodeAt(i)] = i
    }
    const b = nuevo(w, h)
    const n = b.d.length
    let salida = 0, acumulado = 0, bits = 0
    for (let i = 0; i < texto.length && salida < n; i++) {
        const c = texto.charCodeAt(i)
        if (c > 127) continue
        const v = _B64INV[c]
        if (v < 0) continue
        acumulado = (acumulado << 6) | v
        bits += 6
        if (bits < 8) continue
        bits -= 8
        b.d[salida++] = (acumulado >> bits) & 0xFF
    }
    return b
}

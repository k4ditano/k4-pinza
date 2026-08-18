.pragma library

.import "pixeles.js" as P

//  Las herramientas.
//
//  JavaScript puro, sin una sola referencia a QML. La mitad de los fallos de
//  un editor de píxeles son de aritmética de coordenadas —un desplazamiento de
//  uno, una simetría que refleja sobre el eje equivocado, un pincel que se sale
//  de la selección— y esa mitad sólo se caza con pruebas en seco. Por eso esto
//  vive aquí y no dentro de la vista.
//
//  Cada herramienta contesta a abajo/mueve/arriba y trabaja contra una BROCHA,
//  que es quien sabe de selección, de bloqueo de alfa, de simetría y de trama.
//  Una herramienta nunca escribe en el búfer directamente: así ninguna se puede
//  olvidar de respetar la selección, que es el fallo clásico.

// ═══════════════════════════════════════════════════════════════
// la brocha
// ═══════════════════════════════════════════════════════════════

/**
 * ctx = {
 *   buf, ancho, alto,
 *   selContiene(x,y), alfaBloqueado,
 *   tamaño, puntaCuadrada, pincel (búfer o null),
 *   trama, proporcionTrama,
 *   simetriaH, simetriaV, ejeX, ejeY,
 *   baldosa (envuelve por los bordes)
 * }
 */
function Brocha(ctx) {
    this.ctx = ctx
    this.x0 = ctx.ancho; this.y0 = ctx.alto; this.x1 = -1; this.y1 = -1
}

Brocha.prototype.sucio = function (x, y) {
    if (x < this.x0) this.x0 = x
    if (x > this.x1) this.x1 = x
    if (y < this.y0) this.y0 = y
    if (y > this.y1) this.y1 = y
}

Brocha.prototype.rect = function () {
    if (this.x1 < this.x0) return null
    const x = Math.max(0, this.x0), y = Math.max(0, this.y0)
    return { x: x, y: y,
             w: Math.min(this.ctx.ancho, this.x1 + 1) - x,
             h: Math.min(this.ctx.alto, this.y1 + 1) - y }
}

/** Un píxel suelto, con todas las reglas aplicadas. Nadie salta por encima. */
Brocha.prototype.pixel = function (x, y, color, crudo) {
    const c = this.ctx
    if (c.baldosa) {
        x = ((x % c.ancho) + c.ancho) % c.ancho
        y = ((y % c.alto) + c.alto) % c.alto
    }
    if (x < 0 || y < 0 || x >= c.ancho || y >= c.alto) return
    if (!c.selContiene(x, y)) return
    if (c.trama && c.trama !== "solido" && !P.trama(c.trama, x, y, c.proporcionTrama)) return
    if (crudo) P.pon(c.buf, x, y, color)
    else P.mezcla(c.buf, x, y, color, c.alfaBloqueado)
    this.sucio(x, y)
}

/** Los puntos que hay que tocar además de (x,y) por la simetría. */
Brocha.prototype.reflejos = function (x, y) {
    const c = this.ctx
    const out = [[x, y]]
    const ex = c.ejeX >= 0 ? c.ejeX : (c.ancho - 1) / 2
    const ey = c.ejeY >= 0 ? c.ejeY : (c.alto - 1) / 2
    if (c.simetriaH) out.push([Math.round(2 * ex - x), y])
    if (c.simetriaV) out.push([x, Math.round(2 * ey - y)])
    if (c.simetriaH && c.simetriaV) out.push([Math.round(2 * ex - x), Math.round(2 * ey - y)])
    return out
}

/** La punta entera, en un sitio, con sus reflejos. */
Brocha.prototype.sello = function (x, y, color, crudo) {
    const c = this.ctx
    const puntos = this.reflejos(x, y)
    for (let k = 0; k < puntos.length; k++) {
        const px = puntos[k][0], py = puntos[k][1]
        if (c.pincel) {
            const ox = Math.floor(c.pincel.w / 2), oy = Math.floor(c.pincel.h / 2)
            for (let j = 0; j < c.pincel.h; j++) for (let i = 0; i < c.pincel.w; i++) {
                const s = P.lee(c.pincel, i, j)
                if (s[3] === 0) continue
                this.pixel(px + i - ox, py + j - oy, crudo ? color : s, crudo)
            }
        } else {
            const t = P.punta(c.tamaño || 1, c.puntaCuadrada)
            for (let i = 0; i < t.length; i++) this.pixel(px + t[i][0], py + t[i][1], color, crudo)
        }
    }
}

/** De un sitio a otro sin saltos, que es lo que pasa cuando arrastras rápido. */
Brocha.prototype.traza = function (x0, y0, x1, y1, color, crudo) {
    const pts = P.linea(x0, y0, x1, y1)
    for (let i = 0; i < pts.length; i++) this.sello(pts[i][0], pts[i][1], color, crudo)
}

// ═══════════════════════════════════════════════════════════════
// las herramientas
// ═══════════════════════════════════════════════════════════════

var TRANSPARENTE = [0, 0, 0, 0]

/**
 * Fábrica.
 *
 * Devuelve un objeto con abajo/mueve/arriba, y opcionalmente `vistaPrevia`,
 * que son los puntos que hay que pintar por encima sin tocar el búfer — es lo
 * que hace que arrastrar una elipse se vea antes de soltarla.
 */
function crea(nombre, ctx) {
    switch (nombre) {
    case "lapiz":       return new Trazo(ctx, false)
    case "goma":        return new Trazo(ctx, true)
    case "cubo":        return new Cubo(ctx)
    case "cuentagotas": return new Cuentagotas(ctx)
    case "linea":       return new Forma(ctx, "linea")
    case "rectangulo":  return new Forma(ctx, "rectangulo")
    case "elipse":      return new Forma(ctx, "elipse")
    case "degradado":   return new Degradado(ctx)
    case "sombreado":   return new Sombreado(ctx)
    case "sustituye":   return new Sustituye(ctx)
    case "difumina":    return new Retoque(ctx, "difumina")
    case "mancha":      return new Retoque(ctx, "mancha")
    case "aclara":      return new Retoque(ctx, "aclara")
    case "quema":       return new Retoque(ctx, "quema")
    case "marco":       return new SelForma(ctx, "rectangulo")
    case "elipseSel":   return new SelForma(ctx, "elipse")
    case "lazo":        return new Lazo(ctx, false)
    case "lazoPoli":    return new Lazo(ctx, true)
    case "varita":      return new Varita(ctx, true)
    case "porColor":    return new Varita(ctx, false)
    case "mover":       return new Mover(ctx)
    default:            return new Trazo(ctx, false)
    }
}

// ── lápiz y goma ─────────────────────────────────────────────────

function Trazo(ctx, borra) {
    this.ctx = ctx
    this.borra = borra
    this.brocha = new Brocha(ctx)
    this.puntos = []
    this.pintados = 0
    this.color = null
    // el trazo perfecto sólo tiene sentido a un píxel y sin pincel a medida:
    // con una punta gorda no hay esquina que quitar
    this.perfecto = !!ctx.trazoPerfecto && !borra
                    && (ctx.tamaño || 1) <= 1 && !ctx.pincel
}

Trazo.prototype.abajo = function (x, y, boton) {
    this.color = this.borra ? TRANSPARENTE
               : (boton === 2 ? this.ctx.secundario : this.ctx.primario)
    this.puntos = [[x, y]]
    this.pintados = 0
    if (!this.perfecto) this.brocha.sello(x, y, this.color, this.borra)
}

Trazo.prototype.mueve = function (x, y) {
    const ult = this.puntos[this.puntos.length - 1]
    if (ult && ult[0] === x && ult[1] === y) return
    const pts = P.linea(ult[0], ult[1], x, y)
    for (let i = 1; i < pts.length; i++) this.puntos.push(pts[i])
    if (this.perfecto) this._avanza(false)
    else for (let i = 1; i < pts.length; i++)
        this.brocha.sello(pts[i][0], pts[i][1], this.color, this.borra)
}

/**
 * Pinta sólo lo que ya está decidido.
 *
 * Aquí estaba el fallo que cazó la prueba: pintar según se arrastra deja el
 * codo puesto, y perfeccionar después no lo puede borrar porque el píxel ya
 * está en el búfer. Lo que sí se puede es NO pintarlo todavía. Si un punto se
 * queda o se va depende del punto siguiente, así que todo el trazo perfeccionado
 * menos su último punto es definitivo, y eso es lo que se sella. El último se
 * queda esperando a saber en qué se convierte, y se sella al soltar.
 */
Trazo.prototype._avanza = function (final) {
    const limpios = P.perfecciona(this.puntos)
    const hasta = final ? limpios.length : limpios.length - 1
    for (let i = this.pintados; i < hasta; i++)
        this.brocha.sello(limpios[i][0], limpios[i][1], this.color, this.borra)
    if (hasta > this.pintados) this.pintados = hasta
}

Trazo.prototype.arriba = function () {
    if (this.perfecto) this._avanza(true)
    return this.brocha.rect()
}

// ── cubo ─────────────────────────────────────────────────────────

function Cubo(ctx) { this.ctx = ctx; this.brocha = new Brocha(ctx) }

Cubo.prototype.abajo = function (x, y, boton) {
    const c = this.ctx
    const color = boton === 2 ? c.secundario : c.primario
    const limite = c.mascaraSeleccion || null
    const m = c.contiguo ? P.inunda(c.buf, x, y, c.tolerancia, c.ochoVecinos, limite)
                         : P.porColor(c.buf, x, y, c.tolerancia)
    for (let j = 0; j < c.alto; j++) for (let i = 0; i < c.ancho; i++)
        if (m[j * c.ancho + i]) this.brocha.pixel(i, j, color)
}
Cubo.prototype.mueve = function () {}
Cubo.prototype.arriba = function () { return this.brocha.rect() }

// ── cuentagotas ──────────────────────────────────────────────────

function Cuentagotas(ctx) { this.ctx = ctx }
Cuentagotas.prototype.abajo = function (x, y, boton) {
    // del COMPUESTO, no de la capa: lo que quieres coger es el color que ves
    const de = this.ctx.compuesto || this.ctx.buf
    const c = P.lee(de, x, y)
    if (this.ctx.eligeColor) this.ctx.eligeColor(c, boton === 2)
}
Cuentagotas.prototype.mueve = function (x, y, boton) { this.abajo(x, y, boton) }
Cuentagotas.prototype.arriba = function () { return null }

// ── formas ───────────────────────────────────────────────────────

function Forma(ctx, tipo) {
    this.ctx = ctx; this.tipo = tipo
    this.brocha = new Brocha(ctx)
    this.a = null; this.b = null; this.color = null
}

Forma.prototype.abajo = function (x, y, boton) {
    this.a = [x, y]; this.b = [x, y]
    this.color = boton === 2 ? this.ctx.secundario : this.ctx.primario
}
Forma.prototype.mueve = function (x, y) { this.b = [x, y] }

Forma.prototype.puntos = function () {
    if (!this.a || !this.b) return []
    let ax = this.a[0], ay = this.a[1], bx = this.b[0], by = this.b[1]
    if (this.ctx.desdeElCentro) { ax = 2 * this.a[0] - bx; ay = 2 * this.a[1] - by }
    if (this.ctx.proporcionFija && this.tipo !== "linea") {
        const l = Math.max(Math.abs(bx - ax), Math.abs(by - ay))
        bx = ax + Math.sign(bx - ax || 1) * l
        by = ay + Math.sign(by - ay || 1) * l
    }
    if (this.tipo === "linea") {
        if (this.ctx.anguloFijo) {
            const dx = bx - ax, dy = by - ay
            if (Math.abs(dx) > Math.abs(dy) * 2) by = ay
            else if (Math.abs(dy) > Math.abs(dx) * 2) bx = ax
            else { const l = Math.min(Math.abs(dx), Math.abs(dy))
                   bx = ax + Math.sign(dx || 1) * l; by = ay + Math.sign(dy || 1) * l }
        }
        return P.linea(ax, ay, bx, by)
    }
    if (this.tipo === "rectangulo") return P.rectangulo(ax, ay, bx, by, this.ctx.relleno)
    return P.elipse(ax, ay, bx, by, this.ctx.relleno)
}

Forma.prototype.vistaPrevia = function () { return this.puntos() }

Forma.prototype.arriba = function () {
    const pts = this.puntos()
    for (let i = 0; i < pts.length; i++) this.brocha.sello(pts[i][0], pts[i][1], this.color)
    this.a = null; this.b = null
    return this.brocha.rect()
}

// ── degradado ────────────────────────────────────────────────────

function Degradado(ctx) {
    this.ctx = ctx; this.brocha = new Brocha(ctx)
    this.a = null; this.b = null
}
Degradado.prototype.abajo = function (x, y) { this.a = [x, y]; this.b = [x, y] }
Degradado.prototype.mueve = function (x, y) { this.b = [x, y] }
Degradado.prototype.vistaPrevia = function () {
    return this.a && this.b ? P.linea(this.a[0], this.a[1], this.b[0], this.b[1]) : []
}

Degradado.prototype.arriba = function () {
    if (!this.a || !this.b) return null
    const c = this.ctx
    const A = c.primario, B = c.secundario
    const dx = this.b[0] - this.a[0], dy = this.b[1] - this.a[1]
    const largo2 = dx * dx + dy * dy
    const radio = Math.sqrt(largo2) || 1

    for (let y = 0; y < c.alto; y++) for (let x = 0; x < c.ancho; x++) {
        let t
        if (c.tipoDegradado === "radial") {
            t = Math.sqrt((x - this.a[0]) * (x - this.a[0]) + (y - this.a[1]) * (y - this.a[1])) / radio
        } else {
            t = largo2 === 0 ? 0 : ((x - this.a[0]) * dx + (y - this.a[1]) * dy) / largo2
        }
        t = Math.max(0, Math.min(1, t))
        let col
        if (c.degradadoTramado) {
            // Tramado en vez de mezcla: en pixel art un degradado suave
            // introduce cientos de colores nuevos, y eso deja de ser pixel art.
            col = P.trama("bayer", x, y, t) ? B : A
        } else {
            col = [A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t,
                   A[2] + (B[2] - A[2]) * t, A[3] + (B[3] - A[3]) * t]
        }
        this.brocha.pixel(x, y, col)
    }
    this.a = null; this.b = null
    return this.brocha.rect()
}

// ── tinta de sombreado ───────────────────────────────────────────

/**
 * Mueve cada píxel un paso por SU rampa, en vez de aplastarlo con un color.
 *
 * Es la herramienta que separa un editor de pixel art de un editor de imagen:
 * sombrear no es pintar gris encima, es bajar un escalón en la rampa del color
 * que ya había. Si un píxel no se parece a nada de la paleta, no se toca — que
 * es lo correcto: sombrear un color de fuera sería inventarse el resultado.
 */
function Sombreado(ctx) { this.ctx = ctx; this.brocha = new Brocha(ctx); this.vistos = null }

Sombreado.prototype.abajo = function (x, y, boton) {
    this.paso = boton === 2 ? -this.ctx.pasoSombreado : this.ctx.pasoSombreado
    this.vistos = {}
    this._toca(x, y)
}
Sombreado.prototype.mueve = function (x, y) { this._toca(x, y) }

Sombreado.prototype._toca = function (x, y) {
    const c = this.ctx
    const t = c.pincel ? null : P.punta(c.tamaño || 1, c.puntaCuadrada)
    const puntos = t || [[0, 0]]
    const reflejos = this.brocha.reflejos(x, y)
    for (let r = 0; r < reflejos.length; r++)
    for (let i = 0; i < puntos.length; i++) {
        const px = reflejos[r][0] + puntos[i][0], py = reflejos[r][1] + puntos[i][1]
        const k = px + "," + py
        if (this.vistos[k]) continue        // un paso por trazo, no veinte
        this.vistos[k] = 1
        if (px < 0 || py < 0 || px >= c.ancho || py >= c.alto) continue
        if (!c.selContiene(px, py)) continue
        const actual = P.lee(c.buf, px, py)
        if (actual[3] === 0) continue
        const nuevo = c.vecinoEnRampa ? c.vecinoEnRampa(actual, this.paso) : null
        if (!nuevo) continue
        P.pon(c.buf, px, py, nuevo)
        this.brocha.sucio(px, py)
    }
}
Sombreado.prototype.arriba = function () { return this.brocha.rect() }

// ── sustituir color ──────────────────────────────────────────────

function Sustituye(ctx) { this.ctx = ctx; this.brocha = new Brocha(ctx) }
Sustituye.prototype.abajo = function (x, y, boton) {
    const c = this.ctx
    const viejo = P.lee(c.buf, x, y)
    const nuevo = boton === 2 ? c.secundario : c.primario
    for (let j = 0; j < c.alto; j++) for (let i = 0; i < c.ancho; i++) {
        const p = P.lee(c.buf, i, j)
        if (P.distancia(p, viejo) > c.tolerancia) continue
        this.brocha.pixel(i, j, nuevo, true)
    }
}
Sustituye.prototype.mueve = function () {}
Sustituye.prototype.arriba = function () { return this.brocha.rect() }

// ── retoques locales ─────────────────────────────────────────────

function Retoque(ctx, tipo) {
    this.ctx = ctx; this.tipo = tipo
    this.brocha = new Brocha(ctx)
    this.ultimo = null
}
Retoque.prototype.abajo = function (x, y) { this.ultimo = [x, y]; this._toca(x, y) }
Retoque.prototype.mueve = function (x, y) {
    const pts = P.linea(this.ultimo[0], this.ultimo[1], x, y)
    for (let i = 0; i < pts.length; i++) this._toca(pts[i][0], pts[i][1])
    this.ultimo = [x, y]
}
Retoque.prototype.arriba = function () { return this.brocha.rect() }

Retoque.prototype._toca = function (x, y) {
    const c = this.ctx
    const t = P.punta(c.tamaño || 1, c.puntaCuadrada)
    const f = c.fuerza === undefined ? 0.5 : c.fuerza
    for (let i = 0; i < t.length; i++) {
        const px = x + t[i][0], py = y + t[i][1]
        if (px < 0 || py < 0 || px >= c.ancho || py >= c.alto) continue
        if (!c.selContiene(px, py)) continue
        const a = P.lee(c.buf, px, py)
        if (a[3] === 0 && this.tipo !== "difumina") continue
        let n = a

        if (this.tipo === "difumina") {
            let r = 0, g = 0, b = 0, al = 0, cuenta = 0
            for (let j = -1; j <= 1; j++) for (let k = -1; k <= 1; k++) {
                const v = P.lee(c.buf, px + k, py + j)
                r += v[0]; g += v[1]; b += v[2]; al += v[3]; cuenta++
            }
            n = [a[0] + (r/cuenta - a[0]) * f, a[1] + (g/cuenta - a[1]) * f,
                 a[2] + (b/cuenta - a[2]) * f, a[3] + (al/cuenta - a[3]) * f]
        } else if (this.tipo === "mancha") {
            if (!this.arrastrado) { this.arrastrado = a; continue }
            n = [a[0] + (this.arrastrado[0] - a[0]) * f, a[1] + (this.arrastrado[1] - a[1]) * f,
                 a[2] + (this.arrastrado[2] - a[2]) * f, a[3]]
            this.arrastrado = n
        } else {
            const h = P.aHsv(a)
            const d = this.tipo === "aclara" ? 1 + f * 0.4 : 1 - f * 0.4
            n = P.deHsv(h[0], h[1], Math.max(0, Math.min(1, h[2] * d)), a[3])
        }
        P.pon(c.buf, px, py, n)
        this.brocha.sucio(px, py)
    }
}

// ── selección ────────────────────────────────────────────────────

function SelForma(ctx, tipo) { this.ctx = ctx; this.tipo = tipo; this.a = null; this.b = null }
SelForma.prototype.abajo = function (x, y) { this.a = [x, y]; this.b = [x, y] }
SelForma.prototype.mueve = function (x, y) { this.b = [x, y] }
SelForma.prototype.vistaPrevia = function () {
    if (!this.a || !this.b) return []
    return this.tipo === "rectangulo"
         ? P.rectangulo(this.a[0], this.a[1], this.b[0], this.b[1], false)
         : P.elipse(this.a[0], this.a[1], this.b[0], this.b[1], false)
}
SelForma.prototype.arriba = function () {
    if (!this.a || !this.b) return null
    if (this.ctx.ponSeleccionForma)
        this.ctx.ponSeleccionForma(this.tipo, this.a[0], this.a[1], this.b[0], this.b[1])
    this.a = null; this.b = null
    return null     // la selección no ensucia píxeles
}

function Lazo(ctx, poligonal) {
    this.ctx = ctx; this.poligonal = poligonal; this.pts = []
}
Lazo.prototype.abajo = function (x, y) {
    if (this.poligonal) {
        // segundo clic sobre el primer punto = cerrar
        if (this.pts.length > 2 && Math.abs(x - this.pts[0][0]) <= 1
            && Math.abs(y - this.pts[0][1]) <= 1) { this._cierra(); return }
        this.pts.push([x, y])
    } else this.pts = [[x, y]]
}
Lazo.prototype.mueve = function (x, y) {
    if (this.poligonal) { this.movil = [x, y]; return }
    const u = this.pts[this.pts.length - 1]
    if (u && (u[0] !== x || u[1] !== y)) this.pts.push([x, y])
}
Lazo.prototype.vistaPrevia = function () {
    const out = []
    const lista = this.poligonal && this.movil ? this.pts.concat([this.movil]) : this.pts
    for (let i = 0; i + 1 < lista.length; i++) {
        const l = P.linea(lista[i][0], lista[i][1], lista[i+1][0], lista[i+1][1])
        for (let j = 0; j < l.length; j++) out.push(l[j])
    }
    return out
}
Lazo.prototype._cierra = function () {
    if (this.pts.length >= 3 && this.ctx.ponSeleccionPoligono)
        this.ctx.ponSeleccionPoligono(this.pts)
    this.pts = []; this.movil = null
}
Lazo.prototype.arriba = function () { if (!this.poligonal) this._cierra(); return null }
Lazo.prototype.cierra = function () { this._cierra() }

function Varita(ctx, contigua) { this.ctx = ctx; this.contigua = contigua }
Varita.prototype.abajo = function (x, y) {
    const c = this.ctx
    const de = c.compuesto || c.buf
    const m = this.contigua ? P.inunda(de, x, y, c.tolerancia, c.ochoVecinos, null)
                            : P.porColor(de, x, y, c.tolerancia)
    if (c.ponSeleccionMascara) c.ponSeleccionMascara(m)
}
Varita.prototype.mueve = function () {}
Varita.prototype.arriba = function () { return null }

// ── mover ────────────────────────────────────────────────────────

/**
 * Arrastra lo seleccionado —o la capa entera si no hay selección.
 *
 * Levanta los píxeles en el primer clic y los deja al soltar: mientras
 * arrastras, el hueco de donde salieron está vacío, que es lo que se espera y
 * lo que hace que se pueda ver si encaja.
 */
function Mover(ctx) { this.ctx = ctx; this.brocha = new Brocha(ctx) }

Mover.prototype.abajo = function (x, y) {
    const c = this.ctx
    this.desde = [x, y]
    this.recorte = P.clonar(c.buf)
    this.flotante = P.nuevo(c.ancho, c.alto)
    for (let j = 0; j < c.alto; j++) for (let i = 0; i < c.ancho; i++) {
        if (!c.selContiene(i, j)) continue
        const p = P.lee(c.buf, i, j)
        if (p[3] === 0) continue
        P.pon(this.flotante, i, j, p)
        P.pon(c.buf, i, j, TRANSPARENTE)
        this.brocha.sucio(i, j)
    }
    this.dx = 0; this.dy = 0
}

Mover.prototype.mueve = function (x, y) {
    const c = this.ctx
    // limpiar el sitio anterior y volver a poner desplazado
    this._borraFlotante()
    this.dx = x - this.desde[0]; this.dy = y - this.desde[1]
    this._pintaFlotante()
}

Mover.prototype._borraFlotante = function () {
    const c = this.ctx
    for (let j = 0; j < c.alto; j++) for (let i = 0; i < c.ancho; i++) {
        const p = P.lee(this.flotante, i - this.dx, j - this.dy)
        if (p[3] === 0) continue
        P.pon(c.buf, i, j, TRANSPARENTE)
        this.brocha.sucio(i, j)
    }
}

Mover.prototype._pintaFlotante = function () {
    const c = this.ctx
    for (let j = 0; j < c.alto; j++) for (let i = 0; i < c.ancho; i++) {
        const p = P.lee(this.flotante, i - this.dx, j - this.dy)
        if (p[3] === 0) continue
        P.pon(c.buf, i, j, p)
        this.brocha.sucio(i, j)
    }
}

Mover.prototype.arriba = function () {
    if (this.ctx.mueveSeleccion && (this.dx || this.dy))
        this.ctx.mueveSeleccion(this.dx, this.dy)
    return this.brocha.rect()
}

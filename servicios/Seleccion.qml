pragma Singleton

//  La selección.
//
//  Una máscara de un byte por píxel, no un rectángulo: el lazo, la varita y la
//  selección por alfa dan formas cualesquiera, y tratarlas todas igual es lo
//  que permite sumar un lazo a una varita sin casos especiales.
//
//  Todo lo que pinta pregunta aquí antes de escribir. Cuando no hay selección
//  `contiene` dice que sí a todo, así que las herramientas no tienen que saber
//  si hay selección o no.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P

Singleton {
    id: sel

    property var mascara: null      // Uint8Array de ancho*alto, o null
    property int ancho: 0
    property int alto: 0
    property int rev: 0
    readonly property bool activa: rev, mascara !== null
    property var limites: null      // {x,y,w,h} de lo seleccionado

    function contiene(x, y) {
        if (!mascara) return true
        if (x < 0 || y < 0 || x >= ancho || y >= alto) return false
        return mascara[y * ancho + x] !== 0
    }

    function nada() { mascara = null; limites = null; rev++ }

    function todo(w, h) {
        ancho = w; alto = h
        mascara = new Uint8Array(w * h)
        mascara.fill(1)
        limites = { x: 0, y: 0, w: w, h: h }
        rev++
    }

    /** modo: "nueva" · "sumar" · "restar" · "intersecar" */
    function pon(m, w, h, modo) {
        if (!mascara || ancho !== w || alto !== h || modo === "nueva" || !modo) {
            ancho = w; alto = h
            mascara = new Uint8Array(m)
        } else {
            for (let i = 0; i < mascara.length; i++) {
                if (modo === "sumar") mascara[i] = mascara[i] || m[i]
                else if (modo === "restar") mascara[i] = m[i] ? 0 : mascara[i]
                else if (modo === "intersecar") mascara[i] = (mascara[i] && m[i]) ? 1 : 0
            }
        }
        _recalcula()
    }

    function invierte() {
        if (!mascara) return
        for (let i = 0; i < mascara.length; i++) mascara[i] = mascara[i] ? 0 : 1
        _recalcula()
    }

    /** Crecer o encoger la selección en n píxeles. */
    function dilata(n) {
        if (!mascara) return
        for (let paso = 0; paso < Math.abs(n); paso++) {
            const m = new Uint8Array(mascara)
            for (let y = 0; y < alto; y++) for (let x = 0; x < ancho; x++) {
                const i = y * ancho + x
                let vecino = false
                for (let k = 0; k < 4; k++) {
                    const nx = x + [1,-1,0,0][k], ny = y + [0,0,1,-1][k]
                    if (nx < 0 || ny < 0 || nx >= ancho || ny >= alto) { vecino = n < 0; continue }
                    if (n > 0 ? mascara[ny*ancho+nx] : !mascara[ny*ancho+nx]) vecino = true
                }
                if (vecino) m[i] = n > 0 ? 1 : 0
            }
            mascara = m
        }
        _recalcula()
    }

    function desdeRectangulo(x0, y0, x1, y1, w, h, modo) {
        const m = new Uint8Array(w * h)
        const ax = Math.max(0, Math.min(x0, x1)), bx = Math.min(w - 1, Math.max(x0, x1))
        const ay = Math.max(0, Math.min(y0, y1)), by = Math.min(h - 1, Math.max(y0, y1))
        for (let y = ay; y <= by; y++) for (let x = ax; x <= bx; x++) m[y * w + x] = 1
        pon(m, w, h, modo)
    }

    function desdeElipse(x0, y0, x1, y1, w, h, modo) {
        const m = new Uint8Array(w * h)
        const pts = P.elipse(x0, y0, x1, y1, true)
        for (let i = 0; i < pts.length; i++) {
            const p = pts[i]
            if (p[0] >= 0 && p[1] >= 0 && p[0] < w && p[1] < h) m[p[1] * w + p[0]] = 1
        }
        pon(m, w, h, modo)
    }

    /** Un polígono cerrado, que es lo que dejan el lazo y el lazo poligonal. */
    function desdePoligono(pts, w, h, modo) {
        const m = new Uint8Array(w * h)
        if (pts.length < 3) { pon(m, w, h, modo); return }
        for (let y = 0; y < h; y++) {
            const cortes = []
            for (let i = 0; i < pts.length; i++) {
                const a = pts[i], b = pts[(i + 1) % pts.length]
                if ((a[1] <= y && b[1] > y) || (b[1] <= y && a[1] > y))
                    cortes.push(a[0] + (y - a[1]) / (b[1] - a[1]) * (b[0] - a[0]))
            }
            cortes.sort((p, q) => p - q)
            for (let i = 0; i + 1 < cortes.length; i += 2) {
                const de = Math.max(0, Math.ceil(cortes[i]))
                const a = Math.min(w - 1, Math.floor(cortes[i + 1]))
                for (let x = de; x <= a; x++) m[y * w + x] = 1
            }
        }
        pon(m, w, h, modo)
    }

    function _recalcula() {
        let x0 = ancho, y0 = alto, x1 = -1, y1 = -1, hay = false
        for (let y = 0; y < alto; y++) for (let x = 0; x < ancho; x++) {
            if (!mascara[y * ancho + x]) continue
            hay = true
            if (x < x0) x0 = x; if (x > x1) x1 = x
            if (y < y0) y0 = y; if (y > y1) y1 = y
        }
        if (!hay) { mascara = null; limites = null } 
        else limites = { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }
        rev++
    }

    /** El contorno, para dibujar las hormigas. Devuelve segmentos [x0,y0,x1,y1]. */
    function contorno() {
        if (!mascara) return []
        const s = []
        for (let y = 0; y < alto; y++) for (let x = 0; x < ancho; x++) {
            if (!mascara[y * ancho + x]) continue
            if (y === 0 || !mascara[(y-1)*ancho+x]) s.push([x, y, x+1, y])
            if (y === alto-1 || !mascara[(y+1)*ancho+x]) s.push([x, y+1, x+1, y+1])
            if (x === 0 || !mascara[y*ancho+x-1]) s.push([x, y, x, y+1])
            if (x === ancho-1 || !mascara[y*ancho+x+1]) s.push([x+1, y, x+1, y+1])
        }
        return s
    }
}

pragma Singleton

//  Deshacer.
//
//  Por COMANDOS, no por instantáneas. Un trazo guarda sólo el rectángulo que
//  ensució, antes y después: dibujar tres píxeles en un lienzo de 96×96 cuesta
//  unos bytes en vez de 36 KB, y por eso se pueden guardar cientos de pasos
//  sin pensar en la memoria.
//
//  Los cambios de ESTRUCTURA —añadir una capa, borrar un fotograma, cambiar el
//  tamaño— van por otro camino: ahí lo que se guarda es la metainformación
//  entera, que es pequeña, más el MAPA de celdas por referencia. Referencia y
//  no copia: los píxeles tienen su propio historial y esto sólo tiene que
//  recordar qué celdas existían y cómo se llamaban.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "." as S

Singleton {
    id: hist

    readonly property int tope: 400

    PersistentProperties {
        id: memoria
        reloadableId: "pinza.historial"
        property var pila: []
        property int indice: -1
    }

    property int rev: 0
    readonly property bool puedeDeshacer: rev, memoria.indice >= 0
    readonly property bool puedeRehacer: rev, memoria.indice < memoria.pila.length - 1
    readonly property int pasos: rev, memoria.pila.length
    readonly property int actual: rev, memoria.indice

    function nombreDe(i) {
        const c = memoria.pila[i]
        return c ? c.nombre : ""
    }

    function limpia() { memoria.pila = []; memoria.indice = -1; rev++ }

    function _empuja(c) {
        // tirar lo que hubiera por delante: rehacer se pierde al dibujar
        if (memoria.indice < memoria.pila.length - 1)
            memoria.pila = memoria.pila.slice(0, memoria.indice + 1)
        memoria.pila.push(c)
        if (memoria.pila.length > tope) memoria.pila.shift()
        memoria.indice = memoria.pila.length - 1
        rev++
    }

    // ═══════════════════════════════════════════════════════════
    // píxeles
    // ═══════════════════════════════════════════════════════════

    property var _antesBuf: null
    property string _antesClave: ""

    /**
     * Antes de empezar a tocar píxeles.
     *
     * Se clona la celda entera aunque luego sólo se guarde el rectángulo
     * sucio: mientras el trazo está en marcha no se sabe hasta dónde va a
     * llegar, y clonar 16 KB una vez por trazo no se nota.
     */
    function abre(clave, buf) {
        _antesClave = clave
        _antesBuf = buf ? P.clonar(buf) : null
    }

    /** Al soltar. Compara, recorta al rectángulo que cambió y lo apunta. */
    function cierra(nombre, buf) {
        if (!_antesBuf || !buf) { _antesBuf = null; return false }
        const a = _antesBuf, b = buf
        let x0 = a.w, y0 = a.h, x1 = -1, y1 = -1
        for (let y = 0; y < a.h; y++) for (let x = 0; x < a.w; x++) {
            const i = (y * a.w + x) * 4
            if (a.d[i] === b.d[i] && a.d[i+1] === b.d[i+1]
                && a.d[i+2] === b.d[i+2] && a.d[i+3] === b.d[i+3]) continue
            if (x < x0) x0 = x; if (x > x1) x1 = x
            if (y < y0) y0 = y; if (y > y1) y1 = y
        }
        if (x1 < x0) { _antesBuf = null; return false }   // no cambió nada
        const w = x1 - x0 + 1, h = y1 - y0 + 1
        _empuja({
            t: "pixeles", nombre: nombre || "trazo", clave: _antesClave,
            x: x0, y: y0, w: w, h: h,
            antes: P.recorte(a, x0, y0, w, h),
            despues: P.recorte(b, x0, y0, w, h)
        })
        _antesBuf = null
        return true
    }

    /** Un cambio de píxeles ya hecho, del que se conoce el antes y el después. */
    function registra(nombre, clave, x, y, antes, despues) {
        _empuja({ t: "pixeles", nombre: nombre, clave: clave,
                  x: x, y: y, w: antes.w, h: antes.h, antes: antes, despues: despues })
    }

    // ═══════════════════════════════════════════════════════════
    // estructura
    // ═══════════════════════════════════════════════════════════

    property var _antesMeta: null

    function abreEstructura() {
        const m = S.Documento.meta()
        _antesMeta = m ? { meta: JSON.parse(JSON.stringify(m)),
                           celdas: _copiaMapa(),
                           capaActiva: S.Documento.capaActiva,
                           fotograma: S.Documento.fotograma,
                           orientacion: S.Documento.orientacion } : null
    }

    function cierraEstructura(nombre) {
        if (!_antesMeta) return false
        const m = S.Documento.meta()
        if (!m) { _antesMeta = null; return false }
        _empuja({
            t: "estructura", nombre: nombre,
            antes: _antesMeta,
            despues: { meta: JSON.parse(JSON.stringify(m)), celdas: _copiaMapa(),
                       capaActiva: S.Documento.capaActiva,
                       fotograma: S.Documento.fotograma,
                       orientacion: S.Documento.orientacion }
        })
        _antesMeta = null
        return true
    }

    // ═══════════════════════════════════════════════════════════
    // instantánea completa
    // ═══════════════════════════════════════════════════════════
    //
    //  Para lo que toca píxeles POR TODAS PARTES sin pasar por una herramienta:
    //  un guión. El historial de estructura guarda el mapa de celdas por
    //  referencia a propósito —los píxeles tienen su propia entrada— pero un
    //  guión escribe dentro de los búferes sin dejar ninguna, así que deshacerlo
    //  devolvía el mapa apuntando a los mismos búferes ya machacados. Aquí se
    //  copian de verdad. Es caro, y da igual: correr un guión es algo que se
    //  hace una vez y a conciencia, no sesenta veces por segundo.

    property var _antesTodo: null

    function _instantanea() {
        const d = S.Documento.d
        if (!d) return null
        const celdas = {}
        const k = Object.keys(d.celdas)
        for (let i = 0; i < k.length; i++) {
            const v = d.celdas[k[i]]
            celdas[k[i]] = (v && v.enlace) ? { enlace: v.enlace } : P.clonar(v)
        }
        return { meta: JSON.parse(JSON.stringify(S.Documento.meta())), celdas: celdas,
                 capaActiva: S.Documento.capaActiva, fotograma: S.Documento.fotograma,
                 orientacion: S.Documento.orientacion }
    }

    function abreCompleto() { _antesTodo = _instantanea() }

    function cierraCompleto(nombre) {
        if (!_antesTodo) return false
        const antes = _antesTodo
        const despues = _instantanea()
        _antesTodo = null
        if (!despues) return false
        _empuja({ t: "completo", nombre: nombre, antes: antes, despues: despues })
        return true
    }

    /** Deshace sin dejar rastro: para cuando un guión revienta a mitad. */
    function cancelaCompleto() {
        if (!_antesTodo) return false
        const s = _antesTodo
        _antesTodo = null
        _restaura(s)
        return true
    }

    function _restaura(s) {
        const d = S.Documento.d
        if (!d || !s) return
        d.ancho = s.meta.ancho; d.alto = s.meta.alto
        d.capas = JSON.parse(JSON.stringify(s.meta.capas))
        d.fotogramas = JSON.parse(JSON.stringify(s.meta.fotogramas))
        d.orientaciones = s.meta.orientaciones.slice()
        d.etiquetas = JSON.parse(JSON.stringify(s.meta.etiquetas || []))
        const celdas = {}
        const k = Object.keys(s.celdas)
        for (let i = 0; i < k.length; i++) {
            const v = s.celdas[k[i]]
            celdas[k[i]] = (v && v.enlace) ? { enlace: v.enlace } : P.clonar(v)
        }
        d.celdas = celdas
        S.Documento.capaActiva = Math.min(s.capaActiva, d.capas.length - 1)
        S.Documento.fotograma = Math.min(s.fotograma, d.fotogramas.length - 1)
        S.Documento.orientacion = Math.min(s.orientacion, d.orientaciones.length - 1)
        S.Documento.cambia(); S.Documento.cambiaPixeles(null)
    }

    /** Copia superficial del mapa: las claves sí, los búferes por referencia. */
    function _copiaMapa() {
        const d = S.Documento.d
        if (!d) return {}
        const out = {}
        const k = Object.keys(d.celdas)
        for (let i = 0; i < k.length; i++) out[k[i]] = d.celdas[k[i]]
        return out
    }

    // ═══════════════════════════════════════════════════════════
    // andar por la pila
    // ═══════════════════════════════════════════════════════════

    function _aplica(c, haciaAtras) {
        const d = S.Documento.d
        if (!d) return
        if (c.t === "pixeles") {
            let cel = d.celdas[c.clave]
            if (cel && cel.enlace) cel = d.celdas[cel.enlace]
            if (!cel) return
            P.vuelca(cel, haciaAtras ? c.antes : c.despues, c.x, c.y)
            S.Documento.cambiaPixeles({ x: c.x, y: c.y, w: c.w, h: c.h })
        } else if (c.t === "completo") {
            _restaura(haciaAtras ? c.antes : c.despues)
        } else if (c.t === "estructura") {
            const e = haciaAtras ? c.antes : c.despues
            d.ancho = e.meta.ancho; d.alto = e.meta.alto
            d.capas = JSON.parse(JSON.stringify(e.meta.capas))
            d.fotogramas = JSON.parse(JSON.stringify(e.meta.fotogramas))
            d.orientaciones = e.meta.orientaciones.slice()
            d.etiquetas = JSON.parse(JSON.stringify(e.meta.etiquetas || []))
            const out = {}
            const k = Object.keys(e.celdas)
            for (let i = 0; i < k.length; i++) out[k[i]] = e.celdas[k[i]]
            d.celdas = out
            S.Documento.capaActiva = Math.min(e.capaActiva, d.capas.length - 1)
            S.Documento.fotograma = Math.min(e.fotograma, d.fotogramas.length - 1)
            S.Documento.orientacion = Math.min(e.orientacion, d.orientaciones.length - 1)
            S.Documento.cambia(); S.Documento.cambiaPixeles(null)
        }
    }

    function deshace() {
        if (!puedeDeshacer) return false
        _aplica(memoria.pila[memoria.indice], true)
        memoria.indice--
        rev++
        return true
    }

    function rehace() {
        if (!puedeRehacer) return false
        memoria.indice++
        _aplica(memoria.pila[memoria.indice], false)
        rev++
        return true
    }

    /** Saltar a un punto cualquiera, que es lo que hace la hoja de historial. */
    function vaA(i) {
        const destino = Math.max(-1, Math.min(i, memoria.pila.length - 1))
        while (memoria.indice > destino) deshace()
        while (memoria.indice < destino) rehace()
    }
}

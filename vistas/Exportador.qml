//  El puente entre los búferes y los ficheros.
//
//  Ya no tiene Canvas, y eso es el arreglo. Escribir un PNG con Canvas.toDataURL
//  funciona, pero cuesta UN REPINTADO POR FICHERO: hay que redimensionar el
//  lienzo, pedir el pintado, esperar a que le toque, y sólo entonces se puede
//  leer. Con una celda al día no se nota; con una criatura de PMD —quinientas
//  celdas entre todas sus acciones— son ocho segundos de programa bloqueado y
//  parpadeando, porque además había que abrir cada documento para pintarlo.
//
//  Ahora los píxeles van a la forja en base64 y los escribe Pillow, todos los
//  que hagan falta en un solo mensaje. Leer ya iba por ahí desde que el Canvas
//  devolvía capas vacías al arrancar (ver cata/cata.qml), así que el Canvas ha
//  dejado de pintar nada en este camino.
//
//  Sigue siendo una vista y no un servicio por costumbre y por si algún día
//  vuelve a hacer falta pintar algo aquí — pero ya no necesita estar en la
//  escena para funcionar.

import QtQuick
import "../core/pixeles.js" as P
import "../servicios" as S

Item {
    id: raiz
    width: 0; height: 0
    visible: false

    // ═══════════════════════════════════════════════════════════
    // salida
    // ═══════════════════════════════════════════════════════════

    /** Un búfer a un PNG. `cb(bien)`. */
    function escribe(ruta, buf, cb) {
        escribeVarios([{ ruta: ruta, buf: buf }], cb)
    }

    /**
     * Muchos búferes a muchos PNG, en un solo viaje.
     *
     * Se parte en tandas porque un mensaje con quinientas celdas de 48×48 son
     * varios megas de base64 en una sola línea, y eso empieza a doler en el
     * otro extremo. En tandas de cuarenta no se nota ninguna de las dos cosas.
     */
    function escribeVarios(lista, cb) {
        if (!lista.length) { if (cb) cb(true); return }
        const tanda = 40
        let i = 0
        let bien = true

        function siguiente() {
            if (i >= lista.length) { if (cb) cb(bien); return }
            const ficheros = []
            for (let k = 0; k < tanda && i < lista.length; k++, i++) {
                const e = lista[i]
                ficheros.push({ ruta: e.ruta, ancho: e.buf.w, alto: e.buf.h,
                                datos: P.aBase64(e.buf) })
            }
            S.Forja.pide("escribirPixeles", { ficheros: ficheros }, (r) => {
                if (!r.bien) { bien = false; console.warn("no se pudo escribir: " + r.error) }
                Qt.callLater(siguiente)
            })
        }
        siguiente()
    }

    /**
     * Monta una hoja con varias celdas. Devuelve el búfer; no escribe nada.
     *
     * `cols` y `filas` deciden la rejilla, y es lo que separa un tileset de una
     * hoja PMD: en PMD las columnas son fotogramas y las filas orientaciones.
     * Quien lo sabe es el contrato.
     */
    function componHoja(celdas, cols, filas, cw, ch) {
        const gran = P.nuevo(cols * cw, filas * ch)
        for (let f = 0; f < filas; f++) for (let c = 0; c < cols; c++) {
            const b = celdas[f * cols + c]
            if (b) P.vuelca(gran, b, c * cw, f * ch)
        }
        return gran
    }

    // ═══════════════════════════════════════════════════════════
    // entrada
    // ═══════════════════════════════════════════════════════════

    /**
     * Un PNG del disco -> un búfer. `cb(buf o null)`.
     *
     * Por la forja y no por el Canvas. Cargar la imagen con loadImage y leerla
     * con getImageData fallaba de la peor manera posible: al abrir un proyecto
     * recién arrancado el programa, las primeras celdas volvían VACÍAS y sin
     * error, porque el Canvas todavía no tenía la imagen lista cuando le tocaba
     * pintar. Un proyecto se abría a medias y parecía que se habían perdido
     * capas.
     */
    function dePng(ruta, cb) {
        const limpia = ruta.indexOf("file://") === 0 ? ruta.substring(7) : ruta
        S.Forja.pide("leerPixeles", { ruta: limpia }, (r) => {
            if (!r.bien) { console.warn("no se puede leer " + limpia + ": " + r.error); cb(null); return }
            cb(P.deBase64(r.datos, r.ancho, r.alto))
        })
    }

    /** Varios PNG de golpe. `cb({ruta: buf})`. */
    function deVarios(rutas, cb) {
        const out = {}
        let quedan = rutas.length
        if (!quedan) { cb(out); return }
        for (let i = 0; i < rutas.length; i++) {
            const r = rutas[i]
            dePng(r, (b) => {
                if (b) out[r] = b
                if (--quedan === 0) cb(out)
            })
        }
    }

    /** Un PNG del disco troceado en celdas de cw×ch. `cb(lista, cols, filas)`. */
    function trocea(ruta, cw, ch, cb) {
        dePng(ruta, (b) => {
            if (!b) { cb(null, 0, 0); return }
            const cols = Math.max(1, Math.floor(b.w / cw))
            const filas = Math.max(1, Math.floor(b.h / ch))
            const out = []
            for (let f = 0; f < filas; f++) for (let c = 0; c < cols; c++)
                out.push(P.recorte(b, c * cw, f * ch, cw, ch))
            cb(out, cols, filas)
        })
    }
}

//  El puente entre los búferes y los ficheros.
//
//  Existe por el segundo hallazgo de la cata: Canvas.save() devuelve false y no
//  escribe nada en este Qt. Lo que sí funciona es toDataURL, así que el camino
//  de salida es búfer -> Canvas 1:1 -> toDataURL -> la forja escribe el PNG.
//  Y el de entrada es su espejo: loadImage -> drawImage -> getImageData.
//
//  Tiene que vivir DENTRO de una ventana aunque no se vea: un Canvas fuera de
//  la escena no llega a pintar nunca, y entonces toDataURL devuelve un lienzo
//  en blanco sin decir nada. Por eso esto es una vista y no un servicio.

import QtQuick
import "../core/pixeles.js" as P
import "../servicios" as S

Item {
    id: raiz
    width: 1; height: 1
    clip: true
    opacity: 0.004          // invisible de hecho, pero presente en la escena

    property var _cola: []
    property var _actual: null

    // ═══════════════════════════════════════════════════════════
    // salida
    // ═══════════════════════════════════════════════════════════

    /** Un búfer -> un data URL de PNG. `cb(url)`. */
    function aPng(buf, cb) {
        _cola.push({ tipo: "escribe", buf: buf, cb: cb })
        _sigue()
    }

    /**
     * Varios búferes en una sola hoja.
     *
     * `disposicion` decide la rejilla, y es lo que separa un tileset de una
     * hoja PMD: en PMD las columnas son fotogramas y las filas orientaciones,
     * en una tira de efecto todo va en una fila. Quien lo sabe es el contrato.
     */
    function aHoja(celdas, cols, filas, cw, ch, cb) {
        const gran = P.nuevo(cols * cw, filas * ch)
        for (let f = 0; f < filas; f++) for (let c = 0; c < cols; c++) {
            const b = celdas[f * cols + c]
            if (b) P.vuelca(gran, b, c * cw, f * ch)
        }
        aPng(gran, cb)
    }

    // ═══════════════════════════════════════════════════════════
    // entrada
    // ═══════════════════════════════════════════════════════════

    /**
     * Un PNG del disco -> un búfer. `cb(buf o null)`.
     *
     * Por la forja y no por el Canvas. La primera versión cargaba la imagen con
     * loadImage y la leía con getImageData, y fallaba de la peor manera
     * posible: al abrir un proyecto recién arrancado el programa, las primeras
     * celdas volvían VACÍAS y sin error, porque el Canvas todavía no tenía la
     * imagen lista cuando le tocaba pintar. Un proyecto se abría a medias y
     * parecía que se habían perdido capas.
     *
     * Escribir sí se queda en el Canvas: ahí se pinta y se lee el resultado en
     * la misma llamada, sin nada asíncrono en medio, y eso sí es de fiar.
     */
    function dePng(ruta, cb) {
        const limpia = ruta.indexOf("file://") === 0 ? ruta.substring(7) : ruta
        S.Forja.pide("leerPixeles", { ruta: limpia }, (r) => {
            if (!r.bien) { console.warn("no se puede leer " + limpia + ": " + r.error); cb(null); return }
            cb(P.deBase64(r.datos, r.ancho, r.alto))
        })
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

    // ═══════════════════════════════════════════════════════════
    // la cola
    // ═══════════════════════════════════════════════════════════

    function _sigue() {
        if (_actual || !_cola.length) return
        _actual = _cola.shift()
        hoja.width = _actual.buf.w
        hoja.height = _actual.buf.h
        hoja.requestPaint()
    }

    function _termina(resultado) {
        const cb = _actual ? _actual.cb : null
        _actual = null
        if (cb) cb(resultado)
        Qt.callLater(_sigue)
    }

    Canvas {
        id: hoja
        width: 1; height: 1
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image
        anchors.left: parent.left
        anchors.top: parent.top

        onPaint: {
            if (!raiz._actual) return
            const b = raiz._actual.buf
            //  Un repintado que llegue con el tamaño viejo no sirve: se pide
            //  otro y ya está. Sin volver a pedirlo, la cola se quedaría
            //  parada para siempre y el programa dejaría de guardar en
            //  silencio, que es la peor forma de fallar que hay.
            if (width !== b.w || height !== b.h) { Qt.callLater(requestPaint); return }

            const g = getContext("2d")
            g.clearRect(0, 0, b.w, b.h)
            const img = g.createImageData(b.w, b.h)
            for (let i = 0; i < b.d.length; i++) img.data[i] = b.d[i]
            // la de SIETE argumentos: la de tres no hace nada (cata/cata.qml)
            g.putImageData(img, 0, 0, 0, 0, b.w, b.h)
            raiz._termina(toDataURL("image/png"))
        }
    }
}

pragma Singleton

//  El documento.
//
//  TRES EJES, no dos. Una CELDA se direcciona con capa × fotograma ×
//  orientación. Aseprite tiene dos y por eso una hoja de ocho direcciones hay
//  que montarla a mano; aquí la orientación es un eje de primera clase y para
//  un icono simplemente vale uno, con lo que el compás ni se enseña.
//
//  El estado de verdad es un objeto JS dentro de PersistentProperties, no un
//  árbol de propiedades QML. Dos motivos, y los dos importan:
//
//   1. Quickshell RECARGA la configuración cada vez que guardas un .qml. Sin
//      PersistentProperties, tocar el código mientras dibujas se lleva el
//      dibujo por delante. Esto no es pulido: condiciona el modelo entero.
//   2. QML no avisa cuando mutas por dentro un `property var`. En vez de
//      pelearse con eso, hay dos contadores —`rev` y `revPixeles`— y las
//      vistas se enganchan a ellos. Separarlos es lo que hace que un trazo no
//      reconstruya la lista de capas sesenta veces por segundo.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P

Singleton {
    id: doc

    // ── la memoria que sobrevive a la recarga ────────────────────
    PersistentProperties {
        id: memoria
        reloadableId: "pinza.documento"
        property var d: null
        property int capaActiva: 0
        property int fotograma: 0
        property int orientacion: 0
    }

    // ── los contadores a los que se enganchan las vistas ─────────
    property int rev: 0            // estructura: capas, fotogramas, tamaño
    property int revPixeles: 0     // sólo píxeles
    signal pixelesCambiados(int x, int y, int w, int h)

    //  OJO AL ORDEN: primero se marca sucio y DESPUÉS se sube el contador.
    //
    //  Al revés no funciona, y no da error: subir el contador reevalúa el
    //  enlace de `sucio` en ese mismo instante, cuando el documento todavía
    //  está marcado limpio; luego se marca sucio y ya no hay nada que avise,
    //  porque el enlace depende del contador y no del objeto. Estuvo así desde
    //  el principio y `sucio` mentía siempre: el punto de "sin guardar" no
    //  salía, el autoguardado no guardaba, y cambiar de acción de una criatura
    //  se llevaba por delante lo que acabaras de dibujar.
    function cambia() {
        if (memoria.d) memoria.d.sucio = true
        rev++
    }
    function cambiaPixeles(r) {
        if (memoria.d) memoria.d.sucio = true
        revPixeles++
        if (r) pixelesCambiados(r.x, r.y, r.w, r.h)
        else pixelesCambiados(0, 0, ancho, alto)
    }

    /**
     * Repinta sin marcar nada. Para lo que sólo cambia lo que MIRAS.
     *
     * Pasar de una orientación a otra, o de un fotograma a otro, no modifica el
     * documento: sólo cambia qué celda estás viendo. Marcarlo sucio por eso
     * tiene consecuencias de verdad — el autoguardado se dispara sin que hayas
     * tocado nada, cambiar de acción de una criatura guarda ocho proyectos que
     * nadie ha editado, y reproducir la animación ensucia el documento sesenta
     * veces por segundo.
     */
    function refresca(r) {
        revPixeles++
        if (r) pixelesCambiados(r.x, r.y, r.w, r.h)
        else pixelesCambiados(0, 0, ancho, alto)
    }

    // ── acceso cómodo ────────────────────────────────────────────
    readonly property var d: memoria.d
    readonly property bool abierto: memoria.d !== null
    readonly property int ancho: rev, memoria.d ? memoria.d.ancho : 0
    readonly property int alto: rev, memoria.d ? memoria.d.alto : 0
    readonly property int nCapas: rev, memoria.d ? memoria.d.capas.length : 0
    readonly property int nFotogramas: rev, memoria.d ? memoria.d.fotogramas.length : 0
    readonly property int nOrientaciones: rev, memoria.d ? memoria.d.orientaciones.length : 1
    readonly property string nombre: rev, memoria.d ? memoria.d.nombre : ""
    readonly property string ruta: rev, memoria.d ? (memoria.d.ruta || "") : ""
    readonly property bool sucio: rev + revPixeles, memoria.d ? !!memoria.d.sucio : false

    property alias capaActiva: memoria.capaActiva
    property alias fotograma: memoria.fotograma
    property alias orientacion: memoria.orientacion

    //  Los tres cambian lo que ves, no lo que hay: refrescan sin ensuciar.
    onCapaActivaChanged: { rev++ }
    onFotogramaChanged: refresca(null)
    onOrientacionChanged: refresca(null)

    // ═══════════════════════════════════════════════════════════
    // crear
    // ═══════════════════════════════════════════════════════════

    property int _siguienteId: 1
    function _id() { return "c" + (_siguienteId++) }

    /**
     * Un documento nuevo.
     *
     * `orientaciones` es una lista de etiquetas, no un número: para un mueble
     * son ["S","E","N","O"] y para una hoja PMD son las ocho de fila, en su
     * orden. Quien las nombra es el contrato, y así el editor nunca tiene que
     * adivinar cuál es la fila 0.
     */
    function nuevo(o) {
        o = o || {}
        const w = Math.max(1, o.ancho || 32)
        const h = Math.max(1, o.alto || 32)
        const orientaciones = o.orientaciones || ["S"]
        const nFot = Math.max(1, o.fotogramas || 1)

        const idFondo = _id()
        const nuevoDoc = {
            nombre: o.nombre || "sin nombre",
            ruta: o.ruta || "",
            ancho: w, alto: h,
            capas: [{
                id: idFondo, nombre: "capa 1", visible: true, opacidad: 1,
                modo: "normal", bloqueada: false, alfaBloqueado: false,
                tipo: "normal", grupo: "", plegado: false
            }],
            fotogramas: [],
            orientaciones: orientaciones.slice(),
            etiquetas: [],
            celdas: {},
            pack: o.pack || "generico",
            contrato: o.contrato || null,
            baldosa: o.baldosa || null,     // {ancho, alto} si es un tileset
            campos: o.campos || {},         // lo que pide el contrato (desc, family, accion...)
            huella: o.huella || null,       // en casillas, si el contrato la lleva
            sucio: false
        }
        for (let i = 0; i < nFot; i++) nuevoDoc.fotogramas.push({ duracion: o.duracion || 6, nombre: "" })
        for (let f = 0; f < nFot; f++) for (let dr = 0; dr < orientaciones.length; dr++)
            nuevoDoc.celdas[idFondo + ":" + f + ":" + dr] = P.nuevo(w, h)

        memoria.d = nuevoDoc
        memoria.capaActiva = 0
        memoria.fotograma = 0
        memoria.orientacion = 0
        cambia(); cambiaPixeles(null)
        return nuevoDoc
    }

    function cerrar() { memoria.d = null; cambia(); cambiaPixeles(null) }

    // ═══════════════════════════════════════════════════════════
    // celdas
    // ═══════════════════════════════════════════════════════════

    function clave(capaId, f, dr) { return capaId + ":" + f + ":" + dr }

    /**
     * El búfer de una celda, siguiendo el enlace si lo hay.
     *
     * Enlazar celdas es lo que evita repintar un fondo quieto en veinte
     * fotogramas: dos claves apuntan al mismo búfer y pintar en una pinta en
     * las dos, que es justo lo que se quiere.
     */
    function celda(capaId, f, dr, crear) {
        if (!memoria.d) return null
        const k = clave(capaId, f, dr)
        let c = memoria.d.celdas[k]
        if (c && c.enlace) c = memoria.d.celdas[c.enlace]
        if (!c && crear) {
            c = P.nuevo(memoria.d.ancho, memoria.d.alto)
            memoria.d.celdas[k] = c
        }
        return c || null
    }

    function celdaActiva(crear) {
        const c = capa(capaActiva)
        if (!c) return null
        return celda(c.id, fotograma, orientacion, crear !== false)
    }

    function enlaza(capaId, f, dr, haciaF, haciaD) {
        if (!memoria.d) return
        memoria.d.celdas[clave(capaId, f, dr)] = { enlace: clave(capaId, haciaF, haciaD) }
        cambia(); cambiaPixeles(null)
    }

    function desenlaza(capaId, f, dr) {
        if (!memoria.d) return
        const actual = celda(capaId, f, dr, false)
        memoria.d.celdas[clave(capaId, f, dr)] = actual ? P.clonar(actual)
                                                        : P.nuevo(memoria.d.ancho, memoria.d.alto)
        cambia(); cambiaPixeles(null)
    }

    function estaEnlazada(capaId, f, dr) {
        if (!memoria.d) return false
        const c = memoria.d.celdas[clave(capaId, f, dr)]
        return !!(c && c.enlace)
    }

    // ═══════════════════════════════════════════════════════════
    // capas
    // ═══════════════════════════════════════════════════════════

    function capa(i) {
        if (!memoria.d || i < 0 || i >= memoria.d.capas.length) return null
        return memoria.d.capas[i]
    }

    function capaPorId(id) {
        if (!memoria.d) return null
        for (let i = 0; i < memoria.d.capas.length; i++)
            if (memoria.d.capas[i].id === id) return memoria.d.capas[i]
        return null
    }

    function indiceDe(id) {
        if (!memoria.d) return -1
        for (let i = 0; i < memoria.d.capas.length; i++)
            if (memoria.d.capas[i].id === id) return i
        return -1
    }

    /** El orden de la lista es de abajo arriba, como se compone. */
    function añadeCapa(nombre, tipo, donde) {
        if (!memoria.d) return null
        const anterior = capa(capaActiva)
        const c = {
            id: _id(), nombre: nombre || ("capa " + (memoria.d.capas.length + 1)),
            visible: true, opacidad: 1, modo: "normal",
            bloqueada: false, alfaBloqueado: false, tipo: tipo || "normal",
            // nace dentro del mismo grupo que la capa activa, que es donde
            // esperas que aparezca si acabas de abrir un grupo para trabajar
            grupo: anterior ? (anterior.tipo === "grupo" ? anterior.id : anterior.grupo || "") : "",
            plegado: false
        }
        const i = donde === undefined ? capaActiva + 1 : donde
        memoria.d.capas.splice(i, 0, c)
        // un grupo no tiene píxeles propios: sólo junta a los de dentro
        if (c.tipo !== "grupo")
            for (let f = 0; f < nFotogramas; f++) for (let dr = 0; dr < nOrientaciones; dr++)
                memoria.d.celdas[clave(c.id, f, dr)] = P.nuevo(ancho, alto)
        memoria.capaActiva = i
        cambia(); cambiaPixeles(null)
        return c
    }

    function duplicaCapa(i) {
        const orig = capa(i)
        if (!orig) return null
        const c = JSON.parse(JSON.stringify(orig))
        c.id = _id()
        c.nombre = orig.nombre + " copia"
        memoria.d.capas.splice(i + 1, 0, c)
        for (let f = 0; f < nFotogramas; f++) for (let dr = 0; dr < nOrientaciones; dr++) {
            const s = celda(orig.id, f, dr, false)
            memoria.d.celdas[clave(c.id, f, dr)] = s ? P.clonar(s) : P.nuevo(ancho, alto)
        }
        memoria.capaActiva = i + 1
        cambia(); cambiaPixeles(null)
        return c
    }

    /**
     * Borra una capa, y si es un grupo también lo que lleva dentro.
     *
     * Por ID y no por índice. La primera versión recogía los índices de las
     * hijas y las borraba en orden inverso, y eso funciona con una lista plana
     * pero no con grupos anidados: en cuanto una hija es a su vez un grupo, su
     * borrado recursivo corre los índices de todo lo que venía detrás y los que
     * quedaban por borrar apuntaban ya a otra capa. Quedaban capas huérfanas
     * apuntando a un grupo que ya no existía — invisibles para siempre, porque
     * la composición sólo recorre grupos que existen.
     */
    function borraCapa(i) {
        const c = capa(i)
        if (!c) return false

        const fuera = {}
        function recoge(id) {
            fuera[id] = true
            const capas = memoria.d.capas
            for (let k = 0; k < capas.length; k++)
                if ((capas[k].grupo || "") === id && !fuera[capas[k].id]) recoge(capas[k].id)
        }
        recoge(c.id)

        const quedan = memoria.d.capas.filter((x) => !fuera[x.id])
        // un documento sin ninguna capa no es un documento
        if (!quedan.length) return false

        const ids = Object.keys(fuera)
        for (let k = 0; k < ids.length; k++)
            for (let f = 0; f < nFotogramas; f++) for (let dr = 0; dr < nOrientaciones; dr++)
                delete memoria.d.celdas[clave(ids[k], f, dr)]

        memoria.d.capas = quedan
        memoria.capaActiva = Math.max(0, Math.min(memoria.capaActiva, quedan.length - 1))
        _cofre.buf = null
        cambia(); cambiaPixeles(null)
        return true
    }

    function mueveCapa(de, a) {
        if (!memoria.d || de === a) return
        if (a < 0 || a >= memoria.d.capas.length) return
        const c = memoria.d.capas.splice(de, 1)[0]
        memoria.d.capas.splice(a, 0, c)
        memoria.capaActiva = a
        cambia(); cambiaPixeles(null)
    }

    /** Fusiona la capa i con la de debajo, respetando modo y opacidad. */
    function fusionaAbajo(i) {
        const arriba = capa(i), abajo = capa(i - 1)
        if (!arriba || !abajo) return false
        // Con un grupo por medio no está claro qué se pediría: se aplana el
        // grupo primero y luego se fusiona, que son dos decisiones distintas.
        if (arriba.tipo === "grupo" || abajo.tipo === "grupo") return false
        if ((arriba.grupo || "") !== (abajo.grupo || "")) return false
        for (let f = 0; f < nFotogramas; f++) for (let dr = 0; dr < nOrientaciones; dr++) {
            const a = celda(arriba.id, f, dr, false)
            if (!a) continue
            const b = celda(abajo.id, f, dr, true)
            P.compon(b, a, arriba.modo, arriba.opacidad)
        }
        for (let f = 0; f < nFotogramas; f++) for (let dr = 0; dr < nOrientaciones; dr++)
            delete memoria.d.celdas[clave(arriba.id, f, dr)]
        memoria.d.capas.splice(i, 1)
        memoria.capaActiva = Math.max(0, i - 1)
        cambia(); cambiaPixeles(null)
        return true
    }

    function aplana() {
        if (!memoria.d || nCapas <= 1) return
        while (nCapas > 1) fusionaAbajo(nCapas - 1)
        memoria.d.capas[0].nombre = "aplanada"
        memoria.d.capas[0].modo = "normal"
        memoria.d.capas[0].opacidad = 1
        cambia(); cambiaPixeles(null)
    }

    // ═══════════════════════════════════════════════════════════
    // fotogramas
    // ═══════════════════════════════════════════════════════════

    /** Duración en TICS de 1/60 s, que es la unidad que guarda AnimData.xml. */
    function duracion(f) {
        const fr = memoria.d ? memoria.d.fotogramas[f] : null
        return fr ? fr.duracion : 6
    }

    function ponDuracion(f, tics) {
        if (!memoria.d || !memoria.d.fotogramas[f]) return
        memoria.d.fotogramas[f].duracion = Math.max(1, Math.round(tics))
        cambia()
    }

    readonly property int duracionTotal: {
        rev
        if (!memoria.d) return 0
        let t = 0
        for (let i = 0; i < memoria.d.fotogramas.length; i++) t += memoria.d.fotogramas[i].duracion
        return t
    }

    function añadeFotograma(copiando) {
        if (!memoria.d) return
        const i = fotograma + 1
        memoria.d.fotogramas.splice(i, 0, { duracion: duracion(fotograma), nombre: "" })
        // recolocar las celdas de i en adelante
        _reindexaFotogramas(i, 1)
        for (let k = 0; k < memoria.d.capas.length; k++) {
            const id = memoria.d.capas[k].id
            for (let dr = 0; dr < nOrientaciones; dr++) {
                const orig = copiando ? celda(id, fotograma, dr, false) : null
                memoria.d.celdas[clave(id, i, dr)] = orig ? P.clonar(orig) : P.nuevo(ancho, alto)
            }
        }
        memoria.fotograma = i
        cambia(); cambiaPixeles(null)
    }

    function borraFotograma(f) {
        if (!memoria.d || nFotogramas <= 1) return false
        for (let k = 0; k < memoria.d.capas.length; k++) {
            const id = memoria.d.capas[k].id
            for (let dr = 0; dr < nOrientaciones; dr++) delete memoria.d.celdas[clave(id, f, dr)]
        }
        memoria.d.fotogramas.splice(f, 1)
        _reindexaFotogramas(f + 1, -1)
        memoria.fotograma = Math.max(0, Math.min(memoria.fotograma, nFotogramas - 1))
        cambia(); cambiaPixeles(null)
        return true
    }

    function mueveFotograma(de, a) {
        if (!memoria.d || de === a || a < 0 || a >= nFotogramas) return
        const fr = memoria.d.fotogramas.splice(de, 1)[0]
        memoria.d.fotogramas.splice(a, 0, fr)
        // barajar las celdas con el mismo movimiento
        for (let k = 0; k < memoria.d.capas.length; k++) {
            const id = memoria.d.capas[k].id
            for (let dr = 0; dr < nOrientaciones; dr++) {
                const lista = []
                for (let f = 0; f < nFotogramas; f++) lista.push(memoria.d.celdas[clave(id, f, dr)])
                const x = lista.splice(de, 1)[0]
                lista.splice(a, 0, x)
                for (let f = 0; f < nFotogramas; f++) memoria.d.celdas[clave(id, f, dr)] = lista[f]
            }
        }
        memoria.fotograma = a
        cambia(); cambiaPixeles(null)
    }

    /** Corre las claves de celda cuando se inserta o se quita un fotograma. */
    function _reindexaFotogramas(desde, delta) {
        const viejas = memoria.d.celdas
        const nuevas = {}
        const claves = Object.keys(viejas)
        for (let i = 0; i < claves.length; i++) {
            const p = claves[i].split(":")
            const f = parseInt(p[1])
            const nf = f >= desde ? f + delta : f
            if (nf < 0) continue
            let v = viejas[claves[i]]
            if (v && v.enlace) {
                const q = v.enlace.split(":")
                const ef = parseInt(q[1])
                v = { enlace: q[0] + ":" + (ef >= desde ? ef + delta : ef) + ":" + q[2] }
            }
            nuevas[p[0] + ":" + nf + ":" + p[2]] = v
        }
        memoria.d.celdas = nuevas
    }

    // ═══════════════════════════════════════════════════════════
    // orientaciones
    // ═══════════════════════════════════════════════════════════

    /**
     * Cambia el juego de orientaciones sin perder lo dibujado.
     *
     * Las que ya existían se quedan donde están; las nuevas nacen vacías. Así
     * se puede empezar un mueble con una sola orientación y decidir a mitad
     * que gira, sin volver a empezar.
     */
    function ponOrientaciones(lista) {
        if (!memoria.d) return
        const viejas = memoria.d.orientaciones
        memoria.d.orientaciones = lista.slice()
        for (let k = 0; k < memoria.d.capas.length; k++) {
            const id = memoria.d.capas[k].id
            for (let f = 0; f < nFotogramas; f++) for (let dr = 0; dr < lista.length; dr++) {
                const kk = clave(id, f, dr)
                if (!memoria.d.celdas[kk]) memoria.d.celdas[kk] = P.nuevo(ancho, alto)
            }
            // tirar las que sobran
            for (let dr = lista.length; dr < viejas.length; dr++)
                for (let f = 0; f < nFotogramas; f++) delete memoria.d.celdas[clave(id, f, dr)]
        }
        memoria.orientacion = Math.min(memoria.orientacion, lista.length - 1)
        cambia(); cambiaPixeles(null)
    }

    function etiquetaOrientacion(i) {
        if (!memoria.d) return ""
        return memoria.d.orientaciones[i] || ""
    }

    // ═══════════════════════════════════════════════════════════
    // composición
    // ═══════════════════════════════════════════════════════════

    /**
     * La caché del compuesto, en UN objeto que nunca se reasigna.
     *
     * Esto tiene que ser así y no cuatro propiedades sueltas. Una propiedad QML
     * avisa al cambiar, y `compuesto()` la escribe; cualquier enlace que llame
     * a `compuesto()` —la previa, el medidor de estilo, el compás— pasaba a
     * depender de la caché que él mismo acababa de escribir, y Qt lo cazaba
     * como bucle de enlace. El síntoma no era un aviso: era que el lienzo
     * dejaba de pintarse. Mutar los campos de un objeto no emite nada, así que
     * el bucle desaparece de raíz.
     */
    property var _cofre: ({ buf: null, sello: -1, f: -1, d: -1 })

    /**
     * La pila de capas de un (fotograma, orientación), aplanada.
     *
     * Devuelve un búfer que NO hay que modificar. Se guarda en caché y sólo se
     * rehace si cambió algo, porque esto se llama en cada repintado.
     */
    function compuesto(f, dr) {
        if (!memoria.d) return null
        const ff = f === undefined ? fotograma : f
        const dd = dr === undefined ? orientacion : dr
        const sello = rev * 1000000 + revPixeles
        const k = _cofre
        if (k.buf && k.sello === sello && k.f === ff && k.d === dd
            && k.buf.w === memoria.d.ancho && k.buf.h === memoria.d.alto) return k.buf

        const out = P.nuevo(memoria.d.ancho, memoria.d.alto)
        componEn(out, ff, dd, null, false)
        k.buf = out; k.sello = sello; k.f = ff; k.d = dd
        return out
    }

    /**
     * Compone una celda sobre el búfer que le den. EL ÚNICO sitio que sabe
     * cómo se apilan las capas.
     *
     * Lo usan el lienzo —que sólo recompone el rectángulo que ensució el
     * trazo— y `compuesto()`, que lo hace entero para exportar. Tenerlo dos
     * veces sería tener dos respuestas distintas a "cómo se ve esto", y la que
     * saldría por el PNG no tendría por qué ser la que ves en pantalla.
     *
     * `rect` es {x,y,w,h} o null para todo. `conReferencia` incluye las capas
     * de calco, que se ven al dibujar pero no se exportan.
     */
    function componEn(out, ff, dd, rect, conReferencia) {
        if (!memoria.d) return
        const r = rect || { x: 0, y: 0, w: memoria.d.ancho, h: memoria.d.alto }
        _componGrupo(out, "", ff, dd, r, conReferencia)
    }

    /**
     * Un grupo y todo lo que lleva dentro, recursivamente.
     *
     * Un grupo se compone aparte y ENTERO antes de caer sobre lo de abajo, que
     * es la diferencia con dejar sus capas sueltas: la opacidad y el modo del
     * grupo se aplican al resultado, no capa a capa. Poner tres capas al 50 %
     * dentro de un grupo al 50 % no es lo mismo que seis capas al 50 %, y eso
     * es justo para lo que se agrupa.
     */
    function _componGrupo(out, idGrupo, ff, dd, r, conReferencia) {
        const capas = memoria.d.capas
        for (let i = 0; i < capas.length; i++) {
            const c = capas[i]
            if ((c.grupo || "") !== idGrupo) continue
            if (!c.visible) continue
            if (c.tipo === "referencia" && !conReferencia) continue

            if (c.tipo === "grupo") {
                const tmp = P.nuevo(memoria.d.ancho, memoria.d.alto)
                _componGrupo(tmp, c.id, ff, dd, r, conReferencia)
                P.compon(out, tmp, c.modo, c.opacidad, r.x, r.y, r.w, r.h)
                continue
            }
            const b = celda(c.id, ff, dd, false)
            if (!b) continue
            P.compon(out, b, c.tipo === "referencia" ? "normal" : c.modo, c.opacidad,
                     r.x, r.y, r.w, r.h)
        }
    }

    /** Igual pero contando las capas de referencia, para la vista. */
    function compuestoConReferencia(f, dr) {
        if (!memoria.d) return null
        const out = P.nuevo(memoria.d.ancho, memoria.d.alto)
        componEn(out, f === undefined ? fotograma : f,
                 dr === undefined ? orientacion : dr, null, true)
        return out
    }

    // ═══════════════════════════════════════════════════════════
    // grupos
    // ═══════════════════════════════════════════════════════════

    /** Mete la capa i en un grupo nuevo, justo por encima de ella. */
    function agrupa(i, nombre) {
        const c = capa(i)
        if (!c) return null
        const g = {
            id: _id(), nombre: nombre || "grupo", visible: true, opacidad: 1,
            modo: "normal", bloqueada: false, alfaBloqueado: false,
            tipo: "grupo", grupo: c.grupo || "", plegado: false
        }
        memoria.d.capas.splice(i + 1, 0, g)
        c.grupo = g.id
        cambia(); cambiaPixeles(null)
        return g
    }

    /** Saca una capa de su grupo, al nivel del grupo. */
    function desagrupa(i) {
        const c = capa(i)
        if (!c || !c.grupo) return false
        const padre = capaPorId(c.grupo)
        c.grupo = padre ? (padre.grupo || "") : ""
        cambia(); cambiaPixeles(null)
        return true
    }

    /** Cuántos grupos hay por encima de esta capa, para sangrarla en la lista. */
    function hondura(i) {
        const c = capa(i)
        if (!c) return 0
        let n = 0, g = c.grupo
        while (g && n < 8) { const p = capaPorId(g); if (!p) break; g = p.grupo; n++ }
        return n
    }

    /** Si alguno de sus grupos está plegado, esta capa no se enseña. */
    function oculta(i) {
        const c = capa(i)
        if (!c) return false
        let g = c.grupo, n = 0
        while (g && n < 8) {
            const p = capaPorId(g)
            if (!p) break
            if (p.plegado) return true
            g = p.grupo; n++
        }
        return false
    }

    /** Las capas de dentro de un grupo, en orden. */
    function hijas(idGrupo) {
        const out = []
        if (!memoria.d) return out
        for (let i = 0; i < memoria.d.capas.length; i++)
            if ((memoria.d.capas[i].grupo || "") === idGrupo) out.push(i)
        return out
    }

    // ═══════════════════════════════════════════════════════════
    // lienzo
    // ═══════════════════════════════════════════════════════════

    /**
     * Anclaje por tabla y no por letras sueltas.
     *
     * La primera versión miraba si la cadena contenía "o" u "e", y eso mezcla
     * dos idiomas sin avisar: "nw" no lleva ni "o" ni "e", así que el noroeste
     * inglés se centraba en silencio. Una tabla no tiene ese problema y admite
     * las dos formas de escribirlo.
     */
    readonly property var anclajes: ({
        "no": [0, 0], "nw": [0, 0], "n": [1, 0], "ne": [2, 0],
        "o":  [0, 1], "w":  [0, 1], "c": [1, 1], "e":  [2, 1],
        "so": [0, 2], "sw": [0, 2], "s": [1, 2], "se": [2, 2]
    })

    function redimensiona(w, h, anclaje) {
        if (!memoria.d) return
        const a = anclajes[String(anclaje || "c").toLowerCase()] || [1, 1]
        const dx = a[0] === 0 ? 0 : a[0] === 2 ? w - ancho : Math.floor((w - ancho) / 2)
        const dy = a[1] === 0 ? 0 : a[1] === 2 ? h - alto : Math.floor((h - alto) / 2)
        const claves = Object.keys(memoria.d.celdas)
        for (let i = 0; i < claves.length; i++) {
            const v = memoria.d.celdas[claves[i]]
            if (!v || v.enlace) continue
            const n = P.nuevo(w, h)
            P.vuelca(n, v, dx, dy)
            memoria.d.celdas[claves[i]] = n
        }
        memoria.d.ancho = w; memoria.d.alto = h
        _cofre.buf = null
        cambia(); cambiaPixeles(null)
    }

    /** Escala el documento entero. */
    function escala(w, h, suave) {
        if (!memoria.d) return
        const claves = Object.keys(memoria.d.celdas)
        for (let i = 0; i < claves.length; i++) {
            const v = memoria.d.celdas[claves[i]]
            if (!v || v.enlace) continue
            memoria.d.celdas[claves[i]] = suave ? P.escalaSuave(v, w, h) : P.escalaVecino(v, w, h)
        }
        memoria.d.ancho = w; memoria.d.alto = h
        _cofre.buf = null
        cambia(); cambiaPixeles(null)
    }

    /** Recorta el lienzo a lo que hay dibujado, mirando TODAS las celdas. */
    function recortaAlContenido() {
        if (!memoria.d) return null
        let x0 = ancho, y0 = alto, x1 = -1, y1 = -1
        for (let f = 0; f < nFotogramas; f++) for (let dr = 0; dr < nOrientaciones; dr++) {
            const b = compuesto(f, dr)
            const l = P.limites(b)
            if (!l) continue
            if (l.x < x0) x0 = l.x
            if (l.y < y0) y0 = l.y
            if (l.x + l.w - 1 > x1) x1 = l.x + l.w - 1
            if (l.y + l.h - 1 > y1) y1 = l.y + l.h - 1
        }
        if (x1 < x0) return null
        const w = x1 - x0 + 1, h = y1 - y0 + 1
        const claves = Object.keys(memoria.d.celdas)
        for (let i = 0; i < claves.length; i++) {
            const v = memoria.d.celdas[claves[i]]
            if (!v || v.enlace) continue
            memoria.d.celdas[claves[i]] = P.recorte(v, x0, y0, w, h)
        }
        memoria.d.ancho = w; memoria.d.alto = h
        _cofre.buf = null
        cambia(); cambiaPixeles(null)
        return { x: x0, y: y0, w: w, h: h }
    }

    // ═══════════════════════════════════════════════════════════
    // etiquetas de animación
    // ═══════════════════════════════════════════════════════════

    function añadeEtiqueta(nombre, desde, hasta, modo) {
        if (!memoria.d) return
        memoria.d.etiquetas.push({
            nombre: nombre || "sin nombre",
            desde: desde, hasta: hasta,
            modo: modo || "ida",          // ida · vuelta · vaiven
            color: "#D66C34"
        })
        cambia()
    }

    function borraEtiqueta(i) {
        if (!memoria.d) return
        memoria.d.etiquetas.splice(i, 1)
        cambia()
    }

    function etiquetaDe(f) {
        if (!memoria.d) return null
        for (let i = 0; i < memoria.d.etiquetas.length; i++) {
            const e = memoria.d.etiquetas[i]
            if (f >= e.desde && f <= e.hasta) return e
        }
        return null
    }

    // ═══════════════════════════════════════════════════════════
    // serialización
    // ═══════════════════════════════════════════════════════════

    /**
     * Todo el documento MENOS los píxeles.
     *
     * Los búferes se guardan como PNG sueltos en celdas/, no dentro del JSON:
     * un proyecto se puede mirar en un git diff, abrir un fotograma en otro
     * editor y sobrevivir a que pinza no arranque. Es la misma decisión que
     * tomó crabh al meter assets/ en el repositorio.
     */
    function meta() {
        if (!memoria.d) return null
        const enlaces = {}
        const claves = Object.keys(memoria.d.celdas)
        for (let i = 0; i < claves.length; i++) {
            const v = memoria.d.celdas[claves[i]]
            if (v && v.enlace) enlaces[claves[i]] = v.enlace
        }
        return {
            version: 1,
            nombre: memoria.d.nombre,
            ancho: memoria.d.ancho, alto: memoria.d.alto,
            capas: memoria.d.capas,
            fotogramas: memoria.d.fotogramas,
            orientaciones: memoria.d.orientaciones,
            etiquetas: memoria.d.etiquetas,
            enlaces: enlaces,
            pack: memoria.d.pack,
            contrato: memoria.d.contrato,
            baldosa: memoria.d.baldosa,
            campos: memoria.d.campos || {},
            huella: memoria.d.huella || null
        }
    }

    /** Monta el documento desde su meta; los píxeles llegan después. */
    function desdeMeta(m, ruta) {
        const nuevoDoc = {
            nombre: m.nombre, ruta: ruta || "",
            ancho: m.ancho, alto: m.alto,
            capas: m.capas, fotogramas: m.fotogramas,
            orientaciones: m.orientaciones, etiquetas: m.etiquetas || [],
            celdas: {}, pack: m.pack || "generico",
            contrato: m.contrato || null, baldosa: m.baldosa || null,
            campos: m.campos || {}, huella: m.huella || null,
            sucio: false
        }
        for (let i = 0; i < m.capas.length; i++)
            for (let f = 0; f < m.fotogramas.length; f++)
                for (let dr = 0; dr < m.orientaciones.length; dr++)
                    nuevoDoc.celdas[m.capas[i].id + ":" + f + ":" + dr] = P.nuevo(m.ancho, m.alto)
        const ek = Object.keys(m.enlaces || {})
        for (let i = 0; i < ek.length; i++) nuevoDoc.celdas[ek[i]] = { enlace: m.enlaces[ek[i]] }

        // que los ids nuevos no choquen con los cargados
        let mx = 0
        for (let i = 0; i < m.capas.length; i++) {
            const n = parseInt(String(m.capas[i].id).replace("c", ""))
            if (!isNaN(n) && n > mx) mx = n
        }
        _siguienteId = mx + 1

        memoria.d = nuevoDoc
        memoria.capaActiva = 0; memoria.fotograma = 0; memoria.orientacion = 0
        _cofre.buf = null
        cambia(); cambiaPixeles(null)
        return nuevoDoc
    }

    /** Todas las claves de celda con búfer propio, para guardar. */
    function clavesPropias() {
        if (!memoria.d) return []
        const out = []
        const claves = Object.keys(memoria.d.celdas)
        for (let i = 0; i < claves.length; i++) {
            const v = memoria.d.celdas[claves[i]]
            if (v && !v.enlace) out.push(claves[i])
        }
        return out
    }

    function ponCelda(k, buf) {
        if (!memoria.d) return
        memoria.d.celdas[k] = buf
        _cofre.buf = null
    }

    function limpio() { if (memoria.d) { memoria.d.sucio = false; rev++ } }


    function campo(id) { return memoria.d && memoria.d.campos ? memoria.d.campos[id] : undefined }
    function ponCampo(id, v) {
        if (!memoria.d) return
        memoria.d.campos = memoria.d.campos || {}
        memoria.d.campos[id] = v
        cambia()
    }
    function ponHuella(w, h) {
        if (!memoria.d) return
        memoria.d.huella = { ancho: Math.max(1, w), alto: Math.max(1, h) }
        cambia()
    }
    function ponNombre(n) { if (memoria.d) { memoria.d.nombre = n; cambia() } }
    function ponRuta(r) { if (memoria.d) { memoria.d.ruta = r; cambia() } }
}

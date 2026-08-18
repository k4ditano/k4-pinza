pragma Singleton

//  Una criatura entera.
//
//  Una especie NO es una hoja: es una por acción —quieto, andar, atacar,
//  dolerse…— más el AnimData.xml que las ata y el registro que la da de alta en
//  el juego. Dibujar eso a mano, acción por acción, acordándose de que las filas
//  van en un orden concreto y de que las duraciones son tics, es exactamente el
//  trabajo que pinza viene a quitar.
//
//  Un proyecto de especie es una CARPETA con un proyecto por acción:
//
//      MiBicho.especie/
//        especie.json      quién es: dex, papel, sombra, y qué acción tiene qué
//        Idle.pinza/       cada una es un proyecto normal, con sus capas
//        Walk.pinza/
//        retrato.png
//
//  Así cada acción se abre, se dibuja y se deshace como cualquier otra cosa, y
//  la especie sólo añade lo que las ata. Se puede empezar de una criatura del
//  juego —se trocean sus hojas y quedan editables— o en blanco.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "." as S

Singleton {
    id: esp

    property var exportador: null      // lo enchufa shell.qml, igual que Proyecto

    PersistentProperties {
        id: memoria
        reloadableId: "pinza.especie"
        property var d: null
        property string accionActiva: ""
    }

    property int rev: 0
    readonly property var d: memoria.d
    readonly property bool abierta: rev, memoria.d !== null
    readonly property string nombre: rev, memoria.d ? memoria.d.nombre : ""
    readonly property string ruta: rev, memoria.d ? memoria.d.ruta : ""
    property alias accion: memoria.accionActiva

    property string estado: ""
    property real progreso: 0
    signal hecho(string que, string detalle)
    signal falla(string que, string motivo)
    signal cambiada()

    function _avisa() { rev++; cambiada() }

    /** La tabla de acciones la manda el pack, no este fichero. */
    readonly property var plantilla: {
        const c = S.Packs.contrato("pmd")
        return c && c.especie ? c.especie : null
    }
    readonly property var acciones: plantilla ? plantilla.acciones : []

    /** La siguiente o la anterior, para saltar sin soltar el lápiz. */
    function saltaAccion(paso) {
        if (!memoria.d || !memoria.accionActiva) return
        const ids = Object.keys(memoria.d.acciones)
        const i = ids.indexOf(memoria.accionActiva)
        if (i < 0) return
        editaAccion(ids[(i + paso + ids.length) % ids.length], null)
    }

    function accionDe(id) {
        for (let i = 0; i < acciones.length; i++) if (acciones[i].id === id) return acciones[i]
        return null
    }

    // ═══════════════════════════════════════════════════════════
    // crear y abrir
    // ═══════════════════════════════════════════════════════════

    /** Una especie en blanco, con todas sus acciones puestas y vacías. */
    function nueva(o) {
        const nom = (o && o.nombre) || "MiBicho"
        const info = {}
        for (let i = 0; i < acciones.length; i++) {
            const a = acciones[i]
            info[a.id] = {
                indice: i,
                ancho: a.lado, alto: a.lado,
                fotogramas: a.fotogramas,
                duraciones: a.duraciones.slice(),
                hitFrame: a.hitFrame || 0,
                rushFrame: a.rushFrame || 0,
                returnFrame: a.returnFrame || 0,
                hecha: false
            }
        }
        memoria.d = {
            nombre: nom,
            // 10000 en adelante: no puede chocar con ningún dex de verdad
            dex: (o && o.dex) || 10000,
            role: (o && o.role) || "prey",
            shadowSize: (o && o.shadowSize) !== undefined ? o.shadowSize : 1,
            tipos: (o && o.tipos) || ["normal"],
            stats: (o && o.stats) || { hp: 50, atk: 50, def: 50, spa: 50, spd: 50, spe: 50 },
            ruta: (o && o.ruta) || "",
            acciones: info
        }
        memoria.accionActiva = ""
        _ultimoEscrito = ""
        _avisa()
        return memoria.d
    }

    function cierra(cb) {
        guardaTodo(() => {
            memoria.d = null; memoria.accionActiva = ""; _ultimoEscrito = ""; _avisa()
            if (cb) cb(true)
        })
    }

    /**
     * Todo lo que hay delante, al disco: el dibujo abierto y la ficha.
     *
     * Es lo que hay que hacer ANTES de poner otra criatura delante. Sin esto,
     * abrir una segunda especie tiraba lo que llevaras sin guardar de la
     * primera —los píxeles y la ficha— sin preguntar y sin decirlo: el
     * documento se sustituye y ya está.
     */
    function guardaTodo(cb) {
        const laFicha = () => {
            if (!memoria.d || !memoria.d.ruta) { if (cb) cb(true); return }
            recogeYGuarda((bien) => { if (cb) cb(bien) })
        }
        if (S.Documento.abierto && S.Documento.sucio && S.Documento.ruta) {
            S.Proyecto.guarda(null, (bien) => {
                if (!bien) { if (cb) cb(false); return }
                laFicha()
            })
            return
        }
        laFicha()
    }

    function abre(ruta, cb) {
        guardaTodo((bien) => {
            if (!bien) {
                falla("abrir", "no he podido guardar lo que tenías abierto, "
                               + "así que no abro otra criatura encima")
                if (cb) cb(false); return
            }
            _abre(ruta, cb)
        })
    }

    function _abre(ruta, cb) {
        estado = "abriendo"
        S.Forja.leeTexto(ruta + "/especie.json", (r) => {
            estado = ""
            if (!r.bien || !r.texto) { falla("abrir", "no hay especie.json en " + ruta); if (cb) cb(false); return }
            let m = null
            try { m = JSON.parse(r.texto) } catch (e) {}
            if (!m) { falla("abrir", "el especie.json está roto"); if (cb) cb(false); return }
            m.ruta = ruta
            memoria.d = m
            memoria.accionActiva = ""
            _ultimoEscrito = ""
            _avisa()
            hecho("abrir", ruta)

            //  Y se abre una acción, la última que estuviste dibujando o la
            //  primera. Abrir una criatura y quedarte delante de un lienzo
            //  vacío sin saber cuál de las ocho estás viendo no es abrirla.
            const ids = Object.keys(m.acciones || {})
            const cual = (m.ultima && m.acciones[m.ultima]) ? m.ultima : ids[0]
            if (cual) editaAccion(cual, () => { if (cb) cb(true) })
            else if (cb) cb(true)
        })
    }

    //  Lo último que se escribió, para no volver a escribir lo mismo.
    //
    //  La ficha se guarda ahora en cada cambio de acción y cada vez que paras
    //  de dibujar. Casi siempre no ha cambiado nada, y reescribirla igual
    //  ensucia la fecha del fichero y hace ruido en el disco para nada.
    property string _ultimoEscrito: ""

    function guarda(ruta, cb) {
        if (!memoria.d) { if (cb) cb(false); return }
        const destino = ruta || memoria.d.ruta
        if (!destino) { falla("guardar", "no hay carpeta"); if (cb) cb(false); return }
        memoria.d.ruta = destino
        const texto = JSON.stringify(memoria.d, null, 2) + "\n"
        //  Con ruta explícita se escribe siempre: es un «guardar en otro sitio»
        //  y ahí el fichero de destino no tiene por qué existir.
        if (!ruta && texto === _ultimoEscrito) { if (cb) cb(true); return }
        S.Forja.creaCarpeta(destino, () => {
            S.Forja.escribeTexto(destino + "/especie.json", texto, (r) => {
                if (!r.bien) { falla("guardar", r.error); if (cb) cb(false); return }
                _ultimoEscrito = texto
                _avisa()
                hecho("guardar", destino)
                if (cb) cb(true)
            })
        })
    }

    /**
     * Lo que hay delante, a la ficha y al disco.
     *
     * La ficha se llevaba TODO en memoria: cambiabas de acción, se recogía la
     * geometría del documento —fotogramas, duraciones, hitFrame, si está
     * dibujada— y ahí se quedaba. El especie.json no lo escribía nadie salvo
     * al crear la criatura, al exportarla o pulsando el botón de la hoja. Se
     * notaba en que `ultima` no se guardaba nunca: cerrabas y al volver
     * siempre caías en la primera acción, hubieras estado donde hubieras
     * estado. Y lo que no se notaba era peor: si añadías un fotograma o
     * cambiabas una duración, el .pinza tenía la verdad y la ficha se quedaba
     * con lo de antes.
     */
    function recogeYGuarda(cb) {
        if (!memoria.d || !memoria.d.ruta) { if (cb) cb(false); return }
        recogeDelDocumento()
        guarda(null, cb)
    }

    // ═══════════════════════════════════════════════════════════
    // editar una acción
    // ═══════════════════════════════════════════════════════════

    function carpetaDe(id) { return memoria.d.ruta + "/" + id + ".pinza" }

    /**
     * Abre una acción para dibujarla.
     *
     * Si ya tiene proyecto, se abre. Si no, se crea con la geometría que diga
     * la especie: fotogramas, duraciones en tics y las ocho orientaciones en el
     * orden de fila de PMD. Nunca hay que acordarse de ese orden a mano.
     */
    function editaAccion(id, cb) {
        if (!memoria.d) return
        const info = memoria.d.acciones[id]
        if (!info) { falla("acción", "esta especie no tiene «" + id + "»"); return }
        if (!memoria.d.ruta) { falla("acción", "guarda la especie antes de dibujarla"); return }
        if (id === memoria.accionActiva && S.Documento.abierto) { if (cb) cb(true); return }
        //  Si hay un guardado o una apertura en marcha, se anota y ya. Sin
        //  esto, pulsar dos acciones seguidas dejaba dos operaciones pisándose
        //  el documento y el programa se caía sin dejar ni un error.
        if (S.Proyecto.ocupado) { _pendiente = id; return }

        //  Antes de irse, guardar la que estabas dibujando. Cambiar de acción
        //  no puede costarte el trabajo de la anterior: no hay ningún aviso ni
        //  ninguna forma de recuperarlo, y es un clic que se da todo el rato.
        if (memoria.accionActiva && S.Documento.abierto && S.Documento.sucio) {
            recogeDelDocumento()
            const dejo = memoria.accionActiva
            S.Proyecto.guarda(carpetaDe(dejo), (bien) => {
                //  Si no se pudo guardar, NO se cambia de acción: abrir la
                //  siguiente sustituye el documento y lo de «{dejo}» se pierde
                //  sin que nadie lo haya decidido.
                if (!bien) {
                    falla("acción", "no se pudo guardar «" + dejo
                                    + "», así que me quedo aquí")
                    if (cb) cb(false)
                    return
                }
                _abreAccion(id, cb)
            })
            return
        }
        recogeDelDocumento()
        _abreAccion(id, cb)
    }

    property string _pendiente: ""

    function _abreAccion(id, cb) {
        const info = memoria.d.acciones[id]
        memoria.d.ultima = id
        const carpeta = carpetaDe(id)
        S.Forja.pide("existe", { ruta: carpeta + "/proyecto.json" }, (r) => {
            if (r.bien && r.existe) {
                S.Proyecto.abre(carpeta, (bien) => {
                    if (bien) memoria.accionActiva = id
                    _avisa()
                    //  La ficha, al disco: aquí ya lleva lo que se recogió de la
                    //  acción que dejamos Y la nueva `ultima`, así que una sola
                    //  escritura deja las dos cosas puestas.
                    _guardaFicha(() => { if (cb) cb(bien); _atiendePendiente() })
                })
                return
            }
            _creaDocumentoDe(id, info)
            S.Proyecto.guarda(carpeta, (bien) => {
                memoria.accionActiva = id
                _avisa()
                _guardaFicha(() => { if (cb) cb(bien); _atiendePendiente() })
            })
        })
    }

    /** Escribe el especie.json tal y como está ahora, sin tocar nada más. */
    function _guardaFicha(cb) {
        if (!memoria.d || !memoria.d.ruta) { if (cb) cb(false); return }
        guarda(null, cb)
    }

    function _creaDocumentoDe(id, info) {
        const con = S.Packs.contrato("pmd")
        const o = S.Packs.paraDocumento(con, {
            nombre: memoria.d.nombre,
            ancho: info.ancho, alto: info.alto,
            fotogramas: info.fotogramas
        })
        S.Documento.nuevo(o)
        for (let f = 0; f < info.fotogramas; f++)
            S.Documento.ponDuracion(f, info.duraciones[f] || 6)
        S.Documento.ponCampo("accion", id)
        S.Documento.ponCampo("hitFrame", info.hitFrame || 0)
        S.Documento.ponCampo("rushFrame", info.rushFrame || 0)
        S.Documento.ponCampo("returnFrame", info.returnFrame || 0)
        S.Documento.ponCampo("shadowSize", memoria.d.shadowSize)
        S.Historial.limpia()
    }

    /** La acción que quedó esperando mientras había otra en marcha. */
    function _atiendePendiente() {
        if (!_pendiente) return
        const id = _pendiente
        _pendiente = ""
        if (id !== memoria.accionActiva) Qt.callLater(() => editaAccion(id, null))
    }

    /** Lo que el documento abierto tenga ahora, de vuelta a la ficha. */
    function recogeDelDocumento() {
        if (!memoria.d || !memoria.accionActiva || !S.Documento.abierto) return
        const info = memoria.d.acciones[memoria.accionActiva]
        if (!info) return
        info.ancho = S.Documento.ancho
        info.alto = S.Documento.alto
        info.fotogramas = S.Documento.nFotogramas
        info.duraciones = []
        for (let f = 0; f < S.Documento.nFotogramas; f++) info.duraciones.push(S.Documento.duracion(f))
        const c = S.Documento.d.campos || {}
        info.hitFrame = c.hitFrame || 0
        info.rushFrame = c.rushFrame || 0
        info.returnFrame = c.returnFrame || 0
        info.hecha = !P.vacio(S.Documento.compuesto(0, 0))
        _avisa()
    }

    // ═══════════════════════════════════════════════════════════
    // un color en TODAS las acciones
    // ═══════════════════════════════════════════════════════════

    /**
     * Cambia un color en las acciones que NO tienes delante.
     *
     * Recolorear un bicho es cambiarlo en las ocho, y cada acción es un
     * documento aparte: el alcance de la herramienta llega hasta las ocho caras
     * y todos los fotogramas, pero eso sigue siendo Idle. Sin esto tocaba
     * repetir el mismo cambio ocho veces, y basta fallar una para que la
     * criatura cambie de color al echar a andar.
     *
     * Las otras acciones se leen, se tocan y se vuelven a escribir SIN abrirlas.
     * Abrirlas significaría sustituir el documento ocho veces, con el lienzo, la
     * muestra y la previa parpadeando de acción en acción — que es exactamente
     * lo que se arregló al importar una criatura.
     *
     * Como pasan por el disco y no por el documento, esto NO se deshace con
     * Ctrl+Z: el historial es de un documento y estas celdas no están en
     * ninguno. Quien lo llama tiene que decirlo.
     */
    function sustituyeColorEnTodas(viejo, nuevo, tolerancia, cb) {
        if (!memoria.d || !memoria.d.ruta) { if (cb) cb(0, 0); return }
        const cola = Object.keys(memoria.d.acciones)
                           .filter((id) => id !== memoria.accionActiva)
        let celdas = 0, acciones = 0
        estado = "recoloreando"
        progreso = 0
        const total = cola.length

        function siguiente() {
            if (!cola.length) {
                estado = ""
                progreso = 1
                if (celdas) hecho("recolorear", celdas + " celdas en " + acciones + " acciones")
                if (cb) cb(celdas, acciones)
                return
            }
            const id = cola.shift()
            progreso = 1 - cola.length / Math.max(1, total)
            const carpeta = carpetaDe(id)
            S.Forja.leeTexto(carpeta + "/proyecto.json", (r) => {
                //  Una acción que todavía no has dibujado no tiene carpeta, y
                //  eso no es un fallo: no hay nada que recolorear.
                if (!r.bien || !r.texto) { Qt.callLater(siguiente); return }
                let meta = null
                try { meta = JSON.parse(r.texto) } catch (e) {}
                if (!S.Documento.esDocumento(meta)) { Qt.callLater(siguiente); return }
                _recoloreaUna(carpeta, meta, viejo, nuevo, tolerancia, (n) => {
                    if (n) { celdas += n; acciones++ }
                    Qt.callLater(siguiente)
                })
            })
        }
        siguiente()
    }

    function _recoloreaUna(carpeta, meta, viejo, nuevo, tolerancia, cb) {
        //  Las claves propias, las que tienen PNG: las enlazadas comparten
        //  celda con otra y tocarlas dos veces sería tocarla dos veces.
        const enlaces = meta.enlaces || {}
        const claves = []
        for (let i = 0; i < meta.capas.length; i++)
            for (let f = 0; f < meta.fotogramas.length; f++)
                for (let dr = 0; dr < meta.orientaciones.length; dr++) {
                    const k = meta.capas[i].id + ":" + f + ":" + dr
                    if (!enlaces[k]) claves.push(k)
                }
        const rutas = claves.map((k) => carpeta + "/celdas/" + k.split(":").join(".") + ".png")
        exportador.deVarios(rutas, (mapa) => {
            const celdas = {}
            let tocadas = 0
            for (let i = 0; i < claves.length; i++) {
                const b = mapa[rutas[i]]
                if (!b) continue
                let cambio = false
                for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
                    const c = P.lee(b, x, y)
                    if (P.distancia(c, viejo) > tolerancia) continue
                    P.pon(b, x, y, [nuevo[0], nuevo[1], nuevo[2], c[3]])
                    cambio = true
                }
                celdas[claves[i]] = b
                if (cambio) tocadas++
            }
            if (!tocadas) { cb(0); return }
            S.Proyecto.guardaCrudo(carpeta, meta, celdas, () => cb(tocadas))
        })
    }

    // ═══════════════════════════════════════════════════════════
    // traerse una del juego
    // ═══════════════════════════════════════════════════════════

    property var catalogo: []
    property bool catalogoListo: false
    property bool catalogoLeyendo: false
    //  Por qué no se pudo, en cristiano. Antes fallaba en silencio y la lista
    //  se quedaba en «leyendo…» para siempre, que es la peor forma de no
    //  funcionar: parece que va lento y no va a ir nunca.
    property string catalogoError: ""

    /** Las criaturas que el juego ya tiene bajadas, para elegir de dónde partir. */
    function cargaCatalogo(cb) {
        if (catalogoListo) { if (cb) cb(catalogo); return }
        catalogoError = ""
        const base = S.Proyecto.raizPack()
        if (!plantilla) {
            catalogoError = "este pack no describe criaturas"
            if (cb) cb([]); return
        }
        if (!base) {
            catalogoError = "el pack no apunta a ningún repositorio del juego"
            if (cb) cb([]); return
        }
        const fichero = base + "/" + plantilla.datos
        catalogoLeyendo = true
        S.Forja.leeTexto(fichero, (r) => {
            catalogoLeyendo = false
            if (!r.bien || !r.texto) {
                catalogoError = "no encuentro " + fichero
                falla("catálogo", catalogoError)
                if (cb) cb([]); return
            }
            let lista = []
            try { lista = JSON.parse(r.texto) }
            catch (e) {
                catalogoError = fichero + " no es JSON legible"
                if (cb) cb([]); return
            }
            if (!lista.length) {
                catalogoError = "no hay ninguna criatura bajada todavía"
                if (cb) cb([]); return
            }
            lista.sort((a, b) => a.dex - b.dex)
            catalogo = lista
            catalogoListo = true
            if (cb) cb(lista)
        })
    }

    /** Volver a intentarlo, p.ej. tras reapuntar la raíz del pack. */
    function olvidaCatalogo() {
        catalogo = []
        catalogoListo = false
        catalogoError = ""
    }

    function delCatalogo(dex) {
        for (let i = 0; i < catalogo.length; i++) if (catalogo[i].dex === dex) return catalogo[i]
        return null
    }

    /**
     * Trae una criatura del juego y la deja editable.
     *
     * Se trocea cada hoja usando la geometría BAJADA, no adivinada: el ancho de
     * fotograma, las duraciones y los fotogramas de golpe vienen de species.json,
     * que a su vez sale del AnimData.xml original. Adivinar la rejilla de una
     * hoja PMD sale mal —hay acciones de dos fotogramas y de once— y adivinar
     * las duraciones sale mal siempre.
     */
    /**
     * Busca un nombre de carpeta que no pise nada.
     *
     * Importar dos veces la misma criatura es lo normal —una para probar, otra
     * en serio— y machacar la primera sin avisar sería la peor manera de
     * enterarse. `cb` recibe la ruta libre.
     */
    function _rutaLibre(base, cb, intento) {
        const n = intento || 1
        const ruta = n === 1 ? base : base.replace(/\.especie$/, "-" + n + ".especie")
        S.Forja.pide("existe", { ruta: ruta + "/especie.json" }, (r) => {
            if (r.bien && r.existe && n < 50) _rutaLibre(base, cb, n + 1)
            else cb(ruta)
        })
    }

    /**
     * Trae una criatura del juego y la deja editable.
     *
     * Se asegura primero de tener el catálogo: antes dependía de que alguien
     * hubiera abierto la hoja para pedirlo, así que llamar a esto desde un
     * guion o desde la línea de órdenes fallaba con un «no tengo esa criatura»
     * que no era verdad — sólo es que nadie había leído la lista todavía.
     */
    function importa(dex, nombreNuevo, destino, cb) {
        if (!catalogoListo) {
            cargaCatalogo(() => importa(dex, nombreNuevo, destino, cb))
            return
        }
        const fuente = delCatalogo(dex)
        if (!fuente) { falla("importar", "no tengo la criatura " + dex); return }
        const base = S.Proyecto.raizPack()

        const info = {}
        const cola = []
        const claves = Object.keys(fuente.sheets)
        for (let i = 0; i < acciones.length; i++) {
            const id = acciones[i].id
            const g = fuente.anims ? fuente.anims[id] : null
            const hoja = fuente.sheets[id]
            if (!g || !hoja || !g.frameWidth) continue
            info[id] = {
                indice: i,
                ancho: g.frameWidth, alto: g.frameHeight,
                fotogramas: Math.max(1, g.durations.length),
                duraciones: g.durations.slice(),
                hitFrame: g.hitFrame || 0,
                rushFrame: g.rushFrame || 0,
                returnFrame: g.returnFrame || 0,
                hecha: true
            }
            cola.push({ id: id, ruta: base + "/" + plantilla.sprites + hoja, geo: info[id] })
        }
        if (!cola.length) { falla("importar", "esa criatura no trae ninguna acción usable"); return }

        memoria.d = {
            nombre: nombreNuevo || fuente.name,
            dex: 10000 + (fuente.dex % 1000),
            role: fuente.role || "prey",
            shadowSize: fuente.shadowSize !== undefined ? fuente.shadowSize : 1,
            tipos: ["normal"],
            stats: { hp: 50, atk: 50, def: 50, spa: 50, spd: 50, spe: 50 },
            ruta: destino,
            venideDe: { dex: fuente.dex, nombre: fuente.name },
            acciones: info
        }
        memoria.accionActiva = ""
        _avisa()

        estado = "importando"
        progreso = 0
        let hechas = 0
        const total = cola.length
        let carpeta = destino

        function siguiente() {
            if (!cola.length) {
                estado = ""
                guarda(carpeta, () => {
                    hecho("importar", total + " acciones de " + fuente.name
                                      + " → " + carpeta.split("/").pop())
                    //  Y se abre la primera, para no dejarte delante de un
                    //  lienzo vacío preguntándote qué ha pasado.
                    const primera = Object.keys(memoria.d.acciones)[0]
                    if (primera) editaAccion(primera, () => { if (cb) cb(true) })
                    else if (cb) cb(true)
                })
                return
            }
            const t = cola.shift()
            _importaUna(t, () => {
                hechas++
                progreso = hechas / total
                Qt.callLater(siguiente)
            })
        }
        _rutaLibre(destino, (libre) => {
            carpeta = libre
            memoria.d.ruta = libre
            siguiente()
        })
    }

    /**
     * Una acción, troceada y escrita a disco directamente.
     *
     * Ni se abre ni se enseña: se monta la metainformación a mano y se escriben
     * las celdas. Antes esto llamaba a Documento.nuevo por cada acción y el
     * lienzo parpadeaba ocho veces mientras importaba, arrastrando en cada
     * cambio a la muestra, la previa, el compás y el medidor de estilo.
     */
    function _importaUna(t, cb) {
        exportador.trocea(t.ruta, t.geo.ancho, t.geo.alto, (celdas, cols, filas) => {
            if (!celdas) { falla("importar", "no puedo trocear " + t.ruta); cb(); return }

            //  Las columnas son fotogramas y las filas orientaciones. Si la hoja
            //  trae menos filas de las ocho —las hay— se respetan las que haya:
            //  el juego hace lo mismo, `dir % filas`.
            const nFot = Math.min(cols, t.geo.fotogramas)
            const con = S.Packs.contrato("pmd")
            const todas = con.orientaciones.map((x) => x.id)
            const dirs = todas.slice(0, Math.max(1, Math.min(filas, todas.length)))

            const capaId = "c1"
            const fotogramas = []
            for (let f = 0; f < nFot; f++)
                fotogramas.push({ duracion: t.geo.duraciones[f] || 6, nombre: "" })

            const meta = {
                version: 1,
                nombre: memoria.d.nombre,
                ancho: t.geo.ancho, alto: t.geo.alto,
                capas: [{ id: capaId, nombre: "capa 1", visible: true, opacidad: 1,
                          modo: "normal", bloqueada: false, alfaBloqueado: false,
                          tipo: "normal", grupo: "", plegado: false }],
                fotogramas: fotogramas,
                orientaciones: dirs,
                etiquetas: [],
                enlaces: {},
                pack: "crabh",
                contrato: JSON.parse(JSON.stringify(con)),
                baldosa: null,
                campos: {
                    accion: t.id,
                    hitFrame: t.geo.hitFrame,
                    rushFrame: t.geo.rushFrame,
                    returnFrame: t.geo.returnFrame,
                    shadowSize: memoria.d.shadowSize
                },
                huella: null
            }

            const mapa = {}
            for (let dr = 0; dr < dirs.length; dr++) for (let f = 0; f < nFot; f++) {
                const trozo = celdas[dr * cols + f]
                mapa[capaId + ":" + f + ":" + dr] = trozo || P.nuevo(t.geo.ancho, t.geo.alto)
            }

            S.Proyecto.guardaCrudo(carpetaDe(t.id), meta, mapa, () => cb())
        })
    }

    // ═══════════════════════════════════════════════════════════
    // sacarla al juego
    // ═══════════════════════════════════════════════════════════

    /**
     * Escribe la especie entera donde el juego la busca.
     *
     * Una hoja por acción, un AnimData.xml con todas, y la ficha JSON que la da
     * de alta. Los tres tienen que estar de acuerdo, y ese acuerdo es justo lo
     * que se rompe haciéndolo a mano.
     */
    function exporta(cb) {
        if (!memoria.d) return
        //  Exportar abre las ocho acciones una detrás de otra, y abrir
        //  sustituye el documento. Si lo que tienes delante está sin guardar,
        //  eso se lo lleva por delante sin decir nada: exportas la versión de
        //  disco y encima pierdes la de pantalla. Así que primero al disco.
        if (S.Documento.abierto && S.Documento.sucio && S.Documento.ruta) {
            S.Proyecto.guarda(null, (bien) => {
                if (!bien) {
                    falla("exportar", "no he podido guardar lo que tenías abierto; no exporto")
                    if (cb) cb(false); return
                }
                recogeDelDocumento()
                _exporta(cb)
            })
            return
        }
        _exporta(cb)
    }

    function _exporta(cb) {
        const base = S.Proyecto.raizPack()
        if (!base) { falla("exportar", "este pack no apunta a ningún repositorio"); return }
        const carpetaRel = plantilla.carpeta.replace("{nombre}", memoria.d.nombre)
        const carpeta = base + "/" + carpetaRel

        const ids = Object.keys(memoria.d.acciones)
        const anims = []
        const hojas = {}
        let quedan = ids.length
        estado = "exportando"
        progreso = 0
        let hechas = 0

        if (!quedan) { estado = ""; falla("exportar", "no hay ninguna acción"); return }

        S.Forja.creaCarpeta(carpeta, () => {
            const cola = ids.slice()

            function siguiente() {
                if (!cola.length) { _cierraExport(base, carpetaRel, carpeta, anims, hojas, cb); return }
                const id = cola.shift()
                const info = memoria.d.acciones[id]
                S.Proyecto.abre(carpetaDe(id), (bien) => {
                    if (!bien) {
                        // una acción sin dibujar no se exporta, y se dice
                        hechas++; progreso = hechas / ids.length
                        Qt.callLater(siguiente)
                        return
                    }
                    const nFot = S.Documento.nFotogramas
                    const nDir = S.Documento.nOrientaciones
                    const celdas = []
                    for (let dr = 0; dr < nDir; dr++) for (let f = 0; f < nFot; f++)
                        celdas.push(S.Documento.compuesto(f, dr))
                    const dur = []
                    for (let f = 0; f < nFot; f++) dur.push(S.Documento.duracion(f))
                    const campos = S.Documento.d.campos || {}

                    const hoja = exportador.componHoja(celdas, nFot, nDir,
                                                        S.Documento.ancho, S.Documento.alto)
                    {
                        const fichero = id + "-Anim.png"
                        exportador.escribe(carpeta + "/" + fichero, hoja, () => {
                            anims.push({
                                nombre: id, indice: info.indice,
                                ancho: S.Documento.ancho, alto: S.Documento.alto,
                                duraciones: dur,
                                hitFrame: campos.hitFrame || 0,
                                rushFrame: campos.rushFrame || 0,
                                returnFrame: campos.returnFrame || 0
                            })
                            hojas[id] = carpetaRel + "/" + fichero
                            hechas++; progreso = hechas / ids.length
                            Qt.callLater(siguiente)
                        })
                    }
                })
            }
            siguiente()
        })
    }

    function _cierraExport(base, carpetaRel, carpeta, anims, hojas, cb) {
        if (!anims.length) { estado = ""; falla("exportar", "ninguna acción tenía proyecto"); return }
        anims.sort((a, b) => a.indice - b.indice)

        S.Forja.pide("animdata", {
            ruta: carpeta + "/AnimData.xml",
            shadowSize: memoria.d.shadowSize,
            anims: anims
        }, () => {
            // la ficha que da de alta a la criatura en el juego
            const geo = {}
            for (let i = 0; i < anims.length; i++) {
                const a = anims[i]
                geo[a.nombre] = {
                    index: a.indice,
                    frameWidth: a.ancho, frameHeight: a.alto,
                    durations: a.duraciones,
                    hitFrame: a.hitFrame || null,
                    rushFrame: a.rushFrame || null,
                    returnFrame: a.returnFrame || null,
                    copyOf: null,
                    source: a.nombre
                }
            }
            const ficha = {
                dex: memoria.d.dex,
                name: memoria.d.nombre.toLowerCase(),
                role: memoria.d.role,
                shadowSize: memoria.d.shadowSize,
                portrait: null,
                sheets: hojas,
                anims: geo,
                //  La mitad de pokédex. Tipos y habilidades son cadenas normales,
                //  así que una criatura tuya lee la misma tabla de tipos que una
                //  de verdad: nada de ella es un caso especial más abajo.
                pokedex: {
                    dex: memoria.d.dex,
                    name: memoria.d.nombre.toLowerCase(),
                    types: memoria.d.tipos,
                    stats: memoria.d.stats,
                    height: 5, weight: 50,
                    label: memoria.d.nombre,
                    captureRate: 190, growthRate: "medium", color: "green",
                    moves: [], abilities: ["run-away"]
                }
            }
            const fichero = base + "/" + plantilla.manifiesto.replace("{nombre}", memoria.d.nombre)
            S.Forja.escribeTexto(fichero, JSON.stringify(ficha, null, 2) + "\n", () => {
                estado = ""
                hecho("exportar", anims.length + " acciones en " + carpetaRel
                                 + "\n" + plantilla.manifiesto.replace("{nombre}", memoria.d.nombre))
                if (cb) cb(true)
            })
        })
    }
}

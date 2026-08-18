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
        _avisa()
        return memoria.d
    }

    function cierra() { memoria.d = null; memoria.accionActiva = ""; _avisa() }

    function abre(ruta, cb) {
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
            _avisa()
            hecho("abrir", ruta)
            if (cb) cb(true)
        })
    }

    function guarda(ruta, cb) {
        if (!memoria.d) return
        const destino = ruta || memoria.d.ruta
        if (!destino) { falla("guardar", "no hay carpeta"); return }
        memoria.d.ruta = destino
        S.Forja.creaCarpeta(destino, () => {
            S.Forja.escribeTexto(destino + "/especie.json",
                                 JSON.stringify(memoria.d, null, 2) + "\n", (r) => {
                if (!r.bien) { falla("guardar", r.error); if (cb) cb(false); return }
                _avisa()
                hecho("guardar", destino)
                if (cb) cb(true)
            })
        })
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

        const carpeta = carpetaDe(id)
        S.Forja.pide("existe", { ruta: carpeta + "/proyecto.json" }, (r) => {
            if (r.bien && r.existe) {
                S.Proyecto.abre(carpeta, (bien) => { if (bien) memoria.accionActiva = id; _avisa(); if (cb) cb(bien) })
                return
            }
            _creaDocumentoDe(id, info)
            S.Proyecto.guarda(carpeta, (bien) => {
                memoria.accionActiva = id
                _avisa()
                if (cb) cb(bien)
            })
        })
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
    // traerse una del juego
    // ═══════════════════════════════════════════════════════════

    property var catalogo: []
    property bool catalogoListo: false

    /** Las criaturas que el juego ya tiene bajadas, para elegir de dónde partir. */
    function cargaCatalogo(cb) {
        if (catalogoListo) { if (cb) cb(catalogo); return }
        const base = S.Proyecto.raizPack()
        if (!base || !plantilla) { if (cb) cb([]); return }
        S.Forja.leeTexto(base + "/" + plantilla.datos, (r) => {
            if (!r.bien || !r.texto) { falla("catálogo", "no encuentro " + plantilla.datos); if (cb) cb([]); return }
            let lista = []
            try { lista = JSON.parse(r.texto) } catch (e) {}
            lista.sort((a, b) => a.dex - b.dex)
            catalogo = lista
            catalogoListo = true
            if (cb) cb(lista)
        })
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
    function importa(dex, nombreNuevo, destino, cb) {
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

        function siguiente() {
            if (!cola.length) {
                estado = ""
                guarda(destino, () => {
                    hecho("importar", total + " acciones de " + fuente.name)
                    if (cb) cb(true)
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
        siguiente()
    }

    function _importaUna(t, cb) {
        exportador.trocea(t.ruta, t.geo.ancho, t.geo.alto, (celdas, cols, filas) => {
            if (!celdas) { falla("importar", "no puedo trocear " + t.ruta); cb(); return }

            //  Las columnas son fotogramas y las filas orientaciones. Si la hoja
            //  trae menos filas de las ocho —las hay— se respetan las que haya:
            //  el juego hace lo mismo, `dir % filas`.
            const nFot = Math.min(cols, t.geo.fotogramas)
            const orientaciones = S.Packs.contrato("pmd").orientaciones.map((x) => x.id)
            const dirs = orientaciones.slice(0, Math.max(1, Math.min(filas, orientaciones.length)))

            S.Documento.nuevo({
                nombre: memoria.d.nombre,
                ancho: t.geo.ancho, alto: t.geo.alto,
                fotogramas: nFot,
                orientaciones: dirs,
                pack: "crabh",
                contrato: JSON.parse(JSON.stringify(S.Packs.contrato("pmd")))
            })
            for (let f = 0; f < nFot; f++) S.Documento.ponDuracion(f, t.geo.duraciones[f] || 6)
            S.Documento.ponCampo("accion", t.id)
            S.Documento.ponCampo("hitFrame", t.geo.hitFrame)
            S.Documento.ponCampo("rushFrame", t.geo.rushFrame)
            S.Documento.ponCampo("returnFrame", t.geo.returnFrame)
            S.Documento.ponCampo("shadowSize", memoria.d.shadowSize)

            const capa = S.Documento.capa(0)
            for (let dr = 0; dr < dirs.length; dr++) for (let f = 0; f < nFot; f++) {
                const trozo = celdas[dr * cols + f]
                if (!trozo) continue
                P.vuelca(S.Documento.celda(capa.id, f, dr, true), trozo, 0, 0)
            }
            S.Documento.cambiaPixeles(null)
            S.Historial.limpia()
            S.Proyecto.guarda(carpetaDe(t.id), () => cb())
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

                    exportador.aHoja(celdas, nFot, nDir, S.Documento.ancho, S.Documento.alto, (url) => {
                        const fichero = id + "-Anim.png"
                        S.Forja.escribePng(carpeta + "/" + fichero, url, () => {
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
                    })
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

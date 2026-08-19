pragma Singleton

//  Guardar, abrir y exportar.
//
//  El formato de proyecto es UNA CARPETA con un JSON y un PNG por celda. Nada
//  de un binario propio, y por tres razones que se notan a diario: se ve en un
//  git diff, se puede abrir un fotograma suelto en cualquier otro editor
//  mientras a pinza le falte una herramienta, y si mañana el programa no
//  arranca el arte sigue estando ahí. Es la misma decisión que tomó crabh al
//  meter assets/ en el repositorio y dejar public/assets/ como caché.
//
//  Exportar es otra cosa distinta de guardar: guardar conserva las capas y los
//  ejes; exportar aplana lo que el CONTRATO diga, con el nombre que el contrato
//  diga, donde el contrato diga, y escribe además la entrada del manifiesto.
//  Ese último paso es el que hoy se hace a mano.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "." as S

Singleton {
    id: proy

    property var exportador: null      // lo enchufa shell.qml: tiene que ser una vista
    property string estado: ""
    property real progreso: 0
    property string ultimoMensaje: ""
    signal hecho(string que, string detalle)
    signal falla(string que, string motivo)

    readonly property string carpetaBase: (Quickshell.env("HOME") || "~") + "/Proyectos"

    // ═══════════════════════════════════════════════════════════
    // guardar
    // ═══════════════════════════════════════════════════════════

    readonly property bool ocupado: estado !== ""

    /**
     * Guardar y abrir no pueden solaparse.
     *
     * Guardar recorre las celdas del documento y las va mandando por tandas;
     * si mientras tanto se abre otro proyecto, el documento se cambia debajo y
     * lo que se escribe deja de tener que ver con lo que se pidió. Pasaba de
     * verdad: dos cambios de acción seguidos y el programa se caía sin dejar
     * ni un error en el registro.
     *
     * Se guarda la última petición y se atiende al terminar la de ahora, que
     * es lo que espera quien pulsa dos veces: acabar donde pulsó la última.
     */
    property var _enCola: null

    function _despacha() {
        const p = _enCola
        _enCola = null
        if (!p) return
        if (p.que === "abrir") abre(p.ruta, p.cb)
        else if (p.que === "abrirImagen") abreImagen(p.ruta, p.cb)
        else if (p.que === "guardarImagen") guardaImagen(p.cb)
        else guarda(p.ruta, p.cb)
    }

    /**
     * Quita de `celdas/` los PNG que ya no son de nadie.
     *
     * Va SIEMPRE al final y nunca antes: si podara primero y luego fallara la
     * escritura, habría borrado lo viejo sin tener lo nuevo. Y un fallo aquí
     * NO estropea el guardado — las celdas y el proyecto.json ya están en el
     * disco y concuerdan; que sobren ficheros es cosmético, y decir que un
     * guardado bueno ha fallado sería mentir en la dirección contraria pero
     * mentir igual.
     */
    function _poda(destino, claves) {
        const conservar = []
        for (let i = 0; i < claves.length; i++)
            conservar.push(claves[i].split(":").join(".") + ".png")
        S.Forja.poda(destino + "/celdas", "*.png", conservar, (r) => {
            if (!r || !r.bien) { console.warn("no se pudo podar " + destino + "/celdas"); return }
            if (r.cuantos) console.log("podadas " + r.cuantos + " celdas que ya no eran de nadie")
        })
    }

    function guarda(ruta, cb) {
        if (!S.Documento.abierto) return
        const destino = ruta || S.Documento.ruta
        if (!destino) { falla("guardar", "no hay ruta"); return }
        if (ocupado) { _enCola = { que: "guardar", ruta: destino, cb: cb }; return }

        estado = "guardando"
        progreso = 0
        const meta = S.Documento.meta()
        const claves = S.Documento.clavesPropias()

        //  Todas las celdas en un viaje. El nombre de fichero ES la clave: capa,
        //  fotograma y orientación se leen de un vistazo en el explorador.
        //
        //  Se COPIAN, no se referencian: el guardado va por tandas y entre
        //  tanda y tanda puede pasar cualquier cosa —un trazo, abrir otra
        //  cosa—. Copiar ochenta celdas de 32×32 son trescientos kilobytes y
        //  compra que lo que se escribe sea lo que había cuando lo pediste.
        const lista = []
        for (let i = 0; i < claves.length; i++) {
            const k = claves[i]
            lista.push({ ruta: destino + "/celdas/" + k.split(":").join(".") + ".png",
                         buf: P.clonar(S.Documento.d.celdas[k]) })
        }

        //  Si algo falla, NO se marca limpio y NO se escribe el proyecto.json.
        //
        //  Antes se daba por bueno pasara lo que pasara: se escribía el
        //  proyecto.json, se quitaba el punto de «sin guardar» y se decía
        //  «guardado en …» aunque las celdas no hubieran llegado al disco. Un
        //  guardado a medias que además te deja cerrar tranquilo es peor que
        //  no guardar, porque el aviso que te habría salvado ya no sale.
        function _falloAlGuardar(motivo) {
            estado = ""
            falla("guardar", motivo)
            if (cb) cb(false)
            _despacha()
        }

        S.Forja.creaCarpeta(destino + "/celdas", () => {
            S.Forja.escribeTexto(destino + "/paleta.gpl", S.Paleta.aGpl(meta.nombre), null)
            exportador.escribeVarios(lista, (bien) => {
                if (!bien) {
                    _falloAlGuardar("no se pudieron escribir las celdas en " + destino)
                    return
                }
                //  El proyecto.json va DESPUÉS de las celdas, y a propósito: es
                //  el índice de lo demás, y un índice que promete celdas que no
                //  están es lo único que no se puede arreglar mirando la carpeta.
                S.Forja.escribeTexto(destino + "/proyecto.json",
                                     JSON.stringify(meta, null, 2) + "\n", (r) => {
                    if (!r || !r.bien) {
                        _falloAlGuardar("las celdas están escritas, pero el proyecto.json de "
                                        + destino + " no: " + ((r && r.error) || "no sé por qué"))
                        return
                    }
                    estado = ""
                    progreso = 1
                    S.Documento.ponRuta(destino)
                    S.Documento.limpio()
                    ultimoMensaje = "guardado en " + destino
                    hecho("guardar", destino)
                    _poda(destino, claves)
                    if (cb) cb(true)
                    _despacha()
                })
            })
        })
    }

    /**
     * Escribe un proyecto SIN abrirlo.
     *
     * Importar una criatura son ocho proyectos, y hacerlo abriendo cada uno
     * significaba cambiar el documento visible ocho veces: el lienzo iba
     * parpadeando de acción en acción, y con él la muestra, la previa, el
     * compás y el medidor de estilo, todos recalculando por cada cambio. Aquí
     * no se toca nada de lo que estás mirando.
     *
     * `celdas` es un mapa clave -> búfer, con las mismas claves que usa el
     * documento: capa:fotograma:orientación.
     */
    function guardaCrudo(ruta, meta, celdas, cb) {
        const claves = Object.keys(celdas)
        const lista = []
        for (let i = 0; i < claves.length; i++)
            lista.push({ ruta: ruta + "/celdas/" + claves[i].split(":").join(".") + ".png",
                         buf: celdas[claves[i]] })
        S.Forja.creaCarpeta(ruta + "/celdas", () => {
            exportador.escribeVarios(lista, (bien) => {
                S.Forja.escribeTexto(ruta + "/proyecto.json",
                                     JSON.stringify(meta, null, 2) + "\n",
                                     () => {
                    //  Sólo se poda si las celdas llegaron. Podar detrás de una
                    //  escritura fallida sería borrar lo viejo sin tener lo
                    //  nuevo, que es la única forma de que esto pierda trabajo.
                    if (bien) _poda(ruta, claves)
                    if (cb) cb(bien)
                })
            })
        })
    }

    // ═══════════════════════════════════════════════════════════
    // abrir
    // ═══════════════════════════════════════════════════════════

    function abre(ruta, cb) {
        if (ocupado) { _enCola = { que: "abrir", ruta: ruta, cb: cb }; return }
        estado = "abriendo"
        S.Forja.leeTexto(ruta + "/proyecto.json", (r) => {
            if (!r.bien || !r.texto) {
                estado = ""
                falla("abrir", "no hay proyecto.json en " + ruta)
                if (cb) cb(false)
                _despacha()
                return
            }
            let meta
            try { meta = JSON.parse(r.texto) }
            catch (e) { estado = ""; falla("abrir", "el proyecto.json está roto")
                        if (cb) cb(false); _despacha(); return }

            if (!S.Documento.desdeMeta(meta, ruta)) {
                estado = ""
                falla("abrir", "el proyecto.json de " + ruta
                               + " no describe un documento; no lo abro para no escribir encima")
                if (cb) cb(false); _despacha(); return
            }
            if (meta.pack) S.Packs.elige(meta.pack)
            _aplicaRejilla()

            const claves = S.Documento.clavesPropias()
            if (!claves.length) { estado = ""; hecho("abrir", ruta)
                                  if (cb) cb(true); _despacha(); return }

            const rutas = claves.map((k) => ruta + "/celdas/" + k.split(":").join(".") + ".png")
            exportador.deVarios(rutas, (mapa) => {
                for (let i = 0; i < claves.length; i++) {
                    const b = mapa[rutas[i]]
                    if (b) S.Documento.ponCelda(claves[i], b)
                }
                estado = ""
                progreso = 1
                S.Documento.cambiaPixeles(null)
                S.Documento.limpio()
                S.Historial.limpia()
                ultimoMensaje = "abierto " + ruta
                hecho("abrir", ruta)
                if (cb) cb(true)
                _despacha()
            })
        })
    }

    /** La rejilla de casilla la manda el contrato, si lo dice. */
    function _aplicaRejilla() {
        const c = S.Documento.d ? S.Documento.d.contrato : null
        if (c && c.rejilla) {
            S.Ajustes.casillaAncho = c.rejilla.ancho
            S.Ajustes.casillaAlto = c.rejilla.alto
            S.Ajustes.rejillaCasilla = true
        }
        S.Ajustes.modoBaldosa = !!(c && c.baldosa)
    }

    // ═══════════════════════════════════════════════════════════
    // exportar
    // ═══════════════════════════════════════════════════════════

    /**
     * Rellena un patrón de nombre del contrato.
     *
     * Los huecos son los que de verdad hacen falta para que el juego lea bien
     * el fichero: en crabh el número de fotogramas VA EN EL NOMBRE, y de ahí
     * saca el juego la rejilla de la tira. Equivocarlo no da error, da un
     * efecto que se reproduce a trozos.
     */
    function nombraCon(patron, extra) {
        const d = S.Documento.d
        let s = patron
        s = s.replace(/\{nombre\}/g, d.nombre)
        s = s.replace(/\{fotogramas\}/g, String(S.Documento.nFotogramas))
        s = s.replace(/\{orientaciones\}/g, String(S.Documento.nOrientaciones))
        const campos = d.campos || {}
        const k = Object.keys(campos)
        for (let i = 0; i < k.length; i++)
            s = s.replace(new RegExp("\\{" + k[i] + "\\}", "g"), String(campos[k[i]]))
        if (extra) {
            const e = Object.keys(extra)
            for (let i = 0; i < e.length; i++)
                s = s.replace(new RegExp("\\{" + e[i] + "\\}", "g"), String(extra[e[i]]))
        }
        return s
    }

    /** La raíz del pack, con ~ expandida y sin barra final. */
    function raizPack() {
        let r = S.Packs.raiz || ""
        if (r.indexOf("~") === 0) r = (Quickshell.env("HOME") || "") + r.substring(1)
        return r.replace(/\/+$/, "")
    }

    /**
     * Exporta lo que diga el contrato.
     *
     * `opciones.carpeta` gana sobre la del contrato — se puede exportar a
     * cualquier sitio sin tocar el pack, que es lo que hace falta cuando estás
     * probando algo y no quieres escribir dentro del juego todavía.
     */
    function exporta(opciones, cb) {
        if (!S.Documento.abierto) return
        const d = S.Documento.d
        const con = d.contrato
        const salida = (con && con.salida) || { modo: "png", carpeta: "", patron: "{nombre}.png" }
        const o = opciones || {}

        let carpeta = o.carpeta
        if (!carpeta) {
            const base = raizPack()
            const sub = nombraCon(salida.carpeta || "")
            carpeta = base ? (sub ? base + "/" + sub : base) : (S.Documento.ruta || carpetaBase)
        }

        estado = "exportando"
        const escritos = []

        function acaba() {
            estado = ""
            ultimoMensaje = escritos.length === 1 ? "escrito " + escritos[0]
                          : escritos.length + " ficheros escritos en " + carpeta
            hecho("exportar", escritos.join("\n"))
            if (o.manifiesto !== false) _manifiesto(escritos)
            if (salida.animdata) _animdata(carpeta)
            if (cb) cb(escritos)
        }

        S.Forja.creaCarpeta(carpeta, () => {
            const nf = S.Documento.nFotogramas
            const no = S.Documento.nOrientaciones

            // ── un PNG por orientación ───────────────────────────
            if (salida.modo === "png-por-orientacion" && no > 1) {
                const lista = []
                for (let dr = 0; dr < no; dr++) {
                    const nombre = nombraCon(salida.patron,
                                             { orientacion: S.Documento.etiquetaOrientacion(dr) })
                    lista.push({ ruta: carpeta + "/" + nombre,
                                 buf: P.clonar(S.Documento.compuesto(0, dr)) })
                    escritos.push(carpeta + "/" + nombre)
                }
                exportador.escribeVarios(lista, () => acaba())
                return
            }

            // ── una hoja ─────────────────────────────────────────
            if (salida.modo === "hoja" && (nf > 1 || no > 1)) {
                const disp = salida.disposicion || "fotogramas-en-columnas"
                // en PMD y en cualquier hoja con orientaciones, las columnas
                // son fotogramas y las filas orientaciones — ese orden no es
                // negociable, lo lee el juego
                const cols = nf
                const filas = no
                const celdas = []
                for (let dr = 0; dr < filas; dr++) for (let f = 0; f < cols; f++)
                    celdas.push(S.Documento.compuesto(f, dr))
                let patron = salida.patron
                if (no > 1 && salida.patronOrientaciones) patron = salida.patronOrientaciones
                else if (nf === 1 && salida.patronUnico) patron = salida.patronUnico
                const nombre = nombraCon(patron, { accion: (d.campos || {}).accion || "Anim" })
                const hoja = exportador.componHoja(celdas, cols, filas,
                                                   S.Documento.ancho, S.Documento.alto)
                exportador.escribe(carpeta + "/" + nombre, hoja, () => {
                    escritos.push(carpeta + "/" + nombre)
                    acaba()
                })
                return
            }

            // ── un PNG y ya ──────────────────────────────────────
            const patron = (nf === 1 && no === 1 && salida.patronUnico) ? salida.patronUnico : salida.patron
            const nombre = nombraCon(patron, { orientacion: S.Documento.etiquetaOrientacion(0),
                                               accion: (d.campos || {}).accion || "Anim" })
            exportador.escribe(carpeta + "/" + nombre, S.Documento.compuesto(0, 0), () => {
                escritos.push(carpeta + "/" + nombre)
                acaba()
            })
        })
    }

    /**
     * La entrada del manifiesto, si el contrato la pide.
     *
     * Esto es el paso que hoy se teclea a mano después de exportar, y es medio
     * motivo de que pinza exista. La ruta que se apunta es RELATIVA a la raíz
     * del pack, porque es como está escrito el resto del fichero.
     */
    function _manifiesto(escritos) {
        const d = S.Documento.d
        const con = d.contrato
        if (!con || !con.manifiesto || !escritos.length) return
        const base = raizPack()
        if (!base) return

        let rel = escritos[0]
        if (rel.indexOf(base + "/") === 0) rel = rel.substring(base.length + 1)
        rel = rel.replace(/^assets\//, "")

        const entrada = {
            kind: con.manifiesto.kind,
            name: d.nombre,
            path: rel,
            frames: S.Documento.nFotogramas,
            side: Math.max(S.Documento.ancho, S.Documento.alto)
        }
        const campos = con.manifiesto.campos || []
        for (let i = 0; i < campos.length; i++) {
            const v = (d.campos || {})[campos[i]]
            if (v !== undefined && v !== "") entrada[campos[i]] = v
        }

        S.Forja.pide("manifiesto",
                     { fichero: base + "/" + con.manifiesto.fichero, entrada: entrada },
                     (r) => {
                         if (r.bien) ultimoMensaje += "  ·  manifiesto al día (" + r.entradas + " entradas)"
                         else falla("manifiesto", r.error)
                     })
    }

    /** El AnimData.xml de una hoja PMD, con las duraciones en tics tal cual. */
    function _animdata(carpeta) {
        const d = S.Documento.d
        const campos = d.campos || {}
        const dur = []
        for (let f = 0; f < S.Documento.nFotogramas; f++) dur.push(S.Documento.duracion(f))
        S.Forja.pide("animdata", {
            ruta: carpeta + "/AnimData.xml",
            shadowSize: campos.shadowSize || 1,
            anims: [{
                nombre: campos.accion || "Walk",
                indice: 0,
                ancho: S.Documento.ancho, alto: S.Documento.alto,
                duraciones: dur,
                hitFrame: campos.hitFrame || 0,
                rushFrame: campos.rushFrame || 0,
                returnFrame: campos.returnFrame || 0
            }]
        }, (r) => { if (!r.bien) falla("animdata", r.error) })
    }

    // ═══════════════════════════════════════════════════════════
    // animación a fichero
    // ═══════════════════════════════════════════════════════════

    /** GIF o APNG, con las duraciones reales de cada fotograma. */
    function exportaAnimacion(ruta, formato, cb) {
        if (!S.Documento.abierto || S.Documento.nFotogramas < 2) {
            falla("animación", "hacen falta al menos dos fotogramas")
            return
        }
        estado = "montando " + formato
        const tmp = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-anim"
        const dur = []
        const ficheros = []

        S.Forja.creaCarpeta(tmp, () => {
            const lista = []
            for (let f = 0; f < S.Documento.nFotogramas; f++) {
                dur.push(S.Documento.duracion(f))
                const fichero = tmp + "/f" + f + ".png"
                ficheros.push(fichero)
                lista.push({ ruta: fichero,
                             buf: P.clonar(S.Documento.compuesto(f, S.Documento.orientacion)) })
            }
            exportador.escribeVarios(lista, () => {
                S.Forja.pide("gif", { ficheros: ficheros, duraciones: dur,
                                      ruta: ruta, formato: formato }, (r) => {
                    estado = ""
                    if (r.bien) { ultimoMensaje = "escrito " + ruta; hecho("animación", ruta) }
                    else falla("animación", r.error)
                    if (cb) cb(r.bien)
                })
            })
        })
    }

    // ═══════════════════════════════════════════════════════════
    // importar
    // ═══════════════════════════════════════════════════════════

    /** Un PNG suelto como capa nueva del documento actual. */
    /**
     * Un PNG suelto, abierto para tocarlo.
     *
     * Se podía meter una imagen, pero sólo como CAPA del documento que
     * tuvieras delante: con una criatura abierta, tu dibujo aterrizaba dentro
     * de la criatura. Y estaba en «importar», que es donde se busca cuando
     * quieres traer algo a un trabajo que ya existe, no cuando el trabajo ES
     * la imagen.
     *
     * Esto abre la imagen y ya: un documento de su tamaño, con ella dentro, y
     * apuntando de dónde salió para que guardar la devuelva a su sitio en vez
     * de pedirte una carpeta. Abrir un PNG, cambiar tres píxeles y guardar
     * tiene que ser eso y no un rodeo por un proyecto que no querías.
     */
    function abreImagen(ruta, cb) {
        if (ocupado) { _enCola = { que: "abrirImagen", ruta: ruta, cb: cb }; return }
        estado = "abriendo"
        exportador.dePng(ruta, (buf) => {
            estado = ""
            if (!buf) {
                falla("abrir", "no se puede leer " + ruta)
                if (cb) cb(false); _despacha(); return
            }
            const nombre = ruta.split("/").pop().replace(/\.[^.]+$/, "")
            S.Documento.nuevo({ nombre: nombre, ancho: buf.w, alto: buf.h })
            const celda = S.Documento.celdaActiva(true)
            P.vuelca(celda, buf, 0, 0)
            S.Documento.ponImagen(ruta)
            S.Documento.cambiaPixeles(null)
            S.Documento.limpio()
            S.Historial.limpia()
            ultimoMensaje = "abierta " + ruta
            hecho("abrir", ruta)
            if (cb) cb(true)
            _despacha()
        })
    }

    /**
     * La imagen, a un fichero que eliges tú, con su nombre.
     *
     * «Guardar como» era siempre un selector de CARPETA y siempre escribía un
     * proyecto: una carpeta con su json y un PNG por celda. Para lo que es una
     * imagen suelta eso no es guardar como, es convertirla en otra cosa. Aquí
     * se guarda como en cualquier editor de imágenes — eliges dónde, le pones
     * nombre, y sale un fichero.
     *
     * Y a partir de ahí el documento apunta ahí: el siguiente Ctrl+S va al
     * fichero nuevo y no al de antes, que es lo que hace cualquier programa y
     * lo que evita seguir escribiendo encima del original sin querer.
     */
    function guardaImagenEn(ruta, cb) {
        if (!S.Documento.abierto) { if (cb) cb(false); return }
        if (!ruta) { if (cb) cb(false); return }
        S.Documento.ponImagen(ruta)
        guardaImagen(cb)
    }

    /**
     * La imagen, de vuelta al fichero del que salió.
     *
     * Aplana lo que haya —capas, fotograma y cara actuales— porque un PNG no
     * sabe de capas: lo que se escribe es lo que ves.
     */
    function guardaImagen(cb) {
        const ruta = S.Documento.imagen
        if (!ruta) { falla("guardar", "esto no salió de una imagen"); if (cb) cb(false); return }
        if (ocupado) { _enCola = { que: "guardarImagen", cb: cb }; return }
        estado = "guardando"
        const buf = P.clonar(S.Documento.compuesto())
        exportador.escribe(ruta, buf, (bien) => {
            estado = ""
            if (!bien) { falla("guardar", "no se pudo escribir " + ruta); if (cb) cb(false); _despacha(); return }
            S.Documento.limpio()
            ultimoMensaje = "guardada " + ruta
            hecho("guardar", ruta)
            if (cb) cb(true)
            _despacha()
        })
    }

    function importaComoCapa(ruta, cb) {
        exportador.dePng(ruta, (buf) => {
            if (!buf) { falla("importar", "no se puede leer " + ruta); return }
            S.Historial.abreEstructura()
            if (!S.Documento.abierto)
                S.Documento.nuevo({ nombre: "importado", ancho: buf.w, alto: buf.h })
            const capa = S.Documento.añadeCapa(ruta.split("/").pop().replace(/\.png$/, ""))
            const celda = S.Documento.celda(capa.id, S.Documento.fotograma, S.Documento.orientacion, true)
            P.vuelca(celda, buf, 0, 0)
            S.Historial.cierraEstructura("importar")
            S.Documento.cambiaPixeles(null)
            hecho("importar", ruta)
            if (cb) cb(true)
        })
    }

    /**
     * Una hoja troceada en fotogramas y orientaciones.
     *
     * Sirve para retocar arte que ya existe —un rip, un boceto, una hoja que
     * hiciste en otro editor— sin volver a dibujarlo. La rejilla se dice
     * fuera: adivinarla de la imagen sale mal más veces de las que sale bien.
     */
    function importaHoja(ruta, cw, ch, comoOrientaciones, cb) {
        exportador.trocea(ruta, cw, ch, (celdas, cols, filas) => {
            if (!celdas) { falla("importar", "no se puede trocear " + ruta); return }
            const nombre = ruta.split("/").pop().replace(/\.png$/, "")
            S.Documento.nuevo({
                nombre: nombre, ancho: cw, alto: ch,
                fotogramas: cols,
                orientaciones: comoOrientaciones
                    ? Array.from({ length: filas }, (_, i) => "d" + i)
                    : ["u"]
            })
            const capa = S.Documento.capa(0)
            for (let f = 0; f < filas; f++) for (let c = 0; c < cols; c++) {
                const dr = comoOrientaciones ? f : 0
                if (!comoOrientaciones && f > 0) continue
                const celda = S.Documento.celda(capa.id, c, dr, true)
                P.vuelca(celda, celdas[f * cols + c], 0, 0)
            }
            S.Documento.cambiaPixeles(null)
            S.Historial.limpia()
            hecho("importar", cols + "×" + filas + " celdas de " + ruta)
            if (cb) cb(true)
        })
    }

    // ═══════════════════════════════════════════════════════════
    // comprobaciones del juego
    // ═══════════════════════════════════════════════════════════

    property var resultados: []

    /**
     * Lanza las comprobaciones que el pack declare y trae lo que digan.
     *
     * No se interpreta la salida: esos guiones ya están escritos para que los
     * lea una persona, y resumirlos sería perder justo la parte útil.
     */
    function comprueba(guiones, cb) {
        const base = raizPack()
        if (!base) { falla("comprobar", "este pack no apunta a ningún repositorio"); return }
        estado = "comprobando"
        S.Forja.pide("comprobar", { raiz: base, guiones: guiones }, (r) => {
            estado = ""
            resultados = r.bien ? r.resultados : []
            if (!r.bien) falla("comprobar", r.error)
            else hecho("comprobar", resultados.length + " comprobaciones")
            if (cb) cb(resultados)
        })
    }
}

pragma Singleton

//  Todo lo que el programa sabe hacer, en una lista.
//
//  No hay barra de menús. Hay esta lista, y tres formas de llegar a ella: la
//  paleta de comandos (Ctrl+K), la rueda del botón derecho y los atajos. Tener
//  UNA definición por orden es lo que hace que las tres estén siempre de
//  acuerdo — la alternativa es un menú, una rueda y una tabla de atajos que se
//  van separando hasta que un día "voltear" hace cosas distintas según por
//  dónde lo pidas.
//
//  `cuando` decide si la orden está disponible ahora. `hacer` la ejecuta. Nada
//  más: quien quiera enseñar una hoja emite `pideHoja` y que la vista decida,
//  porque un servicio no debería saber cómo es la interfaz.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "." as S

Singleton {
    id: ord

    signal pideHoja(string nombre)
    signal pideAviso(string texto)
    signal pideAjuste()

    readonly property bool hayDoc: S.Documento.abierto
    readonly property bool haySel: S.Seleccion.activa

    property var portapapeles: null      // un búfer, para copiar y pegar

    function _capa() { return S.Documento.capa(S.Documento.capaActiva) }
    function _buf() { return S.Documento.celdaActiva(true) }

    /** Envuelve un cambio de píxeles con su entrada en el historial. */
    function _conHistorial(nombre, fn) {
        const c = _capa()
        if (!c) return
        const b = _buf()
        if (!b) return
        S.Historial.abre(S.Documento.clave(c.id, S.Documento.fotograma, S.Documento.orientacion), b)
        fn(b)
        S.Historial.cierra(nombre, b)
        S.Documento.cambiaPixeles(null)
    }

    /** Igual para lo estructural, que se apunta entero. */
    function _conEstructura(nombre, fn) {
        S.Historial.abreEstructura()
        fn()
        S.Historial.cierraEstructura(nombre)
    }

    /** Sustituye la celda activa por otro búfer, del tamaño que sea. */
    function _reemplaza(nombre, nuevo) {
        _conHistorial(nombre, (b) => {
            for (let i = 0; i < b.d.length; i++) b.d[i] = 0
            P.vuelca(b, nuevo, 0, 0)
        })
    }

    // ═══════════════════════════════════════════════════════════
    // la lista
    // ═══════════════════════════════════════════════════════════

    readonly property var lista: [
        // ── fichero ─────────────────────────────────────────────
        { id: "nuevo", titulo: "Nuevo…", grupo: "fichero", icono: "nuevo", atajo: "Ctrl+N",
          hacer: () => ord.pideHoja("nuevo") },
        { id: "abrir", titulo: "Abrir…", grupo: "fichero", icono: "carpeta", atajo: "Ctrl+O",
          hacer: () => ord.pideHoja("abrir") },
        { id: "guardar", titulo: "Guardar", grupo: "fichero", icono: "guardar", atajo: "Ctrl+S",
          cuando: () => ord.hayDoc,
          hacer: () => S.Documento.ruta ? S.Proyecto.guarda(null, null) : ord.pideHoja("guardarComo") },
        { id: "guardarComo", titulo: "Guardar como…", grupo: "fichero", icono: "guardar",
          atajo: "Ctrl+Shift+S", cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("guardarComo") },
        { id: "exportar", titulo: "Exportar según el contrato", grupo: "fichero", icono: "exportar",
          atajo: "Ctrl+E", cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("exportar") },
        { id: "exportarGif", titulo: "Exportar GIF", grupo: "fichero", icono: "gif",
          cuando: () => ord.hayDoc && S.Documento.nFotogramas > 1,
          hacer: () => ord.pideHoja("exportarAnim") },
        { id: "importar", titulo: "Importar imagen…", grupo: "fichero", icono: "importar",
          hacer: () => ord.pideHoja("importar") },
        { id: "cerrar", titulo: "Cerrar", grupo: "fichero", icono: "cerrar", cuando: () => ord.hayDoc,
          hacer: () => { S.Documento.cerrar(); S.Historial.limpia() } },

        // ── editar ──────────────────────────────────────────────
        { id: "deshacer", titulo: "Deshacer", grupo: "editar", icono: "undo", atajo: "Ctrl+Z",
          cuando: () => S.Historial.puedeDeshacer, hacer: () => S.Historial.deshace() },
        { id: "rehacer", titulo: "Rehacer", grupo: "editar", icono: "redo", atajo: "Ctrl+Shift+Z",
          cuando: () => S.Historial.puedeRehacer, hacer: () => S.Historial.rehace() },
        { id: "copiar", titulo: "Copiar", grupo: "editar", icono: "copiar", atajo: "Ctrl+C",
          cuando: () => ord.hayDoc, hacer: () => {
              const b = ord._buf(); if (!b) return
              const l = S.Seleccion.limites || { x: 0, y: 0, w: b.w, h: b.h }
              const r = P.recorte(b, l.x, l.y, l.w, l.h)
              if (S.Seleccion.activa)
                  for (let y = 0; y < l.h; y++) for (let x = 0; x < l.w; x++)
                      if (!S.Seleccion.contiene(l.x + x, l.y + y)) P.pon(r, x, y, [0,0,0,0])
              ord.portapapeles = r
              ord.pideAviso("copiado " + r.w + "×" + r.h)
          } },
        { id: "cortar", titulo: "Cortar", grupo: "editar", icono: "basura", atajo: "Ctrl+X",
          cuando: () => ord.hayDoc, hacer: () => { ord.ejecuta("copiar"); ord.ejecuta("borrar") } },
        { id: "pegar", titulo: "Pegar", grupo: "editar", atajo: "Ctrl+V",
          cuando: () => ord.hayDoc && ord.portapapeles !== null,
          hacer: () => {
              const l = S.Seleccion.limites
              _conHistorial("pegar", (b) => P.vuelca(b, ord.portapapeles, l ? l.x : 0, l ? l.y : 0))
          } },
        { id: "borrar", titulo: "Borrar", grupo: "editar", atajo: "Del", cuando: () => ord.hayDoc,
          hacer: () => _conHistorial("borrar", (b) => {
              for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++)
                  if (S.Seleccion.contiene(x, y)) P.pon(b, x, y, [0, 0, 0, 0])
          }) },
        { id: "rellenar", titulo: "Rellenar con el primario", grupo: "editar", atajo: "Ctrl+Backspace",
          cuando: () => ord.hayDoc,
          hacer: () => _conHistorial("rellenar", (b) => {
              for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++)
                  if (S.Seleccion.contiene(x, y)) P.mezcla(b, x, y, S.Paleta.primario,
                                                           ord._capa().alfaBloqueado)
          }) },

        // ── selección ───────────────────────────────────────────
        { id: "selTodo", titulo: "Seleccionar todo", grupo: "selección", atajo: "Ctrl+A",
          cuando: () => ord.hayDoc,
          hacer: () => S.Seleccion.todo(S.Documento.ancho, S.Documento.alto) },
        { id: "selNada", titulo: "Quitar la selección", grupo: "selección", atajo: "Ctrl+D",
          cuando: () => ord.haySel, hacer: () => S.Seleccion.nada() },
        { id: "selInvertir", titulo: "Invertir la selección", grupo: "selección", atajo: "Ctrl+I",
          cuando: () => ord.haySel, hacer: () => S.Seleccion.invierte() },
        { id: "selDeAlfa", titulo: "Seleccionar la silueta de la capa", grupo: "selección",
          cuando: () => ord.hayDoc, hacer: () => {
              const b = ord._buf(); if (!b) return
              S.Seleccion.pon(P.porAlfa(b), b.w, b.h, S.Pinceles.modoSeleccion)
          } },
        { id: "selCrecer", titulo: "Crecer la selección", grupo: "selección",
          cuando: () => ord.haySel, hacer: () => S.Seleccion.dilata(1) },
        { id: "selEncoger", titulo: "Encoger la selección", grupo: "selección",
          cuando: () => ord.haySel, hacer: () => S.Seleccion.dilata(-1) },
        { id: "pincelDeSeleccion", titulo: "Hacer un pincel de la selección", grupo: "selección",
          cuando: () => ord.haySel, hacer: () => {
              const b = ord._buf(), l = S.Seleccion.limites
              if (!b || !l) return
              const r = P.recorte(b, l.x, l.y, l.w, l.h)
              for (let y = 0; y < l.h; y++) for (let x = 0; x < l.w; x++)
                  if (!S.Seleccion.contiene(l.x + x, l.y + y)) P.pon(r, x, y, [0,0,0,0])
              S.Pinceles.pincelPersonal = r
              S.Pinceles.elige("lapiz")
              ord.pideAviso("pincel de " + r.w + "×" + r.h)
          } },
        { id: "pincelNormal", titulo: "Volver al pincel normal", grupo: "selección",
          cuando: () => S.Pinceles.pincelPersonal !== null,
          hacer: () => S.Pinceles.pincelPersonal = null },

        // ── transformar ─────────────────────────────────────────
        { id: "voltearH", titulo: "Voltear en horizontal", grupo: "transformar", icono: "espejo",
          atajo: "Shift+H", cuando: () => ord.hayDoc,
          hacer: () => _reemplaza("voltear", P.volteaH(ord._buf())) },
        { id: "voltearV", titulo: "Voltear en vertical", grupo: "transformar", icono: "espejoV",
          atajo: "Shift+V", cuando: () => ord.hayDoc,
          hacer: () => _reemplaza("voltear", P.volteaV(ord._buf())) },
        { id: "girar90", titulo: "Girar 90°", grupo: "transformar", icono: "girar",
          cuando: () => ord.hayDoc && S.Documento.ancho === S.Documento.alto,
          hacer: () => _reemplaza("girar", P.gira90(ord._buf(), 1)) },
        { id: "girar180", titulo: "Girar 180°", grupo: "transformar", icono: "girar",
          cuando: () => ord.hayDoc, hacer: () => _reemplaza("girar", P.gira90(ord._buf(), 2)) },
        { id: "desplazar", titulo: "Desplazar envolviendo…", grupo: "transformar",
          cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("desplazar") },
        { id: "redimensionar", titulo: "Tamaño del lienzo…", grupo: "transformar", icono: "escalar",
          cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("lienzo") },
        { id: "escalar", titulo: "Escalar el dibujo…", grupo: "transformar", icono: "escalar",
          cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("escalar") },
        { id: "recortar", titulo: "Recortar a lo dibujado", grupo: "transformar", icono: "recortar",
          cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("recortar", () => S.Documento.recortaAlContenido()) },
        { id: "contornear", titulo: "Contornear la silueta", grupo: "transformar", icono: "contorno",
          cuando: () => ord.hayDoc,
          hacer: () => _reemplaza("contornear",
                      P.contornea(ord._buf(), S.Paleta.primario, false, "fuera")) },

        // ── capas ───────────────────────────────────────────────
        { id: "capaNueva", titulo: "Capa nueva", grupo: "capas", icono: "mas", atajo: "Ctrl+Shift+N",
          cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("capa nueva", () => S.Documento.añadeCapa()) },
        { id: "capaDuplicar", titulo: "Duplicar la capa", grupo: "capas", icono: "duplicar",
          cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("duplicar capa",
                       () => S.Documento.duplicaCapa(S.Documento.capaActiva)) },
        { id: "capaBorrar", titulo: "Borrar la capa", grupo: "capas", icono: "basura",
          cuando: () => ord.hayDoc && S.Documento.nCapas > 1,
          hacer: () => _conEstructura("borrar capa",
                       () => S.Documento.borraCapa(S.Documento.capaActiva)) },
        { id: "capaFusionar", titulo: "Fusionar con la de abajo", grupo: "capas", icono: "fusion",
          atajo: "Ctrl+M", cuando: () => ord.hayDoc && S.Documento.capaActiva > 0,
          hacer: () => _conEstructura("fusionar",
                       () => S.Documento.fusionaAbajo(S.Documento.capaActiva)) },
        { id: "capaAplanar", titulo: "Aplanar todo", grupo: "capas", icono: "aplanar",
          cuando: () => ord.hayDoc && S.Documento.nCapas > 1,
          hacer: () => _conEstructura("aplanar", () => S.Documento.aplana()) },
        { id: "capaAgrupar", titulo: "Agrupar la capa", grupo: "capas", icono: "carpeta",
          atajo: "Ctrl+G", cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("agrupar",
                       () => S.Documento.agrupa(S.Documento.capaActiva)) },
        { id: "capaDesagrupar", titulo: "Sacar la capa de su grupo", grupo: "capas",
          cuando: () => ord.hayDoc && !!(ord._capa() && ord._capa().grupo),
          hacer: () => _conEstructura("desagrupar",
                       () => S.Documento.desagrupa(S.Documento.capaActiva)) },
        { id: "capaGrupoNuevo", titulo: "Grupo vacío", grupo: "capas", icono: "carpeta",
          cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("grupo nuevo",
                       () => S.Documento.añadeCapa("grupo", "grupo")) },
        { id: "capaReferencia", titulo: "Capa de referencia (para calcar)", grupo: "capas",
          icono: "referencia", cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("capa de referencia", () => {
              const c = S.Documento.añadeCapa("referencia", "referencia")
              c.opacidad = 0.4; c.bloqueada = true
          }) },

        // ── animación ───────────────────────────────────────────
        { id: "fotogramaNuevo", titulo: "Fotograma nuevo", grupo: "animación", icono: "mas",
          atajo: "Alt+N", cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("fotograma nuevo", () => S.Documento.añadeFotograma(false)) },
        { id: "fotogramaCopia", titulo: "Duplicar el fotograma", grupo: "animación", icono: "duplicar",
          atajo: "Alt+D", cuando: () => ord.hayDoc,
          hacer: () => _conEstructura("duplicar fotograma", () => S.Documento.añadeFotograma(true)) },
        { id: "fotogramaBorrar", titulo: "Borrar el fotograma", grupo: "animación", icono: "basura",
          cuando: () => ord.hayDoc && S.Documento.nFotogramas > 1,
          hacer: () => _conEstructura("borrar fotograma",
                       () => S.Documento.borraFotograma(S.Documento.fotograma)) },
        { id: "celdaEnlazar", titulo: "Enlazar con el fotograma anterior", grupo: "animación",
          icono: "enlace", cuando: () => ord.hayDoc && S.Documento.fotograma > 0,
          hacer: () => _conEstructura("enlazar celda", () => S.Documento.enlaza(
                       ord._capa().id, S.Documento.fotograma, S.Documento.orientacion,
                       S.Documento.fotograma - 1, S.Documento.orientacion)) },
        { id: "celdaDesenlazar", titulo: "Desenlazar la celda", grupo: "animación", icono: "enlaceNo",
          cuando: () => ord.hayDoc && ord._capa()
                     && S.Documento.estaEnlazada(ord._capa().id, S.Documento.fotograma,
                                                 S.Documento.orientacion),
          hacer: () => _conEstructura("desenlazar", () => S.Documento.desenlaza(
                       ord._capa().id, S.Documento.fotograma, S.Documento.orientacion)) },
        { id: "reproducir", titulo: "Reproducir / parar", grupo: "animación", icono: "play",
          atajo: "Espacio", cuando: () => ord.hayDoc && S.Documento.nFotogramas > 1,
          hacer: () => S.Animacion.alterna() },
        { id: "etiqueta", titulo: "Etiquetar estos fotogramas…", grupo: "animación",
          cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("etiqueta") },
        { id: "cebolla", titulo: "Piel de cebolla", grupo: "animación", icono: "cebolla", atajo: "C",
          cuando: () => ord.hayDoc, hacer: () => S.Ajustes.cebolla = !S.Ajustes.cebolla },

        // ── orientaciones ───────────────────────────────────────
        { id: "orientaciones", titulo: "Orientaciones…", grupo: "orientaciones", icono: "compas",
          cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("orientaciones") },
        { id: "espejoOrientacion", titulo: "Generar esta orientación volteando su pareja",
          grupo: "orientaciones", icono: "espejo",
          cuando: () => ord.hayDoc && ord.parejaEspejo() >= 0,
          hacer: () => ord.aplicaEspejo() },
        { id: "orientacionSiguiente", titulo: "Orientación siguiente", grupo: "orientaciones",
          atajo: "Tab", cuando: () => ord.hayDoc && S.Documento.nOrientaciones > 1,
          hacer: () => S.Documento.orientacion =
                       (S.Documento.orientacion + 1) % S.Documento.nOrientaciones },

        // ── color ───────────────────────────────────────────────
        { id: "intercambiar", titulo: "Intercambiar los dos colores", grupo: "color", atajo: "X",
          hacer: () => S.Paleta.intercambia() },
        { id: "paletaDelDibujo", titulo: "Sacar la paleta del dibujo", grupo: "color", icono: "paleta",
          cuando: () => ord.hayDoc,
          hacer: () => {
              const n = S.Paleta.desdeBufer(S.Documento.compuesto(), 24)
              ord.pideAviso(n + " colores extraídos")
          } },
        { id: "cuantizar", titulo: "Cuantizar a la paleta…", grupo: "color",
          cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("cuantizar") },
        { id: "paletaAbrir", titulo: "Cargar una paleta…", grupo: "color",
          hacer: () => ord.pideHoja("paletaAbrir") },
        { id: "paletaGuardar", titulo: "Guardar la paleta…", grupo: "color",
          hacer: () => ord.pideHoja("paletaGuardar") },

        // ── vista ───────────────────────────────────────────────
        { id: "ajustarZoom", titulo: "Encajar en la ventana", grupo: "vista", atajo: "Ctrl+0",
          cuando: () => ord.hayDoc, hacer: () => ord.pideAjuste() },
        { id: "zoomMas", titulo: "Acercar", grupo: "vista", atajo: "+",
          hacer: () => S.Ajustes.zoom = Math.min(64, S.Ajustes.zoom < 1 ? 1 : S.Ajustes.zoom + 1) },
        { id: "zoomMenos", titulo: "Alejar", grupo: "vista", atajo: "-",
          hacer: () => S.Ajustes.zoom = Math.max(0.25, S.Ajustes.zoom <= 1 ? S.Ajustes.zoom / 2
                                                                           : S.Ajustes.zoom - 1) },
        { id: "rejilla", titulo: "Rejilla de píxel", grupo: "vista", icono: "rejilla", atajo: "Ctrl+'",
          hacer: () => S.Ajustes.rejillaPixel = !S.Ajustes.rejillaPixel },
        { id: "rejillaCasilla", titulo: "Rejilla de casilla", grupo: "vista", icono: "rejilla",
          hacer: () => S.Ajustes.rejillaCasilla = !S.Ajustes.rejillaCasilla },
        { id: "modoBaldosa", titulo: "Modo baldosa (el lienzo envuelve)", grupo: "vista",
          icono: "baldosa", cuando: () => ord.hayDoc,
          hacer: () => S.Ajustes.modoBaldosa = !S.Ajustes.modoBaldosa },
        { id: "simetriaH", titulo: "Simetría horizontal", grupo: "vista", icono: "simetria",
          hacer: () => S.Ajustes.simetriaH = !S.Ajustes.simetriaH },
        { id: "simetriaV", titulo: "Simetría vertical", grupo: "vista", icono: "simetria",
          hacer: () => S.Ajustes.simetriaV = !S.Ajustes.simetriaV },
        { id: "medidas", titulo: "Medidas de silueta", grupo: "vista", icono: "medidas",
          cuando: () => ord.hayDoc,
          hacer: () => S.Ajustes.medidasSilueta = !S.Ajustes.medidasSilueta },
        { id: "previa", titulo: "Previa en juego", grupo: "vista", icono: "juego",
          cuando: () => ord.hayDoc, hacer: () => S.Ajustes.panelPrevia = !S.Ajustes.panelPrevia },
        { id: "historial", titulo: "Historial", grupo: "vista", icono: "historial",
          hacer: () => S.Ajustes.panelHistorial = !S.Ajustes.panelHistorial },
        { id: "tema", titulo: "Cambiar a claro / oscuro", grupo: "vista",
          hacer: () => ord.pideTema() },

        // ── guiones ─────────────────────────────────────────────
        { id: "guiones", titulo: "Guiones…", grupo: "guiones", icono: "engranaje",
          atajo: "Ctrl+J", cuando: () => ord.hayDoc, hacer: () => ord.pideHoja("guiones") },

        // ── pack ────────────────────────────────────────────────
        { id: "pack", titulo: "Cambiar de pack…", grupo: "pack", icono: "engranaje",
          hacer: () => ord.pideHoja("pack") },
        { id: "comprobar", titulo: "Lanzar las comprobaciones del juego", grupo: "pack",
          icono: "ok", cuando: () => S.Packs.raiz !== "",
          hacer: () => ord.pideHoja("comprobar") },
        { id: "abrirCarpeta", titulo: "Abrir la carpeta del proyecto", grupo: "pack",
          icono: "carpeta", cuando: () => S.Documento.ruta !== "",
          hacer: () => S.Forja.abre(S.Documento.ruta) }
    ]

    signal pideTema()

    // ═══════════════════════════════════════════════════════════
    // usarla
    // ═══════════════════════════════════════════════════════════

    function orden(id) {
        for (let i = 0; i < lista.length; i++) if (lista[i].id === id) return lista[i]
        return null
    }

    function disponible(o) { return !o.cuando || o.cuando() }

    function ejecuta(id) {
        const o = orden(id)
        if (!o) { console.warn("orden desconocida: " + id); return false }
        if (!disponible(o)) return false
        o.hacer()
        return true
    }

    /**
     * Buscar por trozos sueltos, no por prefijo.
     *
     * "vol h" tiene que encontrar "Voltear en horizontal". Buscar por prefijo
     * obliga a recordar cómo empieza el nombre, que es justo lo que la paleta
     * de comandos viene a evitar.
     */
    function busca(texto) {
        const t = (texto || "").toLowerCase().trim()
        const trozos = t.split(/\s+/).filter((x) => x.length)
        const out = []
        for (let i = 0; i < lista.length; i++) {
            const o = lista[i]
            if (!disponible(o)) continue
            const heno = (o.titulo + " " + o.grupo + " " + o.id).toLowerCase()
            let vale = true, puntos = 0
            for (let j = 0; j < trozos.length; j++) {
                const k = heno.indexOf(trozos[j])
                if (k < 0) { vale = false; break }
                puntos += k === 0 ? 0 : k
            }
            if (vale) out.push({ orden: o, puntos: puntos })
        }
        out.sort((a, b) => a.puntos - b.puntos)
        return out.map((x) => x.orden)
    }

    // ═══════════════════════════════════════════════════════════
    // el espejo entre orientaciones
    // ═══════════════════════════════════════════════════════════

    /**
     * Qué orientación es la pareja volteada de la actual.
     *
     * Es la mitad del trabajo de cualquier hoja con caras: dibujas el este y
     * el oeste sale solo. El contrato dice qué pareja con qué; si no lo dice,
     * no hay espejo y esta orden no aparece.
     */
    function parejaEspejo() {
        const d = S.Documento.d
        if (!d || !d.contrato || !d.contrato.espejo) return -1
        const yo = S.Documento.etiquetaOrientacion(S.Documento.orientacion)
        const esp = d.contrato.espejo
        const claves = Object.keys(esp)
        for (let i = 0; i < claves.length; i++) {
            if (esp[claves[i]] === yo) return d.orientaciones.indexOf(claves[i])
            if (claves[i] === yo) return d.orientaciones.indexOf(esp[claves[i]])
        }
        return -1
    }

    function aplicaEspejo() {
        const otra = parejaEspejo()
        if (otra < 0) return
        const c = _capa()
        if (!c) return
        _conEstructura("espejo de orientación", () => {
            for (let f = 0; f < S.Documento.nFotogramas; f++) {
                const origen = S.Documento.celda(c.id, f, otra, false)
                if (!origen) continue
                S.Documento.ponCelda(S.Documento.clave(c.id, f, S.Documento.orientacion),
                                     P.volteaH(origen))
            }
        })
        S.Documento.cambiaPixeles(null)
        pideAviso("orientación generada desde " + S.Documento.etiquetaOrientacion(otra))
    }
}

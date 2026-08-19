pragma Singleton

//  El único sitio del programa que lanza procesos.
//
//  Igual que en k4: la máquina de estados vive en QML y el trabajo sucio en
//  Python. Aquí sólo está la tubería —una petición JSON por línea, una
//  respuesta por línea, emparejadas por `id`— y el que pide dice qué hacer con
//  la respuesta en una función. Las respuestas no tienen por qué llegar en
//  orden, y por eso hay id y no una cola.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: forja

    property bool viva: false
    property bool hayPillow: false
    property string ultimoError: ""
    signal lista()
    signal fallo(string mensaje)

    readonly property string guion: {
        const u = Qt.resolvedUrl("../forja/forja.py").toString()
        return u.indexOf("file://") === 0 ? u.substring(7) : u
    }

    property int _siguiente: 1
    property var _pendientes: ({})

    Process {
        id: proc
        running: true
        command: ["python3", "-u", forja.guion]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: (linea) => {
                let r
                try { r = JSON.parse(linea) }
                catch (e) { console.warn("forja: línea ilegible: " + linea); return }
                const cb = forja._pendientes[r.id]
                delete forja._pendientes[r.id]
                if (!r.bien) {
                    forja.ultimoError = r.error || "error sin nombre"
                    forja.fallo(forja.ultimoError)
                }
                if (cb) cb(r)
            }
        }

        stderr: SplitParser {
            onRead: (linea) => console.warn("forja: " + linea)
        }

        onRunningChanged: {
            forja.viva = running
            if (running) forja.pide("ping", {}, (r) => {
                forja.hayPillow = !!r.pil
                forja.lista()
            })
        }
        onExited: (codigo) => {
            forja.viva = false
            if (codigo !== 0) forja.fallo("la forja se ha caído (código " + codigo + ")")
        }
    }

    /**
     * Manda una orden. `cb` recibe la respuesta entera, con `bien` y `error`
     * si lo hubo — quien pide decide qué hacer con un fallo, porque un fallo
     * al guardar y un fallo al listar una carpeta no se parecen en nada.
     */
    function pide(orden, datos, cb) {
        if (!proc.running) { if (cb) cb({ bien: false, error: "la forja no está viva" }); return -1 }
        const id = _siguiente++
        const p = datos ? JSON.parse(JSON.stringify(datos)) : {}
        p.id = id
        p.orden = orden
        if (cb) _pendientes[id] = cb
        proc.write(JSON.stringify(p) + "\n")
        return id
    }

    // ── atajos de los de siempre ─────────────────────────────────
    function escribePng(ruta, dataUrl, cb) { pide("escribir", { ruta: ruta, datos: dataUrl }, cb) }
    function escribeTexto(ruta, texto, cb)  { pide("escribirTexto", { ruta: ruta, texto: texto }, cb) }
    function leeTexto(ruta, cb)             { pide("leerTexto", { ruta: ruta }, cb) }
    function creaCarpeta(ruta, cb)          { pide("carpeta", { ruta: ruta }, cb) }
    function lista_(ruta, patron, cb)       { pide("listar", { ruta: ruta, patron: patron }, cb) }
    /** Borra de una carpeta lo que no esté en `conservar`. Ver `orden_podar`. */
    function poda(ruta, patron, conservar, cb) {
        pide("podar", { ruta: ruta, patron: patron, conservar: conservar }, cb)
    }
    function abre(ruta)                     { pide("abrir", { ruta: ruta }, null) }
}

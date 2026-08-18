pragma Singleton

//  Los packs.
//
//  Un pack es lo que sabe pinza sobre un juego concreto: sus paletas, sus
//  perfiles de asset, dónde van los ficheros y cómo se llaman. crabh es UNO de
//  ellos, no el cimiento — el pack «genérico» no impone nada y es el que sale
//  por defecto, así que esto sirve igual para el juego siguiente.
//
//  Los tuyos van en ~/.config/pinza/packs/*.json y ganan si repiten id, que es
//  la forma de retocar un pack de serie sin tocar el repositorio.

import QtQuick
import Quickshell
import "." as S

Singleton {
    id: packs

    property var lista: []
    property bool cargados: false
    signal cargadosCambiaron()

    property string activoId: "generico"
    readonly property var activo: {
        cargados
        for (let i = 0; i < lista.length; i++) if (lista[i].id === activoId) return lista[i]
        return lista.length ? lista[0] : null
    }

    readonly property var contratos: activo ? activo.contratos : []
    readonly property var paletas: activo ? (activo.paletas || []) : []
    readonly property var guia: activo ? (activo.guia || null) : null
    //  La raíz efectiva: la que tú hayas apuntado gana sobre la del pack,
    //  porque el pack se comparte y la ruta a tu copia del juego no.
    property int revRaiz: 0
    readonly property string raiz: {
        revRaiz
        const mia = S.Ajustes.raices ? S.Ajustes.raices[activoId] : ""
        if (mia) return mia
        return activo && activo.raiz ? activo.raiz : ""
    }

    function apunta(id, ruta) {
        const m = {}
        const k = Object.keys(S.Ajustes.raices || {})
        for (let i = 0; i < k.length; i++) m[k[i]] = S.Ajustes.raices[k[i]]
        m[id] = ruta
        S.Ajustes.raices = m
        revRaiz++
    }

    function contrato(id) {
        const c = contratos
        for (let i = 0; i < c.length; i++) if (c[i].id === id) return c[i]
        return null
    }

    function carga() {
        S.Forja.pide("packs", {}, (r) => {
            if (!r.bien) { console.warn("no se han podido leer los packs: " + r.error); return }
            const l = r.packs.slice()
            l.sort((a, b) => a.id === "generico" ? -1 : b.id === "generico" ? 1
                             : a.titulo.localeCompare(b.titulo))
            lista = l
            cargados = true
            elige(S.Ajustes.pack || "generico")
            cargadosCambiaron()
        })
    }

    function elige(id) {
        activoId = id
        S.Ajustes.pack = id
        // la paleta del pack pasa a ser la de trabajo, y su guía la del medidor
        if (activo && activo.paletas && activo.paletas.length)
            S.Paleta.cargaRampas(activo.paletas[0].rampas)
        S.Paleta.guia = activo ? (activo.guia || null) : null
    }

    /**
     * Un contrato listo para abrir un documento.
     *
     * Devuelve lo que `Documento.nuevo` necesita: las orientaciones ya
     * convertidas en la lista de etiquetas que el documento guarda, que es lo
     * que hace que el editor nunca tenga que adivinar cuál es la fila 0.
     */
    function paraDocumento(c, extra) {
        const o = (c.orientaciones || [{ id: "u" }]).map((x) => x.id)
        return {
            nombre: (extra && extra.nombre) || "sin nombre",
            ancho: (extra && extra.ancho) || c.ancho,
            alto: (extra && extra.alto) || c.alto,
            orientaciones: (extra && extra.orientaciones) || o,
            fotogramas: (extra && extra.fotogramas) || c.fotogramas || 1,
            duracion: c.duracion || 6,
            pack: activoId,
            contrato: JSON.parse(JSON.stringify(c)),
            baldosa: c.baldosa ? { ancho: c.ancho, alto: c.alto } : null
        }
    }

    /** La flecha y el nombre de una orientación, para el compás. */
    function orientacion(c, id) {
        if (!c || !c.orientaciones) return { id: id, titulo: id, flecha: "·" }
        for (let i = 0; i < c.orientaciones.length; i++)
            if (c.orientaciones[i].id === id) return c.orientaciones[i]
        return { id: id, titulo: id, flecha: "·" }
    }

    /** ¿Esta orientación se genera volteando otra? */
    function espejoDe(c, id) {
        if (!c || !c.espejo) return null
        const k = Object.keys(c.espejo)
        for (let i = 0; i < k.length; i++) {
            if (c.espejo[k[i]] === id) return k[i]     // id se saca de k[i]
        }
        return null
    }

    Component.onCompleted: {
        if (S.Forja.viva) carga()
        else S.Forja.lista.connect(carga)
    }
}

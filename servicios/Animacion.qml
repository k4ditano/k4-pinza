pragma Singleton

//  La reproducción.
//
//  El tiempo se cuenta en TICS de 1/60 s y no en milisegundos. No es capricho:
//  es la unidad en la que están escritas las duraciones de PMD, la que se
//  guarda en AnimData.xml y la que se ve en la tira. Tener una sola unidad en
//  todo el programa evita la clase de fallo en la que una animación va bien en
//  el editor y a destiempo en el juego.

import QtQuick
import Quickshell
import "." as S

Singleton {
    id: anim

    property bool sonando: false
    property real tic: 0                  // posición dentro del ciclo, en tics
    property bool bucle: true
    property string modo: "ida"           // ida · vuelta · vaiven
    property bool soloEtiqueta: true      // quedarse dentro de la etiqueta actual
    property real velocidad: 1.0
    property int _sentido: 1

    readonly property int desde: {
        const e = soloEtiqueta ? S.Documento.etiquetaDe(S.Documento.fotograma) : null
        return e ? e.desde : 0
    }
    readonly property int hasta: {
        const e = soloEtiqueta ? S.Documento.etiquetaDe(S.Documento.fotograma) : null
        return e ? e.hasta : Math.max(0, S.Documento.nFotogramas - 1)
    }

    readonly property int ticsDelTramo: {
        S.Documento.rev
        let t = 0
        for (let f = desde; f <= hasta; f++) t += S.Documento.duracion(f)
        return Math.max(1, t)
    }

    /** Los segundos que dura lo que se está reproduciendo. */
    readonly property real segundos: ticsDelTramo / 60

    function arranca() { if (S.Documento.nFotogramas > 1) { sonando = true; _sentido = 1 } }
    function para()    { sonando = false }
    function alterna() { sonando ? para() : arranca() }

    function vaA(f) {
        S.Documento.fotograma = Math.max(0, Math.min(f, S.Documento.nFotogramas - 1))
        tic = 0
    }
    function siguiente() { vaA(S.Documento.fotograma + 1 > hasta ? desde : S.Documento.fotograma + 1) }
    function anterior()  { vaA(S.Documento.fotograma - 1 < desde ? hasta : S.Documento.fotograma - 1) }

    // 60 Hz clavados: un tic por pulso, que es como lo cuenta el juego.
    Timer {
        interval: 16
        repeat: true
        running: anim.sonando && S.Documento.nFotogramas > 1
        onTriggered: {
            anim.tic += anim.velocidad
            const dur = S.Documento.duracion(S.Documento.fotograma)
            if (anim.tic < dur) return
            anim.tic -= dur

            const m = anim.soloEtiqueta
                    ? (S.Documento.etiquetaDe(S.Documento.fotograma) || { modo: anim.modo }).modo
                    : anim.modo
            let f = S.Documento.fotograma

            if (m === "vaiven") {
                f += anim._sentido
                if (f > anim.hasta) { f = Math.max(anim.desde, anim.hasta - 1); anim._sentido = -1 }
                else if (f < anim.desde) { f = Math.min(anim.hasta, anim.desde + 1); anim._sentido = 1 }
            } else if (m === "vuelta") {
                f--
                if (f < anim.desde) { if (!anim.bucle) { anim.para(); return } f = anim.hasta }
            } else {
                f++
                if (f > anim.hasta) { if (!anim.bucle) { anim.para(); return } f = anim.desde }
            }
            S.Documento.fotograma = f
        }
    }
}

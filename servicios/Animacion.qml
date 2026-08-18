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

    function arranca() {
        if (S.Documento.nFotogramas <= 1) return
        _ultimoMs = Date.now()
        _sentido = 1
        sonando = true
    }
    function para()    { sonando = false }
    function alterna() { sonando ? para() : arranca() }

    function vaA(f) {
        S.Documento.fotograma = Math.max(0, Math.min(f, S.Documento.nFotogramas - 1))
        tic = 0
    }
    function siguiente() { vaA(S.Documento.fotograma + 1 > hasta ? desde : S.Documento.fotograma + 1) }
    function anterior()  { vaA(S.Documento.fotograma - 1 < desde ? hasta : S.Documento.fotograma - 1) }

    // ═══════════════════════════════════════════════════════════
    // el reloj
    // ═══════════════════════════════════════════════════════════
    //
    //  Manda el RELOJ DE PARED, no el temporizador. Antes cada disparo
    //  avanzaba un tic exacto, así que la animación iba a la velocidad a la que
    //  Qt lograra disparar: medido, un 38 % lenta —cada repintado que se pasaba
    //  de presupuesto se comía un tic para siempre—. Y como el sentido de todo
    //  esto es que lo que ves aquí sea lo que se ve en el juego, ir lento no es
    //  un defecto de acabado: es que la herramienta miente.

    property real _ultimoMs: 0

    function _avanzaUno() {
        const m = soloEtiqueta
                ? (S.Documento.etiquetaDe(S.Documento.fotograma) || { modo: modo }).modo
                : modo
        let f = S.Documento.fotograma

        if (m === "vaiven") {
            f += _sentido
            if (f > hasta) { f = Math.max(desde, hasta - 1); _sentido = -1 }
            else if (f < desde) { f = Math.min(hasta, desde + 1); _sentido = 1 }
        } else if (m === "vuelta") {
            f--
            if (f < desde) { if (!bucle) { para(); return } f = hasta }
        } else {
            f++
            if (f > hasta) { if (!bucle) { para(); return } f = desde }
        }
        S.Documento.fotograma = f
    }

    Timer {
        //  Se consulta más a menudo de lo que hace falta a propósito: el reloj
        //  decide cuánto ha pasado, así que disparar de más no acelera nada —
        //  sólo afina cuándo se nota el cambio.
        interval: 8
        repeat: true
        running: anim.sonando && S.Documento.nFotogramas > 1

        onTriggered: {
            const ahora = Date.now()
            let dt = ahora - anim._ultimoMs
            anim._ultimoMs = ahora

            //  Un parón largo —la ventana tapada, un guardado, el portátil
            //  dormido— no debe provocar un acelerón para recuperarlo todo.
            //  Se RECORTA, no se tira: la primera versión lo descartaba y
            //  contaba el hueco como dieciséis milisegundos, y como un
            //  repintado pesado se pasa de largo de esa cuenta, la animación
            //  perdía casi la mitad del tiempo real y salía un 39 % lenta.
            //  Sólo se descarta un hueco absurdo —el ordenador dormido, la
            //  sesión bloqueada—. Todo lo demás se cuenta entero: un parón de
            //  medio segundo por un guardado o un repintado gordo es tiempo
            //  que pasó de verdad, y descontarlo era lo que hacía que la
            //  animación fuera lenta sin que nada lo explicara.
            if (dt < 0 || dt > 3000) dt = 16

            anim.tic += (dt * 60 / 1000) * anim.velocidad

            //  Y si se han acumulado varios fotogramas, se saltan de golpe:
            //  con duraciones de dos o tres tics, un repintado lento se comería
            //  fotogramas enteros y la animación iría a trompicones.
            let vueltas = 0
            while (anim.sonando && vueltas++ < 64) {
                const dur = S.Documento.duracion(S.Documento.fotograma)
                if (anim.tic < dur) break
                anim.tic -= dur
                anim._avanzaUno()
            }
        }
    }
}

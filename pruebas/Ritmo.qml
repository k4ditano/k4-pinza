//  Que la animación vaya al ritmo que dice ir.
//
//  Todo el programa cuenta el tiempo en tics de 1/60 s porque es la unidad que
//  guarda AnimData.xml y la que lee el juego. Si la reproducción del editor va
//  a otra velocidad, la herramienta miente en lo único para lo que existe: ver
//  cómo va a quedar. Medido antes de arreglarlo, iba un 39 % LENTA — cada
//  repintado que se pasaba de presupuesto se comía tiempo real para siempre.
//
//  La prueba monta una escena como la de verdad —lienzo, compás y muestra
//  mirando, ocho orientaciones, un sprite que no es un punto— y cuenta cuántos
//  fotogramas pasan en cuatro segundos de reloj.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    property real t0: 0
    property int vueltas: 0
    property int ultimoF: 0

    FloatingWindow {
        implicitWidth: 700; implicitHeight: 500; visible: true
        V.Exportador { id: ex }
        V.Lienzo { id: l; anchors.fill: parent }
        V.Compas { parent: l; anchors.right: l.right; anchors.bottom: l.bottom }
        V.Muestra { parent: l }
        Component.onCompleted: { S.Proyecto.exportador = ex; arranca.start() }
    }

    Timer { id: arranca; interval: 400; onTriggered: {
        //  Ocho fotogramas de seis tics: un ciclo dura 48 tics, 0,8 s clavados.
        S.Documento.nuevo({ nombre: "ritmo", ancho: 48, alto: 48, fotogramas: 8,
                            orientaciones: ["Down","DownRight","Right","UpRight",
                                            "Up","UpLeft","Left","DownLeft"] })
        const capa = S.Documento.capa(0)
        for (let f = 0; f < 8; f++) {
            S.Documento.ponDuracion(f, 6)
            for (let d = 0; d < 8; d++) {
                const b = S.Documento.celda(capa.id, f, d, true)
                for (let y = 8; y < 40; y++) for (let x = 8 + f; x < 40; x++)
                    P.pon(b, x, y, [200, 100 + d * 6, 60, 255])
            }
        }
        S.Documento.cambiaPixeles(null)

        ck("un ciclo dura lo que suman sus tics",
           S.Documento.duracionTotal === 48 && Math.abs(S.Animacion.segundos - 0.8) < 0.001,
           S.Documento.duracionTotal + " tics · " + S.Animacion.segundos.toFixed(2) + " s")

        //  Limpio antes de arrancar: lo que se comprueba luego es que
        //  REPRODUCIR no ensucie, no que dibujar sí lo haga.
        S.Documento.limpio()
        raiz.t0 = Date.now()
        raiz.ultimoF = S.Documento.fotograma
        S.Animacion.arranca()
        ck("arranca", S.Animacion.sonando)
        medir.start()
    } }

    Connections {
        target: S.Documento
        function onFotogramaChanged() {
            if (S.Documento.fotograma !== raiz.ultimoF) {
                raiz.vueltas++
                raiz.ultimoF = S.Documento.fotograma
            }
        }
    }

    Timer { id: medir; interval: 4000; onTriggered: {
        const seg = (Date.now() - raiz.t0) / 1000
        S.Animacion.para()
        const esperados = seg * 60 / 6          // un fotograma cada seis tics
        const desvio = (raiz.vueltas / esperados) - 1
        raiz.ck("la reproducción va al ritmo que dice, con menos de un 10% de desvío",
                Math.abs(desvio) < 0.10,
                raiz.vueltas + " fotogramas en " + seg.toFixed(2) + " s, esperados "
                + esperados.toFixed(1) + "  ->  " + (desvio * 100).toFixed(1) + "%")
        raiz.ck("y parar la para de verdad", !S.Animacion.sonando)

        //  Y que reproducir no ensucie el documento: cambiar de fotograma es
        //  mirar, no editar. Si ensuciara, el autoguardado se dispararía solo
        //  mientras miras una animación en bucle.
        raiz.ck("reproducir no marca el documento como sin guardar", !S.Documento.sucio)
        raiz.mediaVuelta()
    } }

    //  Y al revés: a media velocidad tienen que pasar la mitad.
    function mediaVuelta() {
        S.Animacion.velocidad = 0.5
        S.Animacion.tic = 0
        vueltas = 0
        ultimoF = S.Documento.fotograma
        t0 = Date.now()
        S.Animacion.arranca()
        medir2.start()
    }

    Timer { id: medir2; interval: 3000; onTriggered: {
        const seg = (Date.now() - raiz.t0) / 1000
        S.Animacion.para()
        const esperados = seg * 60 / 6 * 0.5
        raiz.ck("a media velocidad pasan la mitad de fotogramas",
                Math.abs(raiz.vueltas / esperados - 1) < 0.15,
                raiz.vueltas + " en " + seg.toFixed(2) + " s, esperados " + esperados.toFixed(1))
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\nla animación va al ritmo que dice")
        fin.start()
    } }

    Timer { id: fin; interval: 200; onTriggered: Qt.exit(raiz.malas ? 1 : 0) }
    Timer { interval: 40000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

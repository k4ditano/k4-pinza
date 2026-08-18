//  Que el programa no se vaya poniendo lento por usarlo.
//
//  Cambiar de acción en una criatura —Idle, Walk, Attack…— dejaba el programa
//  ENTERO lento a partir del tercer cambio, y ya no se recuperaba: ni cerrando
//  el documento, ni forzando la recogida de basura. La causa era
//  createImageData, que envenena el motor de JS de forma permanente (hallazgo
//  4 de la cata): a partir de unas cuarenta llamadas, CUALQUIER reserva de
//  memoria pasa de ser gratis a costar medio milisegundo.
//
//  Lo que lo disparaba era que cada acción tiene SU tamaño, así que cambiar de
//  acción obligaba a los lienzos a rehacer su ImageData. Eso es lo que imita
//  esta prueba: documentos de tamaños distintos, uno detrás de otro, con las
//  vistas que pintan píxeles mirando. Sin esas vistas el fallo no aparece.
//
//  Y lo que se mide no es lo que tarda el cambio, sino reservar mil objetos
//  tontos: es la señal que delata el envenenamiento y no depende de lo rápido
//  que vaya el disco.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property var lados: [32, 24, 48, 32, 40, 24, 56, 32, 48, 40, 24, 32, 40, 48]

    /** Reservar a lo tonto. Con el motor sano es 0 ms; envenenado, cientos. */
    function reserva() {
        const t0 = new Date().getTime()
        let b = []
        for (let k = 0; k < 1000; k++) b.push({ x: k })
        return new Date().getTime() - t0
    }

    FloatingWindow {
        implicitWidth: 900; implicitHeight: 620
        visible: true
        V.Exportador { id: ex }
        //  Las vistas que vuelcan píxeles a un Canvas, que son las del caso.
        V.Lienzo { anchors.fill: parent }
        V.Previa { width: 200; height: 240 }
        V.Muestra { }
        Component.onCompleted: { S.Proyecto.exportador = ex; arranca.start() }
    }

    Timer { id: arranca; interval: 400; onTriggered: {
        raiz.pon(0)
        raiz.reserva()
        raiz.partida = raiz.reserva()
        raiz.ck("reservar memoria es gratis antes de tocar nada", raiz.partida <= 12,
                raiz.partida + " ms")
        pasa.start()
    } }

    /** Un documento con dibujo, del tamaño que toque. */
    function pon(i) {
        const lado = lados[i]
        S.Documento.nuevo({ nombre: "lastre" + i, ancho: lado, alto: lado,
                            fotogramas: 2, orientaciones: ["Down", "Right"] })
        const capa = S.Documento.capa(0)
        for (let f = 0; f < 2; f++) for (let d = 0; d < 2; d++) {
            const b = S.Documento.celda(capa.id + ":" + f + ":" + d)
            if (!b) continue
            for (let y = 4; y < lado - 4; y++) for (let x = 4; x < lado - 4; x++)
                P.pon(b, x, y, [200, 90 + f * 40, 40 + d * 60, 255])
        }
        S.Documento.cambiaPixeles(null)
    }

    property int partida: 0
    property int peor: 0
    property int n: 0

    Timer { id: pasa; interval: 500; repeat: true; onTriggered: {
        if (raiz.n >= raiz.lados.length - 1) { pasa.stop(); remata(); return }
        raiz.n++
        raiz.pon(raiz.n)
        mide.start()
    } }
    Timer { id: mide; interval: 300; onTriggered: {
        const t = raiz.reserva()
        if (t > raiz.peor) raiz.peor = t
    } }

    function remata() {
        //  El listón: con el fallo puesto esto pasaba de 0 a cientos de ms, así
        //  que 25 deja sitio de sobra para una máquina cargada sin dejar pasar
        //  el envenenamiento.
        ck("y sigue siendo gratis tras " + (lados.length - 1) + " documentos de tamaños distintos",
           peor <= 25, "lo peor: " + peor + " ms (de partida " + partida + " ms)")
        ck("el motor cierra su ciclo de recogida en una tanda", cierraCiclo() <= 25,
           "si esto tarda, es que está marcando en cada reserva")
        fin.start()
    }

    /** Fuerza una recogida y mide lo que cuesta volver a ir rápido. */
    function cierraCiclo() {
        gc()
        let total = 0
        for (let t = 0; t < 40; t++) {
            const dt = reserva()
            total += dt
            if (dt < 3) break
        }
        return total
    }

    Timer { id: fin; interval: 200; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "")
        Qt.exit(raiz.malas ? 1 : 0)
    } }
    Timer { interval: 80000; running: true; onTriggered: { console.log("TIEMPO AGOTADO"); Qt.exit(1) } }
}

//  Cambiar lo que DURA la animación, no sólo a qué velocidad la miras.
//
//  Antes sólo se podía arrastrando el borde de un fotograma, uno a uno. Vale
//  para afinar el de impacto, pero no para lo más normal —«esto va lento»—, que
//  en una tirada de once fotogramas eran once arrastres y perder por el camino
//  el reparto que ya habías afinado.
//
//  Lo que se comprueba aquí es justo eso: que el reparto se conserva. Si el
//  fotograma de impacto duraba la mitad que el de recuperación, tiene que
//  seguir durando la mitad después de cambiar el compás; si no, cambiar la
//  velocidad te destroza el timing en vez de moverlo.

import QtQuick
import Quickshell
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    FloatingWindow {
        implicitWidth: 400; implicitHeight: 200; visible: true
        V.Exportador { id: ex }
        Component.onCompleted: { S.Proyecto.exportador = ex; arranca.start() }
    }
    Timer { id: arranca; interval: 300; onTriggered: raiz.mira() }

    function duraciones() {
        const d = []
        for (let f = 0; f < S.Documento.nFotogramas; f++) d.push(S.Documento.duracion(f))
        return d
    }

    function mira() {
        S.Documento.nuevo({ nombre: "ritmo2", ancho: 8, alto: 8, fotogramas: 4 })
        //  Un reparto desigual a propósito: 4 · 12 · 4 · 20
        S.Documento.ponDuracion(0, 4)
        S.Documento.ponDuracion(1, 12)
        S.Documento.ponDuracion(2, 4)
        S.Documento.ponDuracion(3, 20)
        ck("de partida, un reparto desigual", duraciones().join(",") === "4,12,4,20",
           duraciones().join(","))
        ck("y su total", S.Documento.duracionTotal === 40, S.Documento.duracionTotal + " tics")

        // ── el doble de lento ────────────────────────────────────
        S.Documento.escalaDuraciones(2)
        ck("el doble de lento dobla cada fotograma",
           duraciones().join(",") === "8,24,8,40", duraciones().join(","))
        ck("y el reparto es el mismo", duraciones()[1] / duraciones()[0] === 3)

        // ── y volver ─────────────────────────────────────────────
        S.Documento.escalaDuraciones(0.5)
        ck("y volver deja lo de antes", duraciones().join(",") === "4,12,4,20",
           duraciones().join(","))

        // ── ningún fotograma puede desaparecer ───────────────────
        S.Documento.escalaDuraciones(0.01)
        ck("por rápido que lo pongas, ningún fotograma baja de un tic",
           duraciones().every((t) => t >= 1), duraciones().join(","))

        // ── que dure lo que le digas ─────────────────────────────
        S.Documento.ponDuracion(0, 4); S.Documento.ponDuracion(1, 12)
        S.Documento.ponDuracion(2, 4); S.Documento.ponDuracion(3, 20)
        const total = S.Documento.duraEnTotal(20)
        ck("puedes pedirle que dure la mitad", total === 20, total + " tics")
        ck("repartiendo como estaba", duraciones().join(",") === "2,6,2,10",
           duraciones().join(","))

        //  Con tics enteros el total no siempre cae exacto, y lo honrado es
        //  devolver el que ha quedado en vez de fingir que sí.
        S.Documento.ponDuracion(0, 3); S.Documento.ponDuracion(1, 3)
        S.Documento.ponDuracion(2, 3); S.Documento.ponDuracion(3, 3)
        const raro = S.Documento.duraEnTotal(10)
        ck("y si con tics enteros no cae exacto, devuelve el que queda",
           raro === S.Documento.duracionTotal && Math.abs(raro - 10) <= 2,
           "pedí 10, quedó " + raro)

        // ── todos al mismo compás ────────────────────────────────
        S.Documento.ponDuracionTodos(6)
        ck("todos al mismo compás", duraciones().join(",") === "6,6,6,6",
           duraciones().join(","))

        // ── y que se pueda deshacer ──────────────────────────────
        const antes = duraciones().join(",")
        S.Historial.abreEstructura()
        S.Documento.escalaDuraciones(3)
        S.Historial.cierraEstructura("más lenta")
        ck("cambiar el ritmo deja un paso en el historial", S.Historial.pasos >= 1,
           S.Historial.pasos + " pasos")
        S.Historial.deshace()
        ck("y deshacerlo devuelve las duraciones", duraciones().join(",") === antes,
           duraciones().join(","))

        // ── la velocidad de mirar es OTRA cosa ───────────────────
        const guardadas = duraciones().join(",")
        S.Animacion.velocidad = 2
        ck("mirar más rápido no toca lo que dura", duraciones().join(",") === guardadas,
           "sigue en " + duraciones().join(","))
        S.Animacion.velocidad = 1

        fin.start()
    }

    Timer { id: fin; interval: 150; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "")
        Qt.exit(raiz.malas ? 1 : 0)
    } }
    Timer { interval: 40000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

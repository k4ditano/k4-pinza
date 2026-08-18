//  Cambiar un color en más de una celda.
//
//  Recolorear un bicho es cambiarlo en sus ocho caras y en todos sus
//  fotogramas. Celda a celda, en una hoja de once por ocho, son ochenta y ocho
//  clics — y basta fallar uno para que la animación parpadee.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property var viejo: [200, 60, 60, 255]
    readonly property var nuevo: [40, 160, 220, 255]

    FloatingWindow {
        implicitWidth: 400; implicitHeight: 300; visible: true
        V.Exportador { id: ex }
        V.Lienzo { id: lienzo; anchors.fill: parent }
        Component.onCompleted: { S.Proyecto.exportador = ex; arranca.start() }
    }
    Timer { id: arranca; interval: 300; onTriggered: raiz.corre() }

    /** Un bicho de mentira: 3 fotogramas × 4 caras, dos capas. */
    function prepara() {
        S.Documento.nuevo({ nombre: "recolor", ancho: 8, alto: 8, fotogramas: 3,
                            orientaciones: ["S", "E", "N", "W"] })
        S.Documento.añadeCapa("encima")
        for (let k = 0; k < 2; k++) {
            const c = S.Documento.capa(k)
            for (let f = 0; f < 3; f++) for (let d = 0; d < 4; d++) {
                const b = S.Documento.celda(c.id, f, d, true)
                P.pon(b, 1, 1, viejo)               // el color a cambiar
                P.pon(b, 6, 6, [20, 20, 20, 255])   // un testigo que no debe cambiar
            }
        }
        S.Documento.capaActiva = 0
        S.Documento.fotograma = 0
        S.Documento.orientacion = 0
        S.Documento.cambiaPixeles(null)
        S.Seleccion.nada()
        S.Pinceles.elige("sustituye")
        S.Pinceles.tolerancia = 8
        S.Paleta.ponPrimario(nuevo)
    }

    /** Cuántas celdas de la capa `k` tienen ya el color nuevo. */
    function cambiadas(k) {
        const c = S.Documento.capa(k)
        let n = 0
        for (let f = 0; f < 3; f++) for (let d = 0; d < 4; d++) {
            const b = S.Documento.celda(c.id, f, d, false)
            if (b && P.lee(b, 1, 1)[2] === 220) n++
        }
        return n
    }
    function testigosIntactos() {
        for (let k = 0; k < 2; k++) {
            const c = S.Documento.capa(k)
            for (let f = 0; f < 3; f++) for (let d = 0; d < 4; d++) {
                const b = S.Documento.celda(c.id, f, d, false)
                if (!b || P.lee(b, 6, 6)[0] !== 20) return false
            }
        }
        return true
    }

    /** Pincha en el píxel (1,1), donde está el color viejo. */
    function pincha() {
        const z = S.Ajustes.zoom
        const mx = S.Ajustes.panX + 1 * z + z / 2
        const my = S.Ajustes.panY + 1 * z + z / 2
        lienzo.pulsa(mx, my, Qt.LeftButton, 0)
        lienzo.suelta(mx, my)
    }

    function corre() {
        // ── sólo esta celda ──────────────────────────────────────
        prepara()
        S.Pinceles.alcanceColor = "celda"
        pincha()
        ck("con alcance «esta celda» sólo cambia una", cambiadas(0) === 1, cambiadas(0) + " de 12")
        ck("y no toca la otra capa", cambiadas(1) === 0)

        // ── todos los fotogramas de esta cara ────────────────────
        prepara()
        S.Pinceles.alcanceColor = "fotogramas"
        S.Pinceles.todasLasCapas = false
        pincha()
        ck("con «todos los fotogramas» cambian los tres de esta cara",
           cambiadas(0) === 3, cambiadas(0) + " de 12")
        ck("pero no las otras orientaciones", cambiadas(0) === 3)
        ck("ni la otra capa", cambiadas(1) === 0)

        // ── todo ─────────────────────────────────────────────────
        prepara()
        S.Pinceles.alcanceColor = "todo"
        S.Pinceles.todasLasCapas = false
        pincha()
        ck("con «y todas las orientaciones» cambian las doce",
           cambiadas(0) === 12, cambiadas(0) + " de 12")
        ck("y sigue sin tocar la otra capa", cambiadas(1) === 0)
        ck("los testigos de otro color aguantan", testigosIntactos())

        // ── todas las capas ──────────────────────────────────────
        prepara()
        S.Pinceles.alcanceColor = "todo"
        S.Pinceles.todasLasCapas = true
        pincha()
        ck("con «todas las capas» cambian las veinticuatro",
           cambiadas(0) === 12 && cambiadas(1) === 12,
           cambiadas(0) + " + " + cambiadas(1))
        S.Pinceles.todasLasCapas = false

        // ── deshacer lo devuelve TODO de una vez ─────────────────
        //  Un cambio que toca veinticuatro celdas tiene que ser UN paso, no
        //  veinticuatro: deshacerlo a mano sería inaguantable.
        ck("un cambio de veinticuatro celdas es un solo paso del historial",
           S.Historial.pasos === 1, S.Historial.pasos)
        S.Historial.deshace()
        ck("deshacer devuelve las veinticuatro de golpe",
           cambiadas(0) === 0 && cambiadas(1) === 0,
           cambiadas(0) + " + " + cambiadas(1))
        S.Historial.rehace()
        ck("y rehacer las vuelve a poner", cambiadas(0) === 12 && cambiadas(1) === 12)

        // ── con selección, sólo dentro ───────────────────────────
        prepara()
        S.Pinceles.alcanceColor = "todo"
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 8, 8, "nueva")
        pincha()
        ck("con una selección puesta no cambia lo de fuera",
           cambiadas(0) === 0, cambiadas(0) + " celdas cambiadas pese a estar fuera")
        S.Seleccion.nada()

        console.log(malas ? "\n" + malas + " FALLOS" : "\nel color se cambia hasta donde se le pide")
        fin.start()
    }
    Timer { id: fin; interval: 150; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 30000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

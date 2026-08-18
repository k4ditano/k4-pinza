//  Que pinches donde pinches, pinte ahí.
//
//  Es la prueba que faltaba y la que más falta hacía: un desajuste entre dónde
//  clicas y dónde aparece el píxel no se ve mirando el código —la aritmética
//  parece bien— y mirando la pantalla sólo se ve que "sale al lado". Aquí se
//  pincha en coordenadas de la vista y se mira qué píxel del búfer cambió.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    //  La misma jaula que en shell.qml: el lienzo NO ocupa la ventana entera,
    //  tiene un carril a la izquierda y paneles a la derecha. Si las
    //  coordenadas se colaran del espacio equivocado, sería justo por aquí.
    FloatingWindow {
        id: ventana
        implicitWidth: 800; implicitHeight: 600
        visible: true

        Rectangle { id: barra; anchors.top: parent.top; width: parent.width; height: 34; color: "#222" }
        Rectangle { id: carril; anchors.top: barra.bottom; anchors.left: parent.left
                    anchors.bottom: parent.bottom; width: 44; color: "#222" }
        Rectangle { id: opciones; anchors.top: barra.bottom; anchors.left: carril.right
                    anchors.right: paneles.left; height: 30; color: "#222" }
        Rectangle { id: paneles; anchors.top: barra.bottom; anchors.right: parent.right
                    anchors.bottom: parent.bottom; width: 232; color: "#222" }
        Rectangle { id: tira; anchors.left: carril.right; anchors.right: paneles.left
                    anchors.bottom: parent.bottom; height: 76; color: "#222" }

        V.Exportador { id: ex }
        V.Lienzo {
            id: lienzo
            anchors.top: opciones.bottom
            anchors.left: carril.right
            anchors.right: paneles.left
            anchors.bottom: tira.top
        }
        Component.onCompleted: { S.Proyecto.exportador = ex; arranca.start() }
    }

    Timer { id: arranca; interval: 400; onTriggered: raiz.corre() }

    /** El único píxel opaco del búfer, o null. */
    function unicoPintado(b) {
        let sitio = null, n = 0
        for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++)
            if (P.lee(b, x, y)[3] > 0) { sitio = [x, y]; n++ }
        return n === 1 ? sitio : (n === 0 ? null : ["muchos:" + n])
    }

    /** Pincha en el CENTRO del píxel (px,py) y devuelve dónde pintó. */
    function pinchaEn(px, py) {
        const b = S.Documento.celdaActiva(true)
        for (let i = 0; i < b.d.length; i++) b.d[i] = 0
        const z = S.Ajustes.zoom
        const mx = S.Ajustes.panX + px * z + z / 2
        const my = S.Ajustes.panY + py * z + z / 2
        lienzo.pulsa(mx, my, Qt.LeftButton, 0)
        lienzo.suelta(mx, my)
        return unicoPintado(S.Documento.celdaActiva(false))
    }

    function corre() {
        S.Documento.nuevo({ nombre: "p", ancho: 24, alto: 24 })
        S.Paleta.ponPrimario([255, 0, 0, 255])
        S.Pinceles.elige("lapiz")

        ck("el lienzo no ocupa la ventana entera",
           lienzo.x === 44 && lienzo.y === 64 && lienzo.width === 524,
           lienzo.x + "," + lienzo.y + " " + lienzo.width + "x" + lienzo.height)

        // ── un clic suelto en varios sitios ──────────────────────
        const sitios = [[0,0], [1,0], [0,1], [5,7], [12,12], [23,23], [23,0], [0,23]]
        let mal = []
        for (let i = 0; i < sitios.length; i++) {
            const q = sitios[i]
            const donde = pinchaEn(q[0], q[1])
            if (!donde || donde[0] !== q[0] || donde[1] !== q[1])
                mal.push("(" + q + ") -> " + donde)
        }
        ck("un clic pinta EL píxel donde pinchas, en las esquinas y en medio",
           mal.length === 0, mal.join("  ·  "))

        // ── con el lienzo desplazado ─────────────────────────────
        S.Ajustes.panX = 37; S.Ajustes.panY = 19
        const desp = pinchaEn(9, 4)
        ck("y también con el lienzo desplazado a mano",
           desp && desp[0] === 9 && desp[1] === 4, String(desp))

        // ── a otros zooms, enteros y no enteros ──────────────────
        let malZoom = []
        for (const z of [1, 2, 3, 7, 13, 26, 0.5]) {
            S.Ajustes.zoom = z
            const d = pinchaEn(6, 11)
            if (!d || d[0] !== 6 || d[1] !== 11) malZoom.push("×" + z + " -> " + d)
        }
        ck("y a cualquier zoom", malZoom.length === 0, malZoom.join("  ·  "))
        S.Ajustes.zoom = 12

        // ── arrastrar ────────────────────────────────────────────
        S.Ajustes.panX = 50; S.Ajustes.panY = 30
        const b = S.Documento.celdaActiva(true)
        for (let i = 0; i < b.d.length; i++) b.d[i] = 0
        const z = S.Ajustes.zoom
        const punto = (px, py) => [S.Ajustes.panX + px * z + z / 2, S.Ajustes.panY + py * z + z / 2]
        let a = punto(3, 3)
        lienzo.pulsa(a[0], a[1], Qt.LeftButton, 0)
        for (let x = 4; x <= 9; x++) { const q = punto(x, 3); lienzo.arrastra(q[0], q[1], Qt.LeftButton, 0) }
        const fin = punto(9, 3)
        lienzo.suelta(fin[0], fin[1])
        const buf = S.Documento.celdaActiva(false)
        let fila = [], fuera = 0
        for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++)
            if (P.lee(buf, x, y)[3] > 0) { if (y === 3) fila.push(x); else fuera++ }
        ck("arrastrar pinta la línea por donde pasas y nada más",
           fila.join() === "3,4,5,6,7,8,9" && fuera === 0,
           "fila 3: [" + fila.join() + "]  fuera: " + fuera)

        // ── lo que cae fuera del lienzo no pinta ────────────────
        for (let i = 0; i < buf.d.length; i++) buf.d[i] = 0
        lienzo.pulsa(S.Ajustes.panX - 30, S.Ajustes.panY - 30, Qt.LeftButton, 0)
        lienzo.suelta(S.Ajustes.panX - 30, S.Ajustes.panY - 30)
        ck("pinchar fuera del dibujo no pinta nada", unicoPintado(buf) === null)

        // ── el cursor que se enseña es el mismo ─────────────────
        const c = punto(17, 8)
        lienzo.arrastra(c[0], c[1], 0, 0)
        ck("y el cursor que se lee en pantalla dice ese mismo píxel",
           lienzo.cursorX === 17 && lienzo.cursorY === 8,
           lienzo.cursorX + "," + lienzo.cursorY)

        //  Y ahora lo que de verdad faltaba: que lo pintado SE VEA.
        //
        //  Aquí vivía el fallo de "dibujo y sale al lado". El píxel entraba
        //  bien en la capa y no llegaba nunca a la pantalla, porque el
        //  repintado por zona sucia no pintaba nada si la zona no empezaba en
        //  (0,0). Comprobar el búfer no bastaba, y por eso hay que esperar a
        //  que el Canvas pinte: no lo hace cuando se lo pides, sino cuando le
        //  toca.
        S.Ajustes.zoom = 9
        lienzo.centra()
        pendientes = [[0,0], [1,1], [7,3], [15,15], [23,23], [23,0], [0,23]]
        ciegos = []
        siguiente()
    }

    property var pendientes: []
    property var ciegos: []
    property var mirando: null

    function siguiente() {
        if (!pendientes.length) { revisaVecino(); return }
        mirando = pendientes.shift()
        pinchaEn(mirando[0], mirando[1])
        espera.restart()
    }

    Timer {
        id: espera
        interval: 90
        onTriggered: {
            const q = raiz.mirando
            const c = lienzo.pixelEnPantalla(q[0], q[1])
            if (!c || c[3] === 0) raiz.ciegos.push("(" + q + ") no se ve")
            else if (c[0] < 200 || c[1] > 60) raiz.ciegos.push("(" + q + ") sale " + c)
            raiz.siguiente()
        }
    }

    function revisaVecino() {
        ck("y lo pintado se VE en el lienzo, no sólo en la capa",
           ciegos.length === 0, ciegos.join("  ·  "))
        pinchaEn(4, 4)
        espera2.restart()
    }

    Timer {
        id: espera2
        interval: 90
        onTriggered: {
            const dentro = lienzo.pixelEnPantalla(4, 4)
            const alLado = lienzo.pixelEnPantalla(5, 4)
            ck("el píxel pintado está donde se pinchó", dentro && dentro[3] > 0, String(dentro))
            ck("y el de al lado sigue vacío", !alLado || alLado[3] === 0, String(alLado))

            //  Y que DESHACER se vea. Deshacer también repinta por zona sucia,
            //  así que sufría el mismo mal: la capa volvía atrás y la pantalla
            //  se quedaba con el trazo puesto. Un deshacer invisible es un
            //  deshacer que no existe.
            ck("hay algo que deshacer", S.Historial.puedeDeshacer, S.Historial.pasos + " pasos")
            S.Ordenes.ejecuta("deshacer")
            espera3.restart()
        }
    }

    Timer {
        id: espera3
        interval: 90
        onTriggered: {
            const c = lienzo.pixelEnPantalla(4, 4)
            ck("deshacer se VE: el píxel desaparece de la pantalla",
               !c || c[3] === 0, String(c))
            S.Ordenes.ejecuta("rehacer")
            espera4.restart()
        }
    }

    Timer {
        id: espera4
        interval: 90
        onTriggered: {
            const c = lienzo.pixelEnPantalla(4, 4)
            ck("y rehacer lo devuelve, también a la vista", c && c[3] > 0, String(c))

            //  Y la goma. Mismo mal: borraba la capa y no la pantalla, porque
            //  putImageData mezcla en vez de reemplazar y un píxel transparente
            //  encima de uno opaco lo dejaba igual.
            S.Pinceles.elige("goma")
            const z = S.Ajustes.zoom
            const mx = S.Ajustes.panX + 4 * z + z / 2
            const my = S.Ajustes.panY + 4 * z + z / 2
            lienzo.pulsa(mx, my, Qt.LeftButton, 0)
            lienzo.suelta(mx, my)
            espera5.restart()
        }
    }
    //  El Canvas pinta cuando le toca, no cuando se lo pides: entre pinchar y
    //  poder leer la pantalla hay que dejar que pase un repintado.
    Timer { id: esperaPintado; interval: 1; repeat: false }
    Timer {
        id: espera5
        interval: 90
        onTriggered: {
            const enCapa = P.lee(S.Documento.celdaActiva(false), 4, 4)
            const enPantalla = lienzo.pixelEnPantalla(4, 4)
            ck("la goma borra de la capa", enCapa[3] === 0, enCapa.join())
            ck("y también de la PANTALLA, que no es lo mismo",
               !enPantalla || enPantalla[3] === 0, String(enPantalla))
            console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS"
                                   : "\nel puntero cae donde debe, se ve, y se puede deshacer")
            salir.start()
        }
    }
    Timer { id: salir; interval: 150; onTriggered: Qt.exit(raiz.malas ? 1 : 0) }
    Timer { interval: 30000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

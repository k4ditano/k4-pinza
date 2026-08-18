//  Seleccionar un trozo y hacerle cosas.
//
//  Es la mitad del trabajo de animar: marcas un brazo, lo volteas, giras una
//  pinza, copias una pata y la pegas en el fotograma siguiente. Lo que hay que
//  comprobar no es que la operación funcione —eso ya lo prueba el motor— sino
//  que toque SÓLO lo marcado y deje el resto del dibujo donde estaba.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property var rojo: [255, 0, 0, 255]
    readonly property var azul: [0, 0, 255, 255]

    function buf() { return S.Documento.celdaActiva(true) }
    function en(x, y) { return P.lee(buf(), x, y) }

    /** Un lienzo con una marca asimétrica dentro y un testigo fuera. */
    function prepara() {
        S.Documento.nuevo({ nombre: "r", ancho: 16, ancho: 16, alto: 16 })
        const b = buf()
        // una "L" dentro del cuadro 4..7, para que voltear se note
        P.pon(b, 4, 4, rojo); P.pon(b, 4, 5, rojo); P.pon(b, 4, 6, rojo); P.pon(b, 5, 6, rojo)
        // y un testigo fuera, que no debe moverse nunca
        P.pon(b, 12, 12, azul)
        S.Documento.cambiaPixeles(null)
    }

    Component.onCompleted: {
        // ── las herramientas están ───────────────────────────────
        const sel = ["marco", "elipseSel", "lazo", "lazoPoli", "varita", "porColor"]
        let faltan = []
        for (const h of sel) {
            S.Pinceles.elige(h)
            if (S.Pinceles.herramienta !== h || !S.Pinceles.esSeleccion) faltan.push(h)
        }
        ck("hay seis formas de seleccionar", faltan.length === 0, faltan.join(" "))
        ck("y cuatro modos de combinarlas",
           ["nueva", "sumar", "restar", "intersecar"].every((m) => {
               S.Pinceles.modoSeleccion = m; return S.Pinceles.modoSeleccion === m }))
        S.Pinceles.modoSeleccion = "nueva"

        // ── voltear respeta la selección ─────────────────────────
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        ck("se selecciona un cuadro de 4×4", S.Seleccion.limites.w === 4 && S.Seleccion.limites.h === 4)
        S.Ordenes.ejecuta("voltearH")
        ck("voltear en horizontal mueve la L dentro del cuadro",
           en(7, 4)[0] === 255 && en(7, 5)[0] === 255 && en(6, 6)[0] === 255 && en(4, 4)[3] === 0,
           "columna 4 " + en(4,4)[3] + ", columna 7 " + en(7,4)[3])
        ck("y NO toca lo que hay fuera", en(12, 12).join() === azul.join())
        ck("se puede deshacer", S.Historial.puedeDeshacer)
        S.Historial.deshace()
        ck("y vuelve como estaba", en(4, 4)[0] === 255 && en(7, 4)[3] === 0)

        // ── voltear sin selección sigue tocando la capa entera ───
        prepara()
        S.Seleccion.nada()
        S.Ordenes.ejecuta("voltearH")
        ck("sin selección, voltear da la vuelta a la capa entera",
           en(11, 4)[0] === 255 && en(3, 12)[2] === 255,
           "la L en x=11 y el testigo en x=3")

        // ── girar la selección ───────────────────────────────────
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        S.Ordenes.ejecuta("girar90")
        ck("girar 90° gira sólo lo marcado",
           en(12, 12).join() === azul.join() && !P.vacio(buf()))
        ck("y la selección gira con el dibujo, para poder encadenar",
           S.Seleccion.activa && S.Seleccion.limites !== null,
           S.Seleccion.limites ? S.Seleccion.limites.w + "×" + S.Seleccion.limites.h : "?")
        S.Ordenes.ejecuta("girar90"); S.Ordenes.ejecuta("girar90"); S.Ordenes.ejecuta("girar90")
        ck("cuatro cuartos de vuelta devuelven la L a su sitio",
           en(4, 4)[0] === 255 && en(4, 6)[0] === 255 && en(5, 6)[0] === 255,
           "esquina " + en(4,4)[3] + " pie " + en(5,6)[3])

        // en un lienzo NO cuadrado, girar sólo se ofrece con selección
        S.Documento.nuevo({ nombre: "ancho", ancho: 24, alto: 8 })
        S.Seleccion.nada()
        ck("sin selección y con lienzo rectangular, girar 90° no se ofrece",
           !S.Ordenes.disponible(S.Ordenes.orden("girar90")))
        S.Seleccion.desdeRectangulo(2, 2, 5, 5, 24, 8, "nueva")
        ck("pero con una selección sí, porque cabe donde estaba",
           S.Ordenes.disponible(S.Ordenes.orden("girar90")))

        // ── copiar, cortar y pegar ───────────────────────────────
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        S.Ordenes.ejecuta("copiar")
        ck("copiar se lleva el trozo del tamaño de la selección",
           S.Ordenes.portapapeles && S.Ordenes.portapapeles.w === 4,
           S.Ordenes.portapapeles ? S.Ordenes.portapapeles.w + "×" + S.Ordenes.portapapeles.h : "nada")
        ck("y sólo lo de dentro de la marca",
           P.lee(S.Ordenes.portapapeles, 0, 0)[0] === 255)

        S.Seleccion.desdeRectangulo(9, 2, 12, 5, 16, 16, "nueva")
        S.Ordenes.ejecuta("pegar")
        ck("pegar lo deja donde estaba la selección", en(9, 2)[0] === 255)
        ck("el original sigue donde estaba", en(4, 4)[0] === 255)
        ck("y lo pegado queda seleccionado, listo para moverlo",
           S.Seleccion.activa && S.Seleccion.contiene(9, 2))
        ck("con la herramienta de mover ya puesta", S.Pinceles.herramienta === "mover")

        // pegar no debe abrir un agujero con lo transparente del recorte
        prepara()
        const b = buf()
        for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++)
            if (P.lee(b, x, y)[3] === 0) P.pon(b, x, y, [30, 30, 30, 255])
        S.Documento.cambiaPixeles(null)
        S.Ordenes.portapapeles = P.nuevo(3, 3)
        P.pon(S.Ordenes.portapapeles, 1, 1, [0, 255, 0, 255])
        S.Seleccion.desdeRectangulo(8, 8, 10, 10, 16, 16, "nueva")
        S.Ordenes.ejecuta("pegar")
        ck("pegar no abre un agujero con lo transparente del recorte",
           en(9, 9)[1] === 255 && en(8, 8)[0] === 30,
           "centro " + en(9,9).join() + " esquina " + en(8,8).join())

        // ── cortar ───────────────────────────────────────────────
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        S.Ordenes.ejecuta("cortar")
        ck("cortar deja el hueco vacío", en(4, 4)[3] === 0)
        ck("y no se lleva lo de fuera", en(12, 12).join() === azul.join())
        ck("pero sí lo tiene en el portapapeles", S.Ordenes.portapapeles.w === 4)

        // ── mover con la herramienta ─────────────────────────────
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        ck("la herramienta de mover existe", S.Ordenes.orden("pincelDeSeleccion") !== null)
        ck("y se puede hacer un pincel de lo seleccionado",
           S.Ordenes.ejecuta("pincelDeSeleccion") && S.Pinceles.pincelPersonal !== null,
           S.Pinceles.pincelPersonal ? S.Pinceles.pincelPersonal.w + "×" + S.Pinceles.pincelPersonal.h : "nada")
        S.Pinceles.pincelPersonal = null

        console.log(malas ? "\n" + malas + " FALLOS" : "\nlo marcado se voltea, gira, copia y pega solo")
        fin.start()
    }
    Timer { id: fin; interval: 150; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 25000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

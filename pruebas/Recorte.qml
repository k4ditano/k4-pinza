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

        // ── escalar la selección ─────────────────────────────────
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        S.Ordenes.transforma("escalar", (b) => P.escalaVecino(b, b.w * 2, b.h * 2))
        ck("escalar la selección la agranda en su sitio",
           S.Seleccion.limites.w === 8 && S.Seleccion.limites.h === 8,
           S.Seleccion.limites.w + "×" + S.Seleccion.limites.h)
        ck("y sigue centrada donde estaba",
           Math.abs((S.Seleccion.limites.x + 4) - 6) <= 1,
           "centro en x=" + (S.Seleccion.limites.x + 4))
        ck("el testigo de fuera aguanta si no le pilla encima",
           en(12, 12).join() === azul.join())

        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        S.Ordenes.transforma("encoger", (b) => P.escalaVecino(b, 2, 2))
        ck("y encogerla también", S.Seleccion.limites.w === 2, S.Seleccion.limites.w)

        // ── girar libre ──────────────────────────────────────────
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        S.Ordenes.transforma("girar libre",
                             (b) => P.giraLibre(b, 30, true),
                             (b) => P.giraLibre(b, 30, false))
        ck("girar 30° deja el trozo girado y más ancho",
           S.Seleccion.activa && S.Seleccion.limites.w > 4,
           S.Seleccion.limites.w + "×" + S.Seleccion.limites.h)
        ck("sin tocar el testigo de fuera", en(12, 12).join() === azul.join())

        //  Y lo que de verdad importa: que la marca cubra lo girado. Si no,
        //  queda dibujo que ves pero no puedes seguir moviendo. Se prueba a
        //  cuarenta y cinco grados clavados, que es el ángulo malo: ahí las
        //  puntas del rombo caen entre muestras.
        prepara()
        S.Seleccion.desdeRectangulo(4, 4, 7, 7, 16, 16, "nueva")
        S.Ordenes.transforma("girar 45",
                             (b) => P.giraLibre(b, 45, true),
                             (b) => P.giraLibre(b, 45, false))
        let fuera = 0
        const bb = buf()
        for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
            if (P.lee(bb, x, y)[3] === 0) continue
            if (x === 12 && y === 12) continue          // el testigo, que no es de la selección
            if (!S.Seleccion.contiene(x, y)) fuera++
        }
        ck("y la marca cubre todo lo girado, sin dejar cachos fuera",
           fuera === 0, fuera + " píxeles girados fuera de su selección")

        // ── y lo que de verdad importa: no encadenar ─────────────
        //
        //  Girar cinco grados cinco veces NO es girar veinticinco: cada giro
        //  vuelve a muestrear lo ya muestreado. Por eso la sesión rehace
        //  siempre desde el estado de partida.
        prepara()
        S.Seleccion.desdeRectangulo(3, 3, 8, 8, 16, 16, "nueva")
        ck("se puede abrir una sesión de transformar", S.Ordenes.empiezaTransformacion())
        const pasos = S.Historial.pasos
        S.Ordenes.ensaya((b) => P.giraLibre(b, 10, true))
        S.Ordenes.ensaya((b) => P.giraLibre(b, 20, true))
        S.Ordenes.ensaya((b) => P.giraLibre(b, 30, true))
        ck("probar ángulos no deja rastro en el historial",
           S.Historial.pasos === pasos, S.Historial.pasos + " vs " + pasos)
        const trasEnsayo = P.clonar(buf())

        // el mismo giro de una vez, desde el original, tiene que dar LO MISMO
        S.Ordenes.cancelaTransformacion()
        S.Ordenes.transforma("de una vez", (b) => P.giraLibre(b, 30, true))
        let distintos = 0
        const ahora = buf()
        for (let i = 0; i < ahora.d.length; i += 4)
            if (ahora.d[i+3] !== trasEnsayo.d[i+3]) distintos++
        ck("y probar tres ángulos deja lo mismo que girar ese ángulo de una vez",
           distintos === 0, distintos + " píxeles distintos")

        // aceptar deja UNA entrada, no tres
        prepara()
        S.Seleccion.desdeRectangulo(3, 3, 8, 8, 16, 16, "nueva")
        const antesDe = S.Historial.pasos
        S.Ordenes.empiezaTransformacion()
        S.Ordenes.ensaya((b) => P.giraLibre(b, 15, false))
        S.Ordenes.ensaya((b) => P.giraLibre(b, 40, false))
        S.Ordenes.aceptaTransformacion("girar", (b) => P.giraLibre(b, 40, false))
        ck("aceptar deja UNA entrada en el historial, no una por prueba",
           S.Historial.pasos === antesDe + 1, (S.Historial.pasos - antesDe) + " entradas")
        S.Historial.deshace()
        ck("y deshacerla devuelve el dibujo entero de golpe",
           en(4, 4)[0] === 255 && en(5, 6)[0] === 255)

        // cancelar no deja nada
        prepara()
        S.Seleccion.desdeRectangulo(3, 3, 8, 8, 16, 16, "nueva")
        const antesCancel = S.Historial.pasos
        S.Ordenes.empiezaTransformacion()
        S.Ordenes.ensaya((b) => P.giraLibre(b, 73, true))
        S.Ordenes.cancelaTransformacion()
        ck("cancelar devuelve el dibujo como estaba",
           en(4, 4)[0] === 255 && en(4, 6)[0] === 255 && en(5, 6)[0] === 255)
        ck("y no deja nada en el historial", S.Historial.pasos === antesCancel)

        console.log(malas ? "\n" + malas + " FALLOS" : "\nlo marcado se voltea, gira, escala, copia y pega solo")
        fin.start()
    }
    Timer { id: fin; interval: 150; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 25000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

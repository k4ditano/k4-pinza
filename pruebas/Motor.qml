//  El motor de píxeles, en seco.
//
//  No abre ventana ni necesita GPU: son funciones puras, y por eso se pueden
//  comprobar de verdad. Si algo de aquí se rompe, se rompe el programa entero.
//
//      QT_QPA_PLATFORM=offscreen qs -p pruebas/motor.qml

import QtQuick
import Quickshell
import "../core/pixeles.js" as P

ShellRoot {
    property int malas: 0
    function ck(que, bien, detalle) {
        if (!bien) malas++
        console.log((bien ? " ok  " : "FALLO") + "  " + que + (detalle !== undefined ? "   ── " + detalle : ""))
    }

    Component.onCompleted: {
        const naranja = [214, 108, 52, 255]
        const verde   = [118, 193, 56, 255]

        // ── búferes ──────────────────────────────────────────────
        let b = P.nuevo(8, 8)
        ck("un búfer nuevo nace vacío", P.vacio(b) && b.d.length === 8 * 8 * 4)
        P.pon(b, 3, 3, naranja)
        ck("pon y lee dicen lo mismo", P.lee(b, 3, 3).join() === naranja.join())
        ck("fuera del lienzo no revienta, devuelve nada", P.lee(b, 99, 99).join() === "0,0,0,0")
        P.pon(b, 99, 99, verde)
        ck("escribir fuera del lienzo no hace nada", P.vacio(P.recorte(b, 4, 4, 4, 4)))

        // ── mezcla por alfa ──────────────────────────────────────
        let m = P.nuevo(2, 2)
        P.mezcla(m, 0, 0, [255, 0, 0, 128])
        const mediaRoja = P.lee(m, 0, 0)
        ck("mezclar sobre vacío conserva el color y baja el alfa",
           mediaRoja[0] === 255 && mediaRoja[3] > 120 && mediaRoja[3] < 136, "alfa " + mediaRoja[3])
        P.mezcla(m, 1, 1, verde, true)
        ck("con el alfa bloqueado no se pinta donde no había nada", P.lee(m, 1, 1)[3] === 0)
        P.pon(m, 1, 1, naranja)
        P.mezcla(m, 1, 1, verde, true)
        ck("con el alfa bloqueado sí se pinta donde ya había",
           P.lee(m, 1, 1)[0] === 118 && P.lee(m, 1, 1)[3] === 255)

        // ── color ────────────────────────────────────────────────
        ck("deHex entiende #rgb, #rrggbb y #rrggbbaa",
           P.deHex("#f00").join() === "255,0,0,255"
           && P.deHex("#D66C34").join() === "214,108,52,255"
           && P.deHex("#D66C3480")[3] === 128)
        ck("aHex es la vuelta exacta", P.aHex(naranja).toLowerCase() === "#d66c34")
        const hsv = P.aHsv([255, 0, 0])
        ck("aHsv sitúa el rojo puro en 0°", Math.round(hsv[0]) === 0 && hsv[1] === 1 && hsv[2] === 1)
        const vuelta = P.deHsv(hsv[0], hsv[1], hsv[2])
        ck("deHsv deshace aHsv", Math.round(vuelta[0]) === 255 && Math.round(vuelta[1]) === 0)
        const rueda = P.deHsv(120, 1, 1)
        ck("120° es verde puro", Math.round(rueda[1]) === 255 && Math.round(rueda[0]) === 0)

        // ── modos de fusión ──────────────────────────────────────
        ck("hay dieciocho modos de fusión", P.MODOS.length === 18, P.MODOS.length + " modos")
        let abajo = P.nuevo(1, 1), arriba = P.nuevo(1, 1)
        P.pon(abajo, 0, 0, [200, 200, 200, 255])
        P.pon(arriba, 0, 0, [128, 128, 128, 255])
        let mult = P.clonar(abajo)
        P.compon(mult, arriba, "multiplicar", 1)
        ck("multiplicar oscurece", P.lee(mult, 0, 0)[0] === Math.round(200 * 128 / 255),
           P.lee(mult, 0, 0)[0] + " (esperado " + Math.round(200 * 128 / 255) + ")")
        let tramaM = P.clonar(abajo)
        P.compon(tramaM, arriba, "trama", 1)
        ck("trama aclara", P.lee(tramaM, 0, 0)[0] > 200)
        let normal = P.clonar(abajo)
        P.compon(normal, arriba, "normal", 0.5)
        ck("la opacidad interpola", Math.abs(P.lee(normal, 0, 0)[0] - 164) <= 2, P.lee(normal, 0, 0)[0])
        let lumi = P.clonar(abajo)
        P.compon(lumi, arriba, "luminosidad", 1)
        ck("luminosidad toma el valor de arriba y el tono de abajo", P.lee(lumi, 0, 0)[0] === 128)

        // la composición por rectángulo tiene que dar lo mismo que la entera
        let ancho = P.nuevo(8, 8), tapa = P.nuevo(8, 8)
        for (let i = 0; i < 64; i++) { P.pon(ancho, i % 8, Math.floor(i / 8), naranja) }
        P.pon(tapa, 2, 2, verde)
        let entera = P.clonar(ancho), trozo = P.clonar(ancho)
        P.compon(entera, tapa, "normal", 1)
        P.compon(trozo, tapa, "normal", 1, 2, 2, 1, 1)
        ck("componer un rectángulo da lo mismo que componer todo",
           entera.d.join() === trozo.d.join())

        // ── formas ───────────────────────────────────────────────
        const l = P.linea(0, 0, 4, 0)
        ck("una línea recta da los puntos justos", l.length === 5 && l[4][0] === 4)
        const diag = P.linea(0, 0, 3, 3)
        ck("una diagonal no se salta píxeles", diag.length === 4 && diag[2].join() === "2,2")
        const rHueco = P.rectangulo(0, 0, 3, 3, false)
        ck("un rectángulo hueco tiene sólo el borde", rHueco.length === 12, rHueco.length + " puntos")
        const rLleno = P.rectangulo(0, 0, 3, 3, true)
        ck("uno relleno tiene todo", rLleno.length === 16)
        const el = P.elipse(0, 0, 7, 7, true)
        ck("una elipse rellena cabe en su caja y es redonda", el.length > 30 && el.length < 64, el.length + " píxeles")
        ck("una punta de radio 1 es un solo píxel", P.punta(1).length === 1)
        ck("una punta redonda de radio 3 no es un cuadrado",
           P.punta(3).length < P.punta(3, true).length)

        // ── trazo perfecto ───────────────────────────────────────
        const codo = P.perfecciona([[0,0],[1,0],[1,1]])
        ck("el trazo perfecto quita la esquina doble", codo.length === 2, codo.length + " de 3")
        const recta = P.perfecciona([[0,0],[1,0],[2,0],[3,0]])
        ck("y no toca una línea recta", recta.length === 4)

        // ── inundación ───────────────────────────────────────────
        let campo = P.nuevo(8, 8)
        for (let x = 0; x < 8; x++) P.pon(campo, x, 4, naranja)   // una pared horizontal
        const arribaM = P.inunda(campo, 0, 0, 8, false)
        let cuenta = 0; for (let i = 0; i < arribaM.length; i++) cuenta += arribaM[i]
        ck("la inundación respeta la pared", cuenta === 32, cuenta + " de 64 píxeles")
        const conOcho = P.inunda(campo, 0, 0, 8, true)
        let c8 = 0; for (let i = 0; i < conOcho.length; i++) c8 += conOcho[i]
        ck("con ocho vecinos tampoco la cruza si es sólida", c8 === 32, c8)
        const todo = P.porColor(campo, 0, 4, 8)
        let ct = 0; for (let i = 0; i < todo.length; i++) ct += todo[i]
        ck("por color coge la pared entera aunque no sea contigua", ct === 8, ct)
        const alfa = P.porAlfa(campo)
        let ca = 0; for (let i = 0; i < alfa.length; i++) ca += alfa[i]
        ck("por alfa coge la silueta", ca === 8, ca)

        // ── transformaciones ─────────────────────────────────────
        let t = P.nuevo(4, 2)
        P.pon(t, 0, 0, naranja)
        ck("voltear en horizontal lleva el píxel al otro lado",
           P.lee(P.volteaH(t), 3, 0).join() === naranja.join())
        ck("voltear en vertical, abajo", P.lee(P.volteaV(t), 0, 1).join() === naranja.join())
        const g = P.gira90(t, 1)
        ck("girar 90° intercambia ancho y alto", g.w === 2 && g.h === 4)
        ck("y lleva la esquina superior izquierda a la superior derecha",
           P.lee(g, 1, 0).join() === naranja.join())
        ck("girar cuatro veces vuelve al sitio", P.gira90(t, 4).d.join() === t.d.join())
        const doble = P.escalaVecino(t, 8, 4)
        ck("escalar por vecino duplica el píxel",
           doble.w === 8 && P.lee(doble, 1, 1).join() === naranja.join())
        const suave = P.escalaSuave(t, 8, 4)
        ck("el escalado suave da el tamaño pedido", suave.w === 8 && suave.h === 4)
        const des = P.desplaza(t, 1, 0)
        ck("desplazar envuelve por el otro lado", P.lee(des, 1, 0).join() === naranja.join())
        const des2 = P.desplaza(t, -1, 0)
        ck("y también hacia atrás", P.lee(des2, 3, 0).join() === naranja.join())

        // ── medidas de silueta ───────────────────────────────────
        let bicho = P.nuevo(16, 16)
        for (let y = 2; y <= 9; y++) for (let x = 4; x <= 11; x++) P.pon(bicho, x, y, naranja)
        const s = P.silueta(bicho)
        ck("pieBajo cuenta las filas vacías de debajo", s.pieBajo === 6, s.pieBajo)
        ck("medioAncho es media silueta", s.medioAncho === 4, s.medioAncho)
        const lim = P.limites(bicho)
        ck("los límites son los del dibujo, no los del lienzo",
           lim.x === 4 && lim.y === 2 && lim.w === 8 && lim.h === 8)
        ck("un búfer vacío no tiene límites", P.limites(P.nuevo(4, 4)) === null)

        // ── paleta ───────────────────────────────────────────────
        let mezclado = P.nuevo(4, 4)
        for (let i = 0; i < 12; i++) P.pon(mezclado, i % 4, Math.floor(i / 4), naranja)
        for (let i = 12; i < 16; i++) P.pon(mezclado, i % 4, Math.floor(i / 4), verde)
        const cols = P.coloresDe(mezclado)
        ck("coloresDe encuentra los dos colores", cols.length === 2)
        ck("y los ordena por frecuencia", cols[0].veces === 12 && cols[1].veces === 4)
        const med = P.medidas(mezclado)
        ck("las medidas ignoran lo transparente", med.pixeles === 16)
        ck("la saturación media es un número entre 0 y 1",
           med.saturacion > 0 && med.saturacion < 1, med.saturacion.toFixed(3))
        const red = P.reduce(mezclado, 2)
        ck("reducir a dos colores da dos colores", red.length === 2, red.map(P.aHex).join(" "))
        const cu = P.cuantiza(mezclado, [[0,0,0,255],[255,255,255,255]])
        ck("cuantizar acerca al más parecido de la lista",
           P.lee(cu, 0, 0)[0] === 255 || P.lee(cu, 0, 0)[0] === 0)
        ck("cuantizar no toca el alfa", P.lee(cu, 0, 0)[3] === 255)
        const ord = P.ordena([[255,255,255,255],[0,0,0,255],[128,128,128,255]], "luma")
        ck("ordenar por luma pone el negro primero", ord[0][0] === 0 && ord[2][0] === 255)

        // ── tramado ──────────────────────────────────────────────
        ck("la trama del 50% alterna", P.trama("50", 0, 0) && !P.trama("50", 1, 0))
        ck("la sólida siempre pinta", P.trama("solido", 3, 7))
        ck("bayer respeta la proporción", P.trama("bayer", 0, 0, 0.9) && !P.trama("bayer", 1, 1, 0.1))

        // ── filtros ──────────────────────────────────────────────
        let solo = P.nuevo(5, 5)
        P.pon(solo, 2, 2, verde)
        const conBorde = P.contornea(solo, naranja, false, "fuera")
        ck("contornear por fuera rodea la silueta",
           P.lee(conBorde, 2, 1).join() === naranja.join() && P.lee(conBorde, 2, 2).join() === verde.join())
        const sust = P.sustituye(solo, verde, naranja, 8)
        ck("sustituir cambia sólo el color pedido", P.lee(sust, 2, 2).join() === naranja.join())
        const aj = P.ajusta(solo, 180, 0, 0)
        ck("ajustar el tono cambia el color pero no el alfa",
           P.lee(aj, 2, 2)[3] === 255 && P.lee(aj, 2, 2).join() !== verde.join())

        // ── base64 ───────────────────────────────────────────────
        //  El camino por el que entran TODAS las imágenes: la forja las lee
        //  con Pillow y llegan por aquí. Si esto se rompe, abrir un proyecto
        //  devuelve capas vacías sin dar ningún error.
        const uno = P.deBase64("/wAA/w==", 1, 1)
        ck("base64 de un píxel rojo opaco", uno.d.join() === "255,0,0,255", uno.d.join())
        const dos = P.deBase64("AAAAAP///wA=", 2, 1)
        ck("y de dos, con alfa distinto",
           dos.d.join() === "0,0,0,0,255,255,255,0", dos.d.join())
        const grande = P.deBase64("/////wAAAP8AAP///wD/AA==", 2, 2)
        ck("el búfer sale del tamaño pedido", grande.w === 2 && grande.h === 2
           && grande.d.length === 16)
        ck("y no se sale aunque sobre texto",
           P.deBase64("/wAA/////wAA", 1, 1).d.join() === "255,0,0,255")
        const salto = P.deBase64("/wAA\n/w==", 1, 1)
        ck("los saltos de línea no le molestan", salto.d.join() === "255,0,0,255", salto.d.join())

        console.log(malas ? "\n" + malas + " FALLOS" : "\nel motor pasa entero")
        fin.start()
    }
    Timer { id: fin; interval: 120; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 30000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

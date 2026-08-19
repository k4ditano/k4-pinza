//  Dibujar por descripción, en seco.
//
//  Todo lo de `figura.js` es función pura, así que aquí se puede comprobar lo
//  único que de verdad importa de esa librería: que la regla de luz produce el
//  sombreado que dice producir. Lo demás —que una elipse sea redonda— se ve;
//  que el lado iluminado salga MÁS CLARO QUE EL OTRO no se ve hasta que
//  exportas, y es justo lo que se rompería sin enterarse nadie.
//
//      QT_QPA_PLATFORM=offscreen qs -p prueba.qml   (con PINZA_PRUEBA)

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../core/figura.js" as F

ShellRoot {
    property int malas: 0
    function ck(que, bien, detalle) {
        if (!bien) malas++
        console.log((bien ? " ok  " : "FALLO") + "  " + que + (detalle !== undefined ? "   ── " + detalle : ""))
    }

    /** La luminancia media de lo pintado dentro de una zona. */
    function lumaEn(b, k, x0, y0, x1, y1) {
        let s = 0, n = 0
        for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
            if (!F.en(k, x, y)) continue
            const c = P.lee(b, x, y)
            if (c[3] < 8) continue
            s += P.luma(c); n++
        }
        return n ? s / n : -1
    }

    Component.onCompleted: {
        // ── máscaras ─────────────────────────────────────────────
        const e = F.elipse(32, 32, 16, 16, 8, 8)
        ck("una elipse cae dentro de sus radios", F.en(e, 16, 16) === 1 && F.en(e, 16, 3) === 0)
        ck("y es simétrica", F.en(e, 9, 16) === F.en(e, 22, 16))

        const l = F.limites(e)
        ck("sus límites son el diámetro", l.w === 16 && l.h === 16, l.w + "x" + l.h)

        const c = F.capsula(32, 32, 8, 8, 24, 8, 3)
        ck("una cápsula cubre su segmento", F.en(c, 16, 8) === 1)
        ck("y engorda hasta su radio", F.en(c, 16, 10) === 1 && F.en(c, 16, 13) === 0)
        ck("con los extremos redondos", F.en(c, 6, 8) === 1 && F.en(c, 4, 8) === 0)

        ck("unir suma", F.cuantos(F.une(F.rect(8, 8, 0, 0, 2, 2), F.rect(8, 8, 4, 4, 2, 2))) === 8)
        ck("restar quita", F.cuantos(F.resta(F.rect(8, 8, 0, 0, 4, 4), F.rect(8, 8, 0, 0, 2, 2))) === 12)
        ck("cortar deja lo común", F.cuantos(F.corta(F.rect(8, 8, 0, 0, 4, 4), F.rect(8, 8, 2, 2, 4, 4))) === 4)

        //  La simetría es media figura convertida en figura entera, que es
        //  como se dibuja un bicho de frente y como se ahorra la mitad del
        //  trabajo al describirlo.
        const media = F.rect(16, 16, 2, 4, 5, 8)
        const entera = F.simetrica(media)
        ck("la simetría duplica la masa", F.cuantos(entera) === 2 * F.cuantos(media))
        ck("y espeja sobre el centro del lienzo", F.en(entera, 13, 6) === 1 && F.en(entera, 2, 6) === 1)

        const t = F.deTexto(["..##..",
                             ".####.",
                             "######"])
        ck("una máscara escrita a mano se lee", F.cuantos(t) === 2 + 4 + 6, F.cuantos(t))
        ck("y respeta el ancho que se ve", t.w === 6 && t.h === 3)

        ck("crecer engorda por los cuatro lados",
           F.cuantos(F.crece(F.rect(9, 9, 4, 4, 1, 1), 1)) === 5)
        ck("el borde es el anillo de fuera",
           F.cuantos(F.borde(F.rect(9, 9, 3, 3, 3, 3))) === 8)

        // ── la regla de luz ──────────────────────────────────────
        //
        //  Lo esencial: una bola con la luz arriba a la izquierda tiene que
        //  salir más clara arriba-izquierda que abajo-derecha. Si esto se
        //  invierte, cada sprite generado sale con el foco donde no es y no
        //  hay forma de verlo salvo mirándolo.
        const bola = F.disco(32, 32, 16, 16, 12)
        const ramp = F.rampa("#7040c0", 5)
        ck("una rampa generada va de oscuro a claro",
           ramp.every((x, i) => i === 0 || P.luma(x) > P.luma(ramp[i - 1])),
           ramp.map(P.aHex).join(" "))

        let b = P.nuevo(32, 32)
        F.cuerpo(b, bola, { rampa: ramp, luz: "NO", grosor: 4, amplitud: 2, contorno: false })

        const claro = lumaEn(b, bola, 8, 8, 13, 13)     // arriba-izquierda
        const oscuro = lumaEn(b, bola, 19, 19, 24, 24)  // abajo-derecha
        ck("con la luz al noroeste, el noroeste sale más claro",
           claro > oscuro + 8, Math.round(claro) + " vs " + Math.round(oscuro))

        //  Y girando la luz gira el sombreado. Es la comprobación que separa
        //  «hay un degradado» de «hay una regla de luz»: sin esto, un
        //  sombreado fijo pasaría la prueba de arriba igual de bien.
        let b2 = P.nuevo(32, 32)
        F.cuerpo(b2, bola, { rampa: ramp, luz: "SE", grosor: 4, amplitud: 2, contorno: false })
        const claro2 = lumaEn(b2, bola, 19, 19, 24, 24)
        const oscuro2 = lumaEn(b2, bola, 8, 8, 13, 13)
        ck("y girando la luz al sureste se invierte",
           claro2 > oscuro2 + 8, Math.round(claro2) + " vs " + Math.round(oscuro2))

        //  El centro no es ni lo uno ni lo otro: el interior de una masa es
        //  color base. Es la propiedad que hace que esto sea pixel art y no un
        //  degradado — si el centro se sombreara, cada figura saldría con una
        //  nube de tonos en vez de con tres.
        const centro = lumaEn(b, bola, 15, 15, 17, 17)
        ck("y el interior se queda en el color base",
           Math.abs(centro - P.luma(ramp[2])) < 6,
           Math.round(centro) + " vs base " + Math.round(P.luma(ramp[2])))

        // ── que no se salga ni invente colores ───────────────────
        //
        //  Dos promesas que un sprite generado tiene que cumplir para que el
        //  editor pueda tratarlo como cualquier otro: no hay un solo píxel
        //  fuera de la silueta, y no hay un solo color que no esté en la
        //  rampa. Lo segundo es lo que permite recolorear la criatura entera
        //  después: un tono intermedio inventado no pertenece a ninguna rampa
        //  y se queda atrás cuando cambias el color.
        let fuera = 0, colados = 0
        const enRampa = (c) => ramp.some((r) => P.distancia(r, c) < 3)
        for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) {
            const px = P.lee(b, x, y)
            if (px[3] < 8) continue
            if (!F.en(bola, x, y)) fuera++
            else if (!enRampa(px)) colados++
        }
        ck("no pinta un solo píxel fuera de la silueta", fuera === 0, fuera)
        ck("y no inventa ningún color que no esté en la rampa", colados === 0, colados)

        //  El contorno va por DENTRO, así que no puede engordar la figura: si
        //  la engordara, un sprite de 32 de ancho pasaría a 34 y dejaría de
        //  cumplir el contrato del pack sin avisar.
        let b3 = P.nuevo(32, 32)
        F.cuerpo(b3, bola, { rampa: ramp, luz: "NO" })
        const lb = P.limites(b3, 8), le = F.limites(bola)
        ck("el contorno no engorda la silueta",
           lb.w === le.w && lb.h === le.h, lb.w + "x" + lb.h + " vs " + le.w + "x" + le.h)

        //  Pegado al borde del lienzo la figura tiene que seguir sombreándose:
        //  fuera del lienzo es fuera de la figura. Si se tratara como «sigue»,
        //  media silueta cortada saldría plana.
        const cortada = F.disco(24, 24, 2, 12, 10)
        let b4 = P.nuevo(24, 24)
        F.cuerpo(b4, cortada, { rampa: ramp, luz: "O", grosor: 3, amplitud: 2, contorno: false })
        const pegado = lumaEn(b4, cortada, 0, 10, 1, 14)
        const lejos = lumaEn(b4, cortada, 9, 10, 11, 14)
        ck("una silueta cortada por el lienzo se sombrea igual",
           pegado > lejos + 4, Math.round(pegado) + " vs " + Math.round(lejos))

        console.log(malas ? "\n" + malas + " FALLOS" : "\nla figura pasa entera")
        fin.start()
    }
    Timer { id: fin; interval: 120; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 30000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

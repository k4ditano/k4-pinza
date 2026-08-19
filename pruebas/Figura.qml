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


        // ── medir ────────────────────────────────────────────────
        //
        //  Una referencia sólo sirve si de ella salen NÚMEROS. Y los números
        //  tienen que ser comparables entre dibujos de tamaños distintos, que
        //  es el caso de verdad: un sprite de 96 contra uno de 40.
        const alta = F.rect(40, 40, 16, 6, 8, 28)
        const baja = F.rect(20, 20, 8, 3, 4, 14)      // la misma forma, a otra escala
        const gorda = F.rect(40, 40, 10, 6, 20, 28)

        const pa = F.perfil(alta, 8), pb = F.perfil(baja, 8)
        ck("el perfil sale normalizado, así que no depende del tamaño",
           pa.every((f, i) => Math.abs(f.ancho - pb[i].ancho) < 0.06),
           pa[0].ancho + " vs " + pb[0].ancho)
        ck("y sí distingue una figura más ancha",
           Math.abs(F.perfil(gorda, 8)[0].ancho - pa[0].ancho) < 0.06 === false ||
           F.perfil(gorda, 8)[0].ancho > 0.9,
           F.perfil(gorda, 8)[0].ancho)

        ck("el solape de algo consigo mismo es 1", F.solape(alta, alta).iou === 1)
        ck("y con la misma forma a otra escala, casi 1",
           F.solape(alta, baja).iou > 0.95, F.solape(alta, baja).iou)
        ck("pero con una forma distinta, bastante menos",
           F.solape(alta, gorda).iou < 0.6,
           F.solape(alta, gorda).iou + " · relación " + JSON.stringify(F.solape(alta, gorda).relacion))

        //  Encontrar el desplazamiento es la mitad de la medida: dos siluetas
        //  iguales corridas dos píxeles no son dos siluetas distintas.
        const corrida = F.mueve(F.disco(40, 40, 20, 20, 9), 2, -1)
        const quieta = F.disco(40, 40, 20, 20, 9)
        ck("y encuentra el desplazamiento entre dos iguales",
           F.solape(corrida, quieta).iou > 0.97, JSON.stringify(F.solape(corrida, quieta)))

        ck("una figura simétrica se sabe simétrica", F.simetria(F.disco(32,32,16,16,9)) > 0.98)
        //  La simetría se mide sobre la propia caja, así que un disco lo es
        //  esté donde esté: lo asimétrico es tener un bulto a un lado.
        const torcida = F.une(F.disco(32,32,16,16,9), F.disco(32,32,25,12,4))
        ck("y una con un bulto a un lado, no", F.simetria(torcida) < 0.85, F.simetria(torcida))

        const cm = F.centro(F.rect(20, 20, 4, 2, 6, 4))
        ck("el centro de masa cae donde debe", Math.abs(cm.x - 6.5) < 0.01 && Math.abs(cm.y - 3.5) < 0.01,
           cm.x + "," + cm.y)

        //  Sacarle las rampas a un dibujo es lo que permite hacer una
        //  variante: una rampa es sustituible, una lista de colores no.
        let mez = P.nuevo(20, 20)
        F.cuerpo(mez, F.rect(20,20,0,0,10,20), { rampa: F.rampa("#c03434", 5), contorno: false })
        F.cuerpo(mez, F.rect(20,20,10,0,10,20), { rampa: F.rampa("#3455c0", 5), contorno: false })
        const rs = F.rampasDe(mez)
        ck("agrupa los colores en las rampas con las que se pintó", rs.length === 2,
           rs.length + " rampas: " + rs.map((r) => r.colores.length).join("+"))
        ck("y cada una va de oscuro a claro",
           rs.every((r) => r.colores.every((c, i) =>
               i === 0 || P.luma(P.deHex(c)) >= P.luma(P.deHex(r.colores[i-1])))))
        let conGris = P.nuevo(20, 20)
        F.cuerpo(conGris, F.rect(20,20,0,0,20,20), { rampa: F.rampa("#c03434", 5), contorno: false })
        F.pinta(conGris, F.rect(20,20,2,2,4,4), "#808080")
        ck("y los neutros van a su propio grupo, no arrastran a ninguna rampa",
           F.rampasDe(conGris).some((r) => r.tono === null),
           JSON.stringify(F.rampasDe(conGris).map((r) => r.tono)))

        const an = F.analiza(mez)
        ck("analizar devuelve la caja, el centro y el perfil de una vez",
           an.limites.w === 20 && an.perfil.length === 16 && an.rampas.length === 2,
           JSON.stringify(an.limites))


        // ── qué es contorno ──────────────────────────────────────
        //
        //  Adivinarlo por el color es adivinar: agrupando por tono, el negro
        //  del contorno y el blanco de un brillo caen los dos en «los
        //  neutros». El contorno no es un color, es una POSICIÓN.
        let dib = P.nuevo(20, 20)
        const redonda = F.disco(20, 20, 10, 10, 7)
        F.cuerpo(dib, redonda, { rampa: F.rampa("#c04040", 5), contorno: false })
        F.pinta(dib, F.borde(redonda), "#000000")
        //  Un ojo NEGRO por dentro: el mismo color que el contorno, en un
        //  sitio que no es contorno. Es el caso que rompe cualquier regla
        //  basada en el color.
        F.pinta(dib, F.disco(20, 20, 8, 8, 1.5), "#000000")

        const con = F.contornoDe(dib)
        ck("el contorno se reconoce por dónde está, no por qué color es",
           con.colores.length === 1 && con.colores[0] === "#000000",
           JSON.stringify(con.colores))
        ck("y cubre el anillo entero", con.cubren > 0.98, con.cubren)

        const negro = con.todos.filter((c) => c.color === "#000000")[0]
        ck("el negro ES el contorno", negro.delAnillo > 0.98, negro.delAnillo)
        ck("pero no todo el negro está en el contorno: el ojo también es negro",
           negro.suyoFuera < 0.95, negro.suyoFuera)

        //  Un contorno que NO es negro tiene que salir igual: si sólo valiera
        //  para el negro, sería la misma regla por color con otro nombre.
        let dib2 = P.nuevo(20, 20)
        F.cuerpo(dib2, redonda, { rampa: F.rampa("#4080c0", 5), contorno: false })
        F.pinta(dib2, F.borde(redonda), "#3b2a1a")
        ck("y un contorno marrón se reconoce igual que uno negro",
           F.contornoDe(dib2).colores[0] === "#3b2a1a",
           JSON.stringify(F.contornoDe(dib2).colores))

        ck("analizar lo trae de serie, que es lo que hace que no se olvide",
           F.analiza(dib).contorno.colores[0] === "#000000")

        //  El caso que costó encontrar: en un sprite PEQUEÑO casi todo el
        //  dibujo está a un píxel del borde, así que colores del CUERPO
        //  aparecen en el anillo con un peso nada despreciable. Acumulando
        //  hasta cubrir el 90 % se colaban como contorno — y un color
        //  protegido por error es un color que el recolor no toca: media
        //  variante sin recolorear y ninguna queja.
        let chico = P.nuevo(12, 12)
        const bolita = F.disco(12, 12, 6, 6, 4)
        F.cuerpo(chico, bolita, { rampa: F.rampa("#c08040", 5), contorno: false })
        F.pinta(chico, F.borde(bolita), "#000000")
        //  Y se le muerde el contorno por un lado, como hacen los sprites de
        //  verdad donde asoma un ala o un pico.
        F.pinta(chico, F.corta(F.borde(bolita), F.rect(12,12,7,0,5,4)), "#f0e0c0")
        const cc = F.contornoDe(chico)
        ck("en un dibujo pequeño, un color de cuerpo en el borde no es contorno",
           cc.colores.length === 1 && cc.colores[0] === "#000000",
           JSON.stringify(cc.colores) + " · manda " + cc.manda)

        //  Pero un contorno de DOS tonos sí existe —matizado por el lado de la
        //  luz— y entonces los dos pesan parecido y hay que admitir los dos.
        let dos = P.nuevo(20, 20)
        F.cuerpo(dos, redonda, { rampa: F.rampa("#4080c0", 5), contorno: false })
        F.pinta(dos, F.borde(redonda), "#101018")
        F.pinta(dos, F.corta(F.borde(redonda), F.rect(20,20,0,0,20,10)), "#404860")
        const cd = F.contornoDe(dos)
        ck("y un contorno matizado en dos tonos se admite entero",
           cd.colores.length === 2, JSON.stringify(cd.colores))

        console.log(malas ? "\n" + malas + " FALLOS" : "\nla figura pasa entera")
        fin.start()
    }
    Timer { id: fin; interval: 120; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 30000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

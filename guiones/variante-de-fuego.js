//  Una variante de estilo, sin dibujar nada.
//
//  Ejemplo largo a propósito: es la técnica entera de hacer un bicho «pero de
//  fuego» a partir del que ya existe, con las tres cosas que hay que saber
//  antes de tocar un píxel.
//
//  1 · SE MIDE ANTES DE TOCAR. `F.analiza` dice qué colores hay, agrupados en
//      las rampas con las que se pintó, y —lo que importa— cuáles forman el
//      contorno.
//
//  2 · EL CONTORNO NO SE TOCA. Y no se reconoce por su color, que puede ser
//      cualquiera, sino por dónde está: los píxeles con algún vecino
//      transparente. Un pack suele tener una convención de contorno —el de
//      crabh es negro puro en todos sus bichos— y un solo sprite que la rompa
//      canta desde lejos.
//
//  3 · SE SUSTITUYE POR ESCALÓN, no por color. Cada color se coloca en su
//      rampa, se mira en qué peldaño cae por luminancia, y se cambia por el
//      que ocupa ese mismo peldaño en la rampa de destino. La sombra sigue
//      siendo sombra, y por eso el bicho se sigue reconociendo.
//
//  Probado sobre el Walk de un Pidgey de crabh: cuarenta celdas —ocho caras
//  por cinco fotogramas— en una pasada, con la silueta intacta.

const F = pinza.fig, P = pinza.px

//  La rampa de fuego, escrita a mano y no generada.
//
//  `F.rampa` gira el tono hacia el AZUL en las sombras, que es lo correcto
//  para casi todo —una sombra real es fría— y es exactamente lo contrario de
//  lo que quiere el fuego: la sombra de una brasa no es azulada, es rojo
//  profundo. El camino de tono del fuego es rojo → naranja → amarillo y no
//  pasa por ningún otro sitio, así que se escribe.
//
//  La del pack tampoco vale de base: son nueve naranjas medios, sin carbón
//  abajo ni brasa arriba, y con los medios demasiado tostados. Esto carga los
//  medios hacia el ROJO y deja el amarillo sólo para lo más caliente.
const FUEGO = [
    "#2a0806", "#4d0f08", "#78160b", "#9e1d0d", "#bd2810",
    "#d43a14", "#e4511a", "#ef6d1e", "#f78d25", "#fbad35",
    "#fdcb5c", "#ffe79c"
].map((h) => P.deHex(h))

const ORO = ["#5a2a06", "#8f4409", "#c06510", "#e08a18", "#f2ac2a",
             "#fbc94e", "#ffe485"].map((h) => P.deHex(h))   // pico y patas

/** Dónde cae un color dentro de su rampa, de 0 (lo más oscuro) a 1. */
function escalon(c, rampa) {
    const l = rampa.map((x) => P.luma(P.deHex(x)))
    const lo = Math.min.apply(null, l), hi = Math.max.apply(null, l)
    if (hi - lo < 1) return 0.5
    return (P.luma(c) - lo) / (hi - lo)
}

/**
 * El color de una rampa en la posición `t`, dentro de un tramo.
 *
 * El tramo importa y es lo que costó ver: mapeando el cuerpo a la rampa
 * ENTERA, su tono más oscuro caía en el carbón —el mismo valor que el
 * contorno— y la forma de dentro desaparecía: el bicho quedaba en silueta
 * plana. Los números decían que la luminancia había SUBIDO, así que no era
 * cuestión de aclarar nada; era que el contorno había dejado de ser el punto
 * más oscuro del dibujo. Se le reservan los dos escalones de abajo.
 */
function enRampa(t, rampa, desde, hasta) {
    const a = desde === undefined ? 0 : desde
    const b = hasta === undefined ? rampa.length - 1 : hasta
    const i = Math.max(0, Math.min(rampa.length - 1, Math.round(a + t * (b - a))))
    return rampa[i]
}

// ── lo primero: qué es contorno ────────────────────────────────
//
//  Antes de tocar un solo píxel. El contorno NO es un color, es una posición:
//  los píxeles opacos con algún vecino transparente. Y se respeta.
//
//  La primera versión de esto lo teñía —un contorno negro sobre fuego parece
//  un agujero recortado, me dije—. Medido: en crabh, el 100 % del borde de la
//  silueta es negro puro en TODOS los bichos. No era un gusto que mejorar, era
//  la convención de la casa, y un solo bicho con el contorno teñido canta
//  desde lejos al lado de los demás.
//
//  Y lo peor no era la decisión: era cómo se tomaba. El contorno caía en «los
//  neutros» junto al blanco de los brillos y se separaban por luminancia. Eso
//  funciona hasta que un bicho tiene el contorno marrón, o un ojo casi negro.
const analisis = F.analiza(pinza.compuesto())
const CONTORNO = {}
for (let i = 0; i < analisis.contorno.colores.length; i++)
    CONTORNO[analisis.contorno.colores[i]] = true
pinza.log("contorno detectado: " + analisis.contorno.colores.join(" ")
          + " (cubre el " + Math.round(analisis.contorno.cubren * 100) + "% del borde)")

// ── el mapa de sustitución, sacado del propio dibujo ───────────
const rampas = analisis.rampas
const mapa = {}
let cuerpo = null, adorno = null
for (let i = 0; i < rampas.length; i++) {
    const r = rampas[i]
    if (r.tono === null) continue                  // los neutros, aparte
    if (!cuerpo || r.pixeles > cuerpo.pixeles) { adorno = cuerpo; cuerpo = r }
    else if (!adorno || r.pixeles > adorno.pixeles) adorno = r
}

for (let i = 0; i < rampas.length; i++) {
    const r = rampas[i]
    for (let j = 0; j < r.colores.length; j++) {
        const c = P.deHex(r.colores[j])
        //  El contorno no se toca. Es lo primero que se comprueba y por eso
        //  va antes que cualquier otra regla.
        if (CONTORNO[r.colores[j]]) continue

        let nuevo
        if (r.tono === null) {
            //  Los neutros que NO son contorno: el blanco de los brillos, que
            //  sí se calienta. Un brillo blanco puro sobre fuego lee como
            //  metal, y este bicho no es de metal.
            nuevo = P.luma(c) < 90 ? P.deHex("#3a1509") : P.deHex("#fff3d0")
        } else if (r === adorno) {
            nuevo = enRampa(escalon(c, r.colores), ORO, 1, ORO.length - 1)
        } else {
            nuevo = enRampa(escalon(c, r.colores), FUEGO, 2, FUEGO.length - 1)
        }
        mapa[r.colores[j]] = nuevo
    }
}
pinza.log("sustituyendo " + Object.keys(mapa).length + " colores")

// ── aplicarlo a TODAS las celdas ───────────────────────────────
//
//  Las ocho caras y los cinco fotogramas de una vez. Hacerlo cara por cara es
//  donde se cuela el fallo que sólo ves cuando el bicho echa a andar.
let tocados = 0
const n = pinza.paraCada((buf) => {
    pinza.paraCadaPixel(buf, (c) => {
        if (c[3] < 8) return
        const k = P.aHex(c)
        if (!mapa[k]) return
        tocados++
        const d = mapa[k]
        return [d[0], d[1], d[2], c[3]]
    })
})

// ── la cresta arde ─────────────────────────────────────────────
//
//  Un paso más caliente en la parte alta de la silueta. No son llamas
//  dibujadas: es que la luz de algo que arde no viene de un foco, sale del
//  propio bicho, y con dejarlo más caliente arriba ya se lee.
pinza.paraCada((buf) => {
    const l = P.limites(buf, 8)
    if (!l) return
    const corte = l.y + Math.round(l.h * 0.34)
    pinza.paraCadaPixel(buf, (c, x, y) => {
        if (c[3] < 8 || y > corte) return
        for (let i = 0; i < FUEGO.length - 2; i++)
            if (P.distancia([FUEGO[i][0], FUEGO[i][1], FUEGO[i][2], c[3]], c) < 6)
                return [FUEGO[i + 2][0], FUEGO[i + 2][1], FUEGO[i + 2][2], c[3]]
    })
})

pinza.log("celdas " + n + " · píxeles sustituidos " + tocados)


// ═══════════════════════════════════════════════════════════════
// llamitas
// ═══════════════════════════════════════════════════════════════
//
//  Ambientales: pequeñas, por arriba, y subiendo con el ciclo de andar.
//
//  Tres cosas que no son un capricho:
//
//  · Nacen del PERFIL DE ARRIBA de cada celda, no de una posición fija. Cada
//    cara y cada fotograma tienen la cabeza en otro sitio —el bicho bota al
//    andar—, y unas llamas clavadas en unas coordenadas se despegarían de él
//    en cuanto se moviera.
//
//  · La fase depende del fotograma, así que el ciclo CIERRA: la llama que se
//    apaga en el último fotograma es la que vuelve a nacer en el primero. Sin
//    eso, la animación da un salto cada vuelta y se nota más que las llamas.
//
//  · No llevan contorno. Son lo único del dibujo que emite luz en vez de
//    recibirla, y un contorno negro alrededor de una llama la convierte en una
//    pegatina con forma de llama.

const LLAMA = ["#8f1f09", "#c8340f", "#ef5d1a", "#fb8f27", "#fdc254", "#fff0b8"]
    .map((h) => P.deHex(h))

/**
 * La CORONILLA: los píxeles más altos, y sólo los que están de verdad arriba.
 *
 * Con el perfil entero salían llamas del canto del ala, en horizontal, porque
 * el ala también tiene un píxel más alto que los de debajo. Se filtra a lo que
 * queda a dos píxeles de la cima real, que es lo que un fuego que sale del
 * bicho haría: subir por encima de la cabeza, no brotarle del costado.
 */
function coronilla(buf) {
    const l = P.limites(buf, 8)
    if (!l) return []
    const cols = []
    let arriba = 1e9
    for (let x = l.x; x < l.x + l.w; x++)
        for (let y = l.y; y < l.y + l.h; y++)
            if (P.lee(buf, x, y)[3] > 8) {
                cols.push({ x: x, y: y })
                if (y < arriba) arriba = y
                break
            }
    return cols.filter((c) => c.y <= arriba + 2)
}

const NF = pinza.doc.fotogramas
let chispas = 0, vacias = 0

for (let o = 0; o < pinza.doc.orientaciones.length; o++) {
    for (let f = 0; f < NF; f++) {
        const b = pinza.celda(0, f, o)
        const c = coronilla(b)
        if (c.length < 2) { vacias++; continue }
        const antes = chispas

        //  Dos, no cuatro. «Ambiental» es que se note cuando miras y no cuando
        //  no miras; con cuatro llamas de tres píxeles el bicho llevaba un
        //  gorro de cocinero.
        const donde = [0.3, 0.7]
        for (let k = 0; k < donde.length; k++) {
            const a = c[Math.floor(donde[k] * (c.length - 1))]
            const fase = ((f + k * 3 + o) % NF) / NF

            //  La llama se adapta al hueco: ENCOGE, no desaparece.
            //
            //  Con una subida fija se salían por arriba en 22 de las 40
            //  celdas —la cabeza no está a la misma altura en cada cara y el
            //  bicho además bota al andar—, y saltándose las que no cabían el
            //  efecto PARPADEABA: dos fotogramas del ciclo se quedaban sin
            //  nada. Ambiental es una presencia constante; algo que aparece y
            //  desaparece cada dos fotogramas es un fallo con buena intención.
            const hueco = a.y                     // filas libres sobre la cabeza
            if (hueco < 2) continue               // pegado al techo: aquí no cabe
            const r = Math.max(0.4, Math.min(0.95 - fase * 0.45, (hueco - 1) / 2))
            const subida = Math.max(0, Math.min(3.4, hueco - 2))
            const cx = a.x + Math.sin((fase + k * 0.4) * 6.2832) * 0.55
            const cy = Math.max(1.8 * r + 1, a.y - 1.2 - fase * subida)

            //  Nace naranja y muere roja, y el amarillo se reserva al primer
            //  fotograma de su vida y a un solo píxel. Un núcleo claro en cada
            //  llama las convierte en cuentas de collar.
            const tono = Math.max(1, Math.min(4,
                            Math.round(4 - fase * 3.2)))
            F.pinta(b, F.capsula(pinza.doc.ancho, pinza.doc.alto,
                                 cx, cy + r * 0.6, cx, cy - r * 0.8, r), LLAMA[tono])
            if (fase < 0.25)
                F.pinta(b, F.disco(pinza.doc.ancho, pinza.doc.alto, cx, cy, 0.45),
                        LLAMA[5])
            chispas++
        }
        if (chispas === antes) vacias++
    }
}
pinza.log("llamas: " + chispas + " · celdas sin ninguna: " + vacias)

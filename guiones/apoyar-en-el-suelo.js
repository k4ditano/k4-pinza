//  Baja la figura hasta que apoye, dejando las filas vacías que le digas.
//
//  crabh mide de los PÍXELES cuántas filas vacías hay bajo el dibujo y las usa
//  para poner los pies en el suelo. Si cada fotograma tiene un hueco distinto,
//  el bicho da botes al andar sin que nadie sepa por qué. Esto lo iguala.

const HUECO = 0      // filas vacías que quieres dejar por debajo
let ajustadas = 0

pinza.paraCada((buf) => {
    const l = pinza.px.limites(buf, 8)
    if (!l) return
    const abajo = buf.h - (l.y + l.h)
    const dy = abajo - HUECO
    if (!dy) return
    const copia = pinza.px.clonar(buf)
    for (let i = 0; i < buf.d.length; i++) buf.d[i] = 0
    pinza.px.vuelca(buf, copia, 0, dy)
    ajustadas++
})

pinza.log("apoyadas", ajustadas, "celdas con", HUECO, "filas de hueco")

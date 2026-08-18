//  Centra el dibujo dentro de su lienzo, celda a celda.
//
//  Útil después de importar arte de fuera, que casi nunca viene centrado, y
//  antes de exportar una hoja: si cada fotograma está descolocado un píxel, la
//  animación tiembla en el juego sin que se vea por qué.

let movidas = 0

pinza.paraCada((buf) => {
    const l = pinza.px.limites(buf)
    if (!l) return
    const dx = Math.round((buf.w - l.w) / 2) - l.x
    const dy = Math.round((buf.h - l.h) / 2) - l.y
    if (!dx && !dy) return
    const copia = pinza.px.clonar(buf)
    for (let i = 0; i < buf.d.length; i++) buf.d[i] = 0
    pinza.px.vuelca(buf, pinza.px.recorte(copia, l.x, l.y, l.w, l.h), l.x + dx, l.y + dy)
    movidas++
})

pinza.log("centradas", movidas, "celdas")

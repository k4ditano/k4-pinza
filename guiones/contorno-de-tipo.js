//  Pone contorno a la silueta con el tono más oscuro de la rampa activa.
//
//  El contorno es la decisión que más se repite dibujando y la que peor sienta
//  hacer a mano en ocho orientaciones. Esto lo hace en todas de una vez.

const rampa = pinza.rampas[0]
const oscuro = rampa.colores[0]
let tocadas = 0

pinza.paraCada((buf, capa, f, d) => {
    if (capa.tipo === "referencia") return
    const con = pinza.px.contornea(buf, oscuro, false, "fuera")
    for (let i = 0; i < buf.d.length; i++) buf.d[i] = con.d[i]
    tocadas++
})

pinza.log("contorneadas", tocadas, "celdas con", pinza.hex(oscuro))

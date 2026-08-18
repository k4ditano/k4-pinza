import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../core/herramientas.js" as H

ShellRoot {
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    function ctx(buf, extra) {
        const c = {
            buf: buf, ancho: buf.w, alto: buf.h,
            selContiene: function () { return true },
            alfaBloqueado: false, tamaño: 1, puntaCuadrada: false, pincel: null,
            trama: "solido", proporcionTrama: 1,
            simetriaH: false, simetriaV: false, ejeX: -1, ejeY: -1, baldosa: false,
            primario: [214, 108, 52, 255], secundario: [118, 193, 56, 255],
            trazoPerfecto: false, tolerancia: 8, contiguo: true, ochoVecinos: false,
            relleno: false, fuerza: 0.5, pasoSombreado: 1,
            tipoDegradado: "lineal", degradadoTramado: true
        }
        if (extra) for (const k in extra) c[k] = extra[k]
        return c
    }

    Component.onCompleted: {
        const naranja = [214, 108, 52, 255]

        // ── la brocha respeta las reglas ─────────────────────────
        let b = P.nuevo(8, 8)
        let br = new H.Brocha(ctx(b))
        br.pixel(3, 3, naranja)
        ck("la brocha pinta donde se le dice", P.lee(b, 3, 3).join() === naranja.join())
        ck("y apunta el rectángulo sucio",
           br.rect().x === 3 && br.rect().y === 3 && br.rect().w === 1 && br.rect().h === 1)

        b = P.nuevo(8, 8)
        br = new H.Brocha(ctx(b, { selContiene: function (x, y) { return x < 4 } }))
        br.pixel(2, 0, naranja); br.pixel(6, 0, naranja)
        ck("la brocha NO pinta fuera de la selección",
           P.lee(b, 2, 0)[3] === 255 && P.lee(b, 6, 0)[3] === 0)

        b = P.nuevo(8, 8)
        br = new H.Brocha(ctx(b, { alfaBloqueado: true }))
        br.pixel(1, 1, naranja)
        ck("con el alfa bloqueado no nacen píxeles nuevos", P.lee(b, 1, 1)[3] === 0)

        b = P.nuevo(8, 8)
        br = new H.Brocha(ctx(b, { trama: "50" }))
        for (let x = 0; x < 4; x++) br.pixel(x, 0, naranja)
        let pintados = 0
        for (let x = 0; x < 4; x++) if (P.lee(b, x, 0)[3]) pintados++
        ck("la trama del 50% deja la mitad", pintados === 2, pintados + " de 4")

        // ── simetría ─────────────────────────────────────────────
        b = P.nuevo(9, 9)
        br = new H.Brocha(ctx(b, { simetriaH: true }))
        br.sello(1, 4, naranja)
        ck("la simetría horizontal refleja sobre el centro",
           P.lee(b, 1, 4)[3] === 255 && P.lee(b, 7, 4)[3] === 255, "eje en x=4")
        b = P.nuevo(9, 9)
        br = new H.Brocha(ctx(b, { simetriaH: true, simetriaV: true }))
        br.sello(1, 1, naranja)
        let cuatro = 0
        const esquinas = [[1,1],[7,1],[1,7],[7,7]]
        for (let i = 0; i < 4; i++) if (P.lee(b, esquinas[i][0], esquinas[i][1])[3]) cuatro++
        ck("con las dos simetrías salen cuatro", cuatro === 4, cuatro)

        // ── modo baldosa ─────────────────────────────────────────
        b = P.nuevo(8, 8)
        br = new H.Brocha(ctx(b, { baldosa: true }))
        br.pixel(-1, 0, naranja)
        ck("en modo baldosa, salirse por la izquierda entra por la derecha",
           P.lee(b, 7, 0)[3] === 255)

        // ── lápiz ────────────────────────────────────────────────
        b = P.nuevo(8, 8)
        let t = H.crea("lapiz", ctx(b))
        t.abajo(0, 0, 1); t.mueve(3, 0); const r = t.arriba()
        let n = 0; for (let x = 0; x <= 3; x++) if (P.lee(b, x, 0)[3]) n++
        ck("el lápiz une los puntos aunque arrastres rápido", n === 4, n + " píxeles")
        ck("y el rectángulo sucio los cubre", r.x === 0 && r.w === 4 && r.h === 1)

        b = P.nuevo(8, 8)
        t = H.crea("lapiz", ctx(b))
        t.abajo(0, 0, 2)
        ck("el botón derecho pinta con el secundario", P.lee(b, 0, 0)[1] === 193)

        // ── trazo perfecto de verdad ─────────────────────────────
        b = P.nuevo(8, 8)
        t = H.crea("lapiz", ctx(b, { trazoPerfecto: true }))
        t.abajo(0, 0, 1); t.mueve(1, 0); t.mueve(1, 1); t.arriba()
        ck("el trazo perfecto no deja la esquina doble",
           P.lee(b, 0, 0)[3] === 255 && P.lee(b, 1, 1)[3] === 255 && P.lee(b, 1, 0)[3] === 0)

        // ── goma ─────────────────────────────────────────────────
        b = P.nuevo(4, 4)
        for (let i = 0; i < 4; i++) P.pon(b, i, 0, naranja)
        t = H.crea("goma", ctx(b))
        t.abajo(0, 0, 1); t.mueve(1, 0); t.arriba()
        ck("la goma deja alfa cero, no negro",
           P.lee(b, 0, 0).join() === "0,0,0,0" && P.lee(b, 3, 0)[3] === 255)

        // ── cubo ─────────────────────────────────────────────────
        b = P.nuevo(8, 8)
        for (let x = 0; x < 8; x++) P.pon(b, x, 4, [0, 0, 0, 255])
        t = H.crea("cubo", ctx(b))
        t.abajo(0, 0, 1); t.arriba()
        ck("el cubo llena hasta la pared y no la cruza",
           P.lee(b, 7, 0)[3] === 255 && P.lee(b, 0, 5)[3] === 0)

        // ── formas ───────────────────────────────────────────────
        b = P.nuevo(8, 8)
        t = H.crea("rectangulo", ctx(b))
        t.abajo(1, 1, 1); t.mueve(5, 5)
        ck("una forma se ve antes de soltarla", t.vistaPrevia().length === 16)
        ck("y no ha tocado el búfer todavía", P.vacio(b))
        t.arriba()
        ck("al soltar sí pinta", P.lee(b, 1, 1)[3] === 255 && P.lee(b, 3, 3)[3] === 0)

        b = P.nuevo(8, 8)
        t = H.crea("elipse", ctx(b, { relleno: true }))
        t.abajo(0, 0, 1); t.mueve(7, 7); t.arriba()
        ck("una elipse rellena llena el centro y no las esquinas",
           P.lee(b, 4, 4)[3] === 255 && P.lee(b, 0, 0)[3] === 0)

        // ── degradado ────────────────────────────────────────────
        b = P.nuevo(16, 4)
        t = H.crea("degradado", ctx(b))
        t.abajo(0, 0, 1); t.mueve(15, 0); t.arriba()
        let izq = 0, der = 0
        for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) {
            if (P.lee(b, x, y)[0] === 214) izq++
            if (P.lee(b, 15 - x, y)[1] === 193) der++
        }
        ck("el degradado tramado va del primario al secundario", izq > 12 && der > 12,
           "izquierda " + izq + "/16, derecha " + der + "/16")

        // ── sombreado por rampa ──────────────────────────────────
        const rampa = [[40,40,40,255], [120,120,120,255], [200,200,200,255]]
        b = P.nuevo(4, 4)
        P.pon(b, 1, 1, [120, 120, 120, 255])
        P.pon(b, 2, 2, [255, 0, 128, 255])   // un color que no es de la rampa
        t = H.crea("sombreado", ctx(b, {
            vecinoEnRampa: function (c, paso) {
                for (let i = 0; i < rampa.length; i++)
                    if (P.distancia([c[0],c[1],c[2],255], rampa[i]) < 40) {
                        const k = Math.max(0, Math.min(rampa.length - 1, i + paso))
                        return [rampa[k][0], rampa[k][1], rampa[k][2], c[3]]
                    }
                return null
            }
        }))
        t.abajo(1, 1, 1); t.arriba()
        ck("sombrear sube un escalón de la rampa", P.lee(b, 1, 1)[0] === 200)
        t = H.crea("sombreado", ctx(b, { vecinoEnRampa: function () { return null } }))
        t.abajo(2, 2, 1); t.arriba()
        ck("y no toca lo que no está en ninguna rampa", P.lee(b, 2, 2)[0] === 255)

        // ── mover ────────────────────────────────────────────────
        b = P.nuevo(8, 8)
        P.pon(b, 1, 1, naranja)
        t = H.crea("mover", ctx(b))
        t.abajo(1, 1); t.mueve(4, 1)
        ck("al arrastrar, el hueco de origen queda vacío", P.lee(b, 1, 1)[3] === 0)
        ck("y el píxel está en el destino", P.lee(b, 4, 1).join() === naranja.join())
        t.arriba()
        ck("y sigue ahí al soltar", P.lee(b, 4, 1).join() === naranja.join())

        // ── cuentagotas ──────────────────────────────────────────
        b = P.nuevo(4, 4)
        P.pon(b, 2, 2, naranja)
        let cogido = null
        t = H.crea("cuentagotas", ctx(b, { eligeColor: function (c) { cogido = c } }))
        t.abajo(2, 2, 1)
        ck("el cuentagotas coge el color de debajo", cogido && cogido.join() === naranja.join())

        console.log(malas ? "\n" + malas + " FALLOS" : "\nlas herramientas pasan enteras")
        fin.start()
    }
    Timer { id: fin; interval: 120; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 20000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

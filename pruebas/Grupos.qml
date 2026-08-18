//  Grupos de capas y guiones.
//
//  Lo de los grupos que hay que comprobar de verdad no es que la lista se
//  sangre: es que un grupo se compone ENTERO antes de caer sobre lo de abajo.
//  Tres capas al 50 % dentro de un grupo al 50 % no es lo mismo que seis capas
//  al 50 %, y esa diferencia es justo para lo que se agrupa.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S

ShellRoot {
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    Component.onCompleted: {
        const rojo = [255, 0, 0, 255], verde = [0, 255, 0, 255], azul = [0, 0, 255, 255]

        // ── un grupo compone aparte ──────────────────────────────
        S.Documento.nuevo({ nombre: "g", ancho: 4, alto: 4 })
        const fondo = S.Documento.capa(0)
        const b0 = S.Documento.celda(fondo.id, 0, 0, true)
        for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) P.pon(b0, x, y, azul)

        const a = S.Documento.añadeCapa("a")
        const ba = S.Documento.celda(a.id, 0, 0, true)
        for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) P.pon(ba, x, y, rojo)
        const b = S.Documento.añadeCapa("b")
        const bb = S.Documento.celda(b.id, 0, 0, true)
        for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) P.pon(bb, x, y, verde)

        // sin grupo: verde al 50% sobre rojo al 50% sobre azul
        a.opacidad = 0.5; b.opacidad = 0.5
        S.Documento.cambia(); S.Documento.cambiaPixeles(null)
        const suelto = P.lee(S.Documento.compuesto(), 1, 1)
        ck("sin agrupar se apilan una a una", suelto[1] > 100, suelto.join())

        // ahora las dos dentro de un grupo al 100%
        S.Documento.capaActiva = 1
        const g = S.Documento.agrupa(1, "juntas")
        ck("agrupar crea un grupo", g !== null && g.tipo === "grupo")
        ck("y la capa queda dentro", S.Documento.capa(1).grupo === g.id)
        // meter también la otra
        const ib = S.Documento.indiceDe(b.id)
        S.Documento.capa(ib).grupo = g.id
        S.Documento.cambia(); S.Documento.cambiaPixeles(null)
        const enGrupo = P.lee(S.Documento.compuesto(), 1, 1)
        //  Casi el mismo, no el mismo: componer el grupo aparte cuantiza a 8
        //  bits una vez más, y eso deja diferencias de un punto. Le pasa a
        //  cualquier editor con grupos; pedir igualdad exacta sería pedir que
        //  no hubiera grupos.
        let peor = 0
        for (let i = 0; i < 4; i++) peor = Math.max(peor, Math.abs(enGrupo[i] - suelto[i]))
        ck("con el grupo al 100% el resultado es el mismo salvo redondeo",
           peor <= 2, enGrupo.join() + " vs " + suelto.join() + " (peor " + peor + ")")

        // y con el grupo a media opacidad SÍ cambia, y no como capas sueltas
        g.opacidad = 0.5
        S.Documento.cambia(); S.Documento.cambiaPixeles(null)
        const medio = P.lee(S.Documento.compuesto(), 1, 1)
        ck("bajar la opacidad del grupo cambia el resultado",
           medio.join() !== enGrupo.join(), medio.join())
        ck("y deja pasar más del fondo azul", medio[2] > enGrupo[2],
           "azul " + medio[2] + " > " + enGrupo[2])

        // ── esconder el grupo esconde lo de dentro ───────────────
        g.visible = false
        S.Documento.cambia(); S.Documento.cambiaPixeles(null)
        const soloFondo = P.lee(S.Documento.compuesto(), 1, 1)
        ck("esconder el grupo esconde todo lo de dentro",
           soloFondo.join() === azul.join(), soloFondo.join())
        g.visible = true

        // ── sangría, plegado y borrado ──────────────────────────
        ck("la capa de dentro está a una de hondura", S.Documento.hondura(1) === 1)
        ck("y el fondo a cero", S.Documento.hondura(0) === 0)
        g.plegado = true
        ck("plegar el grupo esconde sus hijas de la lista", S.Documento.oculta(1))
        ck("pero no al grupo", !S.Documento.oculta(S.Documento.indiceDe(g.id)))
        g.plegado = false

        const anidado = S.Documento.agrupa(1, "más dentro")
        ck("se pueden anidar grupos", S.Documento.hondura(1) === 2, S.Documento.hondura(1))
        const compAnidado = P.lee(S.Documento.compuesto(), 1, 1)
        ck("y anidar no rompe la composición", compAnidado[3] === 255)

        const antes = S.Documento.nCapas
        S.Documento.borraCapa(S.Documento.indiceDe(g.id))
        ck("borrar un grupo se lleva lo de dentro y no deja huérfanas",
           S.Documento.nCapas === 1, S.Documento.nCapas + " de " + antes)
        ck("y lo que queda se sigue viendo",
           P.lee(S.Documento.compuesto(), 1, 1).join() === azul.join())

        // ── el lienzo y la exportación usan la MISMA composición ─
        S.Documento.nuevo({ nombre: "h", ancho: 4, alto: 4 })
        const f2 = S.Documento.capa(0)
        P.pon(S.Documento.celda(f2.id, 0, 0, true), 1, 1, rojo)
        const c2 = S.Documento.añadeCapa("dentro")
        P.pon(S.Documento.celda(c2.id, 0, 0, true), 2, 2, verde)
        S.Documento.agrupa(1, "gg").opacidad = 0.25
        S.Documento.cambiaPixeles(null)
        const porCompuesto = S.Documento.compuesto()
        const aMano = P.nuevo(4, 4)
        S.Documento.componEn(aMano, 0, 0, null, false)
        ck("componEn por rectángulo entero da lo mismo que compuesto()",
           aMano.d.join() === porCompuesto.d.join())
        const porTrozos = P.nuevo(4, 4)
        for (let y = 0; y < 4; y++)
            S.Documento.componEn(porTrozos, 0, 0, { x: 0, y: y, w: 4, h: 1 }, false)
        ck("y componer fila a fila también, que es lo que hace el lienzo",
           porTrozos.d.join() === porCompuesto.d.join())

        // ── guiones ─────────────────────────────────────────────
        S.Documento.nuevo({ nombre: "guion", ancho: 4, alto: 4, fotogramas: 2 })
        const cap = S.Documento.capa(0)
        for (let f = 0; f < 2; f++) P.pon(S.Documento.celda(cap.id, f, 0, true), 1, 1, azul)
        S.Documento.cambiaPixeles(null)

        const ok = S.Guiones.corre(
            "pinza.paraCada((buf) => { pinza.paraCadaPixel(buf, (c) => c[3] ? pinza.color('#FF0000') : null) })\n"
            + "pinza.log('celdas:', pinza.doc.fotogramas)")
        ck("un guión corre", ok === true, S.Guiones.ultimoError ? S.Guiones.ultimoError.mensaje : "")
        ck("y toca TODAS las celdas, no sólo la visible",
           P.lee(S.Documento.celda(cap.id, 0, 0, false), 1, 1)[0] === 255
           && P.lee(S.Documento.celda(cap.id, 1, 0, false), 1, 1)[0] === 255)
        ck("pinza.log se recoge", S.Guiones.salida.indexOf("celdas: 2") >= 0, S.Guiones.salida.trim())
        ck("y todo el guión es UN paso del historial", S.Historial.pasos === 1, S.Historial.pasos)
        S.Historial.deshace()
        ck("deshacerlo lo deshace entero",
           P.lee(S.Documento.celda(cap.id, 0, 0, false), 1, 1).join() === azul.join())

        const roto = S.Guiones.corre("esto no es javascript válido {{{")
        ck("un guión que no compila no revienta el programa", roto === false)
        ck("y lo dice", S.Guiones.ultimoError !== null
           && S.Guiones.ultimoError.mensaje.indexOf("no compila") >= 0,
           S.Guiones.ultimoError ? S.Guiones.ultimoError.mensaje : "")

        const pasos = S.Historial.pasos
        const revienta = S.Guiones.corre("pinza.paraCada((b) => { b.noExiste.nada() })")
        ck("uno que revienta a mitad tampoco tumba nada", revienta === false)
        ck("y deja el documento como estaba",
           P.lee(S.Documento.celda(cap.id, 0, 0, false), 1, 1).join() === azul.join())

        console.log(malas ? "\n" + malas + " FALLOS" : "\ngrupos y guiones pasan enteros")
        fin.start()
    }
    Timer { id: fin; interval: 150; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 25000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

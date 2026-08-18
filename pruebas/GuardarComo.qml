//  «Guardar como» con una criatura abierta se lleva la criatura ENTERA.
//
//  Guardaba sólo la acción que estabas mirando —una de ocho— y encima le ponía
//  el nombre de la criatura, así que acababas con un `Bicho.pinza` suelto que
//  parecía el bicho entero y era su Shoot. Sin error y sin aviso: te enterabas
//  al abrirlo en otra parte y encontrarte una sola animación.
//
//  Pasó de verdad, con un shiny al que se le habían recoloreado las ocho
//  acciones. El trabajo estaba a salvo en la carpeta de la especie, pero la
//  copia que se llevó no era lo que decía ser, que es lo peligroso.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property string base: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-gcomo"

    FloatingWindow {
        implicitWidth: 300; implicitHeight: 200; visible: true
        V.Exportador { id: ex }
        Component.onCompleted: { S.Proyecto.exportador = ex; S.Especie.exportador = ex }
    }
    Connections {
        target: S.Packs
        function onCargadosCambiaron() { arranca.start() }
    }
    Timer { id: arranca; interval: 250; onTriggered: raiz.prepara() }
    Connections {
        target: S.Especie
        function onFalla(q, m) { console.log("   (falla " + q + ": " + m + ")") }
    }

    function pinta(color) {
        const b = S.Documento.celdaActiva(true)
        for (let y = 2; y < S.Documento.alto - 2; y++)
            for (let x = 2; x < S.Documento.ancho - 2; x++) P.pon(b, x, y, color)
        S.Documento.cambiaPixeles(null)
    }

    function prepara() {
        S.Forja.creaCarpeta(base, () => {
            S.Forja.pide("comprobar", { raiz: base, guiones: [
                ["sh", "-c", "rm -rf '" + base + "'/*.especie '" + base + "'/copia"]
            ] }, () => {
                S.Packs.elige("crabh")
                S.Packs.apunta("crabh", base)
                S.Especie.nueva({ nombre: "Brillo", dex: 10902 })
                S.Especie.guarda(base + "/Brillo.especie", () => paso1())
            })
        })
    }

    //  Tres acciones dibujadas, como quien recolorea un bicho entero.
    function paso1() {
        S.Especie.editaAccion("Idle", () => {
            raiz.pinta([90, 160, 240, 255])
            S.Especie.editaAccion("Walk", () => {
                raiz.pinta([90, 160, 240, 255])
                S.Especie.editaAccion("Shoot", () => {
                    raiz.pinta([90, 160, 240, 255])
                    paso2()
                })
            })
        })
    }

    //  Y ahora «guardar como» a otra carpeta, mirando Shoot.
    function paso2() {
        S.Forja.creaCarpeta(base + "/copia", () => {
            S.Especie.guardaComo(base + "/copia", () => {
                const destino = base + "/copia/Brillo.especie"
                S.Forja.pide("listar", { ruta: destino }, (r) => {
                    const hay = (r.ficheros || []).map((e) => e.nombre)
                    ck("la copia tiene la ficha de la criatura",
                       hay.indexOf("especie.json") >= 0, hay.join(" "))
                    ck("y las acciones que habías dibujado, no sólo la que mirabas",
                       hay.indexOf("Idle.pinza") >= 0 && hay.indexOf("Walk.pinza") >= 0
                       && hay.indexOf("Shoot.pinza") >= 0,
                       hay.filter((n) => n.indexOf(".pinza") > 0).join(" "))
                    ck("y NO un proyecto suelto con el nombre de la criatura",
                       hay.indexOf("Brillo.pinza") < 0)
                    paso3(destino)
                })
            })
        })
    }

    //  Que la copia sea de verdad, con los píxeles dentro, y que se siga
    //  trabajando sobre ella y no sobre el original.
    function paso3(destino) {
        ck("y a partir de ahí trabajas sobre la copia",
           S.Especie.d && S.Especie.d.ruta === destino,
           S.Especie.d ? S.Especie.d.ruta : "sin especie")

        S.Forja.leeTexto(destino + "/Walk.pinza/proyecto.json", (r) => {
            let m = null
            try { m = JSON.parse(r.texto) } catch (e) {}
            if (!m) { ck("la acción copiada es un documento", false); fin.start(); return }
            const png = destino + "/Walk.pinza/celdas/" + m.capas[0].id + ".0.0.png"
            ex.dePng(png, (b) => {
                ck("y una acción que no mirabas llega con su dibujo",
                   !!b && !P.vacio(b), png)
                fin.start()
            })
        })
    }

    Timer { id: fin; interval: 250; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "")
        Qt.exit(raiz.malas ? 1 : 0)
    } }
    Timer { interval: 80000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

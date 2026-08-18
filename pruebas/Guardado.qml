//  Que lo que dibujas acabe en el disco, y que si no acaba te enteres.
//
//  Tres agujeros que había, los tres en el mismo sitio: el programa daba por
//  guardado lo que no lo estaba.
//
//   1. La ficha de la criatura —el especie.json— sólo se escribía al crearla,
//      al exportarla o pulsando un botón concreto. Cambiar de acción recogía
//      del documento los fotogramas, las duraciones y el hitFrame… y lo dejaba
//      todo en memoria. Se veía en que `ultima` no se guardaba nunca: cerrabas
//      y volvías siempre a la primera acción. Lo que no se veía era peor: si
//      añadías un fotograma, el .pinza tenía la verdad y la ficha se quedaba
//      con lo de antes.
//
//   2. Abrir otra criatura, cerrar la que tenías o exportar sustituían el
//      documento sin guardar lo que llevaras dibujado. Exportar era el peor de
//      los tres, porque abre las ocho acciones una detrás de otra: exportabas
//      la versión de disco y encima perdías la de pantalla.
//
//   3. Un proyecto.json que no describiera un documento se abría igual y
//      dejaba un fantasma de 0×0 que decía estar abierto. Eso es lo que hace
//      daño de verdad: el siguiente guardado escribe el fantasma encima de las
//      celdas buenas, que sí estaban en la carpeta.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property string base: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-guardado"

    FloatingWindow {
        implicitWidth: 300; implicitHeight: 200
        visible: true
        V.Exportador { id: ex }
        Component.onCompleted: { S.Proyecto.exportador = ex; S.Especie.exportador = ex }
    }
    Connections {
        target: S.Packs
        function onCargadosCambiaron() { arranca.start() }
    }
    Timer { id: arranca; interval: 250; onTriggered: raiz.prepara() }

    function pinta(color) {
        const b = S.Documento.celdaActiva(true)
        for (let y = 2; y < S.Documento.alto - 2; y++)
            for (let x = 2; x < S.Documento.ancho - 2; x++) P.pon(b, x, y, color)
        S.Documento.cambiaPixeles(null)
    }

    /** Lee un json del disco por la forja, sin pasar por el documento. */
    function lee(ruta, cb) {
        S.Forja.leeTexto(ruta, (r) => {
            if (!r.bien || !r.texto) { cb(null); return }
            try { cb(JSON.parse(r.texto)) } catch (e) { cb(null) }
        })
    }

    function prepara() {
        S.Forja.creaCarpeta(base, () => {
            S.Forja.pide("comprobar", { raiz: base, guiones: [
                ["sh", "-c", "rm -rf '" + base + "'/*.especie"]
            ] }, () => {
                S.Packs.elige("crabh")
                S.Packs.apunta("crabh", base)
                S.Especie.nueva({ nombre: "Prueba", dex: 10900 })
                S.Especie.guarda(base + "/Prueba.especie", () => paso1())
            })
        })
    }

    // ── 1 · cambiar de acción escribe la ficha ──────────────────
    function paso1() {
        S.Especie.editaAccion("Idle", () => {
            raiz.pinta([200, 40, 40, 255])
            //  Un fotograma de más: eso vive en la ficha, no en el .pinza.
            S.Documento.añadeFotograma()
            const nFot = S.Documento.nFotogramas
            S.Especie.editaAccion("Walk", () => {
                lee(base + "/Prueba.especie/especie.json", (d) => {
                    ck("cambiar de acción escribe la ficha en el disco", d !== null)
                    if (!d) { fin.start(); return }
                    ck("y con ella la acción donde te has quedado", d.ultima === "Walk", d.ultima)
                    ck("y el fotograma que añadiste a la anterior",
                       d.acciones.Idle.fotogramas === nFot,
                       d.acciones.Idle.fotogramas + " en la ficha, " + nFot + " en el documento")
                    ck("y que esa acción ya tiene dibujo", d.acciones.Idle.hecha === true)
                    ck("sin marcar como dibujada la que está en blanco",
                       d.acciones.Walk.hecha === false)
                    paso2()
                })
            })
        })
    }

    // ── 2 · cerrar y abrir no pierde lo de en medio ─────────────
    function paso2() {
        //  Se dibuja y NO se guarda a mano: cerrar tiene que hacerlo.
        raiz.pinta([40, 200, 60, 255])
        ck("hay algo sin guardar antes de cerrar", S.Documento.sucio)
        const ruta = S.Documento.ruta
        S.Especie.cierra(() => {
            ck("cerrar la criatura la suelta", !S.Especie.abierta)
            S.Proyecto.abre(ruta, (bien) => {
                ck("y lo que estabas dibujando estaba guardado", bien
                   && !P.vacio(S.Documento.compuesto(0, 0)),
                   "en " + ruta)
                paso3()
            })
        })
    }

    // ── 3 · un proyecto que no lo es no se abre ─────────────────
    function paso3() {
        const roto = base + "/roto.pinza"
        S.Forja.escribeTexto(roto + "/proyecto.json", "{}\n", () => {
            S.Proyecto.abre(roto, (bien) => {
                ck("un proyecto.json que no describe un documento no se abre", !bien)
                ck("y no deja un documento fantasma detrás",
                   !S.Documento.abierto || (S.Documento.ancho > 0 && S.Documento.nFotogramas > 0),
                   S.Documento.ancho + "x" + S.Documento.alto + " · "
                   + S.Documento.nFotogramas + " fotogramas")
                paso4()
            })
        })
    }

    // ── 4 · exportar no se lleva por delante lo abierto ─────────
    function paso4() {
        S.Especie.abre(base + "/Prueba.especie", () => {
            S.Especie.editaAccion("Sleep", () => {
                raiz.pinta([60, 60, 220, 255])
                const ruta = S.Documento.ruta
                ck("Sleep tiene dibujo sin guardar antes de exportar", S.Documento.sucio)
                S.Especie.exporta(() => {
                    S.Proyecto.abre(ruta, (bien) => {
                        ck("exportar guarda antes lo que tenías delante", bien
                           && !P.vacio(S.Documento.compuesto(0, 0)))
                        fin.start()
                    })
                })
            })
        })
    }

    Connections {
        target: S.Especie
        function onFalla(q, m) { console.log("   (falla " + q + ": " + m + ")") }
    }
    Connections {
        target: S.Proyecto
        function onFalla(q, m) { console.log("   (falla proyecto " + q + ": " + m + ")") }
    }

    Timer { id: fin; interval: 250; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "")
        Qt.exit(raiz.malas ? 1 : 0)
    } }
    Timer { interval: 80000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

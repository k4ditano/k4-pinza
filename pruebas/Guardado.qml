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
                        paso5()
                    })
                })
            })
        })
    }


    // ── 5 · guardar no se deja celdas de nadie ──────────────────
    //
    //  Borrar una capa la quitaba de la memoria y del proyecto.json, pero sus
    //  PNG se quedaban en `celdas/` para siempre. No corrompe nada —al abrir,
    //  el contador de ids arranca en el máximo más uno, así que una capa nueva
    //  no reutiliza un id viejo— pero la carpeta crecía sin parar y un
    //  `git diff` enseñaba ficheros que no eran de nadie, que es justo lo que
    //  este formato promete no hacer.
    function paso5() {
        const ruta = base + "/Poda.pinza"
        S.Documento.nuevo({ nombre: "Poda", ancho: 8, alto: 8, fotogramas: 2 })
        raiz.pinta([200, 40, 40, 255])
        S.Documento.añadeCapa("sobra")
        raiz.pinta([40, 200, 40, 255])
        S.Proyecto.guarda(ruta, () => {
            S.Forja.lista_(ruta + "/celdas", "*.png", (r1) => {
                ck("dos capas por dos fotogramas son cuatro celdas en disco",
                   r1.ficheros.length === 4, r1.ficheros.length)

                //  Se borra la capa de arriba y se vuelve a guardar. Antes esto
                //  dejaba las dos celdas viejas ahí para siempre.
                S.Documento.borraCapa(1)
                S.Proyecto.guarda(ruta, () => {
                    S.Forja.lista_(ruta + "/celdas", "*.png", (r2) => {
                        ck("y al borrar una capa, sus celdas se van del disco",
                           r2.ficheros.length === 2,
                           r2.ficheros.map((f) => f.nombre).join(" "))
                        //  Lo que queda tiene que ser lo de la capa que sigue
                        //  viva, no dos ficheros cualesquiera.
                        const viva = S.Documento.capa(0).id
                        ck("y las que quedan son las de la capa que sigue viva",
                           r2.ficheros.every((f) => f.nombre.indexOf(viva + ".") === 0),
                           r2.ficheros.map((f) => f.nombre).join(" "))
                        S.Proyecto.abre(ruta, (bien) => {
                            ck("y el proyecto sigue abriéndose con su dibujo",
                               bien && !P.vacio(S.Documento.compuesto(0, 0)))
                            paso6()
                        })
                    })
                })
            })
        })
    }

    //  Una poda sin nada que conservar vaciaría la carpeta entera, y eso no es
    //  nunca lo que alguien quiso: es un fallo aguas arriba. Cuesta una línea
    //  distinguirlo y evita la única forma que tiene esto de perder trabajo.
    function paso6() {
        const ruta = base + "/Poda.pinza/celdas"
        S.Forja.poda(ruta, "*.png", [], (r) => {
            ck("podar sin nada que conservar no borra nada", r.bien && r.cuantos === 0,
               (r && r.omitido) || "")
            S.Forja.lista_(ruta, "*.png", (r2) => {
                ck("y la carpeta sigue entera", r2.ficheros.length === 2, r2.ficheros.length)
                fin.start()
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

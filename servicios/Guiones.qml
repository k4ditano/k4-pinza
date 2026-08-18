pragma Singleton

//  Guiones.
//
//  En JavaScript, que es el idioma en el que ya está escrito el programa: no
//  hace falta empotrar otro intérprete ni traducir el modelo a nada. Un guión
//  recibe un objeto `pinza` y trabaja contra el documento abierto.
//
//  Todo lo que haga un guión entra en el historial como UN paso. Es lo que
//  permite probar uno sin miedo: si hace un destrozo, Ctrl+Z y ya está. Un
//  guión que dejara cuatrocientas entradas en el historial sería peor que no
//  tener guiones.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "." as S

Singleton {
    id: gui

    property var ultimoError: null
    property string salida: ""
    signal escrito(string linea)

    readonly property string carpeta: (Quickshell.env("XDG_CONFIG_HOME")
                                       || (Quickshell.env("HOME") + "/.config")) + "/pinza/guiones"

    property var lista: []

    function refresca() {
        S.Forja.lista_(carpeta, "*.js", (r) => {
            const mios = r.bien ? r.ficheros : []
            S.Forja.lista_(Qt.resolvedUrl("../guiones").toString().replace("file://", ""), "*.js", (r2) => {
                const casa = r2.bien ? r2.ficheros : []
                lista = casa.concat(mios)
            })
        })
    }

    /**
     * La API que ve un guión.
     *
     * Deliberadamente pequeña y en el mismo idioma que el resto: `capa`,
     * `celda`, `fotograma`. Lo que no está aquí se puede hacer igual con
     * `pinza.px`, que es el motor entero — pero entonces te toca a ti no
     * romper nada.
     */
    function api() {
        return {
            px: P,

            get doc() {
                const d = S.Documento.d
                if (!d) return null
                return {
                    nombre: d.nombre, ancho: d.ancho, alto: d.alto,
                    capas: d.capas.length, fotogramas: d.fotogramas.length,
                    orientaciones: d.orientaciones.slice(),
                    contrato: d.contrato ? d.contrato.id : null
                }
            },

            get capaActiva() { return S.Documento.capaActiva },
            get fotograma() { return S.Documento.fotograma },
            get orientacion() { return S.Documento.orientacion },

            capa: (i) => S.Documento.capa(i === undefined ? S.Documento.capaActiva : i),

            /** El búfer de una celda. Se puede escribir directamente. */
            celda: (capa, f, d) => {
                const c = S.Documento.capa(capa === undefined ? S.Documento.capaActiva : capa)
                if (!c) return null
                return S.Documento.celda(c.id,
                    f === undefined ? S.Documento.fotograma : f,
                    d === undefined ? S.Documento.orientacion : d, true)
            },

            /** El compuesto de un (fotograma, orientación). No lo modifiques. */
            compuesto: (f, d) => S.Documento.compuesto(f, d),

            /** Recorre TODAS las celdas: fn(buf, capa, fotograma, orientacion). */
            paraCada: (fn) => {
                const d = S.Documento.d
                if (!d) return 0
                let n = 0
                for (let k = 0; k < d.capas.length; k++)
                    for (let f = 0; f < d.fotogramas.length; f++)
                        for (let o = 0; o < d.orientaciones.length; o++) {
                            const b = S.Documento.celda(d.capas[k].id, f, o, false)
                            if (!b) continue
                            fn(b, d.capas[k], f, o); n++
                        }
                return n
            },

            /** Recorre los píxeles de un búfer: fn(color, x, y) -> color o nada. */
            paraCadaPixel: (buf, fn) => {
                for (let y = 0; y < buf.h; y++) for (let x = 0; x < buf.w; x++) {
                    const c = P.lee(buf, x, y)
                    const n = fn(c, x, y)
                    if (n) P.pon(buf, x, y, n)
                }
            },

            lee: (buf, x, y) => P.lee(buf, x, y),
            pon: (buf, x, y, c) => P.pon(buf, x, y, typeof c === "string" ? P.deHex(c) : c),

            color: (h) => P.deHex(h),
            hex: (c) => P.aHex(c),

            get primario() { return S.Paleta.primario.slice() },
            get secundario() { return S.Paleta.secundario.slice() },
            get rampas() { return S.Paleta.rampas },

            seleccionado: (x, y) => S.Seleccion.contiene(x, y),

            capaNueva: (nombre) => S.Documento.añadeCapa(nombre),
            fotogramaNuevo: (copiando) => S.Documento.añadeFotograma(!!copiando),

            /** Lo que se ve por debajo del guión, en su hoja. */
            log: function () {
                const t = Array.prototype.slice.call(arguments)
                          .map((x) => typeof x === "object" ? JSON.stringify(x) : String(x)).join(" ")
                gui.salida += t + "\n"
                gui.escrito(t)
                console.log("guión: " + t)
            }
        }
    }

    /**
     * Corre un guión.
     *
     * Se envuelve en un `new Function` en vez de en un eval suelto para que sus
     * variables no se mezclen con nada de aquí, y todo el paso queda en una
     * sola entrada del historial.
     */
    function corre(codigo, nombre) {
        ultimoError = null
        salida = ""
        if (!S.Documento.abierto) {
            ultimoError = { mensaje: "no hay ningún documento abierto" }
            return false
        }
        let fn
        try {
            fn = new Function("pinza", codigo)
        } catch (e) {
            ultimoError = { mensaje: "el guión no compila: " + e.message }
            return false
        }

        //  Instantánea completa y no el historial de estructura: un guión
        //  escribe dentro de los búferes sin dejar entradas de píxeles, y el
        //  de estructura guarda el mapa de celdas por REFERENCIA. Deshacer
        //  devolvía el mapa apuntando a los mismos búferes ya machacados —
        //  es decir, no deshacía nada.
        S.Historial.abreCompleto()
        try {
            fn(api())
        } catch (e) {
            ultimoError = { mensaje: String(e.message || e), linea: e.lineNumber }
            // se cancela sin dejar rastro: un guión que revienta a mitad no
            // debería dejar un paso a medias en el historial
            S.Historial.cancelaCompleto()
            return false
        }
        S.Historial.cierraCompleto(nombre || "guión")
        S.Documento.cambia()
        S.Documento.cambiaPixeles(null)
        return true
    }

    function corredeFichero(ruta) {
        S.Forja.leeTexto(ruta, (r) => {
            if (!r.bien || r.texto === null) {
                ultimoError = { mensaje: "no se puede leer " + ruta }
                return
            }
            corre(r.texto, ruta.split("/").pop())
        })
    }

    Component.onCompleted: {
        if (S.Forja.viva) refresca()
        else S.Forja.lista.connect(refresca)
    }
}

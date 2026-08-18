//  Atropellar a propósito.
//
//  Guardar recorre las celdas del documento y las manda por tandas. Si mientras
//  tanto se abre otro proyecto, el documento cambia debajo y lo que se escribe
//  deja de tener que ver con lo que se pidió — y el programa se caía, sin dejar
//  ni un error en el registro. Pulsar dos acciones seguidas basta para
//  provocarlo, y eso se hace sin querer.
//
//  Aquí se hace a propósito: seis cambios encadenados sin esperar a ninguno.
//  Lo que se exige es lo que espera quien pulsa deprisa — acabar donde pulsó la
//  última vez, y no perder lo de antes por el camino.
import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V
ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }
    readonly property string base: "/run/user/1000/pinza-race"
    FloatingWindow { implicitWidth: 200; implicitHeight: 100; visible: true
        V.Exportador { id: ex }
        Component.onCompleted: { S.Proyecto.exportador = ex; S.Especie.exportador = ex } }
    Connections { target: S.Packs; function onCargadosCambiaron() { t.start() } }
    Timer { id: t; interval: 300; onTriggered: {
        S.Packs.elige("crabh")
        S.Packs.apunta("crabh", (Quickshell.env("HOME")||"") + "/Proyectos/crabh")
        S.Especie.nueva({ nombre: "Corredor", dex: 10777 })
        S.Especie.guarda(base + "/Corredor.especie", () => {
            S.Especie.editaAccion("Idle", () => {
                // ensuciar de verdad
                P.pon(S.Documento.celdaActiva(true), 1, 1, [255,0,255,255])
                S.Documento.cambiaPixeles(null)
                console.log("empieza el atropello, sucio =", S.Documento.sucio)
                // seis cambios seguidos sin esperar a ninguno
                S.Especie.editaAccion("Walk", null)
                S.Especie.editaAccion("Attack", null)
                S.Especie.editaAccion("Hurt", null)
                S.Especie.editaAccion("Charge", null)
                S.Especie.editaAccion("Hop", null)
                S.Especie.editaAccion("Sleep", null)
                reposo.start()
            })
        })
    } }
    Timer { id: reposo; interval: 4000; onTriggered: {
        raiz.ck("sigue vivo después de seis cambios atropellados", true)
        raiz.ck("acaba en una acción de verdad, no a medias",
                S.Especie.accion !== "" && S.Documento.abierto, S.Especie.accion)
        raiz.ck("y el documento abierto es el de esa acción",
                S.Documento.campo("accion") === S.Especie.accion,
                S.Documento.campo("accion") + " vs " + S.Especie.accion)
        // y lo que se dibujó en Idle antes del lío tiene que estar
        S.Especie.editaAccion("Idle", () => {
            const b = S.Documento.celda(S.Documento.capa(0).id, 0, 0, false)
            raiz.ck("lo dibujado antes del atropello no se perdió",
                    b && P.lee(b, 1, 1)[0] === 255, b ? P.lee(b, 1, 1).join() : "sin celda")
            // y mirar otra orientación no ensucia
            S.Documento.limpio()
            S.Documento.orientacion = 3
            S.Documento.fotograma = 1
            raiz.ck("mirar otra orientación y otro fotograma NO ensucia el documento",
                    !S.Documento.sucio)
            console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\nno se atropella")
            fin.start()
        })
    } }
    Timer { id: fin; interval: 200; onTriggered: Qt.exit(raiz.malas ? 1 : 0) }
    Timer { interval: 60000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

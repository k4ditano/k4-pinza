//  Que se vea que algo está pasando, y que deje de verse cuando deja de pasar.
//
//  Importar una criatura tarda segundos. Sin nada que lo diga, la ventana se
//  queda igual y no sabes si va, si se colgó o si no llegaste a pulsar — y la
//  tercera conclusión hace que pulses otra vez, que es como se encadenan
//  operaciones que no deberían encadenarse.
//
//  Lo que hay que comprobar de una pantalla de carga es sobre todo que SE VAYA:
//  una que se queda puesta es peor que no tenerla, porque no puedes ni guardar.

import QtQuick
import Quickshell
import "../core" as C
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property string tmp: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-carga"

    FloatingWindow {
        id: ventana
        implicitWidth: 600; implicitHeight: 400; visible: true
        Item {
            id: escena
            anchors.fill: parent
            V.Exportador { id: ex }
            V.Cargando { id: carga }
        }
        Component.onCompleted: { S.Proyecto.exportador = ex; arranca.start() }
    }

    Timer { id: arranca; interval: 300; onTriggered: raiz.paso1() }

    // ── el ancho de una opción cubre sus botones ────────────────
    function paso1() {
        //  La cuenta exacta: lo que ocupa la etiqueta más lo que ocupan los
        //  botones. Con un número fijo —eran 180— una fila de botones más
        //  ancha se salía por debajo del siguiente elemento y los dos textos
        //  se pintaban encima.
        ck("una opción mide su etiqueta más sus botones",
           Math.abs((medidor.implicitWidth - desnudo.implicitWidth) - medidor.anchoEtiqueta) < 1,
           medidor.implicitWidth.toFixed(0) + " con etiqueta, "
           + desnudo.implicitWidth.toFixed(0) + " sin ella, etiqueta de " + medidor.anchoEtiqueta)
        ck("y crece si le pones opciones más largas",
           largo.implicitWidth > medidor.implicitWidth,
           largo.implicitWidth + " vs " + medidor.implicitWidth)

        // ── el aviso de carga ────────────────────────────────────
        ck("en reposo no hay nada que enseñar", !carga.haciendoAlgo && carga.opacity === 0)

        S.Documento.nuevo({ nombre: "carga", ancho: 48, alto: 48, fotogramas: 12 })
        for (let f = 0; f < 12; f++) {
            const b = S.Documento.celda(S.Documento.capa(0).id, f, 0, true)
            for (let i = 0; i < b.d.length; i += 4) { b.d[i] = 200; b.d[i + 3] = 255 }
        }
        S.Documento.cambiaPixeles(null)

        S.Proyecto.guarda(tmp + "/lento.pinza", () => {
            ck("al acabar, se apaga", !carga.haciendoAlgo)
            revisa.start()
        })
        ck("mientras guarda, dice que está haciendo algo", carga.haciendoAlgo, carga.faena)
        //  Y no aparece de golpe: guardar un icono tarda cincuenta
        //  milisegundos y un parpadeo de rueda en cada guardado cansa más que
        //  informar.
        ck("pero todavía no se enseña, que puede acabar enseguida", carga.opacity === 0)
    }

    Timer { id: revisa; interval: 500; onTriggered: {
        raiz.ck("y medio segundo después sigue apagado", carga.opacity === 0 && !carga.haciendoAlgo)
        raiz.ck("sin dejarse el bloqueo de clics puesto", !carga.atascado)
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\nel aviso de carga aparece y se va")
        fin.start()
    } }

    // dos opciones sólo para medirlas
    C.Opcion {
        id: medidor
        etiqueta: "modo"; anchoEtiqueta: 40
        opciones: [{ id: "a", titulo: "uno" }, { id: "b", titulo: "dos" }]
        valor: "a"
    }
    C.Opcion {
        id: desnudo
        opciones: [{ id: "a", titulo: "uno" }, { id: "b", titulo: "dos" }]
        valor: "a"
    }
    C.Opcion {
        id: largo
        etiqueta: "modo"; anchoEtiqueta: 40
        opciones: [{ id: "a", titulo: "una opción bastante larga" },
                   { id: "b", titulo: "y otra igual de larga" }]
        valor: "a"
    }

    Timer { id: fin; interval: 150; onTriggered: Qt.exit(raiz.malas ? 1 : 0) }
    Timer { interval: 25000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

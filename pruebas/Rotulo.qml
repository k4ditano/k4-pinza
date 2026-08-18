//  Que el rótulo salga de su caja.
//
//  Vivía dentro del botón que lo pedía, y el carril de herramientas tiene
//  `clip`: el rótulo se cortaba contra el borde del carril justo donde más
//  falta hace, porque veinte iconos en fila no se aprenden de memoria.

import QtQuick
import Quickshell
import "../core" as C
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    FloatingWindow {
        id: ventana
        implicitWidth: 500; implicitHeight: 400
        visible: true

        //  Una caja estrecha que recorta, como el carril de verdad.
        Rectangle {
            id: carril
            width: 44; height: parent.height
            color: "#222"
            clip: true
            Column {
                C.Boton { id: arriba; icono: "A"; width: 36; pista: "el de arriba" }
                C.Boton { id: abajo; icono: "B"; width: 36; pista: "el de abajo" }
            }
        }
        V.Globo { id: globo }
        Component.onCompleted: t.start()
    }

    Timer { id: t; interval: 300; onTriggered: {
        ck("el carril recorta, como el de verdad", carril.clip && carril.width === 44)

        S.Globo.enseña(arriba, "el de arriba", Qt.AlignBottom)
        ck("encender un rótulo lo enciende", S.Globo.visible && S.Globo.texto === "el de arriba")
        ck("y se coloca sobre el botón que lo pidió",
           Math.abs(S.Globo.x - (arriba.x + arriba.width / 2)) < 1, S.Globo.x)

        // el del otro botón gana, y salir del primero no lo apaga
        S.Globo.enseña(abajo, "el de abajo", Qt.AlignBottom)
        S.Globo.esconde(arriba)
        ck("salir de un botón no borra el rótulo del de al lado",
           S.Globo.texto === "el de abajo", S.Globo.texto)
        S.Globo.esconde(abajo)
        ck("y su dueño sí lo apaga", !S.Globo.visible)

        // lo que importa: que el globo NO esté dentro del carril
        ck("el globo se pinta fuera del carril, en la raíz de la escena",
           globo.parent !== carril && globo.width > carril.width,
           "ancho " + globo.width + " vs carril " + carril.width)

        // y que no se salga de la ventana por el borde
        S.Globo.enseña(arriba, "un rótulo bastante largo para probar el borde", Qt.AlignBottom)
        esperar.start()
    } }

    Timer { id: esperar; interval: 120; onTriggered: {
        const caja = globo.children[0]
        ck("un rótulo largo no se sale de la ventana por la izquierda", caja.x >= 0, caja.x)
        ck("ni por la derecha", caja.x + caja.width <= ventana.width, caja.x + caja.width)
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\nel rótulo sale de su caja")
        fin.start()
    } }
    Timer { id: fin; interval: 120; onTriggered: Qt.exit(raiz.malas ? 1 : 0) }
    Timer { interval: 20000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

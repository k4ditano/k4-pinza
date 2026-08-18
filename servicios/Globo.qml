pragma Singleton

//  El rótulo que sale al pasar por encima, en una capa por encima de todo.
//
//  Antes lo dibujaba cada botón dentro de sí mismo, y eso lo condena a vivir
//  recortado: el carril de herramientas tiene `clip`, así que el rótulo de una
//  herramienta se cortaba contra el borde del carril y no se leía — justo donde
//  más falta hace, porque un carril de veinte iconos no se aprende de memoria.
//
//  Aquí sólo vive el ESTADO: qué texto, dónde y de quién. Quien lo pinta es
//  vistas/Globo.qml, colgado de la raíz de la escena, donde nada lo recorta.

import QtQuick
import Quickshell

Singleton {
    id: globo

    property string texto: ""
    property real x: 0
    property real y: 0
    property int lado: Qt.AlignBottom
    property var dueño: null

    readonly property bool visible: texto.length > 0

    /**
     * `ancla` es el item que lo pide; de él salen la posición y el tamaño.
     *
     * Se guarda quién lo pidió para que soltar el ratón sobre un botón no
     * apague el rótulo del de al lado, que ya lo había encendido.
     */
    function enseña(ancla, txt, donde) {
        if (!ancla || !txt) return
        const p = ancla.mapToItem(null, 0, 0)
        dueño = ancla
        texto = txt
        lado = donde === undefined ? Qt.AlignBottom : donde
        x = p.x + ancla.width / 2
        y = donde === Qt.AlignTop ? p.y : p.y + ancla.height
    }

    /** Sólo lo apaga quien lo encendió: si no, salir de un botón borraría el
        rótulo del de al lado, que acaba de encender el suyo. */
    function esconde(ancla) {
        if (dueño !== ancla) return
        texto = ""
        dueño = null
    }
}

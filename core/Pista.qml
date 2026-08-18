//  Pide el rótulo; no lo pinta.
//
//  Pintarlo aquí dentro lo condenaba a vivir recortado por el primer ancestro
//  con `clip` —el carril de herramientas, por ejemplo—. Ahora sólo avisa al
//  singleton y quien lo dibuja está colgado de la raíz de la escena.

import QtQuick
import "../servicios" as S

Item {
    id: raiz
    property string texto: ""
    property bool mostrar: false
    property int lado: Qt.AlignBottom

    anchors.fill: parent
    visible: false          // no ocupa ni pinta: sólo avisa

    onMostrarChanged: {
        if (mostrar && texto) S.Globo.enseña(parent, texto, lado)
        else S.Globo.esconde(parent)
    }
    onTextoChanged: if (mostrar && texto) S.Globo.enseña(parent, texto, lado)
    Component.onDestruction: S.Globo.esconde(parent)
}

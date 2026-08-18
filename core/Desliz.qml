//  Un deslizador con su número, porque en un editor de píxeles el número
//  importa: "tamaño 3" es una decisión, "más o menos por aquí" no.
import QtQuick
import "." as C

Item {
    id: raiz
    property string etiqueta: ""
    property real valor: 0
    property real minimo: 0
    property real maximo: 1
    property real paso: 0
    property int decimales: 2
    property string sufijo: ""
    property int anchoEtiqueta: 76
    signal cambiado(real v)

    implicitHeight: 22
    //  Un mínimo con sentido: etiqueta, un carril usable y el número. Quien lo
    //  use en una fila puede darle más, pero nunca menos de lo que necesita.
    implicitWidth: (raiz.etiqueta ? raiz.anchoEtiqueta : 0) + 70 + 50

    Text {
        id: et
        text: raiz.etiqueta
        visible: !!raiz.etiqueta
        width: raiz.anchoEtiqueta
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        font.family: C.Tema.tipo
        font.pixelSize: C.Tema.letra
        color: C.Tema.tenue
        elide: Text.ElideRight
    }

    Item {
        id: pista
        anchors.left: raiz.etiqueta ? et.right : parent.left
        anchors.right: num.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 18

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 3; radius: 1.5
            color: C.Tema.borde
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * raiz._t; height: 3; radius: 1.5
            color: C.Tema.acento
        }
        Rectangle {
            x: parent.width * raiz._t - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5
            color: raton.pressed || raton.containsMouse ? C.Tema.acento : C.Tema.tinta
        }
        MouseArea {
            id: raton
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function fija(mx) {
                let t = Math.max(0, Math.min(1, mx / pista.width))
                let v = raiz.minimo + t * (raiz.maximo - raiz.minimo)
                if (raiz.paso > 0) v = Math.round(v / raiz.paso) * raiz.paso
                raiz.cambiado(v)
            }
            onPressed: (m) => fija(m.x)
            onPositionChanged: (m) => { if (pressed) fija(m.x) }
            onWheel: (w) => {
                const p = raiz.paso > 0 ? raiz.paso : (raiz.maximo - raiz.minimo) / 20
                raiz.cambiado(Math.max(raiz.minimo, Math.min(raiz.maximo,
                              raiz.valor + (w.angleDelta.y > 0 ? p : -p))))
            }
        }
    }

    readonly property real _t: maximo > minimo ? (valor - minimo) / (maximo - minimo) : 0

    Text {
        id: num
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        horizontalAlignment: Text.AlignRight
        text: (raiz.decimales > 0 ? raiz.valor.toFixed(raiz.decimales)
                                  : String(Math.round(raiz.valor))) + raiz.sufijo
        font.family: C.Tema.tipoMono
        font.pixelSize: C.Tema.letraChica
        color: C.Tema.tinta
    }
}

//  Un campo de texto o de número.
import QtQuick
import "." as C

Item {
    id: raiz
    property string etiqueta: ""
    property string valor: ""
    property bool numero: false
    property int minimo: 1
    property int maximo: 99999
    property string sufijo: ""
    property int anchoEtiqueta: 76
    signal cambiado(string v)

    implicitHeight: 24
    implicitWidth: 180

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

    Rectangle {
        anchors.left: raiz.etiqueta ? et.right : parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        radius: 3
        color: C.Tema.fondo
        border.width: 1
        border.color: entrada.activeFocus ? C.Tema.acento : C.Tema.borde

        TextInput {
            id: entrada
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: raiz.sufijo ? 26 : 7
            verticalAlignment: TextInput.AlignVCenter
            font.family: raiz.numero ? C.Tema.tipoMono : C.Tema.tipo
            font.pixelSize: C.Tema.letra
            color: C.Tema.tinta
            selectionColor: C.Tema.acento
            selectByMouse: true
            text: raiz.valor
            validator: raiz.numero ? enteros : null
            onTextChanged: if (text !== raiz.valor) raiz.cambiado(text)
            onEditingFinished: {
                if (!raiz.numero) return
                const n = Math.max(raiz.minimo, Math.min(raiz.maximo, parseInt(text) || raiz.minimo))
                if (String(n) !== text) { text = String(n); raiz.cambiado(text) }
            }
            Keys.onUpPressed: if (raiz.numero) { text = String(Math.min(raiz.maximo, (parseInt(text)||0) + 1)); raiz.cambiado(text) }
            Keys.onDownPressed: if (raiz.numero) { text = String(Math.max(raiz.minimo, (parseInt(text)||0) - 1)); raiz.cambiado(text) }
        }
        IntValidator { id: enteros; bottom: raiz.minimo; top: raiz.maximo }

        Text {
            text: raiz.sufijo
            visible: !!raiz.sufijo
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            font.family: C.Tema.tipoMono
            font.pixelSize: C.Tema.letraChica
            color: C.Tema.apagado
        }
    }
}

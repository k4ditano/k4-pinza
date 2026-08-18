//  Un glifo de la Nerd Font, centrado en su caja.
import QtQuick
import "." as C

Text {
    property alias glifo: raiz.text
    id: raiz
    font.family: C.Tema.tipoIcono
    font.pixelSize: C.Tema.letraIcono
    color: C.Tema.tinta
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}

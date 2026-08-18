//  Un rótulo de sección: pequeño, en versalitas, apagado.
import QtQuick
import "." as C

Text {
    font.family: C.Tema.tipo
    font.pixelSize: C.Tema.letraChica
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.8
    font.weight: Font.DemiBold
    color: C.Tema.tenue
}

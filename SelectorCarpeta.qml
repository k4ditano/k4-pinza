//  Un selector de carpeta del sistema.
//
//  Envuelto para poder llamarlo desde donde sea con una señal limpia, y
//  porque FolderDialog devuelve una URL y aquí siempre se quiere una ruta.

import QtQuick
import QtQuick.Dialogs

Item {
    id: raiz
    property string titulo: ""
    signal elegida(string ruta)
    function open() { dlg.open() }

    FolderDialog {
        id: dlg
        title: raiz.titulo
        onAccepted: raiz.elegida(String(selectedFolder).replace("file://", ""))
    }
}

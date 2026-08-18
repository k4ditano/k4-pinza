//  El arrancador de pruebas.
//
//  Vive en la raíz porque Quickshell no deja importar nada por encima de la
//  carpeta desde la que arranca: una prueba dentro de pruebas/ no puede ver
//  core/. Así que la raíz es siempre el proyecto y aquí sólo se elige cuál
//  correr.
//
//      ./pruebas/correr            todas
//      PINZA_PRUEBA=pruebas/Motor.qml qs -p prueba.qml    una

import QtQuick
import Quickshell

ShellRoot {
    Loader {
        source: Quickshell.env("PINZA_PRUEBA") || "pruebas/Motor.qml"
        onStatusChanged: if (status === Loader.Error) { console.log("no carga: " + source); Qt.exit(1) }
    }
}

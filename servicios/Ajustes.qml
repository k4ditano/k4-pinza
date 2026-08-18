pragma Singleton

//  Lo que no es el dibujo: cómo se ve el dibujo.
//
//  Nada de aquí entra en el fichero del proyecto — son preferencias de quien
//  mira, no del arte. Se guardan aparte, en ~/.config/pinza/ajustes.json.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: aj

    // ── vista ────────────────────────────────────────────────────
    property real zoom: 8
    property real panX: 0
    property real panY: 0
    property bool rejillaPixel: true       // línea fina cada píxel, a mucho zoom
    property bool rejillaCasilla: true     // la del contrato o la de la baldosa
    property int casillaAncho: 16
    property int casillaAlto: 16
    property bool ajedrez: true            // fondo de transparencia
    property bool modoBaldosa: false       // el lienzo envuelve de verdad
    property bool medidasSilueta: false    // pieBajo, medio ancho, radio de base

    // ── simetría ─────────────────────────────────────────────────
    property bool simetriaH: false
    property bool simetriaV: false
    property real ejeX: -1                 // -1 = centro
    property real ejeY: -1

    // ── piel de cebolla ──────────────────────────────────────────
    property bool cebolla: false
    property int cebollaAtras: 1
    property int cebollaDelante: 1
    property real cebollaOpacidad: 0.35
    property bool cebollaTeñida: true      // pasado rojo, futuro azul

    // ── paneles ──────────────────────────────────────────────────
    property bool panelCapas: true
    property bool panelPaleta: true
    property bool panelPrevia: false
    property bool panelHistorial: false
    property bool panelMapa: true
    property bool tira: true
    property bool compas: true

    // ── otros ────────────────────────────────────────────────────
    property string pack: "generico"

    //  Dónde está el repositorio de cada pack, si no está donde el pack dice.
    //  Un pack se comparte; la ruta a tu copia del juego no.
    property var raices: ({})
    property int autoguardado: 120         // segundos; 0 lo apaga
    property bool avisoGuia: true          // enseñar el medidor de estilo del pack

    readonly property string carpeta: (Quickshell.env("XDG_CONFIG_HOME")
                                       || (Quickshell.env("HOME") + "/.config")) + "/pinza"

    FileView {
        id: fichero
        path: aj.carpeta + "/ajustes.json"
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text())
                const k = Object.keys(j)
                for (let i = 0; i < k.length; i++) if (aj.hasOwnProperty(k[i])) aj[k[i]] = j[k[i]]
            } catch (e) { /* la primera vez no hay fichero, y está bien */ }
        }
    }

    function guarda() {
        const j = {}
        const nombres = ["zoom", "rejillaPixel", "rejillaCasilla", "casillaAncho", "casillaAlto",
                         "ajedrez", "modoBaldosa", "medidasSilueta", "simetriaH", "simetriaV",
                         "cebolla", "cebollaAtras", "cebollaDelante", "cebollaOpacidad",
                         "cebollaTeñida", "panelCapas", "panelPaleta", "panelPrevia",
                         "panelHistorial", "panelMapa", "tira", "compas", "pack", "autoguardado", "avisoGuia",
                         "raices"]
        for (let i = 0; i < nombres.length; i++) j[nombres[i]] = aj[nombres[i]]
        fichero.setText(JSON.stringify(j, null, 2))
    }
}

pragma Singleton

//  La herramienta activa y sus opciones.
//
//  Aquí sólo vive el ESTADO. Lo que cada herramienta hace está en
//  core/herramientas.js, que es JavaScript puro y por tanto comprobable sin
//  abrir una ventana. Separarlo no es estética: la mitad de los fallos de un
//  editor de píxeles son de aritmética de coordenadas, y esa mitad se caza en
//  una prueba en seco.

import QtQuick
import Quickshell

Singleton {
    id: pin

    // lapiz · goma · cubo · cuentagotas · linea · rectangulo · elipse
    // contorno · degradado · difumina · mancha · aclara · quema · sustituye
    // sombreado · marco · elipseSel · lazo · lazoPoli · varita · porColor
    // mover · mano · zoom
    property string herramienta: "lapiz"
    property string anterior: "lapiz"

    function elige(h) {
        if (h === herramienta) return
        anterior = herramienta
        herramienta = h
    }

    // ── punta ────────────────────────────────────────────────────
    property int tamaño: 1
    property bool puntaCuadrada: false
    property var pincelPersonal: null      // un búfer, si lo hiciste de una selección

    // ── trazo ────────────────────────────────────────────────────
    property bool trazoPerfecto: true      // quita las esquinas dobles
    property string trama: "solido"
    property real proporcionTrama: 1.0

    // ── relleno y varita ─────────────────────────────────────────
    property real tolerancia: 8
    property bool contiguo: true
    property bool ochoVecinos: false

    // ── formas ───────────────────────────────────────────────────
    property bool relleno: false
    property bool desdeElCentro: false

    // ── selección ────────────────────────────────────────────────
    property string modoSeleccion: "nueva"   // nueva · sumar · restar · intersecar

    // ── pinceles de retoque ──────────────────────────────────────
    property real fuerza: 0.5

    // ── degradado ────────────────────────────────────────────────
    property string tipoDegradado: "lineal"  // lineal · radial
    property bool degradadoTramado: true

    // ── sombreado por rampa ──────────────────────────────────────
    property int pasoSombreado: 1            // +1 aclara, -1 oscurece

    readonly property bool esSeleccion: herramienta === "marco" || herramienta === "elipseSel"
                                     || herramienta === "lazo" || herramienta === "lazoPoli"
                                     || herramienta === "varita" || herramienta === "porColor"
    readonly property bool esForma: herramienta === "linea" || herramienta === "rectangulo"
                                 || herramienta === "elipse" || herramienta === "degradado"
}

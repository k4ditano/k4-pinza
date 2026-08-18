pragma Singleton

//  El idioma visual.
//
//  Los mismos tipos que k4 —Adwaita Sans y la Meslo Nerd Font Mono— porque
//  esto va a vivir en el mismo escritorio y no tiene sentido que hable otro
//  idioma. Los grises tiran a verdeazulado en vez de a azul: el editor va a
//  estar todo el día rodeando arte, y un gris neutro frío hace que cualquier
//  color cálido de la paleta parezca más saturado de lo que es.
//
//  Todos los iconos están comprobados por NOMBRE de glifo contra la fuente
//  instalada, no adivinados por codepoint. La mitad de los que "parecían"
//  correctos eran otra cosa: el lápiz salía un asistente y el cubo una carpeta.

import QtQuick
import Quickshell

Singleton {
    id: tema

    readonly property string tipo: "Adwaita Sans"
    readonly property string tipoMono: "Adwaita Mono"
    readonly property string tipoIcono: "MesloLGS Nerd Font Mono"
    readonly property var idioma: Qt.locale("es_ES")

    property bool oscuro: true

    // ── superficies ──────────────────────────────────────────────
    readonly property color fondo:      oscuro ? "#12181A" : "#F0F2ED"
    readonly property color superficie: oscuro ? "#1A2224" : "#E4E9EA"
    readonly property color alta:       oscuro ? "#232D30" : "#DEE4E7"
    readonly property color borde:      oscuro ? "#2C393B" : "#C3CCCE"
    readonly property color bordeSuave: oscuro ? "#212B2D" : "#D6DDDE"

    // ── tinta ────────────────────────────────────────────────────
    readonly property color tinta:  oscuro ? "#E2E8EA" : "#222C2E"
    readonly property color tenue:  oscuro ? "#8E9DA0" : "#637376"
    readonly property color apagado: oscuro ? "#5A686B" : "#98A4A6"

    // ── acento ───────────────────────────────────────────────────
    //  El naranja de caparazón. Se gasta en un sitio: lo activo. Todo lo
    //  demás es gris, para que el arte sea lo único con color de la pantalla.
    readonly property color acento:  oscuro ? "#E4884E" : "#A8471A"
    readonly property color acento2: "#D66C34"
    readonly property color acentoTenue: oscuro ? "#33241B" : "#F2E2D6"

    // ── significados ─────────────────────────────────────────────
    readonly property color bien:  oscuro ? "#8ABD5B" : "#3E6B1E"
    readonly property color aviso: oscuro ? "#EFD409" : "#8A6800"
    readonly property color mal:   oscuro ? "#E0508A" : "#8A1F4A"

    // ── ajedrez de transparencia ─────────────────────────────────
    readonly property color ajedrezA: oscuro ? "#1E2628" : "#FFFFFF"
    readonly property color ajedrezB: oscuro ? "#161E20" : "#E6E9E4"

    // ── medidas ──────────────────────────────────────────────────
    readonly property int radio: 4
    readonly property int hueco: 8
    readonly property int carril: 44
    readonly property int panel: 232
    readonly property int barra: 34
    readonly property int fila: 26

    readonly property int letraChica: 11
    readonly property int letra: 12
    readonly property int letraGrande: 14
    readonly property int letraIcono: 15

    // ── iconos, verificados contra la fuente ─────────────────────
    //  Los del plano suplementario hay que montarlos con fromCodePoint, que
    //  es lo que hace k4 y por lo mismo: en QML un "4" de cinco dígitos
    //  no es lo que parece.
    readonly property var i: ({
        lapiz:       String.fromCodePoint(0xF03EB),
        goma:        String.fromCodePoint(0xF01FE),
        cubo:        String.fromCodePoint(0xF0266),
        cuentagotas: String.fromCodePoint(0xF020B),
        linea:       String.fromCodePoint(0xF055E),
        rectangulo:  String.fromCodePoint(0xF0763),
        elipse:      String.fromCodePoint(0xF0766),
        degradado:   String.fromCodePoint(0xF174A),
        difumina:    String.fromCodePoint(0xF00B5),
        mancha:      String.fromCodePoint(0xF1855),
        aclara:      String.fromCodePoint(0xF00DE),
        quema:       String.fromCodePoint(0xF00DD),
        varita:      String.fromCodePoint(0xF0068),
        lazo:        String.fromCodePoint(0xF0F03),
        poligono:    String.fromCodePoint(0xF0560),
        mover:       String.fromCodePoint(0xF01BE),
        marco:       String.fromCodePoint(0xF0A6D),
        elipseSel:   String.fromCodePoint(0xF0D32),
        sombreado:   String.fromCodePoint(0xF06A0),
        sustituye:   String.fromCodePoint(0xF1313),
        contorno:    String.fromCodePoint(0xF08A1),
        mano:        String.fromCodePoint(0xF0E47),
        lupa:        String.fromCodePoint(0xF0349),
        capas:       String.fromCodePoint(0xF0328),
        paleta:      String.fromCodePoint(0xF03D8),
        play:        String.fromCodePoint(0xF040A),
        pause:       String.fromCodePoint(0xF03E4),
        anterior:    String.fromCodePoint(0xF04AE),
        siguiente:   String.fromCodePoint(0xF04AD),
        undo:        String.fromCodePoint(0xF054C),
        redo:        String.fromCodePoint(0xF044E),
        guardar:     String.fromCodePoint(0xF0193),
        exportar:    String.fromCodePoint(0xF0207),
        importar:    String.fromCodePoint(0xF02FA),
        rejilla:     String.fromCodePoint(0xF02C1),
        cerrar:      String.fromCodePoint(0xF0156),
        mas:         String.fromCodePoint(0xF0415),
        menos:       String.fromCodePoint(0xF0374),
        ojo:         String.fromCodePoint(0xF0208),
        ojoNo:       String.fromCodePoint(0xF0209),
        candado:     String.fromCodePoint(0xF033E),
        candadoNo:   String.fromCodePoint(0xF0FC6),
        copiar:      String.fromCodePoint(0xF018F),
        duplicar:    String.fromCodePoint(0xF0191),
        basura:      String.fromCodePoint(0xF01B4),
        cebolla:     String.fromCodePoint(0xF0F58),
        espejo:      String.fromCodePoint(0xF10E7),
        espejoV:     String.fromCodePoint(0xF10E8),
        girar:       String.fromCodePoint(0xF0467),
        compas:      String.fromCodePoint(0xF018C),
        baldosa:     String.fromCodePoint(0xF0570),
        carpeta:     String.fromCodePoint(0xF0770),
        nuevo:       String.fromCodePoint(0xF0752),
        engranaje:   String.fromCodePoint(0xF0493),
        historial:   String.fromCodePoint(0xF02DA),
        recortar:    String.fromCodePoint(0xF019E),
        escalar:     String.fromCodePoint(0xF0A68),
        enlace:      String.fromCodePoint(0xF0339),
        enlaceNo:    String.fromCodePoint(0xF033A),
        fusion:      String.fromCodePoint(0xF0792),
        aplanar:     String.fromCodePoint(0xF0329),
        referencia:  String.fromCodePoint(0xF0976),
        medidas:     String.fromCodePoint(0xF046D),
        regla:       String.fromCodePoint(0xF0CC2),
        aviso:       String.fromCodePoint(0xF002A),
        ok:          String.fromCodePoint(0xF012C),
        info:        String.fromCodePoint(0xF02FD),
        juego:       String.fromCodePoint(0xF0EB7),
        gif:         String.fromCodePoint(0xF0D78),
        simetria:    String.fromCodePoint(0xF11FD),
        flecha:      String.fromCodePoint(0xF0142),
        abajo:       String.fromCodePoint(0xF0140)
    })
}

//  El lienzo.
//
//  Aquí aterrizan los dos hallazgos de la cata, y conviene tenerlos delante
//  antes de tocar nada de este fichero:
//
//   · putImageData de tres argumentos NO HACE NADA en este Qt. Se traga los
//     píxeles sin quejarse. Hay que usar la forma de siete.
//
//   · Y en la de siete, el ORIGEN SUCIO TIENE QUE SER (0,0). Pasarle un
//     ImageData del tamaño del lienzo y un rectángulo sucio en (10,10) tampoco
//     hace nada — otra vez sin quejarse. Lo que sí funciona es recortar un
//     ImageData del tamaño de la zona sucia y colocarlo con dx,dy. Así está
//     escrito aquí, y esto era el fallo de "dibujo y sale al lado": el trazo
//     no se pintaba nunca, y aparecía de golpe y desplazado cuando algo
//     forzaba un repintado entero.
//
//   · Y putImageData MEZCLA en vez de reemplazar, que es justo lo contrario de
//     lo que dice su definición. Poner un píxel transparente encima de uno
//     opaco no lo borra: lo deja igual. Con eso, la goma no borraba nada y
//     deshacer no deshacía nada — a la vista, porque por dentro las dos
//     funcionaban perfectamente. Por eso aquí se limpia la zona sucia antes de
//     volcarla, siempre.
//
//   · Canvas.save() devuelve false y no escribe. Exportar es toDataURL y la
//     forja escribe el fichero. Eso vive en servicios/Proyecto.qml.
//
//  El zoom NO lo hace el Canvas: el Canvas está siempre a 1:1 con el sprite y
//  quien lo agranda es la GPU, con smooth:false. Por eso da igual dibujar al
//  100 % o al 3200 %: el trabajo de la CPU es el mismo.

import QtQuick
import "../core" as C
import "../core/pixeles.js" as P
import "../core/herramientas.js" as H
import "../servicios" as S

Item {
    id: raiz
    clip: true
    focus: true

    readonly property int aw: S.Documento.ancho
    readonly property int ah: S.Documento.alto
    readonly property real zoom: S.Ajustes.zoom
    readonly property bool hayDoc: S.Documento.abierto

    property int cursorX: -1
    property int cursorY: -1
    property bool dentro: false
    signal colorCogido()

    // ═══════════════════════════════════════════════════════════
    // el búfer compuesto y su repintado por rectángulo
    // ═══════════════════════════════════════════════════════════

    property var _local: null          // búfer compuesto, tamaño del documento
    property var _ctx: null
    property var _pendiente: null      // rectángulo sucio esperando repintado

    function _preparar() {
        if (!hayDoc || !_ctx) return false
        if (!_local || _local.w !== aw || _local.h !== ah) {
            _local = P.nuevo(aw, ah)
            _pendiente = { x: 0, y: 0, w: aw, h: ah }
        }
        return true
    }

    /** Recompone SÓLO el rectángulo pedido y devuelve el recortado al lienzo. */
    function _recompon(r) {
        const d = S.Documento.d
        if (!d) return null
        const x0 = Math.max(0, r.x), y0 = Math.max(0, r.y)
        const x1 = Math.min(aw, r.x + r.w), y1 = Math.min(ah, r.y + r.h)
        if (x1 <= x0 || y1 <= y0) return null
        for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
            const i = (y * aw + x) * 4
            _local.d[i] = 0; _local.d[i+1] = 0; _local.d[i+2] = 0; _local.d[i+3] = 0
        }
        //  La misma función que usa la exportación, con el rectángulo sucio.
        //  Tener aquí una copia de "cómo se apilan las capas" haría que el PNG
        //  que sale no tuviera por qué parecerse a lo que ves.
        S.Documento.componEn(_local, S.Documento.fotograma, S.Documento.orientacion,
                             { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }, true)
        return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
    }

    /**
     * El color que se está enseñando en pantalla en ese píxel.
     *
     * No es lo mismo que lo que hay en la capa: entre el búfer y la pantalla
     * está el repintado, y ahí es donde vivía el fallo de "dibujo y sale al
     * lado". Sin poder mirar esto, ninguna prueba lo habría cazado.
     */
    function pixelEnPantalla(x, y) {
        if (!_ctx) return null
        const d = _ctx.getImageData(x, y, 1, 1).data
        return [d[0], d[1], d[2], d[3]]
    }

    function ensucia(r) {
        const n = r || { x: 0, y: 0, w: aw, h: ah }
        if (!_pendiente) _pendiente = n
        else {
            const x0 = Math.min(_pendiente.x, n.x), y0 = Math.min(_pendiente.y, n.y)
            const x1 = Math.max(_pendiente.x + _pendiente.w, n.x + n.w)
            const y1 = Math.max(_pendiente.y + _pendiente.h, n.y + n.h)
            _pendiente = { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
        }
        arte.requestPaint()
    }

    Connections {
        target: S.Documento
        function onPixelesCambiados(x, y, w, h) { raiz.ensucia({ x: x, y: y, w: w, h: h }) }
        function onRevChanged() { raiz.ensucia(null); cebolla.requestPaint() }
    }
    Connections {
        target: S.Seleccion
        function onRevChanged() { hormigas.requestPaint() }
    }

    // ═══════════════════════════════════════════════════════════
    // el mundo: pan, zoom y todo lo que se dibuja encima
    // ═══════════════════════════════════════════════════════════

    readonly property real anchoVisto: aw * zoom
    readonly property real altoVisto: ah * zoom

    /**
     * Centrar y encajar.
     *
     * Las dos comprueban la geometría antes de tocar nada, y no es paranoia:
     * mientras los anchors se resuelven, este Item pasa por tamaños absurdos
     * —anchura negativa incluida, cuando el panel de la derecha todavía está
     * en x=0 y el carril ya mide 44—. La primera versión centraba en cada
     * cambio de anchura y se quedaba con uno de esos estados intermedios: el
     * lienzo acababa en x=-138, entero fuera de la vista, y parecía que no
     * pintaba. No había nada roto en el pintado.
     */
    function centra() {
        if (width <= 0 || height <= 0) return
        S.Ajustes.panX = Math.round((width - anchoVisto) / 2)
        S.Ajustes.panY = Math.round((height - altoVisto) / 2)
    }

    function ajusta() {
        if (!hayDoc || width <= 0 || height <= 0) return
        const z = Math.max(1, Math.min(64,
                  Math.floor(Math.min((width - 40) / aw, (height - 40) / ah))))
        S.Ajustes.zoom = z
        centra()
    }

    /** Que el lienzo no se pueda perder del todo al redimensionar la ventana. */
    function _asegura() {
        if (!hayDoc || width <= 0 || height <= 0) return
        const m = 32
        S.Ajustes.panX = Math.max(m - anchoVisto, Math.min(width - m, S.Ajustes.panX))
        S.Ajustes.panY = Math.max(m - altoVisto, Math.min(height - m, S.Ajustes.panY))
    }

    onWidthChanged: Qt.callLater(_asegura)
    onHeightChanged: Qt.callLater(_asegura)
    onHayDocChanged: if (hayDoc) Qt.callLater(ajusta)

    //  Abrir un proyecto no cierra el anterior, así que `hayDoc` puede no
    //  cambiar: lo que sí cambia siempre es el tamaño del documento.
    Connections {
        target: S.Documento
        function onAnchoChanged() { Qt.callLater(raiz.ajusta) }
        function onAltoChanged() { Qt.callLater(raiz.ajusta) }
    }

    Rectangle { anchors.fill: parent; color: C.Tema.fondo }

    Item {
        id: mundo
        x: Math.round(S.Ajustes.panX)
        y: Math.round(S.Ajustes.panY)
        width: raiz.anchoVisto
        height: raiz.altoVisto
        visible: raiz.hayDoc

        // ── el ajedrez de transparencia ──────────────────────────
        //  En espacio de PANTALLA y no de sprite: si el damero se agrandara
        //  con el zoom, a ×32 serían cuadros de medio panel y dejaría de
        //  leerse como "aquí no hay nada".
        Canvas {
            id: ajedrez
            anchors.fill: parent
            visible: S.Ajustes.ajedrez
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const g = getContext("2d")
                const t = 8
                g.fillStyle = C.Tema.ajedrezA
                g.fillRect(0, 0, width, height)
                g.fillStyle = C.Tema.ajedrezB
                for (let y = 0; y < height; y += t) for (let x = 0; x < width; x += t)
                    if (((x / t) + (y / t)) % 2 === 1) g.fillRect(x, y, t, t)
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // ── la piel de cebolla ───────────────────────────────────
        Canvas {
            id: cebolla
            //  la caja del ImageData reutilizado; ver P.lienzoImg
            property var caja: ({ img: null })
            width: raiz.aw; height: raiz.ah
            transformOrigin: Item.TopLeft
            scale: raiz.zoom
            smooth: false
            visible: S.Ajustes.cebolla && S.Documento.nFotogramas > 1
            opacity: S.Ajustes.cebollaOpacidad
            renderStrategy: Canvas.Cooperative
            renderTarget: Canvas.Image

            onPaint: {
                if (!visible || !raiz.hayDoc) return
                const g = getContext("2d")
                g.clearRect(0, 0, width, height)
                const f0 = S.Documento.fotograma
                const img = P.lienzoImg(cebolla.caja, g, raiz.aw, raiz.ah)
                const acc = P.nuevo(raiz.aw, raiz.ah)

                for (let k = -S.Ajustes.cebollaAtras; k <= S.Ajustes.cebollaDelante; k++) {
                    if (k === 0) continue
                    const f = f0 + k
                    if (f < 0 || f >= S.Documento.nFotogramas) continue
                    let b = S.Documento.compuesto(f, S.Documento.orientacion)
                    if (!b) continue
                    if (S.Ajustes.cebollaTeñida) {
                        // pasado rojo, futuro azul: saber hacia dónde va el
                        // movimiento sin contar fotogramas
                        b = P.clonar(b)
                        for (let i = 0; i < b.w * b.h; i++) {
                            if (b.d[i*4+3] === 0) continue
                            const l = P.luma([b.d[i*4], b.d[i*4+1], b.d[i*4+2]])
                            if (k < 0) { b.d[i*4] = 90 + l * 0.7; b.d[i*4+1] = l * 0.3; b.d[i*4+2] = l * 0.3 }
                            else       { b.d[i*4] = l * 0.3; b.d[i*4+1] = l * 0.4; b.d[i*4+2] = 90 + l * 0.7 }
                        }
                    }
                    P.compon(acc, b, "normal", 1 / (Math.abs(k) + 0.6))
                }
                P.vuelcaZona(img, acc, 0, 0, raiz.aw, raiz.ah)
                g.putImageData(img, 0, 0, 0, 0, raiz.aw, raiz.ah)
            }
        }

        // ── EL ARTE ──────────────────────────────────────────────
        Canvas {
            id: arte
            property var caja: ({ img: null })
            width: raiz.aw
            height: raiz.ah
            transformOrigin: Item.TopLeft
            scale: raiz.zoom          // el zoom lo hace la GPU, no el Canvas
            smooth: false             // ...y sin suavizar, que es todo el truco
            renderStrategy: Canvas.Cooperative
            renderTarget: Canvas.Image

            onPaint: {
                raiz._ctx = getContext("2d")
                if (!raiz._preparar()) return
                const pend = raiz._pendiente
                if (!pend) return
                raiz._pendiente = null
                const r = raiz._recompon(pend)
                if (!r) return

                //  Un ImageData del tamaño de la ZONA SUCIA, colocado en su
                //  sitio con dx,dy. No se puede pasar el lienzo entero con un
                //  rectángulo sucio desplazado: en este Qt eso no pinta nada y
                //  no da ningún error (comprobado en cata/cata.qml).
                //  Limpiar antes de volcar. Sin esto, un píxel que pasa a
                //  transparente —una goma, un deshacer— se queda en pantalla
                //  para siempre, porque putImageData mezcla en vez de
                //  reemplazar. Ver la cabecera de este fichero.
                raiz._ctx.clearRect(r.x, r.y, r.w, r.h)

                //  Un solo ImageData del tamaño del lienzo, para siempre. La
                //  zona sucia se escribe pegada a su esquina, fila a fila con el
                //  paso del ImageData, y se vuelca desde ahí. Crear uno por
                //  pintado dejaba el motor lento sin vuelta atrás; ver P.lienzoImg.
                const img = P.lienzoImg(arte.caja, raiz._ctx, raiz.aw, raiz.ah)
                P.vuelcaZona(img, raiz._local, r.x, r.y, r.w, r.h)
                raiz._ctx.putImageData(img, r.x, r.y, 0, 0, r.w, r.h)
            }
            onAvailableChanged: if (available) requestPaint()
            Component.onCompleted: requestPaint()
        }

        // ── el modo baldosa: el lienzo repetido alrededor ────────
        Repeater {
            model: S.Ajustes.modoBaldosa ? 8 : 0
            Item {
                readonly property int ix: (index % 3) - 1 + (index >= 4 ? 1 : 0)
                readonly property var celdas: [[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]]
                x: celdas[index][0] * raiz.anchoVisto
                y: celdas[index][1] * raiz.altoVisto
                width: raiz.anchoVisto; height: raiz.altoVisto
                opacity: 0.55
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: arte
                    smooth: false
                    live: true
                    textureSize: Qt.size(raiz.aw, raiz.ah)
                }
            }
        }

        // ── rejillas ─────────────────────────────────────────────
        Canvas {
            id: rejilla
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            visible: (S.Ajustes.rejillaPixel && raiz.zoom >= 6) || S.Ajustes.rejillaCasilla

            onPaint: {
                const g = getContext("2d")
                g.clearRect(0, 0, width, height)
                const z = raiz.zoom

                if (S.Ajustes.rejillaPixel && z >= 6) {
                    g.strokeStyle = C.Tema.oscuro ? "rgba(255,255,255,0.07)" : "rgba(0,0,0,0.07)"
                    g.lineWidth = 1
                    g.beginPath()
                    for (let x = 1; x < raiz.aw; x++) { g.moveTo(x * z + 0.5, 0); g.lineTo(x * z + 0.5, height) }
                    for (let y = 1; y < raiz.ah; y++) { g.moveTo(0, y * z + 0.5); g.lineTo(width, y * z + 0.5) }
                    g.stroke()
                }

                // La rejilla de CASILLA es la del contrato: la casilla del
                // claro, la baldosa del tileset. Es la que dice si el dibujo
                // cabe donde tiene que caber.
                if (S.Ajustes.rejillaCasilla) {
                    const cw = S.Ajustes.casillaAncho * z, ch = S.Ajustes.casillaAlto * z
                    if (cw >= 4 && ch >= 4) {
                        g.strokeStyle = C.Tema.oscuro ? "rgba(228,136,78,0.42)" : "rgba(168,71,26,0.42)"
                        g.lineWidth = 1
                        g.beginPath()
                        for (let x = cw; x < width; x += cw) { g.moveTo(x + 0.5, 0); g.lineTo(x + 0.5, height) }
                        for (let y = ch; y < height; y += ch) { g.moveTo(0, y + 0.5); g.lineTo(width, y + 0.5) }
                        g.stroke()
                    }
                }

                // los bloques del tileset, si el contrato los declara
                const con = S.Documento.d ? S.Documento.d.contrato : null
                if (con && con.bloques) {
                    const t = con.rejilla ? con.rejilla.ancho : 24
                    for (let i = 0; i < con.bloques.length; i++) {
                        const b = con.bloques[i]
                        g.strokeStyle = b.color
                        g.lineWidth = 2
                        g.strokeRect(b.desde * t * z, 0, (b.hasta - b.desde + 1) * t * z, height)
                    }
                }
            }
            Component.onCompleted: requestPaint()
            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
        }
        Connections {
            target: S.Ajustes
            function onZoomChanged() { rejilla.requestPaint(); hormigas.requestPaint(); ajedrez.requestPaint() }
            function onCasillaAnchoChanged() { rejilla.requestPaint() }
            function onCasillaAltoChanged() { rejilla.requestPaint() }
        }

        // ── ejes de simetría ─────────────────────────────────────
        Rectangle {
            visible: S.Ajustes.simetriaH
            width: 1; height: parent.height
            x: Math.round((S.Ajustes.ejeX >= 0 ? S.Ajustes.ejeX + 0.5 : raiz.aw / 2) * raiz.zoom)
            color: C.Tema.acento; opacity: 0.6
        }
        Rectangle {
            visible: S.Ajustes.simetriaV
            height: 1; width: parent.width
            y: Math.round((S.Ajustes.ejeY >= 0 ? S.Ajustes.ejeY + 0.5 : raiz.ah / 2) * raiz.zoom)
            color: C.Tema.acento; opacity: 0.6
        }

        // ── vista previa de la herramienta ───────────────────────
        Canvas {
            id: previa
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            property var puntos: []

            onPaint: {
                const g = getContext("2d")
                g.clearRect(0, 0, width, height)
                if (!puntos.length) return
                const z = raiz.zoom
                g.fillStyle = C.Tema.oscuro ? "rgba(228,136,78,0.85)" : "rgba(168,71,26,0.85)"
                for (let i = 0; i < puntos.length; i++)
                    g.fillRect(puntos[i][0] * z, puntos[i][1] * z, z, z)
            }
            onPuntosChanged: requestPaint()
        }

        // ── las hormigas de la selección ─────────────────────────
        Canvas {
            id: hormigas
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            visible: S.Seleccion.activa
            property real fase: 0

            onPaint: {
                const g = getContext("2d")
                g.clearRect(0, 0, width, height)
                if (!S.Seleccion.activa) return
                const seg = S.Seleccion.contorno()
                const z = raiz.zoom
                g.lineWidth = 1
                for (let paso = 0; paso < 2; paso++) {
                    g.strokeStyle = paso === 0 ? "#000000" : "#FFFFFF"
                    g.setLineDash([4, 4])
                    g.lineDashOffset = paso === 0 ? fase : fase + 4
                    g.beginPath()
                    for (let i = 0; i < seg.length; i++) {
                        g.moveTo(seg[i][0] * z + 0.5, seg[i][1] * z + 0.5)
                        g.lineTo(seg[i][2] * z + 0.5, seg[i][3] * z + 0.5)
                    }
                    g.stroke()
                }
            }
            Timer {
                running: S.Seleccion.activa && raiz.visible
                interval: 90; repeat: true
                onTriggered: { hormigas.fase = (hormigas.fase + 1) % 8; hormigas.requestPaint() }
            }
        }

        // ── medidas de silueta ───────────────────────────────────
        //  Lo que el juego mide de los píxeles y no del recuadro: dejar tres
        //  filas vacías de más cambia dónde pisa el bicho, y eso no se ve.
        Canvas {
            id: medidas
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            visible: S.Ajustes.medidasSilueta

            onPaint: {
                const g = getContext("2d")
                g.clearRect(0, 0, width, height)
                if (!visible || !raiz.hayDoc) return
                const b = S.Documento.compuesto()
                if (!b) return
                const s = P.silueta(b)
                const z = raiz.zoom
                if (s.limites) {
                    g.strokeStyle = "rgba(138,189,91,0.9)"; g.lineWidth = 1
                    g.strokeRect(s.limites.x * z + 0.5, s.limites.y * z + 0.5,
                                 s.limites.w * z - 1, s.limites.h * z - 1)
                }
                // el suelo: donde apoyan los pies
                const suelo = (raiz.ah - s.pieBajo) * z
                g.strokeStyle = "rgba(224,80,138,0.9)"; g.lineWidth = 2
                g.beginPath(); g.moveTo(0, suelo); g.lineTo(width, suelo); g.stroke()
                // el radio de colisión, medido de la silueta
                g.strokeStyle = "rgba(79,191,241,0.85)"; g.lineWidth = 1
                g.beginPath()
                g.ellipse((raiz.aw / 2 - s.base) * z, suelo - s.base * z * 0.5,
                          s.base * 2 * z, s.base * z)
                g.stroke()
            }
            onVisibleChanged: requestPaint()
        }
        Connections {
            target: S.Documento
            function onRevPixelesChanged() { if (medidas.visible) medidas.requestPaint() }
        }

        // ── el borde del lienzo ──────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: C.Tema.borde
        }
    }

    // ═══════════════════════════════════════════════════════════
    // entrada
    // ═══════════════════════════════════════════════════════════

    property var _herramienta: null
    property bool _paneando: false
    property real _panDesdeX: 0
    property real _panDesdeY: 0
    property bool _espacio: false

    function aPixelX(mx) { return Math.floor((mx - mundo.x) / zoom) }
    function aPixelY(my) { return Math.floor((my - mundo.y) / zoom) }

    /** Todo lo que una herramienta necesita saber, en un objeto plano. */
    function _contexto(buf) {
        return {
            buf: buf, ancho: aw, alto: ah,
            selContiene: (x, y) => S.Seleccion.contiene(x, y),
            mascaraSeleccion: S.Seleccion.mascara,
            alfaBloqueado: (S.Documento.capa(S.Documento.capaActiva) || {}).alfaBloqueado,
            tamaño: S.Pinceles.tamaño,
            puntaCuadrada: S.Pinceles.puntaCuadrada,
            pincel: S.Pinceles.pincelPersonal,
            trama: S.Pinceles.trama,
            proporcionTrama: S.Pinceles.proporcionTrama,
            simetriaH: S.Ajustes.simetriaH, simetriaV: S.Ajustes.simetriaV,
            ejeX: S.Ajustes.ejeX, ejeY: S.Ajustes.ejeY,
            baldosa: S.Ajustes.modoBaldosa,
            primario: S.Paleta.primario, secundario: S.Paleta.secundario,
            trazoPerfecto: S.Pinceles.trazoPerfecto,
            tolerancia: S.Pinceles.tolerancia,
            contiguo: S.Pinceles.contiguo,
            ochoVecinos: S.Pinceles.ochoVecinos,
            relleno: S.Pinceles.relleno,
            desdeElCentro: S.Pinceles.desdeElCentro,
            proporcionFija: raiz._mays, anguloFijo: raiz._mays,
            fuerza: S.Pinceles.fuerza,
            pasoSombreado: S.Pinceles.pasoSombreado,
            tipoDegradado: S.Pinceles.tipoDegradado,
            degradadoTramado: S.Pinceles.degradadoTramado,
            compuesto: S.Documento.compuesto(),
            alcance: S.Pinceles.alcanceColor,
            sustituyeAmplio: (viejo, nuevoColor, tol) => raiz.sustituyeEnTodo(viejo, nuevoColor, tol),
            vecinoEnRampa: (c, paso) => S.Paleta.vecinoEnRampa(c, paso),
            eligeColor: (c, secundario) => {
                if (secundario) S.Paleta.ponSecundario(c); else S.Paleta.ponPrimario(c)
                raiz.colorCogido()
            },
            ponSeleccionForma: (tipo, x0, y0, x1, y1) => {
                if (tipo === "rectangulo") S.Seleccion.desdeRectangulo(x0, y0, x1, y1, aw, ah, S.Pinceles.modoSeleccion)
                else S.Seleccion.desdeElipse(x0, y0, x1, y1, aw, ah, S.Pinceles.modoSeleccion)
            },
            ponSeleccionPoligono: (pts) => S.Seleccion.desdePoligono(pts, aw, ah, S.Pinceles.modoSeleccion),
            ponSeleccionMascara: (m) => S.Seleccion.pon(m, aw, ah, S.Pinceles.modoSeleccion),
            mueveSeleccion: (dx, dy) => {
                if (!S.Seleccion.activa) return
                const m = new Uint8Array(aw * ah)
                for (let y = 0; y < ah; y++) for (let x = 0; x < aw; x++)
                    if (S.Seleccion.contiene(x - dx, y - dy)) m[y * aw + x] = 1
                S.Seleccion.pon(m, aw, ah, "nueva")
            }
        }
    }

    property bool _mays: false
    property bool _ctrl: false

    // ═══════════════════════════════════════════════════════════
    // el gesto, aparte del ratón
    // ═══════════════════════════════════════════════════════════
    //
    //  Pulsar, arrastrar y soltar son funciones normales que reciben
    //  coordenadas de ESTE item. El MouseArea de abajo sólo las llama. Así se
    //  puede comprobar en seco que pinchar en un sitio pinta ese píxel y no
    //  otro, que es justo la clase de fallo que no se ve mirando la pantalla —
    //  se ve pintando, y para entonces ya te has vuelto loco.

    function pulsa(mx, my, boton, mods) {
        raiz.forceActiveFocus()
        raiz._mays = !!(mods & Qt.ShiftModifier)
        raiz._ctrl = !!(mods & Qt.ControlModifier)

        if (boton === Qt.MiddleButton || raiz._espacio || S.Pinceles.herramienta === "mano") {
            raiz._paneando = true
            raiz._panDesdeX = mx - S.Ajustes.panX
            raiz._panDesdeY = my - S.Ajustes.panY
            return
        }
        if (!raiz.hayDoc) return
        const capa = S.Documento.capa(S.Documento.capaActiva)
        if (!capa) return
        if (capa.bloqueada && !S.Pinceles.esSeleccion) return

        // Alt sobre cualquier herramienta = cuentagotas, sin cambiar de
        // herramienta. Es el gesto que más se repite dibujando.
        const nombre = (mods & Qt.AltModifier) ? "cuentagotas" : S.Pinceles.herramienta
        const buf = S.Documento.celdaActiva(true)
        if (!buf) return

        raiz._herramienta = H.crea(nombre, raiz._contexto(buf))
        if (!S.Pinceles.esSeleccion && nombre !== "cuentagotas")
            S.Historial.abre(S.Documento.clave(capa.id, S.Documento.fotograma,
                                               S.Documento.orientacion), buf)
        raiz._herramienta.abajo(raiz.aPixelX(mx), raiz.aPixelY(my),
                                boton === Qt.RightButton ? 2 : 1)
        raiz._tras()
    }

    function arrastra(mx, my, botones, mods) {
        raiz.cursorX = raiz.aPixelX(mx)
        raiz.cursorY = raiz.aPixelY(my)
        raiz.dentro = raiz.cursorX >= 0 && raiz.cursorY >= 0
                   && raiz.cursorX < raiz.aw && raiz.cursorY < raiz.ah
        if (raiz._paneando) {
            S.Ajustes.panX = mx - raiz._panDesdeX
            S.Ajustes.panY = my - raiz._panDesdeY
            return
        }
        if (!raiz._herramienta) return
        raiz._mays = !!(mods & Qt.ShiftModifier)
        raiz._herramienta.mueve(raiz.cursorX, raiz.cursorY,
                                (botones & Qt.RightButton) ? 2 : 1)
        raiz._tras()
    }

    function suelta(mx, my) {
        if (raiz._paneando) { raiz._paneando = false; return }
        if (!raiz._herramienta) return
        const r = raiz._herramienta.arriba(raiz.aPixelX(mx), raiz.aPixelY(my))
        previa.puntos = []
        const capa = S.Documento.capa(S.Documento.capaActiva)
        if (r && capa) {
            S.Historial.cierra(S.Pinceles.herramienta, S.Documento.celdaActiva(false))
            S.Documento.cambiaPixeles(r)
        }
        raiz._herramienta = null
    }

    /** Acercar o alejar anclando al cursor, para no perder de vista el detalle. */
    function acerca(mx, my, haciaDentro) {
        const antes = zoom
        const z = Math.max(0.25, Math.min(64, antes * (haciaDentro ? 1.25 : 0.8)))
        const zz = z >= 1 ? Math.max(1, Math.round(z)) : z
        const px = (mx - S.Ajustes.panX) / antes
        const py = (my - S.Ajustes.panY) / antes
        S.Ajustes.zoom = zz
        S.Ajustes.panX = mx - px * zz
        S.Ajustes.panY = my - py * zz
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: raiz._paneando || raiz._espacio ? Qt.ClosedHandCursor
                   : S.Pinceles.herramienta === "mano" ? Qt.OpenHandCursor
                   : Qt.CrossCursor

        onPressed: (m) => raiz.pulsa(m.x, m.y, m.button, m.modifiers)
        onPositionChanged: (m) => raiz.arrastra(m.x, m.y, m.buttons, m.modifiers)
        onReleased: (m) => raiz.suelta(m.x, m.y)
        onExited: { raiz.dentro = false; raiz.cursorX = -1 }

        onWheel: (w) => {
            if (w.modifiers & Qt.ShiftModifier) S.Ajustes.panX += w.angleDelta.y > 0 ? 40 : -40
            else raiz.acerca(w.x, w.y, w.angleDelta.y > 0)
        }
    }

    /**
     * Cambia un color en más de una celda a la vez.
     *
     * Va por instantánea completa y no por rectángulo sucio: el cambio toca
     * decenas de celdas y el historial de píxeles guarda una sola. Deshacerlo
     * tiene que devolverlo todo de golpe, que es lo que espera cualquiera
     * después de un cambio así.
     *
     * Respeta la selección si la hay — recolorear sólo un trozo, en todos los
     * fotogramas, es una petición perfectamente normal.
     */
    function sustituyeEnTodo(viejo, nuevoColor, tolerancia) {
        const d = S.Documento.d
        if (!d) return
        const capaActual = S.Documento.capa(S.Documento.capaActiva)
        if (!capaActual) return

        const todas = S.Pinceles.todasLasCapas
        //  «y las demás acciones» incluye «y las 8 caras»: recolorear la
        //  criatura entera y dejarte una cara sin tocar no lo pide nadie.
        const porAcciones = S.Pinceles.alcanceColor === "acciones"
        const porTodo = porAcciones || S.Pinceles.alcanceColor === "todo"
        const hayFiltro = S.Seleccion.activa

        S.Historial.abreCompleto()
        let tocadas = 0
        for (let k = 0; k < d.capas.length; k++) {
            const c = d.capas[k]
            if (!todas && c.id !== capaActual.id) continue
            if (c.tipo === "grupo" || c.bloqueada) continue
            for (let f = 0; f < S.Documento.nFotogramas; f++)
                for (let dr = 0; dr < S.Documento.nOrientaciones; dr++) {
                    //  Sin "todo", sólo los fotogramas de la cara que miras:
                    //  cambiar el color de un ojo no tiene por qué tocar las
                    //  otras siete orientaciones si no lo pides.
                    if (!porTodo && dr !== S.Documento.orientacion) continue
                    const b = S.Documento.celda(c.id, f, dr, false)
                    if (!b) continue
                    let cambio = false
                    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
                        if (hayFiltro && !S.Seleccion.contiene(x, y)) continue
                        const p = P.lee(b, x, y)
                        if (P.distancia(p, viejo) > tolerancia) continue
                        P.pon(b, x, y, [nuevoColor[0], nuevoColor[1], nuevoColor[2], p[3]])
                        cambio = true
                    }
                    if (cambio) tocadas++
                }
        }
        S.Historial.cierraEstructuraOCompleto(
            "sustituir color en " + tocadas + " celdas")
        S.Documento.cambiaPixeles(null)
        raiz.colorSustituido(tocadas)

        //  Y las otras acciones, que son otros documentos. Se guarda antes la
        //  que tienes delante para que la criatura quede entera de una pieza:
        //  el disco con un color y la pantalla con otro es justo el lío que
        //  esto viene a quitar.
        //  La selección no viaja: en otra acción el dibujo es otro y el mismo
        //  recuadro caería en cualquier sitio. Allí el cambio va entero.
        if (porAcciones && S.Especie.abierta) {
            S.Proyecto.guarda(null, (bien) => {
                if (bien) S.Especie.sustituyeColorEnTodas(viejo, nuevoColor, tolerancia, null)
            })
        }
    }

    signal colorSustituido(int celdas)

    /** Después de cada gesto: repintar lo sucio y la vista previa. */
    function _tras() {
        if (!_herramienta) return
        if (_herramienta.vistaPrevia) previa.puntos = _herramienta.vistaPrevia()
        const r = _herramienta.brocha ? _herramienta.brocha.rect() : null
        if (r) ensucia(r)
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) { _espacio = true; e.accepted = true }
        if (e.key === Qt.Key_Escape) {
            if (_herramienta && _herramienta.cierra) _herramienta.cierra()
            previa.puntos = []
            S.Seleccion.nada()
        }
    }
    Keys.onReleased: (e) => {
        if (e.key === Qt.Key_Space && !e.isAutoRepeat) { _espacio = false; e.accepted = true }
    }

    // ── el mensaje de cuando no hay nada abierto ─────────────────
    Column {
        anchors.centerIn: parent
        visible: !raiz.hayDoc
        spacing: 10
        C.Icono {
            glifo: C.Tema.i.lapiz
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 34
            color: C.Tema.apagado
        }
        Text {
            text: "sin nada abierto"
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: C.Tema.tipo
            font.pixelSize: 15
            color: C.Tema.tenue
        }
        Text {
            text: "Ctrl+N para empezar   ·   Ctrl+K para todo lo demás"
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: C.Tema.tipoMono
            font.pixelSize: C.Tema.letraChica
            color: C.Tema.apagado
        }
    }
}

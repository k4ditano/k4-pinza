//  Las hojas.
//
//  Ni un diálogo modal en todo el programa. Redimensionar, exportar, elegir
//  contrato, cuantizar: todo entra por la derecha y deja el lienzo a la vista y
//  vivo, porque la mitad de estas decisiones sólo se pueden tomar mirando el
//  dibujo. Decidir a cuántos colores cuantizar con el dibujo tapado es adivinar.
//
//  Los selectores de FICHERO sí son del sistema: ahí lo raro sería inventarse
//  un explorador propio peor que el que ya tiene el escritorio.

import QtQuick
import QtQuick.Dialogs
import "../core" as C
import "../core/pixeles.js" as P
import "../servicios" as S

Item {
    id: raiz
    anchors.fill: parent
    z: 800

    property string hoja: ""
    property string modoHoja: ""     // con qué pantalla abrirla, si tiene varias
    readonly property bool abierta: hoja !== ""
    signal aviso(string texto)

    function abre(nombre, modo) { modoHoja = modo || ""; hoja = nombre }
    function cierra() { hoja = "" }

    // el lienzo sigue clicable a la izquierda: esto no tapa nada que no ocupe
    MouseArea {
        anchors.fill: parent
        visible: raiz.abierta
        acceptedButtons: Qt.AllButtons
        onClicked: raiz.cierra()
        enabled: raiz.abierta
        propagateComposedEvents: false
        // sólo la franja de fuera del panel
        anchors.rightMargin: panel.width
    }

    Rectangle {
        id: panel
        width: 300
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        x: raiz.abierta ? 0 : width
        visible: raiz.abierta || x < width
        color: C.Tema.superficie
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.left: parent.left
            width: 1; height: parent.height
            color: C.Tema.borde
        }

        // ── cabecera ─────────────────────────────────────────────
        Item {
            id: cabeza
            width: parent.width
            height: C.Tema.barra

            C.Rotulo {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: raiz._titulos[raiz.hoja] || raiz.hoja
                color: C.Tema.acento
            }
            C.Boton {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                icono: C.Tema.i.cerrar
                width: 24; implicitHeight: 24
                onPulsado: raiz.cierra()
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: C.Tema.borde
            }
        }

        readonly property var contenidos: ({
            "nuevo": cNuevo, "exportar": cExportar, "lienzo": cLienzo, "escalar": cEscalar,
            "orientaciones": cOrientaciones, "pack": cPack, "comprobar": cComprobar,
            "etiqueta": cEtiqueta, "cuantizar": cCuantizar, "desplazar": cDesplazar,
            "importar": cImportar, "exportarAnim": cAnim, "guiones": cGuiones,
            "especie": cEspecie, "transformar": cTransformar
        })

        Flickable {
            anchors.top: cabeza.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            contentHeight: cargador.height
            clip: true

            Loader {
                id: cargador
                width: parent.width
                sourceComponent: panel.contenidos[raiz.hoja] || null
            }
        }
    }

    readonly property var _titulos: ({
        "nuevo": "nuevo", "exportar": "exportar", "lienzo": "tamaño del lienzo",
        "escalar": "escalar el dibujo", "orientaciones": "orientaciones", "pack": "pack",
        "comprobar": "comprobaciones del juego", "etiqueta": "etiqueta",
        "cuantizar": "cuantizar", "desplazar": "desplazar envolviendo",
        "importar": "importar", "exportarAnim": "exportar animación"
    })

    // ═══════════════════════════════════════════════════════════
    // nuevo
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cNuevo
        Column {
            spacing: 9
            property string contratoId: S.Packs.contratos.length ? S.Packs.contratos[0].id : ""
            readonly property var con: S.Packs.contrato(contratoId)
            property int an: con ? con.ancho : 32
            property int al: con ? con.alto : 32
            property int nf: con ? (con.fotogramas || 1) : 1
            property string nombre: "sin nombre"
            property int huellaW: 1
            property int huellaH: 1
            onConChanged: if (con) { an = con.ancho; al = con.alto; nf = con.fotogramas || 1 }

            C.Rotulo { text: "pack" }
            C.Opcion {
                width: parent.width
                opciones: S.Packs.lista.map((p) => ({ id: p.id, titulo: p.titulo }))
                valor: S.Packs.activoId
                onCambiado: (v) => { S.Packs.elige(v); parent.contratoId = S.Packs.contratos[0].id }
            }

            Item { width: 1; height: 2 }
            C.Rotulo { text: "qué estás dibujando" }

            Repeater {
                model: S.Packs.contratos
                Rectangle {
                    width: parent.width
                    height: cuerpo.implicitHeight + 14
                    radius: 3
                    color: modelData.id === parent.parent.contratoId ? C.Tema.acentoTenue
                         : conRaton.containsMouse ? C.Tema.alta : "transparent"
                    border.width: modelData.id === parent.parent.contratoId ? 1 : 0
                    border.color: C.Tema.acento

                    Column {
                        id: cuerpo
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 2
                        Text {
                            text: modelData.titulo
                            font.family: C.Tema.tipo; font.pixelSize: C.Tema.letra
                            font.weight: Font.DemiBold
                            color: modelData.id === parent.parent.parent.contratoId ? C.Tema.acento : C.Tema.tinta
                        }
                        Text {
                            width: parent.width
                            text: modelData.resumen
                            wrapMode: Text.WordWrap
                            font.family: C.Tema.tipo; font.pixelSize: 10
                            color: C.Tema.tenue
                        }
                    }
                    MouseArea {
                        id: conRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: parent.parent.contratoId = modelData.id
                    }
                }
            }

            Item { width: 1; height: 4 }
            C.Campo {
                width: parent.width; etiqueta: "nombre"; valor: parent.nombre
                onCambiado: (v) => parent.nombre = v
            }
            C.Campo {
                width: parent.width; etiqueta: "ancho"; numero: true; sufijo: "px"
                valor: String(parent.an); maximo: 4096
                onCambiado: (v) => parent.an = parseInt(v) || 1
            }
            C.Campo {
                width: parent.width; etiqueta: "alto"; numero: true; sufijo: "px"
                valor: String(parent.al); maximo: 4096
                onCambiado: (v) => parent.al = parseInt(v) || 1
            }
            C.Campo {
                width: parent.width; etiqueta: "fotogramas"; numero: true
                valor: String(parent.nf); maximo: 512
                visible: !parent.con || parent.con.fotogramasLibres !== false
                onCambiado: (v) => parent.nf = parseInt(v) || 1
            }

            Column {
                width: parent.width
                spacing: 4
                visible: parent.con && parent.con.huella
                C.Rotulo { text: "huella en casillas" }
                Text {
                    width: parent.width
                    text: parent.parent.con && parent.parent.con.huella
                          ? parent.parent.con.huella.ayuda : ""
                    wrapMode: Text.WordWrap
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                }
                C.Campo {
                    width: parent.width; etiqueta: "ancho"; numero: true; maximo: 32
                    valor: String(parent.parent.huellaW)
                    onCambiado: (v) => parent.parent.huellaW = parseInt(v) || 1
                }
                C.Campo {
                    width: parent.width; etiqueta: "alto"; numero: true; maximo: 32
                    valor: String(parent.parent.huellaH)
                    onCambiado: (v) => parent.parent.huellaH = parseInt(v) || 1
                }
            }

            Text {
                width: parent.width
                visible: parent.con && parent.con.orientaciones.length > 1
                text: parent.con ? "orientaciones: "
                      + parent.con.orientaciones.map((o) => o.titulo).join(", ") : ""
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }

            Item { width: 1; height: 6 }
            C.Boton {
                texto: "crear"; activo: true; relleno: 14
                onPulsado: {
                    const o = S.Packs.paraDocumento(parent.con, {
                        nombre: parent.nombre, ancho: parent.an, alto: parent.al,
                        fotogramas: parent.nf
                    })
                    S.Documento.nuevo(o)
                    if (parent.con && parent.con.huella)
                        S.Documento.ponHuella(parent.huellaW, parent.huellaH)
                    if (parent.con && parent.con.campos)
                        for (let i = 0; i < parent.con.campos.length; i++) {
                            const c = parent.con.campos[i]
                            if (c.defecto !== undefined) S.Documento.ponCampo(c.id, c.defecto)
                        }
                    S.Proyecto._aplicaRejilla()
                    S.Historial.limpia()
                    raiz.cierra()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // exportar
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cExportar
        Column {
            spacing: 9
            readonly property var con: S.Documento.d ? S.Documento.d.contrato : null
            property string carpeta: ""

            C.Rotulo { text: "va a escribir" }
            Rectangle {
                width: parent.width
                height: destino.implicitHeight + 14
                radius: 3
                color: C.Tema.fondo
                border.width: 1; border.color: C.Tema.bordeSuave
                Text {
                    id: destino
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 8
                    text: raiz._prevePropio()
                    wrapMode: Text.WrapAnywhere
                    font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta
                }
            }

            // los campos que el contrato pida: van al fichero y al manifiesto
            Repeater {
                model: parent.con && parent.con.campos ? parent.con.campos : []
                Column {
                    width: parent.width
                    spacing: 2
                    C.Campo {
                        width: parent.width
                        visible: modelData.tipo === "texto"
                        etiqueta: modelData.titulo
                        valor: String(S.Documento.campo(modelData.id) || "")
                        onCambiado: (v) => S.Documento.ponCampo(modelData.id, v)
                    }
                    C.Campo {
                        width: parent.width
                        visible: modelData.tipo === "numero"
                        etiqueta: modelData.titulo; numero: true; minimo: 0
                        valor: String(S.Documento.campo(modelData.id) || 0)
                        onCambiado: (v) => S.Documento.ponCampo(modelData.id, parseInt(v) || 0)
                    }
                    C.Opcion {
                        width: parent.width
                        visible: modelData.tipo === "opcion"
                        etiqueta: modelData.titulo
                        opciones: modelData.opciones || []
                        valor: String(S.Documento.campo(modelData.id) || modelData.defecto || "")
                        onCambiado: (v) => S.Documento.ponCampo(modelData.id, v)
                    }
                    Text {
                        width: parent.width
                        visible: !!modelData.ayuda
                        text: modelData.ayuda || ""
                        wrapMode: Text.WordWrap
                        font.family: C.Tema.tipo; font.pixelSize: 9; color: C.Tema.apagado
                    }
                }
            }

            Item { width: 1; height: 4 }
            Row {
                spacing: 6
                C.Boton {
                    texto: "exportar"; activo: true; relleno: 14
                    onPulsado: {
                        S.Proyecto.exporta({ carpeta: parent.parent.carpeta || undefined }, () => {})
                        raiz.cierra()
                    }
                }
                C.Boton {
                    texto: "a otra carpeta…"
                    onPulsado: elegirCarpeta.open()
                }
            }
            FolderDialog {
                id: elegirCarpeta
                onAccepted: {
                    S.Proyecto.exporta({ carpeta: String(selectedFolder).replace("file://", ""),
                                         manifiesto: false }, () => {})
                    raiz.cierra()
                }
            }

            Text {
                width: parent.width
                visible: parent.con && parent.con.manifiesto
                text: "además se escribirá la entrada de "
                      + (parent.con && parent.con.manifiesto ? parent.con.manifiesto.fichero : "")
                      + ", que es el paso que si no se hace a mano"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }
        }
    }

    /** Los ficheros que saldrían, calculados igual que los calcula Proyecto. */
    function _prevePropio() {
        if (!S.Documento.abierto) return ""
        const d = S.Documento.d
        const con = d.contrato
        const salida = (con && con.salida) || { modo: "png", carpeta: "", patron: "{nombre}.png" }
        const base = S.Proyecto.raizPack()
        const sub = S.Proyecto.nombraCon(salida.carpeta || "")
        const carpeta = base ? (sub ? base + "/" + sub : base) : (S.Documento.ruta || "…")
        const nf = S.Documento.nFotogramas, no = S.Documento.nOrientaciones
        const out = []
        if (salida.modo === "png-por-orientacion" && no > 1) {
            for (let dr = 0; dr < no; dr++)
                out.push(S.Proyecto.nombraCon(salida.patron,
                         { orientacion: S.Documento.etiquetaOrientacion(dr) }))
        } else if (salida.modo === "hoja" && (nf > 1 || no > 1)) {
            let patron = salida.patron
            if (no > 1 && salida.patronOrientaciones) patron = salida.patronOrientaciones
            else if (nf === 1 && salida.patronUnico) patron = salida.patronUnico
            out.push(S.Proyecto.nombraCon(patron, { accion: (d.campos || {}).accion || "Anim" })
                     + "   (" + nf + " columnas × " + no + " filas)")
            if (salida.animdata) out.push(salida.animdata)
        } else {
            const patron = (nf === 1 && no === 1 && salida.patronUnico) ? salida.patronUnico : salida.patron
            out.push(S.Proyecto.nombraCon(patron,
                     { orientacion: S.Documento.etiquetaOrientacion(0),
                       accion: (d.campos || {}).accion || "Anim" }))
        }
        return carpeta + "/\n  " + out.join("\n  ")
    }

    // ═══════════════════════════════════════════════════════════
    // lienzo, escalar, desplazar
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cLienzo
        Column {
            spacing: 9
            property int an: S.Documento.ancho
            property int al: S.Documento.alto
            property string anclaje: "c"

            C.Campo { width: parent.width; etiqueta: "ancho"; numero: true; maximo: 4096
                      valor: String(parent.an); onCambiado: (v) => parent.an = parseInt(v) || 1 }
            C.Campo { width: parent.width; etiqueta: "alto"; numero: true; maximo: 4096
                      valor: String(parent.al); onCambiado: (v) => parent.al = parseInt(v) || 1 }

            C.Rotulo { text: "anclado a" }
            Grid {
                columns: 3; spacing: 3
                Repeater {
                    model: ["no", "n", "ne", "o", "c", "e", "so", "s", "se"]
                    C.Boton {
                        width: 30; implicitHeight: 26
                        texto: ["↖","↑","↗","←","·","→","↙","↓","↘"][index]
                        activo: parent.parent.anclaje === modelData
                        onPulsado: parent.parent.anclaje = modelData
                    }
                }
            }

            Item { width: 1; height: 4 }
            C.Boton {
                texto: "cambiar"; activo: true; relleno: 14
                onPulsado: {
                    S.Historial.abreEstructura()
                    S.Documento.redimensiona(parent.an, parent.al, parent.anclaje)
                    S.Historial.cierraEstructura("tamaño del lienzo")
                    raiz.cierra()
                }
            }
        }
    }

    Component {
        id: cEscalar
        Column {
            spacing: 9
            property int an: S.Documento.ancho
            property int al: S.Documento.alto
            property bool suave: false

            C.Campo { width: parent.width; etiqueta: "ancho"; numero: true; maximo: 4096
                      valor: String(parent.an); onCambiado: (v) => parent.an = parseInt(v) || 1 }
            C.Campo { width: parent.width; etiqueta: "alto"; numero: true; maximo: 4096
                      valor: String(parent.al); onCambiado: (v) => parent.al = parseInt(v) || 1 }
            Row {
                spacing: 3
                Repeater {
                    model: [[2, "×2"], [3, "×3"], [0.5, "½"]]
                    C.Boton {
                        texto: modelData[1]; relleno: 8; implicitHeight: 22
                        onPulsado: {
                            parent.parent.an = Math.max(1, Math.round(S.Documento.ancho * modelData[0]))
                            parent.parent.al = Math.max(1, Math.round(S.Documento.alto * modelData[0]))
                        }
                    }
                }
            }
            C.Interruptor {
                width: parent.width
                etiqueta: "suavizado tipo RotSprite"
                valor: parent.suave
                onCambiado: (v) => parent.suave = v
            }
            Text {
                width: parent.width
                text: "el vecino cercano deja escalones cuando el factor no es entero; "
                      + "el suavizado decide cada subpíxel por mayoría y sale más limpio"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }
            C.Boton {
                texto: "escalar"; activo: true; relleno: 14
                onPulsado: {
                    S.Historial.abreEstructura()
                    S.Documento.escala(parent.an, parent.al, parent.suave)
                    S.Historial.cierraEstructura("escalar")
                    raiz.cierra()
                }
            }
        }
    }

    Component {
        id: cDesplazar
        Column {
            spacing: 9
            property int dx: 0
            property int dy: 0
            C.Campo { width: parent.width; etiqueta: "en x"; numero: true; minimo: -4096
                      valor: String(parent.dx); onCambiado: (v) => parent.dx = parseInt(v) || 0 }
            C.Campo { width: parent.width; etiqueta: "en y"; numero: true; minimo: -4096
                      valor: String(parent.dy); onCambiado: (v) => parent.dy = parseInt(v) || 0 }
            Text {
                width: parent.width
                text: "lo que se sale por un lado entra por el otro. Es la forma de mover "
                      + "la costura de una baldosa para ver si de verdad casa."
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }
            C.Boton {
                texto: "desplazar"; activo: true; relleno: 14
                onPulsado: {
                    const c = S.Documento.capa(S.Documento.capaActiva)
                    const b = S.Documento.celdaActiva(true)
                    if (!c || !b) return
                    S.Historial.abre(S.Documento.clave(c.id, S.Documento.fotograma,
                                                       S.Documento.orientacion), b)
                    const n = P.desplaza(b, parent.dx, parent.dy)
                    for (let i = 0; i < b.d.length; i++) b.d[i] = n.d[i]
                    S.Historial.cierra("desplazar", b)
                    S.Documento.cambiaPixeles(null)
                    raiz.cierra()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // girar y escalar a ojo
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cTransformar
        Column {
            id: tr
            spacing: 9
            property real angulo: 0
            property real escala: 1
            property bool suave: true
            property bool puesta: false

            //  Se guarda el estado de partida al abrir y CADA cambio se aplica
            //  sobre él, nunca sobre el resultado anterior: girar cinco grados
            //  cinco veces no es girar veinticinco, es deshacer el dibujo.
            Component.onCompleted: S.Ordenes.empiezaTransformacion()
            Component.onDestruction: if (!puesta) S.Ordenes.cancelaTransformacion()

            function receta(paraLaMarca) {
                const a = angulo, e = escala
                //  La marca nunca se suaviza: el promediado de RotSprite la
                //  muerde por los bordes y parte de lo girado se quedaría fuera
                //  de su propia selección.
                const s = paraLaMarca ? false : suave
                return function (b) {
                    let r = b
                    if (Math.abs(e - 1) > 0.001) {
                        const w = Math.max(1, Math.round(b.w * e))
                        const h = Math.max(1, Math.round(b.h * e))
                        r = s ? P.escalaSuave(r, w, h) : P.escalaVecino(r, w, h)
                    }
                    if (Math.abs(a) > 0.001) r = P.giraLibre(r, a, s)
                    return r
                }
            }

            //  Con retardo: mover el mando dispara veinte cambios por segundo y
            //  cada uno rehace el dibujo entero desde cero.
            Timer {
                id: posa
                interval: 110
                onTriggered: S.Ordenes.ensaya(tr.receta(false), tr.receta(true))
            }
            onAnguloChanged: posa.restart()
            onEscalaChanged: posa.restart()
            onSuaveChanged: posa.restart()

            Text {
                width: parent.width
                text: S.Seleccion.activa
                      ? "sobre lo que tienes marcado; el resto del dibujo no se toca"
                      : "sobre la capa entera, porque no hay nada marcado"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10
                color: S.Seleccion.activa ? C.Tema.acento : C.Tema.tenue
            }

            C.Rotulo { text: "girar" }
            C.Desliz {
                width: parent.width
                etiqueta: "ángulo"; anchoEtiqueta: 52; sufijo: "°"
                minimo: -180; maximo: 180; paso: 1; decimales: 0
                valor: tr.angulo
                onCambiado: (v) => tr.angulo = v
            }
            Row {
                spacing: 3
                Repeater {
                    model: [-90, -45, -15, 15, 45, 90]
                    C.Boton {
                        texto: (modelData > 0 ? "+" : "") + modelData
                        relleno: 6; implicitHeight: 20
                        onPulsado: tr.angulo = Math.max(-180, Math.min(180, tr.angulo + modelData))
                    }
                }
            }

            Item { width: 1; height: 4 }
            C.Rotulo { text: "escalar" }
            C.Desliz {
                width: parent.width
                etiqueta: "tamaño"; anchoEtiqueta: 52; sufijo: "%"
                minimo: 10; maximo: 400; paso: 5; decimales: 0
                valor: tr.escala * 100
                onCambiado: (v) => tr.escala = v / 100
            }
            Row {
                spacing: 3
                Repeater {
                    model: [[0.5, "½"], [2, "×2"], [3, "×3"]]
                    C.Boton {
                        texto: modelData[1]
                        relleno: 8; implicitHeight: 20
                        onPulsado: tr.escala = modelData[0]
                    }
                }
                C.Boton {
                    texto: "sin tocar"; relleno: 8; implicitHeight: 20
                    onPulsado: { tr.angulo = 0; tr.escala = 1 }
                }
            }

            Item { width: 1; height: 4 }
            C.Interruptor {
                width: parent.width
                etiqueta: "suavizado tipo RotSprite"
                valor: tr.suave
                onCambiado: (v) => tr.suave = v
            }
            Text {
                width: parent.width
                text: "agranda ×8 limpiando las escaleras, gira, y vuelve a encoger quedándose "
                      + "con el color que más se repite. No inventa colores nuevos, que es lo "
                      + "que estropea un giro en pixel art."
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }

            Item { width: 1; height: 6 }
            Row {
                spacing: 6
                C.Boton {
                    texto: "aplicar"; activo: true; relleno: 14
                    onPulsado: {
                        tr.puesta = true
                        S.Ordenes.aceptaTransformacion(
                            S.Seleccion.activa ? "girar la selección" : "girar la capa",
                            tr.receta(false), tr.receta(true))
                        raiz.cierra()
                    }
                }
                C.Boton {
                    texto: "dejarlo"
                    onPulsado: { S.Ordenes.cancelaTransformacion(); tr.puesta = true; raiz.cierra() }
                }
            }
            Text {
                width: parent.width
                text: "lo que ves ya es el resultado; aplicar sólo lo deja puesto y lo apunta "
                      + "en el historial como un paso"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.apagado
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // orientaciones
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cOrientaciones
        Column {
            spacing: 9
            readonly property var juegos: [
                { id: "una", titulo: "una sola", lista: ["u"] },
                { id: "cuatro", titulo: "cuatro caras (S E N W)", lista: ["S", "E", "N", "W"] },
                { id: "ocho", titulo: "ocho al estilo PMD",
                  lista: ["Down", "DownRight", "Right", "UpRight", "Up", "UpLeft", "Left", "DownLeft"] }
            ]

            Text {
                width: parent.width
                text: "cambiar el juego no pierde lo dibujado: las caras que ya existían se "
                      + "quedan donde están y las nuevas nacen vacías"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }

            Repeater {
                model: parent.juegos
                C.Boton {
                    width: parent.width
                    texto: modelData.titulo
                    activo: S.Documento.nOrientaciones === modelData.lista.length
                    onPulsado: {
                        S.Historial.abreEstructura()
                        S.Documento.ponOrientaciones(modelData.lista)
                        S.Historial.cierraEstructura("orientaciones")
                        raiz.cierra()
                    }
                }
            }

            Item { width: 1; height: 6 }
            C.Rotulo { text: "el orden importa" }
            Text {
                width: parent.width
                text: "en una hoja PMD las filas van Down, DownRight, Right, UpRight, Up, "
                      + "UpLeft, Left, DownLeft. Equivocarlo no da error: da un bicho que mira mal."
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // pack, comprobar, etiqueta, cuantizar, importar, animación
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cPack
        Column {
            spacing: 8
            Repeater {
                model: S.Packs.lista
                Rectangle {
                    width: parent.width
                    height: cuerpoPack.implicitHeight + 14
                    radius: 3
                    color: modelData.id === S.Packs.activoId ? C.Tema.acentoTenue : "transparent"
                    border.width: modelData.id === S.Packs.activoId ? 1 : 0
                    border.color: C.Tema.acento
                    Column {
                        id: cuerpoPack
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 3
                        Text {
                            text: modelData.titulo
                            font.family: C.Tema.tipo; font.pixelSize: C.Tema.letra
                            font.weight: Font.DemiBold
                            color: modelData.id === S.Packs.activoId ? C.Tema.acento : C.Tema.tinta
                        }
                        Text {
                            width: parent.width
                            text: modelData.resumen
                            wrapMode: Text.WordWrap
                            font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                        }
                        Text {
                            visible: !!modelData.raiz
                            text: modelData.raiz || ""
                            font.family: C.Tema.tipoMono; font.pixelSize: 9; color: C.Tema.apagado
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { S.Packs.elige(modelData.id); raiz.cierra() } }
                }
            }
            Item { width: 1; height: 4 }
            Text {
                width: parent.width
                text: "los packs propios van en ~/.config/pinza/packs/*.json y ganan si repiten id"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.apagado
            }
        }
    }

    Component {
        id: cComprobar
        Column {
            spacing: 8
            property var guiones: ["check:tiles", "check:rotations", "check:home"]
            C.Rotulo { text: "en " + S.Proyecto.raizPack() }
            Repeater {
                model: parent.guiones
                C.Boton {
                    width: parent.width
                    texto: "npm run " + modelData
                    onPulsado: S.Proyecto.comprueba([modelData], null)
                }
            }
            C.Boton {
                width: parent.width
                texto: "lanzar todas"; activo: true
                onPulsado: S.Proyecto.comprueba(parent.guiones, null)
            }
            Text {
                visible: S.Proyecto.estado === "comprobando"
                text: "corriendo…"
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.acento
            }
            Repeater {
                model: S.Proyecto.resultados
                Column {
                    width: parent.width
                    spacing: 2
                    Row {
                        spacing: 5
                        C.Icono {
                            glifo: modelData.codigo === 0 ? C.Tema.i.ok : C.Tema.i.aviso
                            color: modelData.codigo === 0 ? C.Tema.bien : C.Tema.mal
                            font.pixelSize: 12
                        }
                        Text {
                            text: String(modelData.guion)
                            font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.min(160, salida.implicitHeight + 10)
                        radius: 3
                        color: C.Tema.fondo
                        border.width: 1; border.color: C.Tema.bordeSuave
                        clip: true
                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 5
                            contentHeight: salida.implicitHeight
                            Text {
                                id: salida
                                width: parent.width
                                text: modelData.salida
                                wrapMode: Text.WrapAnywhere
                                font.family: C.Tema.tipoMono; font.pixelSize: 9; color: C.Tema.tenue
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cEtiqueta
        Column {
            spacing: 9
            property string nombre: "acción"
            property int desde: S.Documento.fotograma
            property int hasta: S.Documento.nFotogramas - 1
            property string modo: "ida"

            C.Campo { width: parent.width; etiqueta: "nombre"; valor: parent.nombre
                      onCambiado: (v) => parent.nombre = v }
            C.Campo { width: parent.width; etiqueta: "del"; numero: true; minimo: 0
                      maximo: S.Documento.nFotogramas - 1; valor: String(parent.desde + 1)
                      onCambiado: (v) => parent.desde = Math.max(0, (parseInt(v) || 1) - 1) }
            C.Campo { width: parent.width; etiqueta: "al"; numero: true; minimo: 0
                      maximo: S.Documento.nFotogramas - 1; valor: String(parent.hasta + 1)
                      onCambiado: (v) => parent.hasta = Math.max(0, (parseInt(v) || 1) - 1) }
            C.Opcion {
                width: parent.width; etiqueta: "modo"
                opciones: [{ id: "ida", titulo: "ida" }, { id: "vuelta", titulo: "vuelta" },
                           { id: "vaiven", titulo: "vaivén" }]
                valor: parent.modo
                onCambiado: (v) => parent.modo = v
            }
            C.Boton {
                texto: "etiquetar"; activo: true; relleno: 14
                onPulsado: {
                    S.Historial.abreEstructura()
                    S.Documento.añadeEtiqueta(parent.nombre, Math.min(parent.desde, parent.hasta),
                                              Math.max(parent.desde, parent.hasta), parent.modo)
                    S.Historial.cierraEstructura("etiqueta")
                    raiz.cierra()
                }
            }

            Item { width: 1; height: 6 }
            Repeater {
                model: S.Documento.rev, (S.Documento.d ? S.Documento.d.etiquetas : [])
                Row {
                    spacing: 6
                    Text {
                        text: modelData.nombre + "  " + (modelData.desde + 1) + "–" + (modelData.hasta + 1)
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tinta
                    }
                    C.Boton {
                        icono: C.Tema.i.basura; width: 22; implicitHeight: 20; peligro: true
                        onPulsado: S.Documento.borraEtiqueta(index)
                    }
                }
            }
        }
    }

    Component {
        id: cCuantizar
        Column {
            spacing: 9
            property int n: 16
            C.Desliz {
                width: parent.width
                etiqueta: "colores"; anchoEtiqueta: 56
                minimo: 2; maximo: 64; paso: 1; decimales: 0
                valor: parent.n
                onCambiado: (v) => parent.n = Math.round(v)
            }
            Text {
                width: parent.width
                text: "aquí no hay ningún límite impuesto: el número lo pones tú. Esto sirve "
                      + "sobre todo para domar arte que viene de fuera —un boceto, un render— "
                      + "que trae cientos de tonos y no se lee como pixel art."
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }
            C.Boton {
                width: parent.width
                texto: "reducir la capa a " + parent.n + " colores"
                onPulsado: {
                    const c = S.Documento.capa(S.Documento.capaActiva)
                    const b = S.Documento.celdaActiva(true)
                    if (!c || !b) return
                    S.Historial.abre(S.Documento.clave(c.id, S.Documento.fotograma,
                                                       S.Documento.orientacion), b)
                    const n = P.cuantiza(b, P.reduce(b, parent.n))
                    for (let i = 0; i < b.d.length; i++) b.d[i] = n.d[i]
                    S.Historial.cierra("cuantizar", b)
                    S.Documento.cambiaPixeles(null)
                    raiz.cierra()
                }
            }
            C.Boton {
                width: parent.width
                texto: "acercar a la paleta cargada"
                visible: S.Paleta.colores.length > 0
                onPulsado: {
                    const c = S.Documento.capa(S.Documento.capaActiva)
                    const b = S.Documento.celdaActiva(true)
                    if (!c || !b) return
                    S.Historial.abre(S.Documento.clave(c.id, S.Documento.fotograma,
                                                       S.Documento.orientacion), b)
                    const n = P.cuantiza(b, S.Paleta.colores)
                    for (let i = 0; i < b.d.length; i++) b.d[i] = n.d[i]
                    S.Historial.cierra("a la paleta", b)
                    S.Documento.cambiaPixeles(null)
                    raiz.cierra()
                }
            }
        }
    }

    Component {
        id: cImportar
        Column {
            spacing: 9
            property string ruta: ""
            property int cw: 32
            property int ch: 32
            property bool filasSonOrientaciones: true

            C.Boton {
                width: parent.width
                texto: parent.ruta ? parent.ruta.split("/").pop() : "elegir un PNG…"
                onPulsado: abreImagen.open()
            }
            FileDialog {
                id: abreImagen
                nameFilters: ["Imágenes (*.png)", "Todo (*)"]
                onAccepted: parent.ruta = String(selectedFile).replace("file://", "")
            }

            C.Boton {
                width: parent.width
                texto: "como capa nueva"
                visible: parent.ruta !== ""
                onPulsado: { S.Proyecto.importaComoCapa(parent.ruta, null); raiz.cierra() }
            }

            Item { width: 1; height: 4 }
            C.Rotulo { text: "o trocear como hoja" }
            C.Campo { width: parent.width; etiqueta: "celda ancho"; numero: true
                      valor: String(parent.cw); onCambiado: (v) => parent.cw = parseInt(v) || 1 }
            C.Campo { width: parent.width; etiqueta: "celda alto"; numero: true
                      valor: String(parent.ch); onCambiado: (v) => parent.ch = parseInt(v) || 1 }
            C.Interruptor {
                width: parent.width
                etiqueta: "las filas son orientaciones"
                valor: parent.filasSonOrientaciones
                onCambiado: (v) => parent.filasSonOrientaciones = v
            }
            Text {
                width: parent.width
                text: "la rejilla se dice aquí y no se adivina de la imagen: adivinarla sale "
                      + "mal más veces de las que sale bien"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }
            C.Boton {
                width: parent.width
                texto: "trocear"; activo: true
                visible: parent.ruta !== ""
                onPulsado: {
                    S.Proyecto.importaHoja(parent.ruta, parent.cw, parent.ch,
                                           parent.filasSonOrientaciones, null)
                    raiz.cierra()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // especie
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cEspecie
        Column {
            id: hojaEsp
            spacing: 9
            property string modo: S.Especie.abierta ? "ficha"
                                 : (raiz.modoHoja || "elegir")
            property string busca: ""
            property string nombreNuevo: "MiBicho"

            //  Siempre, no sólo desde el botón: se puede entrar directo a la
            //  pantalla de traer desde la paleta de comandos, y entonces nadie
            //  pedía el catálogo — la lista se quedaba en "leyendo…" para
            //  siempre.
            Component.onCompleted: S.Especie.cargaCatalogo(null)

            // ── nada abierto: de dónde partir ────────────────────
            Column {
                visible: hojaEsp.modo === "elegir"
                width: parent.width
                spacing: 8

                Text {
                    width: parent.width
                    text: S.Especie.plantilla ? S.Especie.plantilla.ayuda : ""
                    wrapMode: Text.WordWrap
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                }

                C.Boton {
                    width: parent.width
                    texto: "traer una del juego y retocarla"
                    activo: true
                    onPulsado: { S.Especie.cargaCatalogo(null); hojaEsp.modo = "traer" }
                }
                C.Boton {
                    width: parent.width
                    texto: "empezar una en blanco"
                    onPulsado: hojaEsp.modo = "blanco"
                }
                C.Boton {
                    width: parent.width
                    texto: "abrir una que ya tengas…"
                    onPulsado: raiz.pideCarpetaEspecie()
                }
            }

            // ── traer una del juego ──────────────────────────────
            Column {
                visible: hojaEsp.modo === "traer"
                width: parent.width
                spacing: 7

                Text {
                    width: parent.width
                    text: "se trocean sus hojas con la geometría BAJADA —no adivinada— y quedan "
                          + "editables acción por acción, con sus duraciones en tics"
                    wrapMode: Text.WordWrap
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                }
                C.Campo {
                    width: parent.width
                    etiqueta: "buscar"; valor: hojaEsp.busca
                    onCambiado: (v) => hojaEsp.busca = v
                }
                C.Campo {
                    width: parent.width
                    etiqueta: "se llamará"; valor: hojaEsp.nombreNuevo
                    onCambiado: (v) => hojaEsp.nombreNuevo = v
                }
                Destino { width: parent.width; nombre: hojaEsp.nombreNuevo }
                Text {
                    visible: S.Especie.catalogoLeyendo
                    text: "leyendo lo que el juego tiene bajado…"
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.acento
                }

                //  Cuando no se puede, se dice POR QUÉ y se ofrece el arreglo.
                //  Un «leyendo…» eterno parece que va lento y no va a ir nunca.
                Rectangle {
                    visible: S.Especie.catalogoError !== ""
                    width: parent.width
                    height: quejaCol.implicitHeight + 16
                    radius: 3
                    color: C.Tema.acentoTenue
                    border.width: 1; border.color: C.Tema.aviso
                    Column {
                        id: quejaCol
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 6
                        Text {
                            width: parent.width
                            text: S.Especie.catalogoError
                            wrapMode: Text.WrapAnywhere
                            font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta
                        }
                        Text {
                            width: parent.width
                            text: "las criaturas salen de lo que el juego ya ha horneado. "
                                  + "Si aún no lo has hecho, en crabh: npm run assets"
                            wrapMode: Text.WordWrap
                            font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                        }
                        Row {
                            spacing: 6
                            C.Boton {
                                texto: "elegir la carpeta del juego"; relleno: 8; implicitHeight: 22
                                onPulsado: raiz.pideRaizDelPack()
                            }
                            C.Boton {
                                texto: "reintentar"; relleno: 8; implicitHeight: 22
                                onPulsado: { S.Especie.olvidaCatalogo(); S.Especie.cargaCatalogo(null) }
                            }
                        }
                    }
                }

                Text {
                    visible: S.Especie.catalogoListo
                    width: parent.width
                    text: "pulsa una y se trae entera ahí. Si ya hubiera una con ese nombre, "
                          + "la nueva se llamará -2 en vez de machacarla."
                    wrapMode: Text.WordWrap
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.apagado
                }
                Text {
                    visible: S.Especie.catalogoListo
                    width: parent.width
                    text: "de " + S.Proyecto.raizPack()
                    elide: Text.ElideMiddle
                    font.family: C.Tema.tipoMono; font.pixelSize: 9; color: C.Tema.apagado
                }

                Rectangle {
                    width: parent.width
                    height: 260
                    radius: 3
                    color: C.Tema.fondo
                    border.width: 1; border.color: C.Tema.bordeSuave
                    clip: true

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 4
                        clip: true
                        model: {
                            const q = hojaEsp.busca.toLowerCase().trim()
                            if (!q) return S.Especie.catalogo
                            return S.Especie.catalogo.filter(
                                (x) => x.name.indexOf(q) >= 0 || String(x.dex) === q)
                        }
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 24
                            radius: 2
                            color: filaRaton.containsMouse ? C.Tema.alta : "transparent"
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: ("000" + modelData.dex).slice(-4) + "  " + modelData.name
                                font.family: C.Tema.tipoMono; font.pixelSize: 11
                                color: C.Tema.tinta
                            }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: Object.keys(modelData.sheets || {}).length + " acciones"
                                font.family: C.Tema.tipoMono; font.pixelSize: 9
                                color: C.Tema.apagado
                            }
                            MouseArea {
                                id: filaRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    S.Especie.importa(modelData.dex, hojaEsp.nombreNuevo,
                                                      S.Ajustes.taller + "/"
                                                      + hojaEsp.nombreNuevo + ".especie", null)
                                    raiz.cierra()
                                }
                            }
                        }
                    }
                }
                C.Boton { texto: "atrás"; onPulsado: hojaEsp.modo = "elegir" }
            }

            // ── en blanco ────────────────────────────────────────
            Column {
                visible: hojaEsp.modo === "blanco"
                width: parent.width
                spacing: 7
                property int dex: 10000
                property string role: "prey"
                property int sombra: 1

                Text {
                    width: parent.width
                    text: "nacen las ocho acciones vacías, cada una con su tamaño, sus fotogramas "
                          + "y sus duraciones puestas. Sólo queda dibujarlas."
                    wrapMode: Text.WordWrap
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                }
                C.Campo { width: parent.width; etiqueta: "nombre"; valor: hojaEsp.nombreNuevo
                          onCambiado: (v) => hojaEsp.nombreNuevo = v }
                Destino { width: parent.width; nombre: hojaEsp.nombreNuevo }
                C.Campo { width: parent.width; etiqueta: "dex"; numero: true; minimo: 10000
                          maximo: 19999; valor: String(parent.dex)
                          onCambiado: (v) => parent.dex = parseInt(v) || 10000 }
                C.Opcion {
                    width: parent.width; etiqueta: "papel"
                    opciones: [{ id: "starter", titulo: "inicial" }, { id: "prey", titulo: "presa" },
                               { id: "midgame", titulo: "media" }, { id: "predator", titulo: "depredador" },
                               { id: "crab", titulo: "cangrejo" }, { id: "boss", titulo: "jefe" }]
                    valor: parent.role
                    onCambiado: (v) => parent.role = v
                }
                C.Desliz {
                    width: parent.width; etiqueta: "sombra"; anchoEtiqueta: 62
                    minimo: 0; maximo: 3; paso: 1; decimales: 0
                    valor: parent.sombra
                    onCambiado: (v) => parent.sombra = Math.round(v)
                }
                Row {
                    spacing: 6
                    C.Boton {
                        texto: "crear"; activo: true; relleno: 12
                        onPulsado: {
                            const nom = hojaEsp.nombreNuevo
                            const dex = parent.parent.dex
                            const rol = parent.parent.role
                            const som = parent.parent.sombra
                            //  Lo de antes al disco primero: crear una criatura
                            //  nueva sustituye la ficha y el documento, y sin
                            //  esto se llevaba por delante lo que llevaras
                            //  dibujado de la anterior.
                            S.Especie.guardaTodo(() => {
                                S.Especie.nueva({ nombre: nom, dex: dex, role: rol, shadowSize: som })
                                S.Especie.guarda(S.Ajustes.taller + "/" + nom + ".especie", null)
                            })
                            raiz.cierra()
                        }
                    }
                    C.Boton { texto: "atrás"; onPulsado: hojaEsp.modo = "elegir" }
                }
            }

            // ── la ficha, con sus acciones ───────────────────────
            Column {
                visible: hojaEsp.modo === "ficha" && S.Especie.abierta
                width: parent.width
                spacing: 7

                Row {
                    spacing: 8
                    Text {
                        text: S.Especie.nombre
                        font.family: C.Tema.tipo; font.pixelSize: 15; font.weight: Font.Bold
                        color: C.Tema.acento
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: S.Especie.rev, S.Especie.d
                              ? "#" + S.Especie.d.dex + " · " + S.Especie.d.role : ""
                        font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tenue
                    }
                }
                Text {
                    visible: S.Especie.rev, !!(S.Especie.d && S.Especie.d.venideDe)
                    text: S.Especie.d && S.Especie.d.venideDe
                          ? "partiendo de " + S.Especie.d.venideDe.nombre : ""
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.apagado
                }

                C.Rotulo { text: "acciones" }
                Repeater {
                    model: S.Especie.rev, S.Especie.acciones
                    Rectangle {
                        readonly property var info: S.Especie.d ? S.Especie.d.acciones[modelData.id] : null
                        readonly property bool activa: S.Especie.accion === modelData.id
                        width: parent.width
                        height: info ? 30 : 0
                        visible: !!info
                        radius: 3
                        color: activa ? C.Tema.acentoTenue
                             : accRaton.containsMouse ? C.Tema.alta : "transparent"
                        border.width: activa ? 1 : 0
                        border.color: C.Tema.acento

                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Text {
                                text: modelData.id + "  " + modelData.titulo
                                font.family: C.Tema.tipo; font.pixelSize: C.Tema.letra
                                color: parent.parent.activa ? C.Tema.acento : C.Tema.tinta
                            }
                            Text {
                                text: parent.parent.info
                                      ? parent.parent.info.ancho + "×" + parent.parent.info.alto
                                        + " · " + parent.parent.info.fotogramas + " fot · "
                                        + parent.parent.info.duraciones.reduce((a, b) => a + b, 0) + "t"
                                      : ""
                                font.family: C.Tema.tipoMono; font.pixelSize: 9
                                color: C.Tema.apagado
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8; radius: 4
                            color: parent.info && parent.info.hecha ? C.Tema.bien : C.Tema.borde
                        }
                        MouseArea {
                            id: accRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                S.Especie.recogeDelDocumento()
                                S.Especie.editaAccion(modelData.id, null)
                                raiz.cierra()
                            }
                        }
                    }
                }

                Item { width: 1; height: 4 }
                Row {
                    spacing: 6
                    C.Boton {
                        texto: "exportar la especie"; activo: true; relleno: 12
                        onPulsado: {
                            S.Especie.recogeDelDocumento()
                            S.Especie.guarda(null, () => S.Especie.exporta(null))
                            raiz.cierra()
                        }
                    }
                    C.Boton {
                        texto: "guardar"
                        onPulsado: S.Especie.recogeYGuarda(null)
                    }
                }
                Text {
                    width: parent.width
                    text: "exportar escribe una hoja por acción, el AnimData.xml que las ata y la "
                          + "ficha que da de alta a la criatura en el juego. Los tres tienen que "
                          + "estar de acuerdo, y ese acuerdo es lo que se rompe haciéndolo a mano."
                    wrapMode: Text.WordWrap
                    font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                }
                Text {
                    visible: S.Especie.estado !== ""
                    text: S.Especie.estado + "  " + Math.round(S.Especie.progreso * 100) + "%"
                    font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.acento
                }

                Item { width: 1; height: 4 }
                C.Boton { texto: "cerrar la especie"; peligro: true
                          pista: "guarda lo que tengas antes de soltarla"
                          onPulsado: { S.Especie.cierra(null); hojaEsp.modo = "elegir" } }
            }
        }
    }

    /** Dónde va a caer lo que estás creando, y cómo cambiarlo. */
    component Destino: Column {
        property string nombre: ""
        spacing: 2
        C.Rotulo { text: "irá a" }
        Row {
            width: parent.width
            spacing: 6
            Text {
                width: parent.width - 70
                text: S.Ajustes.taller + "/" + nombre + ".especie"
                elide: Text.ElideMiddle
                font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta
                anchors.verticalCenter: parent.verticalCenter
            }
            C.Boton {
                texto: "cambiar"; relleno: 7; implicitHeight: 20
                anchors.verticalCenter: parent.verticalCenter
                onPulsado: raiz.pideTaller()
            }
        }
    }

    signal pideTaller()
    signal pideRaizDelPack()
    signal pideCarpetaEspecie()

    // ═══════════════════════════════════════════════════════════
    // guiones
    // ═══════════════════════════════════════════════════════════

    Component {
        id: cGuiones
        Column {
            spacing: 8
            Component.onCompleted: S.Guiones.refresca()

            Text {
                width: parent.width
                text: "en JavaScript, contra el documento abierto. Todo lo que haga un "
                      + "guión entra en el historial como UN paso, así que se puede probar "
                      + "sin miedo: si hace un destrozo, Ctrl+Z."
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }

            C.Rotulo { text: "los que hay" }
            Repeater {
                model: S.Guiones.lista
                C.Boton {
                    width: parent.width
                    texto: modelData.nombre.replace(/\.js$/, "").replace(/-/g, " ")
                    onPulsado: S.Guiones.corredeFichero(modelData.ruta)
                }
            }
            Text {
                visible: S.Guiones.lista.length === 0
                text: "ninguno todavía"
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.apagado
            }

            Item { width: 1; height: 4 }
            C.Rotulo { text: "o uno a mano" }
            Rectangle {
                width: parent.width
                height: 130
                radius: 3
                color: C.Tema.fondo
                border.width: 1
                border.color: editor.activeFocus ? C.Tema.acento : C.Tema.borde
                clip: true
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentHeight: editor.implicitHeight
                    TextEdit {
                        id: editor
                        width: parent.width
                        font.family: C.Tema.tipoMono
                        font.pixelSize: 11
                        color: C.Tema.tinta
                        selectionColor: C.Tema.acento
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        text: "pinza.paraCada((buf) => {\n"
                            + "  pinza.paraCadaPixel(buf, (c) => {\n"
                            + "    if (c[3] === 0) return\n"
                            + "    return pinza.color('#D66C34')\n"
                            + "  })\n"
                            + "})\n"
                            + "pinza.log('listo')"
                    }
                }
            }
            Row {
                spacing: 6
                C.Boton {
                    texto: "correr"; activo: true; relleno: 12
                    onPulsado: S.Guiones.corre(editor.text, "guión a mano")
                }
                C.Boton {
                    icono: C.Tema.i.carpeta
                    width: 26; implicitHeight: 26
                    pista: "abrir la carpeta de guiones"
                    onPulsado: S.Forja.creaCarpeta(S.Guiones.carpeta,
                                                   () => S.Forja.abre(S.Guiones.carpeta))
                }
            }

            Rectangle {
                width: parent.width
                visible: S.Guiones.ultimoError !== null
                height: err.implicitHeight + 12
                radius: 3
                color: C.Tema.acentoTenue
                border.width: 1; border.color: C.Tema.mal
                Text {
                    id: err
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 7
                    text: S.Guiones.ultimoError ? S.Guiones.ultimoError.mensaje : ""
                    wrapMode: Text.WordWrap
                    font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tinta
                }
            }
            Rectangle {
                width: parent.width
                visible: S.Guiones.salida.length > 0
                height: Math.min(90, sal.implicitHeight + 12)
                radius: 3
                color: C.Tema.fondo
                border.width: 1; border.color: C.Tema.bordeSuave
                clip: true
                Text {
                    id: sal
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 6
                    text: S.Guiones.salida
                    wrapMode: Text.WrapAnywhere
                    font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tenue
                }
            }

            Text {
                width: parent.width
                text: "los tuyos van en ~/.config/pinza/guiones/*.js"
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.apagado
            }
        }
    }

    Component {
        id: cAnim
        Column {
            spacing: 9
            property string formato: "gif"
            C.Opcion {
                width: parent.width; etiqueta: "formato"
                opciones: [{ id: "gif", titulo: "GIF" }, { id: "apng", titulo: "APNG" }]
                valor: parent.formato
                onCambiado: (v) => parent.formato = v
            }
            Text {
                width: parent.width
                text: "con las duraciones reales de cada fotograma. El GIF no tiene alfa "
                      + "parcial: lo transparente se marca de golpe. El APNG sí lo conserva."
                wrapMode: Text.WordWrap
                font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
            }
            C.Boton {
                texto: "elegir dónde y escribir"; activo: true; relleno: 14
                onPulsado: guardaAnim.open()
            }
            FileDialog {
                id: guardaAnim
                fileMode: FileDialog.SaveFile
                currentFile: "file://" + (S.Documento.ruta || S.Proyecto.carpetaBase)
                             + "/" + S.Documento.nombre + "." + parent.formato
                onAccepted: {
                    S.Proyecto.exportaAnimacion(String(selectedFile).replace("file://", ""),
                                                parent.formato, null)
                    raiz.cierra()
                }
            }
        }
    }
}

//  pinza — editor de pixel art.
//
//  Esto monta la ventana y reparte el sitio. No hay lógica de nada aquí: el
//  documento vive en servicios/Documento.qml, lo que se puede hacer está en
//  servicios/Ordenes.qml y cada panel se apaña solo. Añadir una orden es
//  tocar UN fichero, y sale a la vez en la paleta de comandos, en la rueda y
//  en los atajos.
//
//  El reparto: barra de contrato arriba (que es lo que en otro editor sería la
//  barra de menús), carril de herramientas a la izquierda, hojas a la derecha,
//  la tira abajo y el lienzo ocupando todo lo que sobra — que es casi todo,
//  y es lo que se pretende.
//
//      qs -p ~/Proyectos/pinza

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import "core" as C
import "servicios" as S
import "vistas" as V

ShellRoot {
    id: raiz

    FloatingWindow {
        id: ventana
        title: (S.Documento.abierto
                ? S.Documento.nombre + (S.Documento.sucio ? " •" : "")
                : "pinza")
        implicitWidth: 1180
        implicitHeight: 760
        minimumSize.width: 720
        minimumSize.height: 480
        color: C.Tema.fondo
        visible: true

        Item {
            id: escena
            anchors.fill: parent
            focus: true

            // ── el puente con los ficheros ───────────────────────
            //  Tiene que estar dentro de la ventana: un Canvas fuera de la
            //  escena no llega a pintar, y entonces exportar devuelve un
            //  lienzo en blanco sin decir nada.
            V.Exportador { id: exportador }
            Component.onCompleted: S.Proyecto.exportador = exportador

            // ═══════════════════════════════════════════════════
            // reparto
            // ═══════════════════════════════════════════════════

            V.BarraContrato {
                id: barra
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                onPideComandos: comandos.abierta = true
            }

            V.CarrilHerramientas {
                id: carril
                anchors.top: barra.bottom
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: C.Tema.carril
            }

            V.OpcionesHerramienta {
                id: opciones
                anchors.top: barra.bottom
                anchors.left: carril.right
                anchors.right: paneles.left
                height: 30
            }

            V.Lienzo {
                id: lienzo
                anchors.top: opciones.bottom
                anchors.left: carril.right
                anchors.right: paneles.left
                anchors.bottom: tira.top
            }

            V.Compas {
                anchors.right: lienzo.right
                anchors.bottom: lienzo.bottom
                anchors.margins: 14
                parent: lienzo
            }

            V.Tira {
                id: tira
                anchors.left: carril.right
                anchors.right: paneles.left
                anchors.bottom: parent.bottom
                visible: S.Ajustes.tira && S.Documento.abierto
                height: visible ? implicitHeight : 0
            }

            // ── los paneles de la derecha ────────────────────────
            Rectangle {
                id: paneles
                anchors.top: barra.bottom
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: C.Tema.panel
                color: C.Tema.superficie

                Rectangle {
                    anchors.left: parent.left
                    width: 1; height: parent.height
                    color: C.Tema.borde
                }

                Flickable {
                    anchors.fill: parent
                    anchors.leftMargin: 1
                    contentHeight: pila.implicitHeight
                    clip: true

                    Column {
                        id: pila
                        width: parent.width
                        spacing: 1

                        V.PanelPaleta { width: pila.width; visible: S.Ajustes.panelPaleta }
                        V.PanelCapas  { width: pila.width; visible: S.Ajustes.panelCapas }
                        V.Previa      { width: pila.width; visible: S.Ajustes.panelPrevia }
                        V.MapaPrueba {
                            width: pila.width
                            //  Sólo cuando el documento es un tileset: en un
                            //  sprite no significa nada y sería ruido fijo.
                            visible: S.Ajustes.panelMapa && S.Documento.abierto
                                     && !!(S.Documento.d && S.Documento.d.contrato
                                           && S.Documento.d.contrato.mapaPrueba)
                        }
                        V.PanelHistorial { width: pila.width; visible: S.Ajustes.panelHistorial }
                    }
                }
            }

            // ── lo que flota por encima ──────────────────────────
            V.Hojas { id: hojas }
            V.Comandos { id: comandos }
            V.Rueda { id: rueda }

            // ── el aviso pasajero ────────────────────────────────
            Rectangle {
                id: aviso
                anchors.horizontalCenter: lienzo.horizontalCenter
                anchors.bottom: lienzo.bottom
                anchors.bottomMargin: 20
                width: avisoTexto.implicitWidth + 26
                height: 30
                radius: 4
                color: C.Tema.alta
                border.width: 1
                border.color: C.Tema.borde
                opacity: 0
                z: 700
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Text {
                    id: avisoTexto
                    anchors.centerIn: parent
                    font.family: C.Tema.tipo
                    font.pixelSize: C.Tema.letra
                    color: C.Tema.tinta
                }
                Timer { id: relojAviso; interval: 2600; onTriggered: aviso.opacity = 0 }

                function di(t) { avisoTexto.text = t; opacity = 1; relojAviso.restart() }
            }

            // ── la barra de estado, en el borde del lienzo ───────
            Row {
                anchors.right: lienzo.right
                anchors.bottom: lienzo.bottom
                anchors.margins: 6
                spacing: 10
                z: 600
                visible: S.Documento.abierto && !S.Ajustes.compas

                Text {
                    text: lienzo.dentro ? lienzo.cursorX + ", " + lienzo.cursorY : "—"
                    font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tenue
                }
                Text {
                    text: "×" + (S.Ajustes.zoom >= 1 ? S.Ajustes.zoom.toFixed(0)
                                                     : S.Ajustes.zoom.toFixed(2))
                    font.family: C.Tema.tipoMono; font.pixelSize: 10; color: C.Tema.tenue
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // atajos
        // ═══════════════════════════════════════════════════════
        //
        //  Los de ORDEN se sacan de la propia lista, así que un atajo nuevo se
        //  declara donde se declara la orden y no hay una segunda tabla que se
        //  desincronice. Las teclas sueltas de herramienta van aparte porque
        //  no son órdenes: son un modo.

        //  Instantiator y no Repeater: un Shortcut no es un Item, y Repeater
        //  sólo sabe repetir Items — se quejaba y no creaba ni un atajo.
        Instantiator {
            model: S.Ordenes.lista.filter((o) => !!o.atajo && o.atajo !== "Espacio")
            delegate: Shortcut {
                sequences: [modelData.atajo.replace("Del", "Delete")]
                onActivated: S.Ordenes.ejecuta(modelData.id)
            }
        }

        Shortcut { sequences: ["Ctrl+K"]; onActivated: comandos.abierta = !comandos.abierta }
        Shortcut { sequences: ["Space"]; onActivated: if (!comandos.abierta) S.Animacion.alterna() }
        Shortcut { sequences: ["B"]; onActivated: S.Pinceles.elige("lapiz") }
        Shortcut { sequences: ["E"]; onActivated: S.Pinceles.elige("goma") }
        Shortcut { sequences: ["G"]; onActivated: S.Pinceles.elige("cubo") }
        Shortcut { sequences: ["I"]; onActivated: S.Pinceles.elige("cuentagotas") }
        Shortcut { sequences: ["L"]; onActivated: S.Pinceles.elige("linea") }
        Shortcut { sequences: ["U"]; onActivated: S.Pinceles.elige("rectangulo") }
        Shortcut { sequences: ["O"]; onActivated: S.Pinceles.elige("elipse") }
        Shortcut { sequences: ["D"]; onActivated: S.Pinceles.elige("degradado") }
        Shortcut { sequences: ["S"]; onActivated: S.Pinceles.elige("sombreado") }
        Shortcut { sequences: ["R"]; onActivated: S.Pinceles.elige("sustituye") }
        Shortcut { sequences: ["M"]; onActivated: S.Pinceles.elige("marco") }
        Shortcut { sequences: ["Q"]; onActivated: S.Pinceles.elige("lazo") }
        Shortcut { sequences: ["W"]; onActivated: S.Pinceles.elige("varita") }
        Shortcut { sequences: ["V"]; onActivated: S.Pinceles.elige("mover") }
        Shortcut { sequences: ["H"]; onActivated: S.Pinceles.elige("mano") }
        Shortcut { sequences: ["["]; onActivated: S.Pinceles.tamaño = Math.max(1, S.Pinceles.tamaño - 1) }
        Shortcut { sequences: ["]"]; onActivated: S.Pinceles.tamaño = Math.min(32, S.Pinceles.tamaño + 1) }
        Shortcut { sequences: ["Escape"]; onActivated: {
            if (comandos.abierta) comandos.abierta = false
            else if (hojas.abierta) hojas.cierra()
            else S.Seleccion.nada()
        } }
    }

    // ═══════════════════════════════════════════════════════════
    // cableado
    // ═══════════════════════════════════════════════════════════

    Connections {
        target: S.Ordenes
        function onPideHoja(nombre) {
            if (nombre === "guardarComo") { guardarComo.open(); return }
            if (nombre === "abrir") { abrir.open(); return }
            hojas.abre(nombre)
        }
        function onPideAviso(texto) { aviso.di(texto) }
        function onPideAjuste() { lienzo.ajusta() }
        function onPideTema() { C.Tema.oscuro = !C.Tema.oscuro }
    }

    Connections {
        target: S.Proyecto
        function onHecho(que, detalle) { aviso.di(S.Proyecto.ultimoMensaje) }
        function onFalla(que, motivo) { aviso.di(que + ": " + motivo) }
    }
    Connections {
        target: S.Forja
        function onFallo(mensaje) { aviso.di("forja: " + mensaje) }
    }

    // el botón derecho sostenido saca la rueda; un clic corto pinta con el
    // secundario, que es lo que se espera de él
    Connections {
        target: lienzo
        function onColorCogido() { aviso.di("color " + S.Paleta.primarioHex) }
    }

    // ═══════════════════════════════════════════════════════════
    // ficheros
    // ═══════════════════════════════════════════════════════════

    property var guardarComo: null
    property var abrir: null

    Loader {
        active: true
        sourceComponent: Item {
            Component.onCompleted: { raiz.guardarComo = guardarDlg; raiz.abrir = abrirDlg }
            SelectorCarpeta {
                id: guardarDlg
                titulo: "Guardar el proyecto en"
                onElegida: (ruta) => S.Proyecto.guarda(ruta + "/" + S.Documento.nombre + ".pinza", null)
            }
            SelectorCarpeta {
                id: abrirDlg
                titulo: "Abrir un proyecto"
                onElegida: (ruta) => S.Proyecto.abre(ruta, null)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // autoguardado
    // ═══════════════════════════════════════════════════════════
    //
    //  Sólo si el proyecto YA tiene una carpeta. Autoguardar uno sin ruta
    //  significa inventarse dónde, y aparecerían carpetas donde nadie las puso.

    Timer {
        interval: Math.max(30, S.Ajustes.autoguardado) * 1000
        running: S.Ajustes.autoguardado > 0
        repeat: true
        onTriggered: {
            if (!S.Documento.abierto || !S.Documento.sucio || !S.Documento.ruta) return
            if (S.Proyecto.estado !== "") return
            S.Proyecto.guarda(null, null)
        }
    }

    // ═══════════════════════════════════════════════════════════
    // desde fuera
    // ═══════════════════════════════════════════════════════════
    //
    //  Para que abrir un proyecto desde el escritorio vaya a la ventana que ya
    //  tienes en vez de arrancar otra. Dos instancias no se llevan mal —cada
    //  una tiene su documento— pero se pisarían los ajustes, y sobre todo no es
    //  lo que espera nadie al hacer doble clic.
    //
    //      qs -c pinza ipc call pinza abrir /ruta/al/proyecto.pinza

    IpcHandler {
        target: "pinza"

        function abrir(ruta: string): string {
            if (!ruta) return "hace falta una ruta"
            S.Proyecto.abre(ruta, null)
            ventana.visible = true
            return "abriendo " + ruta
        }

        function importar(ruta: string): string {
            if (!ruta) return "hace falta una ruta"
            S.Proyecto.importaComoCapa(ruta, null)
            ventana.visible = true
            return "importando " + ruta
        }

        function nuevo(): string {
            hojas.abre("nuevo")
            ventana.visible = true
            return "listo"
        }

        function guardar(): string {
            if (!S.Documento.abierto) return "no hay nada abierto"
            if (!S.Documento.ruta) return "este documento no tiene carpeta todavía"
            S.Proyecto.guarda(null, null)
            return "guardando en " + S.Documento.ruta
        }

        function exportar(): string {
            if (!S.Documento.abierto) return "no hay nada abierto"
            S.Proyecto.exporta({}, null)
            return "exportando " + S.Documento.nombre
        }

        function estado(): string {
            if (!S.Documento.abierto) return "sin nada abierto"
            return S.Documento.nombre + " · " + S.Documento.ancho + "x" + S.Documento.alto
                 + " · " + S.Documento.nFotogramas + " fotogramas"
                 + " · " + S.Documento.nOrientaciones + " orientaciones"
                 + (S.Documento.sucio ? " · sin guardar" : "")
        }
    }

    //  Abrir algo al arrancar.
    //
    //  Sirve para lanzarlo desde el explorador de ficheros o desde un guion, y
    //  es además lo que permite comprobar la interfaz de verdad sin tener que
    //  darle a los botones a mano.
    //
    //      PINZA_ABRIR=~/Proyectos/loquesea.pinza qs -p ~/Proyectos/pinza
    Component.onCompleted: {
        S.Ajustes.pack = S.Ajustes.pack || "generico"
        const abrirme = Quickshell.env("PINZA_ABRIR")
        if (abrirme) Qt.callLater(() => S.Proyecto.abre(abrirme, null))
        const importame = Quickshell.env("PINZA_IMPORTAR")
        if (importame) Qt.callLater(() => S.Proyecto.importaComoCapa(importame, null))
    }
}

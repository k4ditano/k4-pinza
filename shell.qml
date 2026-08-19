//  K4 Pinza — editor de pixel art.
//
//  Copyright (C) 2026 k4ditano
//
//  Este programa es software libre: puedes redistribuirlo y/o modificarlo bajo
//  los términos de la Licencia Pública General de GNU, versión 3 o posterior,
//  tal y como la publica la Free Software Foundation. Se distribuye con la
//  esperanza de que sea útil, pero SIN NINGUNA GARANTÍA. El texto completo está
//  en el fichero LICENSE, y también en <https://www.gnu.org/licenses/>.
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
import QtQuick.Window
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "core" as C
import "core/pixeles.js" as P
import "core/figura.js" as F
import "servicios" as S
import "vistas" as V

ShellRoot {
    id: raiz

    FloatingWindow {
        id: ventana
        title: (S.Documento.abierto
                ? S.Documento.nombre + (S.Documento.sucio ? " •" : "")
                : "K4 Pinza")
        implicitWidth: 1180
        implicitHeight: 760
        minimumSize.width: 720
        minimumSize.height: 480
        color: C.Tema.fondo
        visible: true

        property bool mostrarAcciones: true

        Item {
            id: escena
            anchors.fill: parent
            focus: true

            // ── el puente con los ficheros ───────────────────────
            //  Tiene que estar dentro de la ventana: un Canvas fuera de la
            //  escena no llega a pintar, y entonces exportar devuelve un
            //  lienzo en blanco sin decir nada.
            V.Exportador { id: exportador }
            Component.onCompleted: {
                S.Proyecto.exportador = exportador
                S.Especie.exportador = exportador
            }

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

            //  Arriba a la derecha porque el compás vive abajo a la derecha.
            //  Se puede arrastrar a donde estorbe menos, que depende del dibujo.
            V.Muestra {
                parent: lienzo
                x: Math.max(0, lienzo.width - width - 14)
                y: 14
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

                        //  Arriba del todo cuando hay una criatura abierta: es
                        //  lo primero que hay que saber, en cuál de las ocho
                        //  estás.
                        V.PanelAcciones {
                            width: pila.width
                            visible: ventana.mostrarAcciones && S.Especie.abierta
                                     && S.Especie.accion !== ""
                        }
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
            V.Cargando { }
            V.Globo { }
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

            // ── la barra de estado ───────────────────────────────
            //
            //  Abajo a la IZQUIERDA, y siempre. Estaba a la derecha y escondida
            //  cuando había compás — o sea, escondida justo al dibujar un
            //  sprite con orientaciones, que es cuando más falta hace saber en
            //  qué píxel estás.
            Row {
                anchors.left: lienzo.left
                anchors.bottom: lienzo.bottom
                anchors.margins: 8
                spacing: 12
                z: 600
                visible: S.Documento.abierto
                parent: lienzo

                Text {
                    text: lienzo.dentro ? lienzo.cursorX + ", " + lienzo.cursorY : "—"
                    font.family: C.Tema.tipoMono
                    font.pixelSize: 11
                    color: lienzo.dentro ? C.Tema.tinta : C.Tema.apagado
                }
                Text {
                    text: "×" + (S.Ajustes.zoom >= 1 ? S.Ajustes.zoom.toFixed(0)
                                                     : S.Ajustes.zoom.toFixed(2))
                    font.family: C.Tema.tipoMono
                    font.pixelSize: 11
                    color: C.Tema.tenue
                }
                Text {
                    visible: S.Seleccion.activa && S.Seleccion.limites !== null
                    text: S.Seleccion.limites
                          ? "sel " + S.Seleccion.limites.w + "×" + S.Seleccion.limites.h : ""
                    font.family: C.Tema.tipoMono
                    font.pixelSize: 11
                    color: C.Tema.acento
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // atajos
        // ═══════════════════════════════════════════════════════
        //
        //  Las teclas sueltas —B de lápiz, E de goma— se apagan mientras
        //  escribes. Sin esto no se puede teclear un nombre: escribir "Bicho"
        //  cambiaba de herramienta cuatro veces y las letras no llegaban al
        //  campo. Un atajo de una sola letra y un campo de texto no pueden
        //  estar encendidos a la vez.

        //  Quién tiene el foco se pregunta por la propiedad adjunta Window de
        //  un item de dentro: FloatingWindow es una envoltura de Quickshell y
        //  no expone activeFocusItem por sí misma.
        readonly property bool escribiendo: {
            const it = escena.Window.activeFocusItem
            return !!it && typeof it.selectByMouse !== "undefined"
        }
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
                //  Los de una sola letra se apagan mientras escribes, igual que
                //  los de abajo: si no, teclear un nombre cambia de herramienta.
                enabled: modelData.atajo.length > 1 || !ventana.escribiendo
                sequences: [modelData.atajo.replace("Del", "Delete")]
                onActivated: S.Ordenes.ejecuta(modelData.id)
            }
        }

        Shortcut { sequences: ["Ctrl+K"]; onActivated: comandos.abierta = !comandos.abierta }
        //  Ctrl+Y además de Ctrl+Shift+Z: media humanidad usa uno y media el otro.
        Shortcut { sequences: ["Ctrl+Y"]; onActivated: S.Ordenes.ejecuta("rehacer") }
        Shortcut { sequences: ["Space"]; onActivated: if (!comandos.abierta) S.Animacion.alterna() }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["B"]; onActivated: S.Pinceles.elige("lapiz") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["E"]; onActivated: S.Pinceles.elige("goma") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["G"]; onActivated: S.Pinceles.elige("cubo") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["I"]; onActivated: S.Pinceles.elige("cuentagotas") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["L"]; onActivated: S.Pinceles.elige("linea") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["U"]; onActivated: S.Pinceles.elige("rectangulo") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["O"]; onActivated: S.Pinceles.elige("elipse") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["D"]; onActivated: S.Pinceles.elige("degradado") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["S"]; onActivated: S.Pinceles.elige("sombreado") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["R"]; onActivated: S.Pinceles.elige("sustituye") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["M"]; onActivated: S.Pinceles.elige("marco") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["Q"]; onActivated: S.Pinceles.elige("lazo") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["W"]; onActivated: S.Pinceles.elige("varita") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["V"]; onActivated: S.Pinceles.elige("mover") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["H"]; onActivated: S.Pinceles.elige("mano") }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["["]; onActivated: S.Pinceles.tamaño = Math.max(1, S.Pinceles.tamaño - 1) }
        Shortcut { enabled: !ventana.escribiendo; sequences: ["]"]; onActivated: S.Pinceles.tamaño = Math.min(32, S.Pinceles.tamaño + 1) }
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
            //  "especie:traer" abre la hoja de especie directamente en la
            //  pantalla de traer, que es un clic menos desde la paleta.
            const dos = nombre.split(":")
            hojas.abre(dos[0], dos[1])
        }
        function onPideAbrirImagen() { if (raiz.abrirImagen) raiz.abrirImagen.open() }
        function onPideGuardarImagen() {
            if (!raiz.guardarImagen) return
            //  Propone el nombre que ya tiene, que es lo que espera cualquiera:
            //  guardar como sobre «bicho.png» debe salir con «bicho.png» escrito
            //  y el cursor listo para cambiarlo, no con el campo en blanco.
            const ya = S.Documento.imagen
            raiz.guardarImagen.currentFile =
                "file://" + (ya || (S.Ajustes.taller + "/" + (S.Documento.nombre || "dibujo") + ".png"))
            raiz.guardarImagen.open()
        }
        function onPideAviso(texto) { aviso.di(texto) }
        function onPideAjuste() { lienzo.ajusta() }
        function onPideTema() { C.Tema.oscuro = !C.Tema.oscuro }
    }

    Connections {
        target: hojas
        function onPideTaller() { elegirTaller.open() }
        function onPideRaizDelPack() { elegirRaiz.open() }
        function onPideCarpetaEspecie() { abrirEspecie.open() }
    }

    Connections {
        target: S.Packs
        function onRaizDescartada(pack, ruta) {
            aviso.di("la carpeta apuntada de «" + pack + "» ya no existe; se usa la del pack")
            S.Especie.olvidaCatalogo()
        }
    }

    Connections {
        target: S.Especie
        function onHecho(que, detalle) { aviso.di(que + ": " + detalle) }
        function onFalla(que, motivo) { aviso.di(que + ": " + motivo) }
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
        //  Un cambio que toca ochenta celdas que no estás viendo necesita
        //  decir que pasó algo; si no, parece que no ha hecho nada.
        function onColorSustituido(celdas) {
            if (S.Pinceles.alcanceColor !== "celda")
                aviso.di("color cambiado en " + celdas + " celdas")
        }
    }

    // ═══════════════════════════════════════════════════════════
    // ficheros
    // ═══════════════════════════════════════════════════════════

    property var guardarComo: null
    property var abrir: null
    //  Los diálogos viven dentro de un Loader, así que sus ids NO se ven desde
    //  fuera: por eso están todos aquí. Sin esta línea, la orden de abrir una
    //  imagen llamaba a un id que no existía en su ámbito y no pasaba nada —
    //  sin error, que es lo que la hacía difícil de ver.
    property var abrirImagen: null
    property var guardarImagen: null
    property var abrirEspecie: null
    property var elegirTaller: null
    property var elegirRaiz: null

    Loader {
        active: true
        sourceComponent: Item {
            Component.onCompleted: {
                raiz.guardarComo = guardarDlg; raiz.abrir = abrirDlg
                raiz.abrirImagen = abrirImagenDlg
                raiz.guardarImagen = guardarImagenDlg
                raiz.abrirEspecie = abrirEspecieDlg
                raiz.elegirTaller = tallerDlg
                raiz.elegirRaiz = raizDlg
            }
            SelectorCarpeta {
                id: guardarDlg
                //  Con una criatura abierta, «guardar como» es la criatura
                //  entera. Guardar sólo la acción que miras y llamarla como al
                //  bicho es prometer ocho animaciones y entregar una.
                titulo: S.Especie.abierta ? "Guardar la criatura en"
                                          : "Guardar el proyecto en"
                onElegida: (ruta) => {
                    if (S.Especie.abierta) S.Especie.guardaComo(ruta, null)
                    else S.Proyecto.guarda(ruta + "/" + S.Documento.nombre + ".pinza", null)
                }
            }
            SelectorCarpeta {
                id: abrirDlg
                titulo: "Abrir un proyecto"
                onElegida: (ruta) => S.Proyecto.abre(ruta, null)
            }
            //  Un PNG suelto se abre con un selector de FICHEROS y no de
            //  carpetas: un proyecto es una carpeta y una imagen es un
            //  fichero, y ningún diálogo del sistema elige las dos cosas. Por
            //  eso son dos órdenes y no una con un desplegable.
            FileDialog {
                id: guardarImagenDlg
                title: "Guardar la imagen como"
                fileMode: FileDialog.SaveFile
                defaultSuffix: "png"
                nameFilters: ["PNG (*.png)", "Imágenes (*.png *.jpg *.jpeg *.bmp *.webp)",
                              "Todo (*)"]
                onAccepted: S.Proyecto.guardaImagenEn(String(selectedFile).replace("file://", ""), null)
            }
            FileDialog {
                id: abrirImagenDlg
                title: "Abrir una imagen"
                nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.gif *.bmp *.webp)", "Todo (*)"]
                onAccepted: S.Proyecto.abreImagen(String(selectedFile).replace("file://", ""), null)
            }
            SelectorCarpeta {
                id: abrirEspecieDlg
                titulo: "Abrir una especie"
                onElegida: (ruta) => S.Especie.abre(ruta, null)
            }
            SelectorCarpeta {
                id: raizDlg
                titulo: "Dónde está el repositorio del juego"
                onElegida: (ruta) => {
                    S.Packs.apunta(S.Packs.activoId, ruta)
                    S.Especie.olvidaCatalogo()
                    S.Especie.cargaCatalogo(null)
                }
            }
            SelectorCarpeta {
                id: tallerDlg
                titulo: "Dónde dejar lo que crees"
                onElegida: (ruta) => S.Ajustes.taller = ruta
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // autoguardado
    // ═══════════════════════════════════════════════════════════
    //
    //  Sólo si el proyecto YA tiene una carpeta. Autoguardar uno sin ruta
    //  significa inventarse dónde, y aparecerían carpetas donde nadie las puso.

    //  Dos relojes, no uno.
    //
    //  El de abajo va cada dos minutos y es el que cubre estar dibujando sin
    //  parar. Éste salta cuando PARAS: seis segundos sin tocar nada y lo que
    //  hay se va al disco. Con sólo el periódico, cerrar la sesión o quedarse
    //  sin luz justo antes del siguiente aviso te costaba hasta dos minutos de
    //  trabajo, y no hay forma de enterarse desde dentro: cerrar la ventana no
    //  avisa a nadie —ni `closed` ni `visible` se enteran en este Quickshell—
    //  y matar el proceso, menos.
    Timer {
        id: reposo
        interval: 6000
        running: false
        onTriggered: guardaLoQueHaya()
    }
    Connections {
        target: S.Documento
        function onRevPixelesChanged() { if (S.Ajustes.autoguardado > 0) reposo.restart() }
        function onRevChanged() { if (S.Ajustes.autoguardado > 0) reposo.restart() }
    }

    function guardaLoQueHaya() {
        if (S.Proyecto.estado !== "") return
        if (!S.Documento.abierto || !S.Documento.sucio || !S.Documento.ruta) {
            //  Aunque el dibujo esté guardado, la ficha de la criatura puede
            //  haberse quedado atrás: cambiar duraciones o fotogramas la mueve
            //  a ella, no al .pinza.
            if (S.Especie.abierta) S.Especie.recogeYGuarda(null)
            return
        }
        //  Y si hay criatura, la ficha detrás del dibujo: las dos cosas cuentan
        //  como «lo que llevo hecho».
        S.Proyecto.guarda(null, (bien) => {
            if (bien && S.Especie.abierta) S.Especie.recogeYGuarda(null)
        })
    }

    Timer {
        interval: Math.max(30, S.Ajustes.autoguardado) * 1000
        running: S.Ajustes.autoguardado > 0
        repeat: true
        onTriggered: guardaLoQueHaya()
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

    //  Los ayudantes del IPC, fuera del IpcHandler.
    //
    //  `IpcHandler` intenta exponer TODAS sus funciones, tengan tipo o no, y
    //  con una que lleve argumentos sin tipar suelta un aviso por cada
    //  recarga. Un ayudante privado no tiene por qué salir a la interfaz
    //  pública sólo por vivir al lado, así que vive aquí.
    QtObject {
        id: mira

    /** El índice de la primera capa de calco, o -1. */
    function _iReferencia() {
        const d = S.Documento.d
        if (!d) return -1
        for (let i = 0; i < d.capas.length; i++)
            if (d.capas[i].tipo === "referencia") return i
        return -1
    }

    function _bufDe(que, f, o, capa) {
        if (!S.Documento.abierto) return null
        const d = S.Documento.d
        const ff = f === undefined || f === null ? S.Documento.fotograma : f
        const oo = o === undefined || o === null ? S.Documento.orientacion : o
        if (que === "referencia" || que === "capa") {
            const i = que === "referencia" ? _iReferencia()
                      : (capa === undefined || capa === null ? S.Documento.capaActiva : capa)
            const c = S.Documento.capa(i)
            if (!c) return null
            return S.Documento.celda(c.id, ff, oo, false)
        }
        if (que === "celda") return S.Documento.celdaActiva(false)
        if (que === "hoja") {
            //  Toda la animación de un vistazo: los fotogramas en columnas
            //  y las orientaciones en filas, que es como las lee el juego y
            //  como se ve de un golpe si una cara se ha quedado atrás.
            const cols = d.fotogramas.length, filas = d.orientaciones.length
            const celdas = []
            for (let y = 0; y < filas; y++) for (let x = 0; x < cols; x++)
                celdas.push(S.Documento.compuesto(x, y))
            return exportador.componHoja(celdas, cols, filas, d.ancho, d.alto)
        }
        return S.Documento.compuesto(f, o)
    }
    }

    IpcHandler {
        target: "pinza"

        /**
          * Devolver la ventana.
          *
          * Cerrar la ventana NO mata el proceso —y este Quickshell ni siquiera
          * se entera de que la has cerrado: ni `closed` ni `visible` cambian—.
          * Sin esto, cerrarla y volver a escribir `pinza` no te la devolvía:
          * arrancaba contra una instancia que ya estaba y te quedabas sin nada
          * en pantalla. `qs -c pinza ipc call pinza mostrar`
          */
        function mostrar(): string {
            //  Apagar y encender, no sólo encender: cuando cierras la ventana
            //  desde el gestor, Quickshell sigue creyendo que está visible, así
            //  que `visible = true` no hace nada porque ya lo era.
            ventana.visible = false
            ventana.visible = true
            return "aquí estoy"
        }

        function abrir(ruta: string): string {
            if (!ruta) return "hace falta una ruta"
            S.Proyecto.abre(ruta, null)
            ventana.visible = true
            return "abriendo " + ruta
        }

        /** Abrir una criatura entera. `qs -c pinza ipc call pinza especie /ruta.especie` */
        function especie(ruta: string): string {
            if (!ruta) return "hace falta una ruta"
            S.Especie.abre(ruta, null)
            ventana.visible = true
            return "abriendo " + ruta
        }

        /** Abrir un PNG suelto para retocarlo. */
        function imagen(ruta: string): string {
            if (!ruta) return "hace falta una ruta"
            S.Proyecto.abreImagen(ruta, null)
            ventana.visible = true
            return "abriendo " + ruta
        }

        /** Guardar lo abierto como imagen en una ruta dada. Para guiones. */
        function guardarImagen(ruta: string): string {
            if (!S.Documento.abierto) return "no hay nada abierto"
            if (!ruta) return "hace falta una ruta"
            S.Proyecto.guardaImagenEn(ruta, null)
            return "guardando en " + ruta
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

        /** Cualquier orden del programa, por su id. `qs -c pinza ipc call pinza orden deshacer` */
        function orden(id: string): string {
            const o = S.Ordenes.orden(id)
            if (!o) return "no existe la orden «" + id + "»"
            if (!S.Ordenes.disponible(o)) return "«" + o.titulo + "» no se puede ahora mismo"
            S.Ordenes.ejecuta(id)
            return o.titulo
        }

        /** Cambiar de pack desde fuera. `qs -c pinza ipc call pinza pack crabh` */
        function pack(id: string): string {
            for (let i = 0; i < S.Packs.lista.length; i++)
                if (S.Packs.lista[i].id === id) { S.Packs.elige(id); return "pack: " + id }
            return "no hay ningún pack «" + id + "»"
        }

        /** Elegir herramienta desde fuera. `qs -c pinza ipc call pinza herramienta sustituye` */
        function herramienta(id: string): string {
            S.Pinceles.elige(id)
            return S.Herramientas.nombre(id)
        }

        /** Enseñar u ocultar un panel. `qs -c pinza ipc call pinza panel tira=0` */
        function panel(qual: string): string {
            const p = qual.split("=")
            const on = p[1] === "1"
            if (p[0] === "compas") S.Ajustes.compas = on
            else if (p[0] === "muestra") S.Ajustes.muestra = on
            else if (p[0] === "paleta") S.Ajustes.panelPaleta = on
            else if (p[0] === "capas") S.Ajustes.panelCapas = on
            else if (p[0] === "tira") S.Ajustes.tira = on
            else if (p[0] === "acciones") ventana.mostrarAcciones = on
            else return "no sé qué es " + p[0]
            return p[0] + "=" + on
        }

        function interior(): string {
            const d = S.Documento.d
            if (d === null) return "d es null"
            if (d === undefined) return "d es undefined"
            let claves = []
            try { claves = Object.keys(d) } catch (e) { return "no se puede mirar: " + e }
            const cel = d.celdas ? Object.keys(d.celdas) : null
            let primera = "sin celdas"
            if (cel && cel.length) {
                const b = d.celdas[cel[0]]
                primera = cel[0] + " -> " + (b === null ? "null" : (typeof b))
                          + (b && b.d ? " d=" + (b.d.length) + " (" + (b.d.constructor ? b.d.constructor.name : "?") + ")"
                                      : " SIN d")
                          + (b ? " " + b.w + "x" + b.h : "")
            }
            return "claves: [" + claves.join(",") + "]"
                 + " · nombre=" + JSON.stringify(d.nombre)
                 + " · ancho=" + d.ancho + " alto=" + d.alto
                 + " · capas=" + (d.capas ? d.capas.length : "AUSENTE")
                 + " · fotogramas=" + (d.fotogramas ? d.fotogramas.length : "AUSENTE")
                 + " · celdas=" + (cel ? cel.length : "AUSENTE")
                 + " · " + primera
        }

        function estado(): string {
            if (!S.Documento.abierto) return "sin nada abierto"
            return S.Documento.nombre + " · " + S.Documento.ancho + "x" + S.Documento.alto
                 + " · " + S.Documento.nFotogramas + " fotogramas"
                 + " · " + S.Documento.nOrientaciones + " orientaciones"
                 + (S.Documento.sucio ? " · sin guardar" : "")
        }

        // ═══════════════════════════════════════════════════════
        // para máquinas
        // ═══════════════════════════════════════════════════════
        //
        //  Los verbos de arriba contestan en prosa porque los lee una persona
        //  en una terminal. Estos contestan en JSON porque los lee un programa
        //  —hoy, el servidor MCP de `mcp/`—, y «0054 · 40x40 · 1 fotogramas»
        //  obliga a cada cliente a inventarse un analizador que se rompe el día
        //  que alguien cambia un punto medio de sitio.
        //
        //  Todos son de ida y vuelta INMEDIATA salvo `previa`, que escribe un
        //  fichero y por tanto pasa por la forja: ahí se devuelve la ruta y el
        //  que llama espera a que aparezca. La forja escribe con temporal y
        //  `rename`, así que el fichero existe sólo cuando está entero — no
        //  hace falta ningún otro aviso.

        /**
         * Escribe un PNG de lo que hay, para poder MIRARLO desde fuera.
         *
         *     {"ruta":"/tmp/x.png", "escala":8, "que":"compuesto|celda|hoja",
         *      "fotograma":0, "orientacion":0, "fondo":"ajedrez|#rrggbb|ninguno"}
         *
         * El fondo de ajedrez no es decoración: sin él, lo transparente y lo
         * negro son el mismo píxel para quien mira la imagen, y media
         * conversación se va en discutir si el hueco está vacío o pintado.
         */
        function previa(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON: " + e }) }
            if (!S.Documento.abierto) return JSON.stringify({ bien: false, error: "no hay nada abierto" })
            if (!s.ruta) return JSON.stringify({ bien: false, error: "hace falta una ruta" })

            const src = mira._bufDe(s.que || "compuesto",
                               s.fotograma === undefined ? undefined : s.fotograma,
                               s.orientacion === undefined ? undefined : s.orientacion)
            if (!src) return JSON.stringify({ bien: false, error: "no hay nada que enseñar" })

            //  La escala se recorta sola para no devolver una imagen enorme:
            //  una hoja de once fotogramas por ocho caras a ×8 son cuatro mil
            //  píxeles de ancho, y nadie gana nada con eso.
            const tope = Math.max(64, s.max || 1200)
            let esc = Math.max(1, Math.round(s.escala || 8))
            while (esc > 1 && (src.w * esc > tope || src.h * esc > tope)) esc--

            let out = P.escalaVecino(src, src.w * esc, src.h * esc)

            const fondo = s.fondo === undefined ? "ajedrez" : s.fondo
            if (fondo && fondo !== "ninguno") {
                const cuadro = Math.max(4, esc)
                const base = P.nuevo(out.w, out.h)
                const claro = [70, 70, 76, 255], oscuro = [54, 54, 60, 255]
                const plano = fondo === "ajedrez" ? null : P.deHex(fondo)
                for (let y = 0; y < out.h; y++) for (let x = 0; x < out.w; x++)
                    P.pon(base, x, y, plano ? plano
                          : ((Math.floor(x / cuadro) + Math.floor(y / cuadro)) % 2 ? oscuro : claro))
                for (let y = 0; y < out.h; y++) for (let x = 0; x < out.w; x++) {
                    const c = P.lee(out, x, y)
                    if (c[3] > 0) P.mezcla(base, x, y, c, false)
                }
                out = base
            }

            exportador.escribe(s.ruta, out, () => {})
            return JSON.stringify({ bien: true, ruta: s.ruta, ancho: out.w, alto: out.h,
                                    escala: esc, origen: { ancho: src.w, alto: src.h } })
        }

        /** Todo el estado, en JSON. Lo que `estado` cuenta en prosa. */
        function ficha(): string {
            const out = {
                abierto: S.Documento.abierto,
                pack: S.Ajustes.pack,
                herramienta: S.Pinceles.herramienta,
                paleta: {
                    primario: P.aHex(S.Paleta.primario),
                    secundario: P.aHex(S.Paleta.secundario),
                    rampas: S.Paleta.rampas.map((r) => ({
                        nombre: r.nombre, colores: r.colores.map((c) => P.aHex(c)) }))
                },
                criatura: null,
                documento: null
            }
            if (S.Especie.abierta)
                out.criatura = { nombre: S.Especie.nombre, ruta: S.Especie.ruta,
                                 accion: S.Especie.accion,
                                 acciones: S.Especie.acciones.map((a) => a.id) }
            const d = S.Documento.d
            if (d) out.documento = {
                nombre: d.nombre, ruta: d.ruta, imagen: d.imagen,
                ancho: d.ancho, alto: d.alto, sucio: d.sucio,
                fotogramas: d.fotogramas.map((f) => f.duracion),
                orientaciones: d.orientaciones.slice(),
                capas: d.capas.map((c, i) => ({ i: i, nombre: c.nombre, visible: c.visible,
                                                opacidad: c.opacidad, modo: c.modo,
                                                tipo: c.tipo, grupo: c.grupo })),
                capaActiva: S.Documento.capaActiva,
                fotograma: S.Documento.fotograma,
                orientacion: S.Documento.orientacion,
                contrato: d.contrato ? { id: d.contrato.id, titulo: d.contrato.titulo || d.contrato.id } : null,
                seleccion: S.Seleccion.activa ? S.Seleccion.limites : null
            }
            return JSON.stringify(out)
        }

        /**
         * El dibujo como rejilla de caracteres.
         *
         * Para quien lee esto sin ojos: mil símbolos legibles en vez de un PNG
         * que no puede abrir. Y editable — se puede hablar de la fila 12.
         */
        function rejilla(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON" }) }
            const b = mira._bufDe(s.que || "compuesto", s.fotograma, s.orientacion)
            if (!b) return JSON.stringify({ bien: false, error: "no hay nada abierto" })
            const r = F.aTexto(b)
            r.bien = true
            return JSON.stringify(r)
        }

        /** Las medidas que el juego saca de los píxeles, y la guía del pack. */
        function medidas(): string {
            if (!S.Documento.abierto) return JSON.stringify({ bien: false, error: "no hay nada abierto" })
            const b = S.Documento.compuesto()
            const sil = P.silueta(b)
            return JSON.stringify({
                bien: true,
                ancho: b.w, alto: b.h,
                limites: P.limites(b, 8),
                silueta: { pieBajo: sil.pieBajo, medioAncho: sil.medioAncho, base: sil.base },
                paleta: S.Paleta.mide(b),
                guia: S.Paleta.guia,
                colores: P.coloresDe(b, 24).map((x) => ({ color: P.aHex(x.color), veces: x.veces }))
            })
        }

        /** Las órdenes que existen y cuáles se pueden ahora mismo. */
        function ordenes(): string {
            return JSON.stringify(S.Ordenes.lista.map((o) => ({
                id: o.id, titulo: o.titulo, grupo: o.grupo, atajo: o.atajo || "",
                disponible: S.Ordenes.disponible(o)
            })))
        }

        /**
         * Corre JavaScript contra el documento abierto.
         *
         * Es el verbo que lo abre todo, y por eso lleva la red debajo: pasa por
         * `Guiones`, así que entra en el historial como UN paso con el nombre
         * que se le dé y un Ctrl+Z lo deshace entero. Un guion que revienta a
         * mitad no deja rastro.
         */
        function guion(codigo: string, nombre: string): string {
            if (!codigo) return JSON.stringify({ bien: false, error: "no hay código" })
            const bien = S.Guiones.corre(codigo, nombre || "guion")
            return JSON.stringify({
                bien: bien,
                error: bien ? null : (S.Guiones.ultimoError ? S.Guiones.ultimoError.mensaje : "falló"),
                linea: bien || !S.Guiones.ultimoError ? null : (S.Guiones.ultimoError.linea || null),
                salida: S.Guiones.salida
            })
        }

        /**
         * Un documento nuevo sin pasar por la hoja.
         *
         *     {"nombre":"poción","ancho":32,"alto":32,"fotogramas":1,
         *      "orientaciones":["S"],"contrato":"idDelPack"}
         *
         * Con `contrato` sale con la geometría y las caras que manda el pack,
         * que es la diferencia entre un lienzo suelto y algo que el juego sabrá
         * leer al exportarlo.
         */
        function crear(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON" }) }
            //  Sólo lo que de verdad han pedido: `paraDocumento` rellena lo
            //  que falte CON EL CONTRATO, así que meter aquí un 32×32 por
            //  defecto no era un defecto, era pisar al contrato. Pedir la
            //  criatura de crabh daba un lienzo suelto de 32×32 con una sola
            //  cara, que es justo lo contrario de lo que se había pedido.
            let o = { nombre: s.nombre || "sin nombre" }
            for (const k of ["ancho", "alto", "fotogramas", "orientaciones"])
                if (s[k] !== undefined) o[k] = s[k]
            if (s.contrato) {
                const c = S.Packs.contrato(s.contrato)
                if (!c) return JSON.stringify({ bien: false, error: "no hay contrato «" + s.contrato + "»" })
                o = S.Packs.paraDocumento(c, o)
            } else {
                o.ancho = o.ancho || 32
                o.alto = o.alto || 32
                o.fotogramas = o.fotogramas || 1
                o.orientaciones = o.orientaciones || ["S"]
            }
            S.Documento.nuevo(o)
            S.Proyecto._aplicaRejilla()
            S.Historial.limpia()
            ventana.visible = true
            return JSON.stringify({ bien: true, nombre: S.Documento.nombre,
                                    ancho: S.Documento.ancho, alto: S.Documento.alto })
        }

        // ═══════════════════════════════════════════════════════
        // referencia y medida
        // ═══════════════════════════════════════════════════════

        /**
         * Mete una imagen como capa de CALCO.
         *
         *     {"ruta":"/tmp/x.png", "opacidad":0.4, "anclaje":"abajo"}
         *
         * Una capa de calco no se exporta —`compuesto()` compone con
         * `conReferencia` en falso y la exportación pasa por ahí—, así que lo
         * que entre por aquí no puede acabar dentro de un PNG por accidente.
         * Es la diferencia entre mirar una referencia y copiarla.
         *
         * Se recorta a lo dibujado y se reescala para caber en el lienzo,
         * porque una referencia viene del tamaño que viene —un sprite de 96
         * contra un contrato de 40— y superponerla a pelo no sirve de nada.
         */
        function referencia(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON" }) }
            if (!S.Documento.abierto) return JSON.stringify({ bien: false, error: "no hay nada abierto" })
            if (!s.ruta) return JSON.stringify({ bien: false, error: "hace falta una ruta" })
            const nombre = s.nombre || "calco"

            exportador.dePng(s.ruta, (buf) => {
                if (!buf) { console.warn("no se puede leer " + s.ruta); return }
                const W = S.Documento.ancho, H = S.Documento.alto
                let puesto = P.nuevo(W, H)
                const l = P.limites(buf, 8)
                if (l) {
                    const f = Math.min((W - 2) / l.w, (H - 2) / l.h)
                    const trozo = P.recorte(buf, l.x, l.y, l.w, l.h)
                    const esc = f < 1 || s.encaja
                        ? P.escalaVecino(trozo, Math.max(1, Math.round(l.w * f)),
                                                Math.max(1, Math.round(l.h * f)))
                        : trozo
                    const dx = Math.round((W - esc.w) / 2)
                    //  Apoyada abajo y no centrada: dos bichos comparten el
                    //  suelo, no el centro. Centrando, la referencia queda
                    //  flotando un par de píxeles por encima de tus pies y
                    //  todas las medidas salen corridas.
                    const dy = (s.anclaje === "centro") ? Math.round((H - esc.h) / 2)
                                                        : (H - esc.h - 1)
                    P.estampa(puesto, esc, dx, dy)
                }
                S.Historial.abreEstructura()
                const vieja = mira._iReferencia()
                if (vieja >= 0 && s.sustituye !== false) S.Documento.borraCapa(vieja)
                //  Dónde estabas dibujando, para devolverte ahí.
                const antes = S.Documento.capa(S.Documento.capaActiva)
                const capa = S.Documento.añadeCapa(nombre, "referencia")
                capa.opacidad = s.opacidad === undefined ? 0.45 : s.opacidad
                capa.bloqueada = true
                for (let f2 = 0; f2 < S.Documento.nFotogramas; f2++)
                    for (let o2 = 0; o2 < S.Documento.nOrientaciones; o2++)
                        P.vuelca(S.Documento.celda(capa.id, f2, o2, true), puesto, 0, 0)
                //  La capa activa vuelve a ser la tuya.
                //
                //  `añadeCapa` deja activa la que acaba de crear, que para una
                //  capa normal es lo que quieres y para un CALCO es justo lo
                //  contrario: poner una referencia no es cambiar de sitio de
                //  trabajo. Y el calco nace bloqueado, así que el siguiente
                //  trazo no iba a ninguna parte y no decía por qué.
                if (antes) {
                    const i = S.Documento.indiceDe(antes.id)
                    if (i >= 0) S.Documento.capaActiva = i
                }
                S.Historial.cierraEstructura("referencia")
                S.Documento.cambiaPixeles(null)
            })
            return JSON.stringify({ bien: true, ruta: s.ruta, nombre: nombre, esperando: true })
        }

        /** Los números de un dibujo: proporciones, perfil, rampas, valores. */
        function analiza(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON" }) }
            const b = mira._bufDe(s.que || "compuesto", s.fotograma, s.orientacion, s.capa)
            if (!b) return JSON.stringify({ bien: false, error: "ahí no hay nada que medir" })
            const r = F.analiza(b, s.franjas)
            r.bien = true
            return JSON.stringify(r)
        }

        /**
         * Cuánto se parecen dos siluetas, en un número.
         *
         *     {"a":{"que":"compuesto"}, "b":{"que":"referencia"}}
         *
         * Es lo que convierte «se parece» en algo con lo que se puede BUSCAR:
         * mueves un parámetro del aparejo, vuelves a medir, y te quedas con el
         * que sube. Sin un número, ajustar es opinar ocho veces seguidas.
         */
        function compara(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON" }) }
            const A = s.a || { que: "compuesto" }, B = s.b || { que: "referencia" }
            const ba = mira._bufDe(A.que || "compuesto", A.fotograma, A.orientacion, A.capa)
            const bb = mira._bufDe(B.que || "referencia", B.fotograma, B.orientacion, B.capa)
            if (!ba || !bb) return JSON.stringify({ bien: false, error: "falta uno de los dos" })
            const ka = F.deBuffer(ba), kb = F.deBuffer(bb)
            const sol = F.solape(ka, kb)
            const pa = F.perfil(ka, s.franjas || 12), pb = F.perfil(kb, s.franjas || 12)
            //  La diferencia franja a franja dice DÓNDE discrepan, que es lo
            //  accionable: un solape bajo sólo dice que algo va mal.
            const dif = pa.map((f, i) => +(f.ancho - (pb[i] ? pb[i].ancho : 0)).toFixed(3))
            return JSON.stringify({
                bien: true, solape: sol.iou, desplazamiento: { x: sol.dx, y: sol.dy },
                relacion: sol.relacion,
                anchoPorFranja: { tuyo: pa.map((f) => f.ancho), suyo: pb.map((f) => f.ancho),
                                  diferencia: dif },
                peor: dif.reduce((m, v, i) => Math.abs(v) > Math.abs(dif[m]) ? i : m, 0)
            })
        }

        /**
         * Trocea una hoja de sprites y la abre como documento.
         *
         *     {"ruta":"…/Walk-Anim.png","ancho":32,"alto":32,"contrato":"pmd"}
         *
         * Las columnas son fotogramas y las filas orientaciones, que es como
         * las escribe el juego. Es la puerta de entrada para trabajar sobre
         * algo que YA existe —una variante, un recolor, un rediseño— sin tener
         * que dibujarlo otra vez desde cero.
         *
         * Con `contrato` se le ponen a las filas los nombres de cara que manda
         * el pack en vez de d0…d7, que es la diferencia entre ocho filas y
         * ocho ORIENTACIONES: sin eso el editor no sabe cuál es el sur y el
         * compás no puede colocarlas.
         */
        function hoja(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON" }) }
            if (!s.ruta) return JSON.stringify({ bien: false, error: "hace falta una ruta" })
            const cw = s.ancho || 32, ch = s.alto || 32
            S.Proyecto.importaHoja(s.ruta, cw, ch, s.orientaciones === false ? false : true, (bien) => {
                if (!bien) return
                if (s.contrato) {
                    const c = S.Packs.contrato(s.contrato)
                    if (c && c.orientaciones
                        && c.orientaciones.length === S.Documento.nOrientaciones) {
                        S.Documento.ponOrientaciones(c.orientaciones.map((o) => o.id))
                        S.Documento.d.contrato = JSON.parse(JSON.stringify(c))
                        S.Documento.cambia()
                    }
                }
                if (s.nombre) S.Documento.ponNombre(s.nombre)
            })
            ventana.visible = true
            return JSON.stringify({ bien: true, ruta: s.ruta, celda: cw + "x" + ch, esperando: true })
        }

        // ═══════════════════════════════════════════════════════
        // criaturas
        // ═══════════════════════════════════════════════════════

        /**
         * Trae una criatura entera del catálogo del pack.
         *
         *     {"dex":16, "nombre":"PideyFuego", "destino":"/ruta/donde"}
         *
         * Entera quiere decir TODAS sus acciones, cada una con su geometría y
         * sus duraciones. Es la diferencia entre retocar un bicho y retocar
         * una hoja suya: un recolor que sólo llega a `Walk` deja un bicho que
         * cambia de color al pararse, y eso no se ve dibujando — se ve
         * jugando.
         */
        function traer(spec: string): string {
            let s = {}
            try { s = spec ? JSON.parse(spec) : {} } catch (e) { return JSON.stringify({ bien: false, error: "el spec no es JSON" }) }
            if (s.dex === undefined) return JSON.stringify({ bien: false, error: "hace falta un dex" })
            if (!s.destino) return JSON.stringify({ bien: false, error: "hace falta un destino" })

            //  `Especie.importa` espera la ruta COMPLETA del .especie, no la
            //  carpeta donde meterlo. Dándole una carpeta a secas te esparce
            //  las ocho acciones y el especie.json por dentro de ella — que
            //  con un descuido es tu carpeta personal llena de Idle.pinza y
            //  Walk.pinza sueltos. Si no acaba en .especie se toma como el
            //  sitio, que es lo que cualquiera querría decir.
            const nom = s.nombre || ("dex" + s.dex)
            const destino = /\.especie$/.test(s.destino)
                            ? s.destino
                            : s.destino.replace(/\/+$/, "") + "/" + nom + ".especie"
            S.Especie.importa(s.dex, s.nombre || "", destino, () => {})
            ventana.visible = true
            return JSON.stringify({ bien: true, dex: s.dex, destino: destino, esperando: true })
        }

        /**
         * Cambia a una acción de la criatura abierta.
         *
         * Guarda sola la que dejas, que es lo que permite recorrerlas todas en
         * un bucle sin perder nada por el camino.
         */
        function accion(id: string): string {
            if (!S.Especie.abierta) return JSON.stringify({ bien: false, error: "no hay ninguna criatura abierta" })
            if (!id) return JSON.stringify({ bien: true, accion: S.Especie.accion,
                                             acciones: S.Especie.acciones.map((a) => a.id) })
            const hay = S.Especie.acciones.some((a) => a.id === id)
            if (!hay) return JSON.stringify({ bien: false, error: "no tiene la acción «" + id + "»" })
            S.Especie.editaAccion(id, () => {})
            return JSON.stringify({ bien: true, accion: id, esperando: true })
        }

        /** Recoge lo que hay delante y guarda la criatura entera. */
        function guardarCriatura(): string {
            if (!S.Especie.abierta) return JSON.stringify({ bien: false, error: "no hay ninguna criatura abierta" })
            S.Especie.recogeYGuarda(() => {})
            return JSON.stringify({ bien: true, ruta: S.Especie.ruta, esperando: true })
        }

        /** El catálogo del pack, para saber qué se puede traer. */
        function catalogo(): string {
            S.Especie.cargaCatalogo(() => {})
            return JSON.stringify({
                bien: S.Especie.catalogoListo,
                error: S.Especie.catalogoError || null,
                leyendo: S.Especie.catalogoLeyendo,
                cuantas: S.Especie.catalogo.length,
                criaturas: S.Especie.catalogo.map((c) => ({ dex: c.dex, nombre: c.name }))
            })
        }

        /** Guardar en una carpeta concreta, sin diálogo. Para un lote. */
        function guardarEn(ruta: string): string {
            if (!S.Documento.abierto) return JSON.stringify({ bien: false, error: "no hay nada abierto" })
            if (!ruta) return JSON.stringify({ bien: false, error: "hace falta una ruta" })
            S.Proyecto.guarda(ruta, null)
            return JSON.stringify({ bien: true, ruta: ruta })
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

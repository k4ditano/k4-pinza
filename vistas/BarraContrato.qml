//  La barra de contrato.
//
//  Aquí iría la barra de menús en cualquier otro editor. En su lugar va lo que
//  estás dibujando y bajo qué reglas: el perfil, el tamaño, los ejes, la huella
//  si la hay y a dónde va a salir el fichero. Los menús no hacen falta —para
//  eso está Ctrl+K— pero saber que este PNG tiene que medir 32×32, llamarse
//  Home_Bed_N.png y aparecer en el manifiesto sí hace falta, todo el rato.

import QtQuick
import "../core" as C
import "../servicios" as S

Rectangle {
    id: raiz
    implicitHeight: C.Tema.barra
    color: C.Tema.superficie

    readonly property var con: S.Documento.d ? S.Documento.d.contrato : null

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: C.Tema.borde
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: derecha.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        clip: true

        // ── el nombre, editable en el sitio ──────────────────────
        Item {
            width: Math.max(70, nombre.implicitWidth + 10)
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            visible: S.Documento.abierto

            TextInput {
                id: nombre
                anchors.fill: parent
                anchors.leftMargin: 4
                verticalAlignment: TextInput.AlignVCenter
                text: S.Documento.nombre
                font.family: C.Tema.tipo
                font.pixelSize: C.Tema.letraGrande
                font.weight: Font.DemiBold
                color: C.Tema.acento
                selectByMouse: true
                selectionColor: C.Tema.acento
                onEditingFinished: if (text) S.Documento.ponNombre(text)
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: nombre.activeFocus ? 1 : 0
                border.color: C.Tema.acento
                radius: 3
            }
        }

        Text {
            text: S.Documento.sucio ? "•" : ""
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 15
            color: C.Tema.aviso
        }

        Repeater {
            id: chips
            model: raiz._trozos
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                //  El último se esconde entero si no cabe, en vez de salir
                //  cortado a mitad de palabra. Sólo el último: esconder uno de
                //  en medio recolocaría los siguientes y podría entrar en un
                //  baile de aparecer y desaparecer.
                visible: index < chips.count - 1
                         || x + implicitWidth <= (parent ? parent.width : 0)
                Text {
                    text: "│"
                    font.family: C.Tema.tipoMono
                    font.pixelSize: C.Tema.letra
                    color: C.Tema.borde
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: modelData
                    font.family: C.Tema.tipoMono
                    font.pixelSize: C.Tema.letraChica
                    color: C.Tema.tenue
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    /**
     * Lo que el contrato impone, en trozos legibles de un vistazo.
     *
     * Se reasigna sólo cuando cambia de verdad, por lo mismo que en la muestra:
     * un `property var` que devuelve un array nuevo hace que el Repeater tire
     * y rehaga todos sus delegados en cada cambio del documento.
     */
    property var _trozos: []

    function recalculaTrozos() {
        const t = _calcula()
        if (t.join("\u0001") !== _trozos.join("\u0001")) _trozos = t
    }
    Component.onCompleted: recalculaTrozos()
    Connections {
        target: S.Documento
        function onRevChanged() { raiz.recalculaTrozos() }
    }
    Connections {
        target: S.Especie
        function onCambiada() { raiz.recalculaTrozos() }
    }

    function _calcula() {
        if (!S.Documento.abierto) return []
        const t = []
        //  Si esto es una acción de una criatura, decirlo: es lo que orienta
        //  cuando llevas ocho proyectos abiertos que se llaman todos igual.
        if (S.Especie.abierta && S.Especie.accion)
            t.push(S.Especie.nombre + " · " + S.Especie.accion)
        t.push((con ? con.titulo.toLowerCase() : "libre") + " · "
               + S.Documento.ancho + "×" + S.Documento.alto)
        if (S.Documento.nFotogramas > 1)
            t.push(S.Documento.nFotogramas + " fotogramas · "
                   + (S.Documento.duracionTotal / 60).toFixed(2) + " s")
        if (S.Documento.nOrientaciones > 1)
            t.push(S.Documento.nOrientaciones + " orientaciones")
        const h = S.Documento.d.huella
        if (h) t.push("huella " + h.ancho + "×" + h.alto + " casillas")
        //  Resuelto, no el patrón crudo: saber que va a "assets/species/{nombre}"
        //  no dice nada; saber que va a "assets/species/Cangrejito" sí.
        //
        //  Y sólo los dos últimos tramos: la ruta entera no cabe en la barra y
        //  se cortaba a mitad de palabra, que queda a medio camino entre
        //  informar y ensuciar. Los dos últimos son los que identifican.
        if (con && con.salida && con.salida.carpeta) {
            const partes = S.Proyecto.nombraCon(con.salida.carpeta).split("/").filter(Boolean)
            t.push("→ " + partes.slice(-2).join("/"))
        }
        return t
    }

    // ── la derecha: deshacer, pack, avisos y los comandos ────────
    Row {
        id: derecha
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        //  Deshacer a la vista y no sólo en un atajo. Un editor sin un botón de
        //  deshacer parece un editor sin deshacer, por mucho que Ctrl+Z
        //  funcione — y además da la cuenta de por dónde vas.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            C.Boton {
                icono: C.Tema.i.undo
                width: 26; implicitHeight: 24
                tenue: !S.Historial.puedeDeshacer
                pista: S.Historial.puedeDeshacer
                       ? "deshacer «" + S.Historial.nombreDe(S.Historial.actual) + "»   Ctrl+Z"
                       : "nada que deshacer"
                onPulsado: S.Ordenes.ejecuta("deshacer")
            }
            C.Boton {
                icono: C.Tema.i.redo
                width: 26; implicitHeight: 24
                tenue: !S.Historial.puedeRehacer
                pista: S.Historial.puedeRehacer
                       ? "rehacer «" + S.Historial.nombreDe(S.Historial.actual + 1) + "»   Ctrl+Shift+Z"
                       : "nada que rehacer"
                onPulsado: S.Ordenes.ejecuta("rehacer")
            }
            C.Boton {
                icono: C.Tema.i.historial
                width: 26; implicitHeight: 24
                activo: S.Ajustes.panelHistorial
                tenue: S.Historial.pasos === 0
                pista: "el historial entero (" + S.Historial.pasos + " pasos)"
                onPulsado: S.Ajustes.panelHistorial = !S.Ajustes.panelHistorial
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 18
            color: C.Tema.borde
        }

        //  Las tres vistas que se pueden apagar, con un botón cada una.
        //
        //  Tenían atajo y estaban en los comandos, que es como decir que no
        //  estaban: si apagas la muestra sin querer, no hay nada en pantalla
        //  que te diga que existe ni cómo volver a encenderla. El botón que se
        //  queda encendido cuando la vista está puesta es, además, la única
        //  forma de saber de un vistazo qué tienes abierto.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: S.Documento.abierto
            spacing: 1
            C.Boton {
                icono: C.Tema.i.lupa
                width: 26; implicitHeight: 24
                activo: S.Ajustes.muestra
                pista: "el dibujo a tamaño real, flotando sobre el lienzo   P"
                onPulsado: S.Ajustes.muestra = !S.Ajustes.muestra
            }
            C.Boton {
                icono: C.Tema.i.juego
                width: 26; implicitHeight: 24
                activo: S.Ajustes.panelPrevia
                pista: "la previa en juego: sobre el suelo, con su sombra y sus medidas"
                onPulsado: S.Ajustes.panelPrevia = !S.Ajustes.panelPrevia
            }
            C.Boton {
                icono: C.Tema.i.compas
                width: 26; implicitHeight: 24
                activo: S.Ajustes.compas
                tenue: S.Documento.nOrientaciones < 2
                pista: S.Documento.nOrientaciones < 2
                       ? "el compás de las caras (este dibujo sólo tiene una)"
                       : "el compás: saltar entre las " + S.Documento.nOrientaciones + " caras"
                onPulsado: S.Ajustes.compas = !S.Ajustes.compas
            }
        }

        Rectangle {
            visible: S.Documento.abierto
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 18
            color: C.Tema.borde
        }

        // Un aviso del contrato, si lo hay. No bloquea nada: enseña.
        Rectangle {
            visible: raiz._aviso !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: avisoTexto.implicitWidth + 22
            height: 20
            radius: 3
            color: C.Tema.acentoTenue
            border.width: 1
            border.color: C.Tema.aviso
            Row {
                anchors.centerIn: parent
                spacing: 5
                C.Icono {
                    glifo: C.Tema.i.aviso
                    color: C.Tema.aviso
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: avisoTexto
                    text: raiz._aviso
                    font.family: C.Tema.tipo
                    font.pixelSize: C.Tema.letraChica
                    color: C.Tema.tinta
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        C.Boton {
            texto: S.Packs.activo ? S.Packs.activo.titulo : "genérico"
            pista: "el pack manda las paletas, los perfiles y a dónde salen los ficheros"
            implicitHeight: 22
            relleno: 8
            anchors.verticalCenter: parent.verticalCenter
            onPulsado: S.Ordenes.ejecuta("pack")
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 52; height: 20
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: C.Tema.borde
            Text {
                anchors.centerIn: parent
                text: "Ctrl K"
                font.family: C.Tema.tipoMono
                font.pixelSize: 10
                color: C.Tema.tenue
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: raiz.pideComandos()
            }
        }
    }

    signal pideComandos()

    /**
     * El aviso del contrato.
     *
     * crabh rechaza en check-tiles.mjs cualquier objeto que haya que deformar
     * fuera de ×0.4–×1.6 para que quepa en su huella, y cualquiera cuya
     * proporción de dibujo no case con la de la huella. Enseñarlo aquí, con el
     * número, es más útil que enterarse al lanzar las comprobaciones.
     */
    readonly property string _aviso: {
        S.Documento.rev
        if (!S.Documento.abierto || !con || !con.avisos) return ""
        const h = S.Documento.d.huella
        if (!h || !con.rejilla) return ""
        const casilla = con.rejilla.ancho
        const escala = (h.ancho * casilla) / S.Documento.ancho
        if (escala < 0.4 || escala > 1.6)
            return "el dibujo se deformaría ×" + escala.toFixed(2) + " para caber en su huella"
        const arte = S.Documento.ancho / S.Documento.alto
        const pie = h.ancho / h.alto
        if (Math.abs(Math.log(arte / pie) / Math.LN2) > 1.05)
            return "la proporción del dibujo no casa con la de la huella"
        return ""
    }
}

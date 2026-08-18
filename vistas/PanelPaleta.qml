//  El color.
//
//  Rampas, no una rejilla de cuadraditos. Un pixel artist no piensa "este
//  verde" sino "la sombra, el cuerpo y el brillo de este verde", y tenerlas
//  como unidad es lo que hace posible la tinta de sombreado: pintar con ella
//  mueve cada píxel un paso por SU rampa en vez de aplastarlo con un plano.
//
//  Debajo, el medidor. Si el pack trae guía te dice dónde estás respecto a
//  ella. NO PROHÍBE NADA: es un cuentakilómetros, no una barrera, y se apaga
//  en Ajustes. Sin pack con guía, ni aparece.

import QtQuick
import QtQuick.Dialogs
import "../core" as C
import "../core/pixeles.js" as P
import "../servicios" as S

C.Hoja {
    id: raiz
    titulo: "color"
    icono: C.Tema.i.paleta

    //  Igual que en la previa: calcularlo por enlace hace que dependa de la
    //  caché que `compuesto()` acaba de escribir. Además medir el dibujo
    //  entero en cada trazo sería caro, y aquí no hace falta esa frescura.
    property var medida: null
    function mide() {
        medida = (S.Documento.abierto && S.Ajustes.avisoGuia)
               ? S.Paleta.mide(S.Documento.compuesto()) : null
    }
    Timer {
        id: espera
        interval: 250
        onTriggered: raiz.mide()
    }
    Component.onCompleted: mide()
    Connections {
        target: S.Documento
        function onRevPixelesChanged() { espera.restart() }
        function onRevChanged() { espera.restart() }
    }

    Column {
        width: parent.width
        spacing: 7

        // ── los dos colores ──────────────────────────────────────
        Item {
            width: parent.width
            height: 40

            Rectangle {
                id: secu
                x: 18; y: 12
                width: 26; height: 26
                radius: 3
                color: S.Paleta.secundarioHex
                border.width: 1
                border.color: C.Tema.borde
                MouseArea {
                    anchors.fill: parent
                    onClicked: { elector.cual = 2; elector.selectedColor = S.Paleta.secundarioHex; elector.open() }
                }
            }
            Rectangle {
                x: 2; y: 0
                width: 30; height: 30
                radius: 3
                color: S.Paleta.primarioHex
                border.width: 2
                border.color: C.Tema.tinta
                MouseArea {
                    anchors.fill: parent
                    onClicked: { elector.cual = 1; elector.selectedColor = S.Paleta.primarioHex; elector.open() }
                }
            }
            C.Boton {
                x: 50; y: 4
                width: 22; implicitHeight: 22
                texto: "⇄"
                pista: "intercambiar   X"
                onPulsado: S.Paleta.intercambia()
            }

            Column {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 1
                spacing: 1
                Text {
                    text: S.Paleta.primarioHex
                    font.family: C.Tema.tipoMono
                    font.pixelSize: C.Tema.letraChica
                    color: C.Tema.tinta
                    horizontalAlignment: Text.AlignRight
                    width: 62
                }
                Text {
                    text: S.Paleta.secundarioHex
                    font.family: C.Tema.tipoMono
                    font.pixelSize: 10
                    color: C.Tema.tenue
                    horizontalAlignment: Text.AlignRight
                    width: 62
                }
            }
        }

        ColorDialog {
            id: elector
            property int cual: 1
            onAccepted: {
                const c = [selectedColor.r * 255, selectedColor.g * 255, selectedColor.b * 255, 255]
                if (cual === 1) S.Paleta.ponPrimario(c); else S.Paleta.ponSecundario(c)
            }
        }

        // ── las rampas ───────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 3

            Repeater {
                model: S.Paleta.rev, S.Paleta.rampas

                Item {
                    width: parent.width
                    height: 20
                    readonly property int iRampa: index

                    Text {
                        id: nombreRampa
                        width: 52
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.nombre
                        font.family: C.Tema.tipo
                        font.pixelSize: 10
                        color: S.Paleta.rampaActiva === index ? C.Tema.acento : C.Tema.tenue
                        elide: Text.ElideRight
                    }

                    Row {
                        anchors.left: nombreRampa.right
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 16
                        spacing: 2

                        Repeater {
                            model: modelData.colores
                            Rectangle {
                                width: Math.max(8, (parent.width - (parent.children.length - 1) * 2)
                                                   / Math.max(1, parent.children.length))
                                height: 16
                                radius: 2
                                color: P.aHex(modelData)
                                border.width: swRaton.containsMouse ? 2 : 0
                                border.color: C.Tema.tinta

                                MouseArea {
                                    id: swRaton
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (m) => {
                                        S.Paleta.rampaActiva = iRampa
                                        if (m.button === Qt.RightButton) S.Paleta.ponSecundario(modelData)
                                        else S.Paleta.ponPrimario(modelData)
                                    }
                                }
                                C.Pista { texto: P.aHex(modelData); mostrar: swRaton.containsMouse; lado: Qt.AlignTop }
                            }
                        }
                    }
                }
            }
        }

        Row {
            spacing: 2
            C.Boton { icono: C.Tema.i.mas; implicitHeight: 20; width: 24
                      pista: "rampa nueva con el color primario"
                      onPulsado: S.Paleta.añadeRampa(null, [S.Paleta.primario]) }
            C.Boton { texto: "+ tono"; implicitHeight: 20; relleno: 6
                      pista: "añadir el primario a esta rampa"
                      onPulsado: S.Paleta.añadeColor(S.Paleta.rampaActiva, S.Paleta.primario) }
            C.Boton { icono: C.Tema.i.varita; implicitHeight: 20; width: 24
                      pista: "sacar la paleta del dibujo"
                      onPulsado: S.Ordenes.ejecuta("paletaDelDibujo") }
            C.Boton { icono: C.Tema.i.carpeta; implicitHeight: 20; width: 24
                      pista: "cargar una paleta (.gpl, .hex, .png)"
                      onPulsado: abrePaleta.open() }
        }

        FileDialog {
            id: abrePaleta
            title: "Cargar una paleta"
            nameFilters: ["Paletas (*.gpl *.hex *.txt *.png)", "Todo (*)"]
            onAccepted: {
                const ruta = String(selectedFile).replace("file://", "")
                S.Forja.pide("paletaFichero", { ruta: ruta }, (r) => {
                    if (!r.bien || !r.colores.length) return
                    S.Paleta.cargaRampas([{ nombre: ruta.split("/").pop(), colores: r.colores }])
                })
            }
        }

        // ── el medidor, si el pack trae guía ─────────────────────
        Rectangle {
            visible: S.Paleta.guia !== null && raiz.medida !== null
            width: parent.width
            height: guia.implicitHeight + 12
            radius: 3
            color: C.Tema.fondo
            border.width: 1
            border.color: C.Tema.bordeSuave

            Column {
                id: guia
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 7
                spacing: 2

                Row {
                    width: parent.width
                    C.Rotulo { text: "guía de " + (S.Packs.activo ? S.Packs.activo.titulo : "") }
                    Item { width: parent.width - 120; height: 1 }
                    C.Icono {
                        glifo: C.Tema.i.info
                        font.pixelSize: 11
                        color: C.Tema.apagado
                        MouseArea {
                            id: infoRaton
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                        }
                        C.Pista {
                            texto: S.Paleta.guia ? S.Paleta.guia.aviso : ""
                            mostrar: infoRaton.containsMouse
                            lado: Qt.AlignTop
                        }
                    }
                }

                Row {
                    width: parent.width
                    Text {
                        text: "colores"
                        width: 66
                        font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                    }
                    Text {
                        text: raiz.medida && S.Paleta.guia ? raiz.medida.colores + " / " + S.Paleta.guia.colores : ""
                        font.family: C.Tema.tipoMono; font.pixelSize: 10
                        color: raiz.medida && raiz.medida.coloresFuera ? C.Tema.aviso : C.Tema.bien
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        text: "saturación"
                        width: 66
                        font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                    }
                    Text {
                        text: raiz.medida && S.Paleta.guia
                              ? raiz.medida.saturacion.toFixed(2) + " / " + S.Paleta.guia.saturacion : ""
                        font.family: C.Tema.tipoMono; font.pixelSize: 10
                        color: raiz.medida && raiz.medida.saturacionFuera ? C.Tema.aviso : C.Tema.bien
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        text: "luminancia"
                        width: 66
                        font.family: C.Tema.tipo; font.pixelSize: 10; color: C.Tema.tenue
                    }
                    Text {
                        text: raiz.medida && S.Paleta.guia
                              ? Math.round(raiz.medida.luminancia) + " / " + S.Paleta.guia.luminancia : ""
                        font.family: C.Tema.tipoMono; font.pixelSize: 10
                        color: raiz.medida && raiz.medida.luminanciaFuera ? C.Tema.aviso : C.Tema.bien
                    }
                }
            }
        }
    }
}

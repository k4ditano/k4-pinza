//  La tira.
//
//  Aseprite pone celdas de ancho fijo y la duración en un diálogo. Aquí el
//  ancho ES la duración, en TICS de 1/60 s, con una regla debajo. Arrastrando
//  el borde derecho de un fotograma se retima la animación mirándola, que es
//  como se retima de verdad: ver que el fotograma de impacto dura cuatro tics
//  y el de recuperación doce es lo que hace que un golpe se sienta bien, y con
//  un diálogo por fotograma eso no se ve nunca.
//
//  Y el tic no es una unidad decorativa: es la que guarda AnimData.xml y la
//  que lee el juego. Una sola unidad en todo el programa evita la clase de
//  fallo en que la animación va bien aquí y a destiempo allí.

import QtQuick
import "../core" as C
import "../servicios" as S

Rectangle {
    id: raiz
    color: C.Tema.superficie
    implicitHeight: 76

    readonly property real pxPorTic: 4.2
    readonly property real anchoMin: 22

    Rectangle {
        anchors.top: parent.top
        width: parent.width; height: 1
        color: C.Tema.borde
    }

    // ═══════════════════════════════════════════════════════════
    // mandos de reproducción
    // ═══════════════════════════════════════════════════════════

    Row {
        id: mandos
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        C.Boton {
            icono: C.Tema.i.anterior
            pista: "fotograma anterior"
            implicitHeight: 26
            onPulsado: S.Animacion.anterior()
        }
        C.Boton {
            icono: S.Animacion.sonando ? C.Tema.i.pause : C.Tema.i.play
            activo: S.Animacion.sonando
            pista: "reproducir   Espacio"
            implicitHeight: 26
            onPulsado: S.Animacion.alterna()
        }
        C.Boton {
            icono: C.Tema.i.siguiente
            pista: "fotograma siguiente"
            implicitHeight: 26
            onPulsado: S.Animacion.siguiente()
        }
        //  Con play y pausa, porque es de la misma familia: cómo lo MIRAS. Lo
        //  que dura de verdad está al otro lado de la tira, con los tics, y
        //  tenerlos juntos era pedir que se confundieran.
        C.Boton {
            texto: S.Animacion.velocidadTexto
            activo: S.Animacion.velocidad !== 1
            relleno: 8
            implicitHeight: 26
            pista: "a qué velocidad lo MIRAS: sólo la previa. Lo que se guarda y "
                   + "lo que reproduce el juego son los tics de cada fotograma"
            onPulsado: S.Animacion.otraVelocidad()
        }
    }

    // ═══════════════════════════════════════════════════════════
    // los fotogramas
    // ═══════════════════════════════════════════════════════════

    Flickable {
        id: rio
        anchors.left: mandos.right
        anchors.leftMargin: 10
        anchors.right: cola.left
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        contentWidth: fila.width + 40
        clip: true
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id: fila
            height: parent.height
            spacing: 3

            Repeater {
                model: S.Documento.rev, S.Documento.nFotogramas

                Item {
                    id: fot
                    readonly property int tics: S.Documento.duracion(index)
                    readonly property bool actual: S.Documento.fotograma === index
                    readonly property var etiqueta: S.Documento.etiquetaDe(index)
                    readonly property bool enlazada: {
                        S.Documento.rev
                        const c = S.Documento.capa(S.Documento.capaActiva)
                        return c ? S.Documento.estaEnlazada(c.id, index, S.Documento.orientacion) : false
                    }

                    width: Math.max(raiz.anchoMin, tics * raiz.pxPorTic)
                    height: fila.height

                    // la banda de la etiqueta, arriba
                    Rectangle {
                        visible: !!fot.etiqueta
                        width: parent.width; height: 3
                        radius: 1.5
                        color: fot.etiqueta ? fot.etiqueta.color : "transparent"
                    }

                    Rectangle {
                        id: caja
                        anchors.fill: parent
                        anchors.topMargin: 6
                        anchors.bottomMargin: 14
                        radius: 3
                        color: fot.actual ? C.Tema.acentoTenue
                             : fotRaton.containsMouse ? C.Tema.alta : C.Tema.fondo
                        border.width: 1
                        border.color: fot.actual ? C.Tema.acento : C.Tema.borde

                        // el número del fotograma
                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: index + 1
                            font.family: C.Tema.tipoMono
                            font.pixelSize: 10
                            color: fot.actual ? C.Tema.acento : C.Tema.tenue
                        }
                        // y su duración, que es lo que mide la caja
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: fot.tics + "t"
                            font.family: C.Tema.tipoMono
                            font.pixelSize: 10
                            color: C.Tema.tinta
                            visible: caja.width > 26
                        }
                        C.Icono {
                            visible: fot.enlazada
                            glifo: C.Tema.i.enlace
                            anchors.centerIn: parent
                            font.pixelSize: 11
                            color: C.Tema.tenue
                        }

                        MouseArea {
                            id: fotRaton
                            anchors.fill: parent
                            anchors.rightMargin: 5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { S.Animacion.para(); S.Documento.fotograma = index }
                        }
                    }

                    // ── el tirador de retimar ────────────────────
                    //  Arrastrar aquí cambia los tics. El cursor lo dice, y el
                    //  ancho responde en vivo: la animación se está retimando
                    //  delante de ti, no en un diálogo.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: caja.top
                        anchors.bottom: caja.bottom
                        width: 5
                        color: tirador.pressed ? C.Tema.acento
                             : tirador.containsMouse ? C.Tema.acento2 : "transparent"
                        radius: 2

                        MouseArea {
                            id: tirador
                            anchors.fill: parent
                            anchors.margins: -2
                            hoverEnabled: true
                            cursorShape: Qt.SizeHorCursor
                            property real desde: 0
                            property int ticsDesde: 0
                            //  Un paso del historial por arrastre, no por cada
                            //  píxel que mueves. Retimar no se podía deshacer:
                            //  ponDuracion cambiaba el documento y nadie lo
                            //  apuntaba, así que un tirón sin querer se quedaba.
                            onPressed: (m) => {
                                desde = m.x; ticsDesde = fot.tics
                                S.Historial.abreEstructura()
                            }
                            onPositionChanged: (m) => {
                                if (!pressed) return
                                const d = Math.round((m.x - desde) / raiz.pxPorTic)
                                S.Documento.ponDuracion(index, Math.max(1, ticsDesde + d))
                            }
                            onReleased: {
                                if (fot.tics === ticsDesde) { S.Historial.olvidaEstructura(); return }
                                S.Historial.cierraEstructura("fotograma " + (index + 1)
                                                             + ": " + fot.tics + " tics")
                            }
                        }
                    }
                }
            }

            // añadir fotograma
            C.Boton {
                icono: C.Tema.i.mas
                width: raiz.anchoMin
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 34
                pista: "fotograma nuevo   Alt+N"
                visible: S.Documento.abierto
                onPulsado: S.Ordenes.ejecuta("fotogramaNuevo")
                onPulsadoDerecho: S.Ordenes.ejecuta("fotogramaCopia")
            }
        }

        // ── la regla de tics ─────────────────────────────────────
        Canvas {
            id: regla
            anchors.bottom: parent.bottom
            width: fila.width
            height: 9
            renderStrategy: Canvas.Cooperative
            visible: S.Documento.nFotogramas > 1

            onPaint: {
                const g = getContext("2d")
                g.clearRect(0, 0, width, height)
                g.strokeStyle = C.Tema.oscuro ? "rgba(226,232,234,0.28)" : "rgba(34,44,46,0.28)"
                g.fillStyle = g.strokeStyle
                g.lineWidth = 1
                g.font = "9px " + C.Tema.tipoMono
                let x = 0, t = 0
                for (let f = 0; f < S.Documento.nFotogramas; f++) {
                    const w = Math.max(raiz.anchoMin, S.Documento.duracion(f) * raiz.pxPorTic)
                    // una marca cada 30 tics: medio segundo
                    for (let k = 0; k < S.Documento.duracion(f); k++) {
                        if ((t + k) % 30 !== 0) continue
                        const px = x + k * raiz.pxPorTic
                        g.beginPath(); g.moveTo(px + 0.5, 0); g.lineTo(px + 0.5, 5); g.stroke()
                        g.fillText(((t + k) / 60).toFixed(1) + "s", px + 3, 9)
                    }
                    x += w + 3
                    t += S.Documento.duracion(f)
                }
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: S.Documento
                function onRevChanged() { regla.requestPaint() }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // la cola: cebolla, bucle y el total
    // ═══════════════════════════════════════════════════════════

    Row {
        id: cola
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        C.Boton {
            icono: C.Tema.i.cebolla
            activo: S.Ajustes.cebolla
            pista: "piel de cebolla — pasado en rojo, futuro en azul   C"
            implicitHeight: 26
            onPulsado: S.Ajustes.cebolla = !S.Ajustes.cebolla
        }
        C.Boton {
            texto: S.Animacion.modo === "ida" ? "→" : S.Animacion.modo === "vuelta" ? "←" : "⇄"
            activo: true
            relleno: 9
            implicitHeight: 26
            pista: "ida · vuelta · vaivén"
            onPulsado: S.Animacion.modo = S.Animacion.modo === "ida" ? "vaiven"
                     : S.Animacion.modo === "vaiven" ? "vuelta" : "ida"
        }
        //  Lo que dura, y se puede escribir encima.
        //
        //  Estaba aquí como número muerto, que es raro: es la cifra que más
        //  miras de la tira y la que quieres cambiar. Escribir un total nuevo
        //  estira o encoge TODOS los fotogramas en proporción, así que el
        //  reparto que ya habías afinado —el de impacto corto, el de
        //  recuperación largo— se conserva; sólo cambia el compás.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            C.Boton {
                anchors.verticalCenter: parent.verticalCenter
                texto: "−"
                width: 22; implicitHeight: 22
                tenue: !S.Documento.abierto
                //  Van con el número, no con la sensación: menos tics es menos
                //  tiempo, o sea más rápida. Al revés —«−» para ir más lento—
                //  el botón dice una cosa y la cifra de al lado la contraria.
                pista: "menos tics: la animación va más rápida   Alt+-"
                onPulsado: S.Ordenes.ejecuta("masRapida")
            }
            C.Boton {
                anchors.verticalCenter: parent.verticalCenter
                texto: "+"
                width: 22; implicitHeight: 22
                tenue: !S.Documento.abierto
                pista: "más tics: la animación va más lenta   Alt++"
                onPulsado: S.Ordenes.ejecuta("masLenta")
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                C.Campo {
                    width: 76
                    numero: true
                    minimo: 1; maximo: 99999
                    sufijo: "t"
                    valor: String(S.Documento.duracionTotal)
                    onCambiado: (v) => {
                        const n = parseInt(v)
                        if (!n || n === S.Documento.duracionTotal) return
                        S.Historial.abreEstructura()
                        S.Documento.duraEnTotal(n)
                        S.Historial.cierraEstructura("cambiar el ritmo")
                    }
                }
                Text {
                    text: (S.Documento.duracionTotal / 60).toFixed(2) + " s"
                    font.family: C.Tema.tipoMono
                    font.pixelSize: 10
                    color: C.Tema.tenue
                    horizontalAlignment: Text.AlignRight
                    width: 76
                }
            }
        }
    }
}

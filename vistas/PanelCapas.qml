//  Las capas.
//
//  De arriba abajo en pantalla, de abajo arriba en la composición: la lista se
//  enseña al revés que el array porque lo que está más cerca de ti se dibuja
//  encima, y verlo al revés es lo que confunde a todo el mundo.
//
//  Lo que va en la fila es lo que se toca a diario: verla, bloquearla y el
//  candado de alfa. La opacidad y el modo, debajo, porque se tocan una vez y
//  se quedan.

import QtQuick
import "../core" as C
import "../core/pixeles.js" as P
import "../servicios" as S

C.Hoja {
    id: raiz
    titulo: "capas"
    icono: C.Tema.i.capas

    Column {
        width: parent.width
        spacing: 3

        Repeater {
            model: S.Documento.rev, S.Documento.nCapas

            Rectangle {
                readonly property int idx: S.Documento.nCapas - 1 - index   // al revés
                readonly property var capa: S.Documento.capa(idx)
                readonly property bool actual: S.Documento.capaActiva === idx

                width: parent.width
                height: 26
                radius: 3
                color: actual ? C.Tema.acentoTenue : filaRaton.containsMouse ? C.Tema.alta : "transparent"
                border.width: actual ? 1 : 0
                border.color: C.Tema.acento

                MouseArea {
                    id: filaRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: S.Documento.capaActiva = idx
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    C.Boton {
                        width: 20; implicitHeight: 20
                        icono: capa && capa.visible ? C.Tema.i.ojo : C.Tema.i.ojoNo
                        tenue: capa ? !capa.visible : false
                        pista: "verla"
                        onPulsado: {
                            capa.visible = !capa.visible
                            S.Documento.cambia(); S.Documento.cambiaPixeles(null)
                        }
                    }
                    C.Boton {
                        width: 20; implicitHeight: 20
                        icono: capa && capa.bloqueada ? C.Tema.i.candado : C.Tema.i.candadoNo
                        tenue: capa ? !capa.bloqueada : true
                        pista: "bloquear la capa entera"
                        onPulsado: { capa.bloqueada = !capa.bloqueada; S.Documento.cambia() }
                    }
                    C.Boton {
                        width: 20; implicitHeight: 20
                        texto: "α"
                        activo: capa ? capa.alfaBloqueado : false
                        tenue: capa ? !capa.alfaBloqueado : true
                        pista: "bloquear lo transparente: pintar sólo donde ya hay algo"
                        onPulsado: { capa.alfaBloqueado = !capa.alfaBloqueado; S.Documento.cambia() }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 74
                    anchors.right: marcas.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: capa ? capa.nombre : ""
                    font.family: C.Tema.tipo
                    font.pixelSize: C.Tema.letra
                    color: capa && capa.tipo === "referencia" ? C.Tema.tenue
                         : actual ? C.Tema.acento : C.Tema.tinta
                    font.italic: capa ? capa.tipo === "referencia" : false
                    elide: Text.ElideRight
                }

                Row {
                    id: marcas
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        visible: capa ? capa.modo !== "normal" : false
                        text: capa ? capa.modo.substring(0, 3) : ""
                        font.family: C.Tema.tipoMono
                        font.pixelSize: 9
                        color: C.Tema.acento2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: capa ? capa.opacidad < 1 : false
                        text: capa ? Math.round(capa.opacidad * 100) : ""
                        font.family: C.Tema.tipoMono
                        font.pixelSize: 9
                        color: C.Tema.tenue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Item { width: 1; height: 3 }

        // ── lo de la capa activa ─────────────────────────────────
        C.Desliz {
            width: parent.width
            visible: S.Documento.abierto
            etiqueta: "opacidad"; anchoEtiqueta: 62
            minimo: 0; maximo: 1; paso: 0.01; decimales: 2
            valor: {
                S.Documento.rev
                const c = S.Documento.capa(S.Documento.capaActiva)
                return c ? c.opacidad : 1
            }
            onCambiado: (v) => {
                const c = S.Documento.capa(S.Documento.capaActiva)
                if (!c) return
                c.opacidad = v
                S.Documento.cambia(); S.Documento.cambiaPixeles(null)
            }
        }

        C.Opcion {
            width: parent.width
            visible: S.Documento.abierto
            etiqueta: "modo"; anchoEtiqueta: 62
            opciones: P.MODOS
            valor: {
                S.Documento.rev
                const c = S.Documento.capa(S.Documento.capaActiva)
                return c ? c.modo : "normal"
            }
            onCambiado: (v) => {
                const c = S.Documento.capa(S.Documento.capaActiva)
                if (!c) return
                c.modo = v
                S.Documento.cambia(); S.Documento.cambiaPixeles(null)
            }
        }

        Item { width: 1; height: 2 }

        Row {
            spacing: 2
            C.Boton { icono: C.Tema.i.mas; implicitHeight: 22; width: 26
                      pista: "capa nueva"; onPulsado: S.Ordenes.ejecuta("capaNueva") }
            C.Boton { icono: C.Tema.i.duplicar; implicitHeight: 22; width: 26
                      pista: "duplicar"; onPulsado: S.Ordenes.ejecuta("capaDuplicar") }
            C.Boton { icono: C.Tema.i.fusion; implicitHeight: 22; width: 26
                      pista: "fusionar con la de abajo"; tenue: S.Documento.capaActiva === 0
                      onPulsado: S.Ordenes.ejecuta("capaFusionar") }
            C.Boton { icono: C.Tema.i.referencia; implicitHeight: 22; width: 26
                      pista: "capa de referencia, para calcar"
                      onPulsado: S.Ordenes.ejecuta("capaReferencia") }
            C.Boton { icono: C.Tema.i.basura; implicitHeight: 22; width: 26; peligro: true
                      pista: "borrar"; tenue: S.Documento.nCapas <= 1
                      onPulsado: S.Ordenes.ejecuta("capaBorrar") }
        }
    }
}

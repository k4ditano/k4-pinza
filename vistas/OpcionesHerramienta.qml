//  Las opciones de la herramienta activa.
//
//  Arriba y en horizontal, no metidas en el carril: lo que cambia al elegir
//  herramienta tiene que estar donde se lea de un vistazo, y un carril
//  vertical de 44 px no da para eso.

import QtQuick
import "../core" as C
import "../servicios" as S

Rectangle {
    id: raiz

    color: C.Tema.superficie
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: C.Tema.borde
    }

    readonly property string h: S.Pinceles.herramienta
    readonly property bool esTrazo: h === "lapiz" || h === "goma" || h === "sombreado"
                                 || h === "difumina" || h === "mancha"
                                 || h === "aclara" || h === "quema"
    readonly property bool esRelleno: h === "cubo" || h === "varita" || h === "porColor"
                                   || h === "sustituye"
    readonly property bool esFormaCerrada: h === "rectangulo" || h === "elipse"

    //  Se desliza. Con la ventana estrecha, las últimas opciones de una
    //  herramienta se salían por la derecha y no había forma de llegar a
    //  ellas: quedaban invisibles y sin manera de alcanzarlas.
    Flickable {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        contentWidth: opcs.width + 10
        flickableDirection: Flickable.HorizontalFlick
        clip: true

    Row {
        id: opcs
        height: parent.height
        spacing: 14

        // el nombre de lo que estás usando
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            text: S.Herramientas.nombre(raiz.h)
            font.family: C.Tema.tipo
            font.pixelSize: C.Tema.letra
            font.weight: Font.DemiBold
            color: C.Tema.acento
            elide: Text.ElideRight
        }

        C.Desliz {
            visible: raiz.esTrazo
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            etiqueta: "tamaño"; anchoEtiqueta: 46
            minimo: 1; maximo: 32; paso: 1; decimales: 0
            valor: S.Pinceles.tamaño
            onCambiado: (v) => S.Pinceles.tamaño = Math.round(v)
        }
        C.Boton {
            visible: raiz.esTrazo
            anchors.verticalCenter: parent.verticalCenter
            texto: "punta cuadrada"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.puntaCuadrada
            onPulsado: S.Pinceles.puntaCuadrada = !S.Pinceles.puntaCuadrada
        }
        C.Boton {
            visible: S.Pinceles.herramienta === "lapiz"
            anchors.verticalCenter: parent.verticalCenter
            texto: "trazo perfecto"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.trazoPerfecto
            pista: "quita las esquinas dobles del trazo a mano alzada"
            onPulsado: S.Pinceles.trazoPerfecto = !S.Pinceles.trazoPerfecto
        }
        C.Boton {
            visible: S.Pinceles.pincelPersonal !== null
            anchors.verticalCenter: parent.verticalCenter
            texto: "pincel propio " + (S.Pinceles.pincelPersonal
                   ? S.Pinceles.pincelPersonal.w + "×" + S.Pinceles.pincelPersonal.h : "")
            relleno: 7; implicitHeight: 22; activo: true
            pista: "clic para volver al pincel normal"
            onPulsado: S.Pinceles.pincelPersonal = null
        }

        C.Opcion {
            visible: raiz.esTrazo || raiz.esFormaCerrada
            anchors.verticalCenter: parent.verticalCenter
            width: 250
            etiqueta: "trama"; anchoEtiqueta: 40
            opciones: [{ id: "solido", titulo: "sólida" }, { id: "50", titulo: "50%" },
                       { id: "25", titulo: "25%" }, { id: "75", titulo: "75%" }]
            valor: S.Pinceles.trama
            onCambiado: (v) => S.Pinceles.trama = v
        }

        C.Desliz {
            visible: raiz.esRelleno
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            etiqueta: "tolerancia"; anchoEtiqueta: 62
            minimo: 0; maximo: 200; paso: 1; decimales: 0
            valor: S.Pinceles.tolerancia
            onCambiado: (v) => S.Pinceles.tolerancia = v
        }
        C.Boton {
            visible: S.Pinceles.herramienta === "cubo" || S.Pinceles.herramienta === "varita"
            anchors.verticalCenter: parent.verticalCenter
            texto: "contiguo"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.contiguo
            onPulsado: S.Pinceles.contiguo = !S.Pinceles.contiguo
        }
        C.Boton {
            visible: S.Pinceles.herramienta === "cubo" || S.Pinceles.herramienta === "varita"
            anchors.verticalCenter: parent.verticalCenter
            texto: "8 vecinos"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.ochoVecinos
            pista: "también por las diagonales"
            onPulsado: S.Pinceles.ochoVecinos = !S.Pinceles.ochoVecinos
        }

        //  Recolorear casi nunca es cosa de una celda: cambiar el color de un
        //  bicho es cambiarlo en sus ocho caras y en todos sus fotogramas.
        //  Los títulos, cortos: la barra va apretada y el detalle cabe en el
        //  rótulo que sale al pasar por encima.
        C.Opcion {
            visible: S.Pinceles.herramienta === "sustituye"
            anchors.verticalCenter: parent.verticalCenter
            etiqueta: "cambia en"; anchoEtiqueta: 62
            opciones: [{ id: "celda", titulo: "esta celda" },
                       { id: "fotogramas", titulo: "los fotogramas" },
                       { id: "todo", titulo: "y las 8 caras" }]
            valor: S.Pinceles.alcanceColor
            onCambiado: (v) => S.Pinceles.alcanceColor = v
        }
        C.Boton {
            visible: S.Pinceles.herramienta === "sustituye" && S.Pinceles.alcanceColor !== "celda"
            anchors.verticalCenter: parent.verticalCenter
            texto: "y capas"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.todasLasCapas
            pista: "si no, sólo la capa en la que estás"
            onPulsado: S.Pinceles.todasLasCapas = !S.Pinceles.todasLasCapas
        }

        C.Boton {
            visible: raiz.esFormaCerrada
            anchors.verticalCenter: parent.verticalCenter
            texto: "relleno"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.relleno
            onPulsado: S.Pinceles.relleno = !S.Pinceles.relleno
        }
        C.Boton {
            visible: raiz.esFormaCerrada
            anchors.verticalCenter: parent.verticalCenter
            texto: "desde el centro"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.desdeElCentro
            onPulsado: S.Pinceles.desdeElCentro = !S.Pinceles.desdeElCentro
        }

        C.Opcion {
            visible: S.Pinceles.herramienta === "degradado"
            anchors.verticalCenter: parent.verticalCenter
            etiqueta: "tipo"; anchoEtiqueta: 32
            opciones: [{ id: "lineal", titulo: "lineal" }, { id: "radial", titulo: "radial" }]
            valor: S.Pinceles.tipoDegradado
            onCambiado: (v) => S.Pinceles.tipoDegradado = v
        }
        C.Boton {
            visible: S.Pinceles.herramienta === "degradado"
            anchors.verticalCenter: parent.verticalCenter
            texto: "tramado"; relleno: 7; implicitHeight: 22
            activo: S.Pinceles.degradadoTramado
            pista: "sin tramar, un degradado mete cientos de colores nuevos"
            onPulsado: S.Pinceles.degradadoTramado = !S.Pinceles.degradadoTramado
        }

        C.Desliz {
            visible: S.Pinceles.herramienta === "difumina" || S.Pinceles.herramienta === "mancha"
                  || S.Pinceles.herramienta === "aclara" || S.Pinceles.herramienta === "quema"
            anchors.verticalCenter: parent.verticalCenter
            width: 140
            etiqueta: "fuerza"; anchoEtiqueta: 44
            minimo: 0.05; maximo: 1; paso: 0.05; decimales: 2
            valor: S.Pinceles.fuerza
            onCambiado: (v) => S.Pinceles.fuerza = v
        }

        C.Opcion {
            visible: S.Pinceles.herramienta === "sombreado"
            anchors.verticalCenter: parent.verticalCenter
            etiqueta: "paso"; anchoEtiqueta: 34
            opciones: [{ id: "1", titulo: "aclarar" }, { id: "-1", titulo: "oscurecer" }]
            valor: String(S.Pinceles.pasoSombreado)
            onCambiado: (v) => S.Pinceles.pasoSombreado = parseInt(v)
        }

        C.Opcion {
            visible: S.Pinceles.esSeleccion
            anchors.verticalCenter: parent.verticalCenter
            etiqueta: "modo"; anchoEtiqueta: 36
            opciones: [{ id: "nueva", titulo: "nueva" }, { id: "sumar", titulo: "sumar" },
                       { id: "restar", titulo: "restar" }, { id: "intersecar", titulo: "cortar" }]
            valor: S.Pinceles.modoSeleccion
            onCambiado: (v) => S.Pinceles.modoSeleccion = v
        }
    }
    }
}

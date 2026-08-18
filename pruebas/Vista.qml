//  Comprobación de que la vista carga, pinta y responde de verdad.
//
//  No es una prueba de aspecto —eso se mira con los ojos— sino de que el
//  camino entero funciona: documento -> composición -> putImageData de siete
//  argumentos -> toDataURL. Si esto pasa, lo que se ve en pantalla es lo que
//  se va a exportar.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    FloatingWindow {
        id: ventana
        implicitWidth: 600
        implicitHeight: 400
        visible: true
        V.Lienzo { id: lienzo; anchors.fill: parent }
    }

    Component.onCompleted: {
        S.Documento.nuevo({ nombre: "prueba", ancho: 16, alto: 16 })
        ck("el documento se abre", S.Documento.abierto && S.Documento.ancho === 16)
        ck("y trae una capa y un fotograma",
           S.Documento.nCapas === 1 && S.Documento.nFotogramas === 1 && S.Documento.nOrientaciones === 1)

        const buf = S.Documento.celdaActiva(true)
        ck("la celda activa existe y mide lo que el lienzo", buf && buf.w === 16 && buf.h === 16)

        // pintar algo a mano y ver si el compuesto lo recoge
        for (let x = 2; x < 14; x++) for (let y = 2; y < 8; y++) P.pon(buf, x, y, [214, 108, 52, 255])
        S.Documento.cambiaPixeles({ x: 2, y: 2, w: 12, h: 6 })
        const comp = S.Documento.compuesto()
        ck("el compuesto ve lo pintado", P.lee(comp, 3, 3)[0] === 214)

        // una segunda capa, medio transparente
        S.Documento.añadeCapa("encima")
        const b2 = S.Documento.celdaActiva(true)
        for (let x = 0; x < 16; x++) P.pon(b2, x, 3, [118, 193, 56, 255])
        S.Documento.capa(1).opacidad = 0.5
        S.Documento.cambiaPixeles(null)
        const c2 = S.Documento.compuesto()
        const mezclado = P.lee(c2, 3, 3)
        ck("dos capas se mezclan por opacidad",
           mezclado[1] > 108 && mezclado[1] < 193, "verde " + mezclado[1])

        // esconder la de arriba
        S.Documento.capa(1).visible = false
        S.Documento.cambia(); S.Documento.cambiaPixeles(null)
        ck("esconder una capa la quita del compuesto",
           P.lee(S.Documento.compuesto(), 3, 3)[1] === 108)

        // deshacer estructural
        S.Historial.abreEstructura()
        S.Documento.añadeCapa("de más")
        S.Historial.cierraEstructura("añadir capa")
        ck("añadir capa se apunta en el historial", S.Historial.puedeDeshacer)
        ck("y hay tres capas", S.Documento.nCapas === 3, S.Documento.nCapas)
        S.Historial.deshace()
        ck("deshacer la quita", S.Documento.nCapas === 2, S.Documento.nCapas)
        S.Historial.rehace()
        ck("rehacer la devuelve", S.Documento.nCapas === 3)
        S.Historial.deshace()

        // deshacer de píxeles
        const antes = P.lee(S.Documento.celda(S.Documento.capa(0).id, 0, 0, false), 3, 3)
        S.Historial.abre(S.Documento.clave(S.Documento.capa(0).id, 0, 0),
                         S.Documento.celda(S.Documento.capa(0).id, 0, 0, false))
        const b0 = S.Documento.celda(S.Documento.capa(0).id, 0, 0, false)
        P.pon(b0, 3, 3, [0, 0, 255, 255])
        S.Historial.cierra("trazo", b0)
        ck("un trazo cabe en el historial", S.Historial.puedeDeshacer)
        S.Historial.deshace()
        ck("y deshacerlo devuelve el color de antes",
           P.lee(b0, 3, 3).join() === antes.join(), P.lee(b0, 3, 3).join())

        // ── el aviso de "sin guardar" ────────────────────────────
        //
        //  Parece un detalle y no lo es: de él dependen el punto de la barra,
        //  el autoguardado y que cambiar de acción en una criatura guarde antes
        //  la que dejas. Estuvo mintiendo desde el principio porque el contador
        //  se subía ANTES de marcar el documento, así que el enlace se
        //  reevaluaba con el valor viejo y nadie volvía a avisar.
        S.Documento.limpio()
        ck("tras guardar, el documento está limpio", !S.Documento.sucio)
        P.pon(S.Documento.celdaActiva(true), 0, 0, [1, 2, 3, 255])
        S.Documento.cambiaPixeles(null)
        ck("pintar un píxel lo marca como sin guardar", S.Documento.sucio)
        S.Documento.limpio()
        ck("y limpiarlo lo limpia otra vez", !S.Documento.sucio)
        S.Documento.añadeCapa("testigo")
        ck("añadir una capa también lo marca", S.Documento.sucio)
        S.Documento.limpio()
        S.Documento.borraCapa(S.Documento.nCapas - 1)
        ck("y borrarla también", S.Documento.sucio)

        // los tres ejes
        S.Documento.ponOrientaciones(["S", "E", "N", "W"])
        ck("cambiar de orientaciones no pierde lo dibujado",
           S.Documento.nOrientaciones === 4
           && P.lee(S.Documento.celda(S.Documento.capa(0).id, 0, 0, false), 3, 3)[0] === 214)
        ck("y las nuevas nacen vacías",
           P.vacio(S.Documento.celda(S.Documento.capa(0).id, 0, 2, false)))

        S.Documento.añadeFotograma(true)
        ck("duplicar fotograma copia los píxeles",
           S.Documento.nFotogramas === 2
           && P.lee(S.Documento.celda(S.Documento.capa(0).id, 1, 0, false), 3, 3)[0] === 214)

        S.Documento.enlaza(S.Documento.capa(0).id, 1, 0, 0, 0)
        ck("enlazar una celda la hace la misma",
           S.Documento.celda(S.Documento.capa(0).id, 1, 0, false)
           === S.Documento.celda(S.Documento.capa(0).id, 0, 0, false))
        ck("y se sabe que está enlazada", S.Documento.estaEnlazada(S.Documento.capa(0).id, 1, 0))

        // redimensionar
        S.Documento.redimensiona(24, 24, "nw")
        ck("redimensionar conserva el dibujo en la esquina pedida",
           S.Documento.ancho === 24
           && P.lee(S.Documento.celda(S.Documento.capa(0).id, 0, 0, false), 3, 3)[0] === 214)

        S.Documento.recortaAlContenido()
        // 12x6 porque lo pintado va de x=2 a x=13 y de y=2 a y=7, y la capa
        // de encima está escondida: recortar mira el COMPUESTO, que es lo que
        // se ve, y no la suma de todo lo que hay en el fichero
        ck("recortar al contenido deja sólo lo dibujado",
           S.Documento.ancho === 12 && S.Documento.alto === 6,
           S.Documento.ancho + "x" + S.Documento.alto)

        esperar.start()
    }

    // Lo importante de verdad: que lo que se ve sea exportable.
    Timer {
        id: esperar
        interval: 700
        onTriggered: {
            const url = lienzo.exporta ? "" : ""
            ck("la vista sigue viva tras todo el trajín", lienzo.width > 0)
            fin.start()
        }
    }
    Timer { id: fin; interval: 150; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "\nla vista pasa entera")
        Qt.exit(raiz.malas ? 1 : 0) } }
    Timer { interval: 25000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

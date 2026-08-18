//  Un PNG suelto que se convierte en criatura.
//
//  El camino que faltaba, y era el natural: abres un dibujo, decides que va a
//  ser un bicho, y le vas poniendo acciones con los nombres y las caras que tú
//  digas. Antes había que empezar por la criatura —eligiendo un pack que
//  trajera plantilla— y sólo después dibujar, que es pedirle a alguien que
//  decida el nombre de las ocho animaciones antes de haber hecho ninguna. Y
//  sin pack, no había acciones: las sacaba del contrato y de nada más.
//
//  Aparte, abrir una imagen sólo se podía como CAPA del documento que
//  tuvieras delante: con una criatura abierta, tu PNG aterrizaba dentro de la
//  criatura.

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S
import "../vistas" as V

ShellRoot {
    id: raiz
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    readonly property string base: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pinza-suelta"
    readonly property string png: base + "/bicho.png"

    FloatingWindow {
        implicitWidth: 300; implicitHeight: 200; visible: true
        V.Exportador { id: ex }
        Component.onCompleted: { S.Proyecto.exportador = ex; S.Especie.exportador = ex }
    }
    Connections {
        target: S.Packs
        function onCargadosCambiaron() { arranca.start() }
    }
    Timer { id: arranca; interval: 250; onTriggered: raiz.prepara() }
    Connections {
        target: S.Especie
        function onFalla(q, m) { console.log("   (falla " + q + ": " + m + ")") }
    }
    Connections {
        target: S.Proyecto
        function onFalla(q, m) { console.log("   (falla proyecto " + q + ": " + m + ")") }
    }

    //  Un PNG en el disco, escrito sin pasar por el documento.
    function prepara() {
        S.Forja.creaCarpeta(base, () => {
            S.Forja.pide("comprobar", { raiz: base, guiones: [
                ["sh", "-c", "rm -rf '" + base + "'/*.especie '" + base + "'/*.png"]
            ] }, () => {
                //  A propósito el pack genérico: la gracia es que esto funcione
                //  sin plantilla de criatura.
                S.Packs.elige("generico")
                S.Ajustes.taller = base
                const b = P.nuevo(20, 28)
                for (let y = 3; y < 25; y++) for (let x = 3; x < 17; x++)
                    P.pon(b, x, y, [210, 90, 60, 255])
                ex.escribe(raiz.png, b, () => paso1())
            })
        })
    }

    // ── 1 · abrir la imagen ─────────────────────────────────────
    function paso1() {
        ck("el pack genérico no trae plantilla de criatura",
           S.Especie.plantilla === null)
        S.Proyecto.abreImagen(raiz.png, (bien) => {
            ck("se abre un PNG suelto", bien && S.Documento.abierto)
            ck("con el tamaño de la imagen", S.Documento.ancho === 20 && S.Documento.alto === 28,
               S.Documento.ancho + "x" + S.Documento.alto)
            ck("y el dibujo dentro", !P.vacio(S.Documento.compuesto()))
            ck("se llama como el fichero", S.Documento.nombre === "bicho", S.Documento.nombre)
            ck("y recuerda de dónde salió", S.Documento.imagen === raiz.png)
            ck("no queda como sin guardar recién abierto", !S.Documento.sucio)
            paso2()
        })
    }

    // ── 2 · guardar devuelve el PNG a su sitio ──────────────────
    function paso2() {
        const c = S.Documento.celdaActiva(true)
        P.pon(c, 1, 1, [20, 220, 120, 255])
        S.Documento.cambiaPixeles(null)
        ck("tocar la imagen la deja sin guardar", S.Documento.sucio)
        S.Proyecto.guardaImagen((bien) => {
            ck("guardar la devuelve a su fichero", bien && !S.Documento.sucio)
            ex.dePng(raiz.png, (b) => {
                const p = b ? P.lee(b, 1, 1) : null
                ck("y el cambio está en el PNG del disco",
                   !!p && P.distancia(p, [20, 220, 120, 255]) < 6, p ? p.join(",") : "no se lee")
                paso2b()
            })
        })
    }

    // ── 2b · guardar como imagen, con su nombre ─────────────────
    //  «Guardar como» era siempre un selector de CARPETA y siempre escribía un
    //  proyecto. Para una imagen suelta eso no es guardar como: es convertirla
    //  en otra cosa.
    function paso2b() {
        const otra = raiz.base + "/copia.png"
        S.Proyecto.guardaImagenEn(otra, (bien) => {
            ck("una imagen se guarda con el nombre que le pongas", bien)
            ck("y el documento pasa a apuntar al fichero nuevo",
               S.Documento.imagen === otra, S.Documento.imagen)
            ex.dePng(otra, (b) => {
                ck("el fichero nuevo tiene el dibujo",
                   !!b && !P.vacio(b) && b.w === 20 && b.h === 28,
                   b ? b.w + "x" + b.h : "no se lee")
                //  Y el original no se toca: seguir escribiendo encima de él
                //  después de un «guardar como» es el fallo clásico.
                ex.dePng(raiz.png, (o) => {
                    ck("y el original sigue donde estaba", !!o && !P.vacio(o))
                    paso2c()
                })
            })
        })
    }

    //  La forja decide el formato por la extensión del destino: un temporal
    //  siempre .png dejaba un PNG con nombre de JPEG, que no falla al escribir
    //  y falla al abrirlo en otro programa.
    function paso2c() {
        const jpg = raiz.base + "/copia.jpg"
        S.Proyecto.guardaImagenEn(jpg, () => {
            S.Forja.pide("pngInfo", { ruta: jpg }, (r) => {
                ck("un destino .jpg no sale siendo un PNG con nombre falso",
                   !r.bien, r.bien ? "salió PNG de " + r.ancho + "x" + r.alto : "no es PNG, bien")
                //  y se vuelve a apuntar al PNG para lo que viene
                S.Documento.ponImagen(raiz.png)
                paso3()
            })
        })
    }

    // ── 3 · hacer una criatura con esto ─────────────────────────
    function paso3() {
        S.Especie.desdeDocumento({ nombre: "Suelto", accion: "Quieto", carpeta: raiz.base }, (bien) => {
            ck("la imagen se convierte en criatura", bien && S.Especie.abierta)
            ck("con la acción que le pusiste", S.Especie.acciones.length === 1
               && S.Especie.acciones[0].id === "Quieto",
               S.Especie.acciones.map((a) => a.id).join(" "))
            ck("y sin pack que la mande", S.Especie.plantilla === null)
            ck("lo dibujado es esa acción, no un lienzo nuevo",
               !P.vacio(S.Documento.compuesto()))
            paso4()
        })
    }

    // ── 4 · acciones a mano, con sus caras ──────────────────────
    function paso4() {
        S.Especie.añadeAccion("Andar", { ancho: 20, alto: 28, fotogramas: 4, orientaciones: 8 }, () => {
            S.Especie.añadeAccion("Icono", { ancho: 20, alto: 28, fotogramas: 1, orientaciones: 1 }, () => {
                ck("se le añaden acciones con nombre propio", S.Especie.acciones.length === 3,
                   S.Especie.acciones.map((a) => a.id).join(" "))
                const andar = S.Especie.d.acciones.Andar
                const icono = S.Especie.d.acciones.Icono
                ck("y cada una con las caras que dijiste",
                   andar.orientaciones === 8 && icono.orientaciones === 1,
                   "Andar " + andar.orientaciones + " · Icono " + icono.orientaciones)
                ck("dos acciones con el mismo nombre no cuelan",
                   (S.Especie.añadeAccion("Andar", {}, null), S.Especie.acciones.length === 3))
                paso5()
            })
        })
    }

    // ── 5 · el documento de una acción respeta sus caras ────────
    function paso5() {
        S.Especie.editaAccion("Andar", () => {
            ck("abrir una acción de ocho caras da ocho", S.Documento.nOrientaciones === 8,
               S.Documento.nOrientaciones + " caras")
            S.Especie.editaAccion("Icono", () => {
                ck("y una de una, una", S.Documento.nOrientaciones === 1,
                   S.Documento.nOrientaciones + " cara")
                paso6()
            })
        })
    }

    // ── 6 · la ayuda con las direcciones ────────────────────────
    function paso6() {
        S.Especie.editaAccion("Andar", () => {
            const c = S.Documento.celdaActiva(true)
            for (let y = 4; y < 24; y++) for (let x = 4; x < 16; x++)
                P.pon(c, x, y, [60, 120, 230, 255])
            S.Documento.cambiaPixeles(null)
            ck("siete caras en blanco antes de repartir", S.Ordenes.carasVacias() === 7,
               S.Ordenes.carasVacias() + "")
            S.Ordenes.repartirCara()
            ck("repartir las llena todas", S.Ordenes.carasVacias() === 0)

            const capa = S.Documento.capa(S.Documento.capaActiva)
            let llenas = 0
            for (let dr = 0; dr < 8; dr++) {
                const b = S.Documento.celda(capa.id, 0, dr, false)
                if (b && !P.vacio(b)) llenas++
            }
            ck("las ocho tienen dibujo", llenas === 8, llenas + " de 8")
            ck("y es un solo paso del historial que se deshace de golpe",
               S.Historial.puedeDeshacer)
            S.Historial.deshace()
            ck("deshacer devuelve las siete en blanco", S.Ordenes.carasVacias() === 7,
               S.Ordenes.carasVacias() + "")

            //  Y el espejo sin contrato: el pack genérico no declara parejas.
            S.Documento.orientacion = S.Documento.etiquetasOrientacion
                                      ? 2 : 2   // Right, en el orden de PMD
            ck("el espejo funciona sin pack que declare las parejas",
               S.Ordenes.parejaEspejo() >= 0, "pareja " + S.Ordenes.parejaEspejo())
            paso7()
        })
    }

    // ── 7 · cerrar cierra TODO ──────────────────────────────────
    //  Soltaba el documento y se dejaba la criatura puesta: te quedabas
    //  mirando un lienzo vacío con el panel de acciones al lado diciendo que
    //  estabas dibujando un bicho, y lo siguiente que hicieras trabajaba sobre
    //  una criatura que ya habías cerrado.
    function paso7() {
        ck("antes de cerrar hay documento y criatura",
           S.Documento.abierto && S.Especie.abierta)
        S.Ordenes.ejecuta("cerrar")
        cierre.start()
    }
    Timer { id: cierre; interval: 1200; onTriggered: {
        raiz.ck("cerrar suelta el documento", !S.Documento.abierto)
        raiz.ck("y también la criatura", !S.Especie.abierta)
        raiz.ck("así que no quedan acciones a la vista", S.Especie.acciones.length === 0,
                S.Especie.acciones.length + "")
        raiz.ck("y el historial queda vacío", S.Historial.pasos === 0,
                S.Historial.pasos + "")
        fin.start()
    } }

    Timer { id: fin; interval: 250; onTriggered: {
        console.log(raiz.malas ? "\n" + raiz.malas + " FALLOS" : "")
        Qt.exit(raiz.malas ? 1 : 0)
    } }
    Timer { interval: 90000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

import QtQuick
import Quickshell
import "../core/pixeles.js" as P
import "../servicios" as S

ShellRoot {
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    Component.onCompleted: {
        ck("hay órdenes de sobra", S.Ordenes.lista.length > 50, S.Ordenes.lista.length + " órdenes")

        // ninguna repetida: si dos comparten id, una es inalcanzable
        const vistos = {}
        let repes = []
        for (let i = 0; i < S.Ordenes.lista.length; i++) {
            const id = S.Ordenes.lista[i].id
            if (vistos[id]) repes.push(id)
            vistos[id] = 1
        }
        ck("ningún id repetido", repes.length === 0, repes.join(" "))

        // toda orden tiene título, grupo y algo que hacer
        let cojas = []
        for (let i = 0; i < S.Ordenes.lista.length; i++) {
            const o = S.Ordenes.lista[i]
            if (!o.titulo || !o.grupo || typeof o.hacer !== "function") cojas.push(o.id)
        }
        ck("todas tienen título, grupo y acción", cojas.length === 0, cojas.join(" "))

        // sin documento, casi nada está disponible
        const sinDoc = S.Ordenes.lista.filter((o) => S.Ordenes.disponible(o)).length
        ck("sin documento abierto se ofrece poco", sinDoc < S.Ordenes.lista.length,
           sinDoc + " de " + S.Ordenes.lista.length)

        S.Documento.nuevo({ nombre: "prueba", ancho: 16, alto: 16 })
        const conDoc = S.Ordenes.lista.filter((o) => S.Ordenes.disponible(o)).length
        ck("con documento se ofrece mucho más", conDoc > sinDoc, conDoc + " de " + S.Ordenes.lista.length)

        // buscar por trozos sueltos
        ck("buscar 'vol h' encuentra voltear en horizontal",
           S.Ordenes.busca("vol h").length > 0 && S.Ordenes.busca("vol h")[0].id === "voltearH",
           S.Ordenes.busca("vol h").map((o) => o.id).join(" "))
        ck("buscar por grupo también vale", S.Ordenes.busca("capas").length >= 3,
           S.Ordenes.busca("capas").map((o) => o.id).join(" "))
        ck("buscar algo que no existe no devuelve nada", S.Ordenes.busca("zzzz").length === 0)

        // ejecutar de verdad
        const buf = S.Documento.celdaActiva(true)
        P.pon(buf, 1, 1, [214, 108, 52, 255])
        S.Documento.cambiaPixeles(null)
        S.Ordenes.ejecuta("voltearH")
        ck("voltear en horizontal mueve el píxel", P.lee(S.Documento.celdaActiva(false), 14, 1)[0] === 214)
        ck("y se puede deshacer", S.Historial.puedeDeshacer)
        S.Historial.deshace()
        ck("deshacerlo lo devuelve", P.lee(S.Documento.celdaActiva(false), 1, 1)[0] === 214)

        S.Ordenes.ejecuta("selTodo")
        ck("seleccionar todo selecciona", S.Seleccion.activa)
        S.Ordenes.ejecuta("copiar")
        ck("copiar llena el portapapeles", S.Ordenes.portapapeles !== null)
        S.Ordenes.ejecuta("selNada")
        ck("quitar la selección la quita", !S.Seleccion.activa)

        S.Ordenes.ejecuta("capaNueva")
        ck("capa nueva añade una", S.Documento.nCapas === 2)
        S.Ordenes.ejecuta("capaBorrar")
        ck("y borrarla la quita", S.Documento.nCapas === 1)

        // el espejo de orientaciones
        S.Documento.nuevo({ nombre: "mueble", ancho: 16, alto: 16,
                            orientaciones: ["S", "E", "N", "W"],
                            contrato: { espejo: { "E": "W" } } })
        const c = S.Documento.capa(0)
        const este = S.Documento.celda(c.id, 0, 1, true)
        P.pon(este, 2, 5, [214, 108, 52, 255])
        S.Documento.orientacion = 3       // el oeste
        ck("el oeste sabe que su pareja es el este", S.Ordenes.parejaEspejo() === 1,
           S.Ordenes.parejaEspejo())
        S.Ordenes.ejecuta("espejoOrientacion")
        ck("y se genera volteado", P.lee(S.Documento.celda(c.id, 0, 3, false), 13, 5)[0] === 214)
        S.Documento.orientacion = 0
        ck("una orientación sin pareja no ofrece espejo", S.Ordenes.parejaEspejo() === -1)

        console.log(malas ? "\n" + malas + " FALLOS" : "\nlas órdenes pasan enteras")
        fin.start()
    }
    Timer { id: fin; interval: 150; onTriggered: Qt.exit(malas ? 1 : 0) }
    Timer { interval: 20000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

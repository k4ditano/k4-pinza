import QtQuick
import Quickshell
import "../servicios" as S

ShellRoot {
    property int malas: 0
    function ck(q, b, d) { if (!b) malas++; console.log((b ? " ok  " : "FALLO") + "  " + q + (d !== undefined ? "   ── " + d : "")) }

    Component.onCompleted: {
        ck("Documento carga", S.Documento !== null)
        ck("Historial carga", S.Historial !== null)
        ck("Seleccion carga", S.Seleccion !== null)
        ck("Ajustes carga", S.Ajustes !== null)
        ck("Pinceles carga", S.Pinceles !== null)
        ck("Paleta carga con rampas de arranque", S.Paleta.rampas.length > 0, S.Paleta.rampas.length + " rampas")
        ck("Animacion carga", S.Animacion !== null)
        ck("Forja carga", S.Forja !== null)
        ck("Packs carga", S.Packs !== null)
    }

    Connections {
        target: S.Packs
        function onCargadosCambiaron() {
            ck("los packs llegan de la forja", S.Packs.lista.length >= 2,
               S.Packs.lista.map((p) => p.id).join(" "))
            ck("el genérico es el de por defecto", S.Packs.activoId === "generico")
            ck("el genérico no impone guía de color", S.Packs.guia === null)
            const c = S.Packs.contrato("libre")
            ck("el contrato libre existe y deja elegir el tamaño", c !== null && c.tamañoLibre === true)
            S.Packs.elige("crabh")
            //  Por nombre y no por cuenta: contar es frágil, y además lo que
            //  importa es que estén ESTOS, no cuántos hay.
            const hay = S.Packs.contratos.map((x) => x.id)
            const faltan = ["item", "objeto", "vfx", "ataque", "pmd", "dtef"]
                           .filter((x) => hay.indexOf(x) < 0)
            ck("crabh trae sus perfiles", faltan.length === 0,
               faltan.length ? "faltan " + faltan.join(" ") : hay.join(" "))
            ck("crabh trae guía, y es informativa",
               S.Packs.guia !== null && S.Packs.guia.modo === "informativo")
            ck("y trae la paleta de la casa", S.Paleta.rampas.length === 19, S.Paleta.rampas.length + " rampas")
            const pmd = S.Packs.contrato("pmd")
            ck("el perfil de criatura tiene las ocho orientaciones en su orden",
               pmd.orientaciones.length === 8 && pmd.orientaciones[0].id === "Down"
               && pmd.orientaciones[1].id === "DownRight" && pmd.orientaciones[7].id === "DownLeft")
            const doc = S.Packs.paraDocumento(pmd, { nombre: "prueba" })
            ck("y se convierte en documento con esas etiquetas",
               doc.orientaciones.join(",") === "Down,DownRight,Right,UpRight,Up,UpLeft,Left,DownLeft")
            S.Packs.elige("generico")
            fin.start()
        }
    }
    Timer { id: fin; interval: 200; onTriggered: { console.log(malas ? "\n" + malas + " FALLOS" : "\nhumo limpio"); Qt.exit(malas ? 1 : 0) } }
    Timer { interval: 15000; running: true; onTriggered: { console.log("AGOTADO"); Qt.exit(1) } }
}

#!/usr/bin/env bash
#
#  Instala K4 Pinza en el sistema, sin copiar nada.
#
#      ./instalar.sh            instalar o actualizar
#      ./instalar.sh --quitar   deshacerlo
#
#  El programa se llama K4 Pinza; el comando, la carpeta de ajustes y la
#  extensión de los ficheros siguen siendo `pinza` a secas, que es lo que se
#  teclea y lo que ya está escrito en el disco de quien lo tenga puesto.
#
#  Lo que se instala son ENLACES y lanzadores: el código se queda donde está,
#  así que seguir desarrollando aquí es seguir usando lo instalado, sin volver a
#  instalar nada. Todo va al directorio del usuario — nada de sudo, nada fuera
#  de $HOME.
#
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")" && pwd)"
BIN="${HOME}/.local/bin"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATOS="${XDG_DATA_HOME:-$HOME/.local/share}"
LANZADORES="${DATOS}/applications"
ICONOS="${DATOS}/icons/hicolor"
QSDIR="${CONFIG}/quickshell"

verde()  { printf '\033[32m%s\033[0m\n' "$*"; }
gris()   { printf '\033[2m%s\033[0m\n' "$*"; }
rojo()   { printf '\033[31m%s\033[0m\n' "$*"; }

# ── quitar ───────────────────────────────────────────────────────
if [ "${1:-}" = "--quitar" ]; then
    rm -f  "${BIN}/pinza"
    rm -f  "${LANZADORES}/pinza.desktop"
    rm -f  "${ICONOS}"/*/apps/pinza.png
    [ -L "${QSDIR}/pinza" ] && rm -f "${QSDIR}/pinza"
    command -v update-desktop-database >/dev/null && \
        update-desktop-database "${LANZADORES}" 2>/dev/null || true
    command -v gtk-update-icon-cache >/dev/null && \
        gtk-update-icon-cache -qtf "${ICONOS}" 2>/dev/null || true
    verde "K4 Pinza desinstalada. Tus proyectos, tus packs y tus guiones siguen donde estaban."
    gris  "  ${CONFIG}/pinza/"
    exit 0
fi

# ── lo que hace falta ────────────────────────────────────────────
falta=0
for orden in qs python3; do
    command -v "$orden" >/dev/null || { rojo "falta $orden"; falta=1; }
done
python3 -c "import PIL" 2>/dev/null || { rojo "falta python-pillow"; falta=1; }
[ "$falta" -eq 0 ] || { rojo "instala eso primero y vuelve"; exit 1; }

#  Las fuentes se miran sobre una variable y no en una tubería: con `pipefail`,
#  `grep -q` cierra la tubería en cuanto encuentra algo, fc-list se lleva un
#  SIGPIPE y el conjunto cuenta como fallo — avisaba de que faltaban fuentes que
#  estaban instaladas.
FUENTES="$(fc-list 2>/dev/null || true)"
case "$FUENTES" in
    *"Adwaita Sans"*) ;;
    *) gris "aviso: no encuentro la fuente «Adwaita Sans»; la interfaz saldrá con otra" ;;
esac
case "$FUENTES" in
    *"MesloLGS Nerd Font"*) ;;
    *) gris "aviso: no encuentro «MesloLGS Nerd Font Mono»; los iconos saldrán como cuadros" ;;
esac

mkdir -p "${BIN}" "${LANZADORES}" "${QSDIR}"

# ── que `qs -c pinza` funcione, sin mover el código ──────────────
if [ -e "${QSDIR}/pinza" ] && [ ! -L "${QSDIR}/pinza" ]; then
    rojo "${QSDIR}/pinza existe y no es un enlace. No lo toco."
    exit 1
fi
ln -sfn "${RAIZ}" "${QSDIR}/pinza"

# ── el icono, dibujado en tools/icono.py ─────────────────────────
python3 "${RAIZ}/tools/icono.py" --a "${ICONOS}" >/dev/null

# ── el lanzador ──────────────────────────────────────────────────
#
#  Por temporal y `mv`, no escribiendo encima: si el lanzador está
#  ejecutándose en ese momento —reinstalar desde una terminal abierta con
#  él, por ejemplo— escribir encima da «Text file busy» y se queda a
#  medias. Reemplazarlo entero funciona siempre y además es atómico: no
#  hay un instante en que el fichero esté a mitad.
cat > "${BIN}/pinza.nuevo" <<LANZADOR
#!/usr/bin/env bash
#
#  Lanzador de K4 Pinza. Lo escribe ./instalar.sh; no lo edites aquí.
#
#      pinza                        abre el editor
#      pinza Bicho.pinza            abre ese proyecto
#      pinza dibujo.png             lo importa como capa
#      pinza --estado               qué hay abierto ahora mismo
#      pinza --nuevo                la hoja de documento nuevo
#      pinza --mostrar              devolver la ventana si la cerraste
#
set -euo pipefail

#  Se arranca por NOMBRE de configuración y no por ruta a propósito: para
#  Quickshell, \`qs -c pinza\` y \`qs -p /ruta/a/pinza\` son dos instancias
#  distintas, y entonces el IPC de abajo nunca encontraría la ventana abierta.

#  Si ya hay una ventana abierta, se le habla por IPC en vez de arrancar otra:
#  dos instancias se pisarían los ajustes, y sobre todo no es lo que espera
#  nadie al hacer doble clic en un proyecto.
#  La respuesta se captura en vez de dejarla correr: cuando no hay ninguna
#  ventana abierta, qs escribe «No running instances…» por la salida normal, y
#  sin capturarla se colaba en medio de la respuesta de verdad.
hablar() {
    local salida
    if salida="\$(qs -c pinza ipc call pinza "\$@" 2>/dev/null)"; then
        [ -n "\$salida" ] && printf '%s\n' "\$salida"
        return 0
    fi
    return 1
}

case "\${1:-}" in
    --estado) hablar estado || echo "pinza no está abierta"; exit 0 ;;
    --mostrar) hablar mostrar && exit 0 || true ;;
    --nuevo)  hablar nuevo  && exit 0 || true ;;
    --ayuda|-h|--help)
        sed -n '3,10p' "\$0" | sed 's/^#\\s\\?//'; exit 0 ;;
esac

ruta="\${1:-}"
if [ -n "\$ruta" ]; then
    ruta="\$(readlink -f "\$ruta")"
    if [ -d "\$ruta" ] || [ "\${ruta##*.}" = "pinza" ]; then
        hablar abrir "\$ruta" && exit 0 || true
        exec env PINZA_ABRIR="\$ruta" qs -c pinza
    else
        hablar importar "\$ruta" && exit 0 || true
        exec env PINZA_IMPORTAR="\$ruta" qs -c pinza
    fi
fi

#  Si ya hay una instancia, se le pide que enseñe la ventana en vez de
#  arrancar otra: cerrar la ventana no mata el proceso, así que sin esto
#  volver a escribir `pinza` no te devolvía nada.
hablar mostrar && exit 0 || true
exec qs -c pinza
LANZADOR
chmod +x "${BIN}/pinza.nuevo"
mv -f "${BIN}/pinza.nuevo" "${BIN}/pinza"

# ── el lanzador del escritorio ───────────────────────────────────
cat > "${LANZADORES}/pinza.desktop.nuevo" <<ESCRITORIO
[Desktop Entry]
Type=Application
Version=1.0
Name=K4 Pinza
GenericName=Editor de pixel art
GenericName[en]=Pixel art editor
Comment=Un editor de pixel art que sabe qué estás dibujando
Comment[en]=A pixel art editor that knows what you are drawing
Exec=${BIN}/pinza %f
TryExec=${BIN}/pinza
Icon=pinza
Terminal=false
Categories=Graphics;2DGraphics;RasterGraphics;
Keywords=pixel;art;sprite;spritesheet;tileset;animacion;animation;hoja;baldosa;
MimeType=image/png;
StartupNotify=true
StartupWMClass=org.quickshell
Actions=nuevo;

[Desktop Action nuevo]
Name=Documento nuevo
Exec=${BIN}/pinza --nuevo
ESCRITORIO
mv -f "${LANZADORES}/pinza.desktop.nuevo" "${LANZADORES}/pinza.desktop"

command -v update-desktop-database >/dev/null && \
    update-desktop-database "${LANZADORES}" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null && \
    gtk-update-icon-cache -qtf "${ICONOS}" 2>/dev/null || true

# ── decir qué ha pasado ──────────────────────────────────────────
verde "K4 Pinza instalada"
gris  "  ${BIN}/pinza"
gris  "  ${LANZADORES}/pinza.desktop"
gris  "  ${QSDIR}/pinza -> ${RAIZ}"
gris  "  ${ICONOS}/*/apps/pinza.png"
echo
echo "  pinza                    abrir el editor"
echo "  pinza Bicho.pinza        abrir un proyecto"
echo "  pinza dibujo.png         importarlo como capa"
echo "  pinza --estado           qué hay abierto"
echo
gris "El código se queda en ${RAIZ}: no hay copia, así que seguir"
gris "desarrollando ahí es seguir usando lo instalado."

case ":${PATH}:" in
    *":${BIN}:"*) ;;
    *) echo; rojo "aviso: ${BIN} no está en tu PATH, así que el comando \`pinza\` no se encontrará" ;;
esac

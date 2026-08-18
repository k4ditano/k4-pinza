#!/usr/bin/env python3
"""El icono, dibujado a mano en una rejilla de 32×32.

Un editor de pixel art con un icono vectorial suavizado sería una contradicción,
así que el icono ES pixel art: se escribe aquí como una rejilla de caracteres y
se escala por vecino más próximo a los tamaños que pide el escritorio. Todos los
tamaños son múltiplos enteros de 32 para que ninguno salga con píxeles a medias.

Los colores son los de la casa: la rampa `fire` de crabh para el caparazón y el
contorno neutro de tools/style.json, que nunca es negro puro.

    python3 tools/icono.py                 # a ~/.local/share/icons/...
    python3 tools/icono.py --a carpeta/    # a donde le digas
"""

import argparse
import os

from PIL import Image

# ── la paleta ───────────────────────────────────────────────────
#  La rampa `fire` de crabh para el caparazón y el contorno neutro de
#  tools/style.json, que nunca es negro puro.
CONTORNO = (0x2C, 0x37, 0x39, 255)
SOMBRA   = (0x8A, 0x2B, 0x12, 255)
CUERPO   = (0xD6, 0x6C, 0x34, 255)
BRILLO   = (0xF3, 0xC0, 0x7E, 255)

#  La SILUETA y nada más: una pinza de cangrejo abierta, con los dos dedos
#  arriba y la palma abajo. Sólo la forma, porque escribir a mano las cuatro
#  tonalidades sobre 1024 casillas es un ejercicio de erratas — el sombreado se
#  calcula abajo con una regla que se dice una vez.
SILUETA = """
.......###............###.......
.......###............###.......
......#####..........#####......
......#####..........#####......
......#####..........#####......
.....######..........######.....
.....######..........######.....
.....#######........#######.....
....########........########....
....########........########....
....#########......#########....
....#########......#########....
...##########......##########...
...##########......##########...
...##########......##########...
..############....############..
..############....############..
..############################..
.##############################.
.##############################.
.##############################.
..############################..
...##########################...
....########################....
.....######################.....
.......##################.......
.........##############.........
..........############..........
.............######.............
.............######.............
.............######.............
.............######.............
"""

def _lleno(lineas, x, y):
    if x < 0 or y < 0 or y >= len(lineas) or x >= 32:
        return False
    return lineas[y][x] == "#"


def _hayHueco(lineas, x, y, dxs, dys):
    """¿Hay fondo en alguno de estos vecinos?"""
    for dy in dys:
        for dx in dxs:
            if not _lleno(lineas, x + dx, y + dy):
                return True
    return False


def rejilla():
    """La silueta, sombreada por el borde.

    El tono NO sale de la altura dentro de la figura —eso partía la palma en dos
    bandas horizontales y dejaba los dedos enteros de un color— sino de qué
    borde tiene cerca cada píxel: los que rozan el fondo por arriba o por la
    izquierda cogen el brillo, los que lo rozan por abajo o por la derecha la
    sombra, y el resto es cuerpo. Un foco arriba a la izquierda, que es como
    está iluminado el arte del juego.
    """
    lineas = [l.ljust(32, ".")[:32] for l in SILUETA.strip("\n").split("\n")]
    if len(lineas) != 32:
        raise SystemExit("la silueta tiene %d filas y hacen falta 32" % len(lineas))

    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = im.load()
    for y in range(32):
        for x in range(32):
            if lineas[y][x] != "#":
                continue
            if _hayHueco(lineas, x, y, [-1, 0, 1], [-1, 0, 1]):
                px[x, y] = CONTORNO
            elif _hayHueco(lineas, x, y, [-2, -1, 0], [-2, -1, 0]):
                px[x, y] = BRILLO
            elif _hayHueco(lineas, x, y, [0, 1, 2], [0, 1, 2]):
                px[x, y] = SOMBRA
            else:
                px[x, y] = CUERPO
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", default=os.path.expanduser(
        "~/.local/share/icons/hicolor"))
    ap.add_argument("--tamanos", default="32,64,128,256")
    args = ap.parse_args()

    base = rejilla()
    for t in [int(x) for x in args.tamanos.split(",")]:
        if t % 32:
            raise SystemExit("%d no es múltiplo de 32: saldría con píxeles a medias" % t)
        # vecino más próximo, que es lo único que conserva el pixel art
        im = base.resize((t, t), Image.NEAREST)
        carpeta = os.path.join(args.a, "%dx%d" % (t, t), "apps")
        os.makedirs(carpeta, exist_ok=True)
        ruta = os.path.join(carpeta, "pinza.png")
        im.save(ruta)
        print(ruta)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Mira desde fuera lo que pinza dejó escrito para una criatura.

Se llama desde pruebas/Especie.qml y contesta un JSON. Vive en un fichero y no
empotrado en el QML porque una expresión regular con barras dentro de una cadena
de QML dentro de un heredoc de bash es un ejercicio de contar barras invertidas —
lo fue, y las contó mal.
"""

import json
import os
import re
import sys

from PIL import Image

base, nombre, dexOriginal = sys.argv[1], sys.argv[2], int(sys.argv[3])
carpeta = os.path.join(base, "assets/species", nombre)

original = json.load(open(os.path.join(base, "public/data/species.json")))
fuente = [s for s in original if s["dex"] == dexOriginal][0]

xml = open(os.path.join(carpeta, "AnimData.xml"), encoding="utf8").read()


def duraciones(accion):
    trozo = xml.split("<Name>%s</Name>" % accion)[1].split("</Anim>")[0]
    return [int(d) for d in re.findall(r"<Duration>(\d+)</Duration>", trozo)]


hoja = Image.open(os.path.join(carpeta, "Walk-Anim.png"))
hojaOriginal = Image.open(os.path.join(base, "public", fuente["sheets"]["Walk"]))
ficha = json.load(open(os.path.join(base, "assets/species", nombre + ".json")))

print(json.dumps({
    "hojas": len([f for f in os.listdir(carpeta) if f.endswith("-Anim.png")]),
    "walk": list(hoja.size),
    "walkOrig": list(hojaOriginal.size),
    "sombra": int(re.search(r"<ShadowSize>(\d+)</ShadowSize>", xml).group(1)),
    "anims": re.findall(r"<Name>(\w+)</Name>", xml),
    "walkDur": duraciones("Walk"),
    "walkDurOrig": fuente["anims"]["Walk"]["durations"],
    "idleDur": duraciones("Idle"),
    "idleDurOrig": fuente["anims"]["Idle"]["durations"],
    "attackHit": int(re.search(r"<HitFrame>(\d+)</HitFrame>", xml).group(1))
                 if "<HitFrame>" in xml else 0,
    "attackHitOrig": fuente["anims"]["Attack"]["hitFrame"] or 0,
    "ficha": {
        "dex": ficha["dex"],
        "name": ficha["name"],
        "acciones": sorted(ficha["sheets"].keys()),
        "tienePokedex": "pokedex" in ficha,
        "walkGeo": [ficha["anims"]["Walk"]["frameWidth"],
                    ficha["anims"]["Walk"]["frameHeight"]],
        "rutaWalk": ficha["sheets"]["Walk"],
        "tipos": ficha["pokedex"]["types"],
    },
    "retoque": list(hoja.convert("RGBA").getpixel((1, 1))),
}))

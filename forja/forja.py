#!/usr/bin/env python3
"""La forja: todo lo que produce o consume FICHEROS.

Pinza dibuja en QML y no manda nada binario por la tubería. Lo que cruza son
líneas de JSON, y el límite binario es el sistema de ficheros. La razón de que
esto exista y no esté todo en QML es sencilla: Canvas.save() de Qt 6 devuelve
false y no escribe nada (está comprobado en cata/cata.qml), así que exportar es
toDataURL -> base64 -> aquí. Ya puestos, esto hace también el GIF, el atlas, el
XML de PMD y llamar a las comprobaciones del juego, que son cosas para las que
Python con Pillow es la herramienta obvia y QML no lo es.

Protocolo: una petición JSON por línea en stdin, una respuesta JSON por línea
en stdout. Cada petición lleva un `id` que vuelve en la respuesta, porque las
respuestas no tienen por qué llegar en orden.

    {"id": 7, "orden": "escribir", "ruta": "...", "datos": "data:image/png;base64,..."}
    {"id": 7, "bien": true, "bytes": 155}
"""

import base64
import glob
import json
import os
import re
import subprocess
import sys
import traceback

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "pinza"
)

try:
    from PIL import Image
    HAY_PIL = True
except ImportError:
    HAY_PIL = False


def expande(ruta):
    return os.path.abspath(os.path.expanduser(os.path.expandvars(ruta or "")))


def de_base64(datos):
    """Acepta tanto un data: URL entero como el base64 pelado."""
    if "," in datos[:64]:
        datos = datos.split(",", 1)[1]
    return base64.b64decode(datos)


# ═══════════════════════════════════════════════════════════════
# órdenes
# ═══════════════════════════════════════════════════════════════


def orden_ping(p):
    return {"pil": HAY_PIL, "raiz": RAIZ, "config": CONFIG}


def orden_packs(p):
    """Los packs del programa más los tuyos, y los tuyos ganan si repiten id."""
    packs = {}
    for carpeta in (os.path.join(RAIZ, "packs"), os.path.join(CONFIG, "packs")):
        for f in sorted(glob.glob(os.path.join(carpeta, "*.json"))):
            if os.path.basename(f) == "indice.json":
                continue
            try:
                d = json.load(open(f, encoding="utf8"))
                d["_fichero"] = f
                packs[d.get("id", os.path.basename(f)[:-5])] = d
            except Exception as e:
                packs.setdefault("_errores", [])
                sys.stderr.write("pack roto %s: %s\n" % (f, e))
    return {"packs": list(packs.values())}


def orden_carpeta(p):
    os.makedirs(expande(p["ruta"]), exist_ok=True)
    return {"ruta": expande(p["ruta"])}


def orden_existe(p):
    return {"existe": os.path.exists(expande(p["ruta"]))}


def orden_listar(p):
    base = expande(p["ruta"])
    patron = p.get("patron", "*")
    ficheros = sorted(glob.glob(os.path.join(base, patron)))
    return {"ficheros": [
        {"ruta": f, "nombre": os.path.basename(f),
         "carpeta": os.path.isdir(f), "bytes": os.path.getsize(f) if os.path.isfile(f) else 0}
        for f in ficheros
    ]}


def orden_leer_texto(p):
    ruta = expande(p["ruta"])
    if not os.path.exists(ruta):
        return {"texto": None}
    return {"texto": open(ruta, encoding="utf8").read()}


def orden_escribir_texto(p):
    ruta = expande(p["ruta"])
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    # temporal + rename: si se corta la luz a mitad no se queda un json roto
    tmp = ruta + ".pinza-tmp"
    with open(tmp, "w", encoding="utf8") as f:
        f.write(p["texto"])
    os.replace(tmp, ruta)
    return {"ruta": ruta, "bytes": len(p["texto"])}


def orden_escribir(p):
    """Un PNG, desde el toDataURL del lienzo."""
    ruta = expande(p["ruta"])
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    b = de_base64(p["datos"])
    tmp = ruta + ".pinza-tmp"
    with open(tmp, "wb") as f:
        f.write(b)
    os.replace(tmp, ruta)
    return {"ruta": ruta, "bytes": len(b)}


def orden_borrar(p):
    ruta = expande(p["ruta"])
    if os.path.isfile(ruta):
        os.remove(ruta)
        return {"borrado": True}
    return {"borrado": False}


def orden_png_info(p):
    ruta = expande(p["ruta"])
    with open(ruta, "rb") as f:
        b = f.read(32)
    import struct
    w, h = struct.unpack(">II", b[16:24])
    return {"ancho": w, "alto": h, "tipoColor": b[25]}


def orden_leer_pixeles(p):
    """Un PNG -> sus píxeles RGBA crudos, en base64.

    Existe porque leer con el Canvas de QML no es de fiar: depende de que la
    imagen esté cargada EN EL MOMENTO en que toca pintar, y al arrancar el
    programa no lo está. El síntoma era silencioso y de los peores — devolvía un
    búfer vacío sin dar error, así que un proyecto se abría a medias y parecía
    que se habían perdido capas. Escribir sí se queda en QML: ahí se pinta y se
    lee el resultado en la misma llamada, sin nada asíncrono por medio.
    """
    if not HAY_PIL:
        raise RuntimeError("hace falta python-pillow para leer imágenes")
    im = Image.open(expande(p["ruta"])).convert("RGBA")
    return {"ancho": im.width, "alto": im.height,
            "datos": base64.b64encode(im.tobytes()).decode("ascii")}


def orden_escribir_pixeles(p):
    """Escribe PNG a partir de píxeles RGBA crudos, uno o muchos de una vez.

    Existe para no pasar cada fichero por el Canvas de QML. Escribir un PNG por
    ahí cuesta un repintado por fichero, y una criatura de PMD son quinientas
    celdas: el programa se quedaba ocho segundos bloqueado y parpadeando porque
    además había que abrir cada documento para pintarlo. Aquí llegan todas
    juntas en un mensaje.
    """
    if not HAY_PIL:
        raise RuntimeError("hace falta python-pillow para escribir imágenes")
    trozos = p.get("ficheros") or [p]
    escritos = []
    for f in trozos:
        ruta = expande(f["ruta"])
        os.makedirs(os.path.dirname(ruta), exist_ok=True)
        crudo = base64.b64decode(f["datos"])
        esperado = int(f["ancho"]) * int(f["alto"]) * 4
        if len(crudo) < esperado:
            crudo = crudo + b"\x00" * (esperado - len(crudo))
        im = Image.frombytes("RGBA", (int(f["ancho"]), int(f["alto"])), crudo[:esperado])
        # el temporal conserva la extensión: Pillow decide el formato por ella
        tmp = ruta + ".pinza-tmp.png"
        im.save(tmp)
        os.replace(tmp, ruta)
        escritos.append(ruta)
    return {"escritos": escritos, "cuantos": len(escritos)}


def orden_gif(p):
    """Monta un GIF (o un APNG) con los fotogramas ya exportados.

    Las duraciones llegan en TICS de 1/60 s, que es la unidad del editor, y se
    pasan a milisegundos aquí — no en QML, para que haya una sola conversión en
    todo el programa.
    """
    if not HAY_PIL:
        raise RuntimeError("hace falta python-pillow para exportar animación")
    imagenes = [Image.open(expande(f)).convert("RGBA") for f in p["ficheros"]]
    ms = [max(20, int(round(t * 1000.0 / 60.0))) for t in p["duraciones"]]
    ruta = expande(p["ruta"])
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    if p.get("formato", "gif") == "apng":
        imagenes[0].save(ruta, save_all=True, append_images=imagenes[1:],
                         duration=ms, loop=0, format="PNG")
    else:
        # GIF no tiene alfa parcial: se cuantiza y se marca un índice transparente
        conv = []
        for im in imagenes:
            q = im.convert("RGBA")
            fondo = Image.new("RGBA", q.size, (0, 0, 0, 0))
            fondo.paste(q, (0, 0), q)
            pal = fondo.convert("P", palette=Image.ADAPTIVE, colors=255)
            mascara = fondo.split()[3].point(lambda a: 255 if a <= 8 else 0)
            pal.paste(255, mascara)
            conv.append(pal)
        conv[0].save(ruta, save_all=True, append_images=conv[1:], duration=ms,
                     loop=0, transparency=255, disposal=2, optimize=False)
    return {"ruta": ruta, "fotogramas": len(imagenes)}


def orden_manifiesto(p):
    """Añade o actualiza una entrada en el authored.json de crabh.

    Este es el paso que hoy se hace a mano después de exportar, y es la mitad
    de la razón de que pinza exista. Se respeta el orden del fichero y se
    machaca por `name` + `kind`, para que exportar dos veces no duplique.
    """
    ruta = expande(p["fichero"])
    if os.path.exists(ruta):
        doc = json.load(open(ruta, encoding="utf8"))
    else:
        doc = {"entries": []}
    doc.setdefault("entries", [])
    entrada = p["entrada"]
    for i, e in enumerate(doc["entries"]):
        if e.get("name") == entrada.get("name") and e.get("kind") == entrada.get("kind"):
            doc["entries"][i] = {**e, **entrada}
            break
    else:
        doc["entries"].append(entrada)
        doc["entries"].sort(key=lambda e: (e.get("kind", ""), e.get("name", "")))
    tmp = ruta + ".pinza-tmp"
    with open(tmp, "w", encoding="utf8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, ruta)
    return {"ruta": ruta, "entradas": len(doc["entries"])}


def orden_animdata(p):
    """El AnimData.xml que lee el cargador de PMD.

    Las duraciones van en tics tal cual, sin convertir: el formato ya está en
    tics de 1/60 s y es exactamente la unidad con la que se retima en la tira.
    """
    ruta = expande(p["ruta"])
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    anims = p["anims"]
    fuera = ['<?xml version="1.0" encoding="utf-8"?>', "<AnimData>",
             "  <ShadowSize>%d</ShadowSize>" % int(p.get("shadowSize", 1)), "  <Anims>"]
    for a in anims:
        fuera.append("    <Anim>")
        fuera.append("      <Name>%s</Name>" % a["nombre"])
        fuera.append("      <Index>%d</Index>" % int(a.get("indice", 0)))
        fuera.append("      <FrameWidth>%d</FrameWidth>" % int(a["ancho"]))
        fuera.append("      <FrameHeight>%d</FrameHeight>" % int(a["alto"]))
        for clave, etiqueta in (("hitFrame", "HitFrame"), ("rushFrame", "RushFrame"),
                                ("returnFrame", "ReturnFrame")):
            if a.get(clave):
                fuera.append("      <%s>%d</%s>" % (etiqueta, int(a[clave]), etiqueta))
        fuera.append("      <Durations>")
        for d in a["duraciones"]:
            fuera.append("        <Duration>%d</Duration>" % int(d))
        fuera.append("      </Durations>")
        fuera.append("    </Anim>")
    fuera += ["  </Anims>", "</AnimData>", ""]
    tmp = ruta + ".pinza-tmp"
    open(tmp, "w", encoding="utf8").write("\n".join(fuera))
    os.replace(tmp, ruta)
    return {"ruta": ruta, "anims": len(anims)}


def orden_comprobar(p):
    """Lanza las comprobaciones del juego y devuelve lo que digan.

    El pack dice cuáles. No se interpreta la salida: se enseña tal cual, porque
    esos guiones ya están escritos para que los lea una persona.
    """
    raiz = expande(p["raiz"])
    salidas = []
    for g in p["guiones"]:
        try:
            r = subprocess.run(g if isinstance(g, list) else ["npm", "run", "-s", g],
                               cwd=raiz, capture_output=True, text=True, timeout=120)
            salidas.append({"guion": g, "codigo": r.returncode,
                            "salida": (r.stdout + r.stderr).strip()[:8000]})
        except Exception as e:
            salidas.append({"guion": g, "codigo": -1, "salida": str(e)})
    return {"resultados": salidas}


def orden_trocear(p):
    """Parte una hoja en fotogramas sueltos, para importar arte de fuera."""
    if not HAY_PIL:
        raise RuntimeError("hace falta python-pillow")
    im = Image.open(expande(p["ruta"])).convert("RGBA")
    cw, ch = int(p["ancho"]), int(p["alto"])
    cols, filas = im.width // cw, im.height // ch
    destino = expande(p["destino"])
    os.makedirs(destino, exist_ok=True)
    fuera = []
    for f in range(filas):
        for c in range(cols):
            trozo = im.crop((c * cw, f * ch, (c + 1) * cw, (f + 1) * ch))
            nombre = os.path.join(destino, "f%d.d%d.png" % (c, f))
            trozo.save(nombre)
            fuera.append({"ruta": nombre, "fotograma": c, "orientacion": f})
    return {"celdas": fuera, "cols": cols, "filas": filas}


def orden_paleta_fichero(p):
    """Los colores de un fichero de paleta: .gpl, .hex, .txt o un PNG."""
    ruta = expande(p["ruta"])
    ext = os.path.splitext(ruta)[1].lower()
    if ext == ".png" and HAY_PIL:
        im = Image.open(ruta).convert("RGBA")
        vistos, orden = set(), []
        for px in im.getdata():
            if px[3] < 8:
                continue
            k = px[:3]
            if k not in vistos:
                vistos.add(k)
                orden.append("#%02x%02x%02x" % k)
        return {"colores": orden[:256]}
    texto = open(ruta, encoding="utf8", errors="replace").read()
    if ext == ".gpl":
        cols = []
        for linea in texto.splitlines():
            m = re.match(r"^\s*(\d{1,3})\s+(\d{1,3})\s+(\d{1,3})", linea)
            if m:
                cols.append("#%02x%02x%02x" % tuple(int(x) for x in m.groups()))
        return {"colores": cols}
    return {"colores": ["#" + m.lstrip("#") for m in
                        re.findall(r"#?[0-9a-fA-F]{6}", texto)]}


def orden_abrir(p):
    """Abre una ruta con el visor del sistema, para 'enseñar en la carpeta'."""
    subprocess.Popen(["xdg-open", expande(p["ruta"])],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"abierto": True}


ORDENES = {
    "ping": orden_ping,
    "packs": orden_packs,
    "carpeta": orden_carpeta,
    "existe": orden_existe,
    "listar": orden_listar,
    "leerTexto": orden_leer_texto,
    "escribirTexto": orden_escribir_texto,
    "escribir": orden_escribir,
    "escribirPixeles": orden_escribir_pixeles,
    "borrar": orden_borrar,
    "pngInfo": orden_png_info,
    "leerPixeles": orden_leer_pixeles,
    "gif": orden_gif,
    "manifiesto": orden_manifiesto,
    "animdata": orden_animdata,
    "comprobar": orden_comprobar,
    "trocear": orden_trocear,
    "paletaFichero": orden_paleta_fichero,
    "abrir": orden_abrir,
}


def main():
    for linea in sys.stdin:
        linea = linea.strip()
        if not linea:
            continue
        try:
            p = json.loads(linea)
        except Exception as e:
            print(json.dumps({"id": 0, "bien": False, "error": "json ilegible: %s" % e}),
                  flush=True)
            continue
        pid = p.get("id", 0)
        fn = ORDENES.get(p.get("orden"))
        if fn is None:
            print(json.dumps({"id": pid, "bien": False,
                              "error": "orden desconocida: %s" % p.get("orden")}), flush=True)
            continue
        try:
            r = fn(p) or {}
            r["id"] = pid
            r["bien"] = True
            print(json.dumps(r, ensure_ascii=False), flush=True)
        except Exception as e:
            sys.stderr.write(traceback.format_exc())
            print(json.dumps({"id": pid, "bien": False, "error": str(e)}), flush=True)


if __name__ == "__main__":
    main()

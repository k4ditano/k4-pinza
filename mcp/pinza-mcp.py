#!/usr/bin/env python3
#
#  El servidor MCP de Pinza.
#
#  Deja que un modelo conduzca el editor: crear un documento, dibujar por
#  descripción, MIRAR lo que le ha salido y corregirlo. Lo de mirar no es un
#  adorno — sin devolver la imagen, el modelo dibuja a ciegas y no hay bucle;
#  con ella, cada paso se puede juzgar y arreglar, que es como dibuja
#  cualquiera.
#
#  Por debajo no hace nada por su cuenta: todo pasa por el IPC de Quickshell
#  contra la instancia que ya está abierta. Eso importa por tres razones y las
#  tres son la misma — no hay un segundo motor de píxeles, no hay una segunda
#  respuesta a «cómo se ve esto», y TÚ VES LO QUE HACE mientras lo hace, en la
#  ventana que ya tenías delante. Lo que dibuja entra en el historial como un
#  paso y se deshace con Ctrl+Z.
#
#  Sin dependencias a propósito. El programa se instala con symlinks y no pide
#  sudo; obligar a un `pip install` para esto sería romper esa promesa por una
#  librería que aquí son ciento cincuenta líneas de JSON-RPC.
#
#      mcp/pinza-mcp.py            se habla por la entrada estándar
#
#  En Claude Code:
#      claude mcp add pinza -- /ruta/a/pinza/mcp/pinza-mcp.py

import base64
import json
import os
import subprocess
import sys
import time

#  Lo que el servidor le cuenta al modelo nada más conectarse.
#
#  Es el único sitio donde caben instrucciones que no van pegadas a una
#  herramienta, y por eso lleva lo que se aprende ROMPIENDO cosas: el orden de
#  trabajo. Cada línea de aquí es un fallo que ya se cometió una vez.
GUIA = """
Pinza es un editor de pixel art que sabe qué estás dibujando: un dibujo es
capas x fotogramas x ORIENTACIONES, y una criatura son varias acciones, cada
una con su geometría.

Orden de trabajo. No es burocracia: cada paso evita un fallo que no da error.

1. MIRA QUÉ HAY. pinza_estado. Si hay una criatura abierta, tiene ACCIONES y
   el trabajo es sobre todas — un recolor que sólo llega a «Walk» deja un
   bicho que cambia de color al pararse, y eso no se ve dibujando.

2. MIDE ANTES DE TOCAR, y mide TODO. pinza_analiza con que:"todo" mira todas
   las celdas juntas. Con que:"compuesto" mides UNA, y lo que no salga en esa
   celda se queda sin tocar en las otras treinta y nueve.

3. EL CONTORNO NO SE TOCA salvo que te lo pidan. No se reconoce por su color
   —puede ser cualquiera— sino por dónde está, y pinza_analiza te lo dice ya
   detectado. Un pack suele tener una convención de contorno; pregúntasela al
   arte que ya existe con pinza_convenciones antes de decidir que la mejoras.

4. DIBUJA DESCRIBIENDO, no poniendo píxeles. pinza_dibuja con `pinza.fig`:
   masas, siluetas y una regla de luz. Escribir una rejilla a mano sale mal y
   no se puede corregir; una descripción se corrige cambiando un número.

5. MIRA LO QUE HA SALIDO. pinza_ver después de cada cambio. Dibujar sin mirar
   es dibujar a ciegas.

6. VERIFICA EN EL DISCO. pinza_verifica lee los PNG escritos. Lo que se ve en
   el editor no es lo que sale; eso sólo lo dice el disco, y los fallos que
   importan —un color sin sustituir, algo recortado contra el borde— no dan
   error en ningún sitio.

Dos avisos que cuestan caros:

· Un número no es el objetivo. pinza_compara da un parecido de 0 a 1 y sirve
  para saber HACIA DÓNDE moverse, no para maximizarlo: el máximo parecido con
  la silueta de otra criatura suele ser un sprite peor.

· Las órdenes del editor trabajan sobre la capa ACTIVA. Para tocar una capa
  concreta usa pinza_capa con su índice; «borra la capa» creyendo que se
  llevará el calco y que se lleve el dibujo es un error de una línea.
""".strip()


CONFIG = "pinza"
VERSIONES = ("2025-06-18", "2025-03-26", "2024-11-05")

CARPETA = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "pinza-mcp")


def avisa(t):
    """A la salida de error: la estándar es del protocolo y sólo del protocolo."""
    print(t, file=sys.stderr, flush=True)


# ═══════════════════════════════════════════════════════════════
# hablar con el editor
# ═══════════════════════════════════════════════════════════════

class SinVentana(Exception):
    pass


def ipc(funcion, *args, espera=30):
    orden = ["qs", "-c", CONFIG, "ipc", "call", CONFIG, funcion]
    orden += [str(a) for a in args]
    try:
        r = subprocess.run(orden, capture_output=True, text=True, timeout=espera)
    except FileNotFoundError:
        raise SinVentana("no encuentro `qs`: hace falta Quickshell instalado")
    except subprocess.TimeoutExpired:
        raise SinVentana("el editor no contesta")
    salida = (r.stdout or "").strip()
    #  Cuando no hay ninguna instancia, qs lo dice por la salida NORMAL y con
    #  código 0 en algunas versiones, así que no vale mirar sólo el código.
    if "No running instances" in salida or "No running instances" in (r.stderr or ""):
        raise SinVentana("no hay ninguna ventana de Pinza abierta")
    if r.returncode != 0 and not salida:
        raise SinVentana((r.stderr or "").strip() or "el IPC falló")
    return salida


def arranca():
    """Abre el editor si no lo estaba. Con ventana: la gracia es verlo."""
    try:
        ipc("estado", espera=6)
        return True
    except SinVentana:
        pass
    avisa("pinza-mcp: no hay ventana, abriendo el editor…")
    try:
        subprocess.Popen(["qs", "-c", CONFIG],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except FileNotFoundError:
        return False
    for _ in range(40):
        time.sleep(0.5)
        try:
            ipc("estado", espera=5)
            return True
        except SinVentana:
            continue
    return False


def pide(funcion, *args):
    """Como `ipc`, pero arrancando el editor si hiciera falta."""
    try:
        return ipc(funcion, *args)
    except SinVentana:
        if not arranca():
            raise
        return ipc(funcion, *args)


def pideJson(funcion, *args):
    t = pide(funcion, *args)
    try:
        return json.loads(t)
    except json.JSONDecodeError:
        return {"bien": False, "error": "respuesta ilegible: " + t[:200]}


# ═══════════════════════════════════════════════════════════════
# traer una referencia de fuera
# ═══════════════════════════════════════════════════════════════
#
#  La red vive AQUÍ y no en el editor. Pinza no habla con internet: se le pasa
#  una ruta a un fichero que ya está en el disco. Así la forja sigue siendo el
#  único sitio que toca el mundo exterior, el editor sigue funcionando sin
#  conexión, y lo que se descarga queda en un fichero que se puede mirar.

CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "pinza-mcp")

AGENTE = "pinza-mcp/1.0 (+https://github.com/k4ditano/k4-pinza)"

#  Las generaciones que son pixel art de verdad. La "por defecto" de PokeAPI
#  es un render moderno y no sirve de referencia para dibujar píxeles: te da
#  proporciones de un modelo 3D suavizado.
GENERACIONES = {
    "iii": ("generation-iii", "emerald"),
    "iv": ("generation-iv", "platinum"),
    "v": ("generation-v", "black-white"),
}


def baja(url, destino):
    import urllib.request
    pet = urllib.request.Request(url, headers={"User-Agent": AGENTE})
    with urllib.request.urlopen(pet, timeout=25) as r:
        datos = r.read()
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    tmp = destino + ".parcial"
    with open(tmp, "wb") as f:
        f.write(datos)
    os.replace(tmp, destino)
    return destino


def dePokeapi(nombre, generacion, dorso, brillante):
    """El sprite de un bicho de PokeAPI, en fichero local.

    Se cachea la ficha y el PNG: pedir cinco variantes del mismo bicho no
    debería ser cinco viajes, y sobre todo así se puede seguir trabajando sin
    conexión en cuanto lo has traído una vez.
    """
    import json as _json
    import urllib.request
    nombre = nombre.strip().lower()
    ficha = os.path.join(CACHE, "pokeapi", nombre + ".json")
    if not os.path.exists(ficha):
        baja("https://pokeapi.co/api/v2/pokemon/" + nombre, ficha)
    with open(ficha) as f:
        d = _json.load(f)

    sp = d["sprites"]
    gen = GENERACIONES.get((generacion or "v").lower())
    if gen:
        try:
            sp = sp["versions"][gen[0]][gen[1]]
        except KeyError:
            pass
    clave = ("back_" if dorso else "front_") + ("shiny" if brillante else "default")
    url = sp.get(clave) or sp.get("front_default")
    if not url:
        raise RuntimeError("«%s» no tiene sprite %s en la generación %s"
                           % (nombre, clave, generacion or "v"))
    destino = os.path.join(CACHE, "pokeapi",
                           "%s-%s-%s.png" % (nombre, generacion or "v", clave))
    if not os.path.exists(destino):
        baja(url, destino)
    return destino, url


def aFicheroLocal(fuente, generacion, dorso, brillante):
    """Cualquier fuente -> una ruta en el disco. Devuelve (ruta, de dónde)."""
    if fuente.startswith("pokeapi:"):
        return dePokeapi(fuente[8:], generacion, dorso, brillante)
    if fuente.startswith("http://") or fuente.startswith("https://"):
        import hashlib
        h = hashlib.sha256(fuente.encode()).hexdigest()[:16]
        ext = os.path.splitext(fuente.split("?")[0])[1] or ".png"
        destino = os.path.join(CACHE, "url", h + ext)
        if not os.path.exists(destino):
            baja(fuente, destino)
        return destino, fuente
    ruta = os.path.expanduser(fuente)
    if not os.path.exists(ruta):
        raise RuntimeError("no existe " + ruta)
    return ruta, ruta


# ═══════════════════════════════════════════════════════════════
# verificar desde fuera
# ═══════════════════════════════════════════════════════════════
#
#  Lo que se ve en el editor no es lo que sale: eso sólo lo dice el disco. Es
#  la misma regla con la que se prueba el programa —Pillow leyendo los PNG
#  desde fuera— aplicada a lo que dibuja una IA, y por la misma razón: los
#  fallos que importan son los que no dan error. Un color sin sustituir, un
#  contorno teñido sin querer, una llama recortada contra el borde del lienzo.
#  Los tres se ven en los ficheros y ninguno se queja.

def _pngs(carpeta):
    import glob
    return sorted(glob.glob(os.path.join(carpeta, "celdas", "*.png")))


def _proyectos(ruta):
    """Un .pinza es uno; un .especie son todas sus acciones."""
    import glob
    ruta = os.path.expanduser(ruta.rstrip("/"))
    if os.path.exists(os.path.join(ruta, "proyecto.json")):
        return [(os.path.basename(ruta), ruta)]
    dentro = sorted(glob.glob(os.path.join(ruta, "*.pinza")))
    if dentro:
        return [(os.path.basename(d)[:-6], d) for d in dentro]
    raise RuntimeError("en %s no hay ni un proyecto.json ni carpetas .pinza" % ruta)


def _hx(c):
    return "#%02x%02x%02x" % (int(c[0]), int(c[1]), int(c[2]))


def _tocanElBorde(carpeta):
    """Los nombres de celda cuyo dibujo llega al filo del lienzo."""
    import numpy as np
    from PIL import Image
    fuera = set()
    for f in _pngs(carpeta):
        a = np.array(Image.open(f).convert("RGBA"))[:, :, 3] > 8
        if not a.any():
            continue
        if a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
            fuera.add(os.path.basename(f))
    return fuera


def verifica(ruta, paleta=None, contorno=None, base=None):
    """Audita lo que hay escrito. Devuelve un informe por acción.

    Con `base` se compara contra otro proyecto —el original del que salió la
    variante— y sólo se cuenta lo que has añadido tú. Sin eso, la herramienta
    te acusa de lo que ya venía en el material: el Charge de un Pidgey tiene
    treinta celdas tocando el filo del lienzo antes de que nadie lo toque, y un
    aviso que salta siempre deja de leerse a la tercera vez.
    """
    try:
        import numpy as np
        from PIL import Image
    except ImportError:
        raise RuntimeError("hace falta python-pillow (y numpy) para verificar")

    permitido = set(x.lower() for x in (paleta or []))
    espera = set(x.lower() for x in (contorno or []))
    previos = {}
    if base:
        try:
            for n, c in _proyectos(base):
                previos[n] = _tocanElBorde(c)
        except Exception:                               # noqa: BLE001
            previos = {}

    informe = []
    for nombre, carpeta in _proyectos(ruta):
        fuera, celdas, vacias, pegadas, malcontorno = {}, 0, 0, [], []
        anillo = {}
        for f in _pngs(carpeta):
            im = np.array(Image.open(f).convert("RGBA"))
            celdas += 1
            a = im[:, :, 3] > 8
            if not a.any():
                vacias += 1
                continue
            #  Contenido tocando el borde del lienzo: o el dibujo no cabe, o
            #  algo que se le añadió por encima se está recortando.
            if a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
                pegadas.append(os.path.basename(f))
            v = np.zeros_like(a)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                v |= ~np.roll(a, (dy, dx), (0, 1))
            b = a & v
            cuenta = {}
            for px in im[b][:, :3]:
                h = _hx(px)
                cuenta[h] = cuenta.get(h, 0) + 1
                anillo[h] = anillo.get(h, 0) + 1
            if cuenta:
                manda = max(cuenta.items(), key=lambda x: x[1])[0]
                if espera and manda not in espera:
                    malcontorno.append((os.path.basename(f), manda))
            if permitido:
                for px in np.unique(im[a][:, :3], axis=0):
                    h = _hx(px)
                    if h not in permitido:
                        fuera[h] = fuera.get(h, 0) + 1
        nuevas = ([p for p in pegadas if p not in previos[nombre]]
                  if nombre in previos else pegadas)
        informe.append({
            "accion": nombre, "celdas": celdas, "vacias": vacias,
            "coloresFuera": sorted(fuera.items(), key=lambda x: -x[1]),
            "tocanElBorde": nuevas,
            "conBase": nombre in previos,
            "yaTocaban": len(pegadas) - len(nuevas),
            "contornoRaro": malcontorno,
            "anillo": sorted(anillo.items(), key=lambda x: -x[1])[:4],
        })
    return informe


def convenciones(carpeta, cuantos=8):
    """Qué reglas sigue de hecho el arte que ya existe en un sitio.

    Un pack trae una guía de estilo escrita, pero las convenciones que de
    verdad mandan están en los ficheros: de qué color es el contorno, cuántos
    colores gasta un sprite, de qué tamaño son las celdas. Preguntárselo al
    arte que ya hay es la diferencia entre una variante que pertenece al juego
    y una que canta desde lejos — y a mí me costó teñir un contorno negro que
    era negro en los ciento cincuenta y ocho bichos del pack.
    """
    import glob
    try:
        import numpy as np
        from PIL import Image
    except ImportError:
        raise RuntimeError("hace falta python-pillow (y numpy)")

    carpeta = os.path.expanduser(carpeta)
    hojas = sorted(glob.glob(os.path.join(carpeta, "**", "*.png"), recursive=True))[:cuantos * 4]
    if not hojas:
        raise RuntimeError("no hay ningún PNG bajo " + carpeta)
    anillo, colores, tam = {}, [], {}
    mirados = 0
    for h in hojas[:cuantos]:
        im = np.array(Image.open(h).convert("RGBA"))
        a = im[:, :, 3] > 8
        if not a.any():
            continue
        mirados += 1
        tam["%dx%d" % (im.shape[1], im.shape[0])] = tam.get("%dx%d" % (im.shape[1], im.shape[0]), 0) + 1
        v = np.zeros_like(a)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            v |= ~np.roll(a, (dy, dx), (0, 1))
        for px in im[a & v][:, :3]:
            k = _hx(px)
            anillo[k] = anillo.get(k, 0) + 1
        colores.append(len(np.unique(im[a][:, :3], axis=0)))
    total = sum(anillo.values()) or 1
    orden = sorted(anillo.items(), key=lambda x: -x[1])
    return {
        "ficheros": mirados,
        "contorno": [{"color": c, "delAnillo": round(n / total, 3)} for c, n in orden[:3]],
        "coloresPorHoja": {"minimo": min(colores) if colores else 0,
                           "maximo": max(colores) if colores else 0},
        "tamaños": sorted(tam.items(), key=lambda x: -x[1])[:4],
    }


# ═══════════════════════════════════════════════════════════════
# mirar
# ═══════════════════════════════════════════════════════════════

def imagen(spec):
    """Pide una previa y espera a que el PNG exista.

    Se espera a que APAREZCA el fichero y no a ningún aviso porque la forja
    escribe con temporal y `rename`: mientras se escribe, en la ruta final no
    hay nada, y en cuanto hay algo está entero. El nombre lleva un contador
    para no leer nunca la previa de la llamada anterior si esta falla.
    """
    os.makedirs(CARPETA, exist_ok=True)
    imagen.n = getattr(imagen, "n", 0) + 1
    ruta = os.path.join(CARPETA, "previa-%d-%d.png" % (os.getpid(), imagen.n))
    if os.path.exists(ruta):
        os.unlink(ruta)

    spec = dict(spec)
    spec["ruta"] = ruta
    r = pideJson("previa", json.dumps(spec))
    if not r.get("bien"):
        return None, r.get("error", "no se pudo componer la previa")

    limite = time.time() + 20
    while time.time() < limite:
        if os.path.exists(ruta) and os.path.getsize(ruta) > 0:
            break
        time.sleep(0.05)
    else:
        return None, "la previa no llegó a escribirse"

    with open(ruta, "rb") as f:
        datos = base64.b64encode(f.read()).decode("ascii")
    try:
        os.unlink(ruta)
    except OSError:
        pass
    return (datos, r)


# ═══════════════════════════════════════════════════════════════
# las herramientas
# ═══════════════════════════════════════════════════════════════

API = """
`pinza.fig` es la librería de dibujo por descripción (core/figura.js). Se
declaran MASAS, se unen en una silueta y el sombreado sale de una REGLA — no se
ponen píxeles a mano.

MÁSCARAS (formas booleanas; todas devuelven una máscara del tamaño del lienzo)
  fig.elipse(w,h, cx,cy, rx,ry)        fig.disco(w,h, cx,cy, r)
  fig.rect(w,h, x,y, an,al, redondeo)  fig.capsula(w,h, x0,y0, x1,y1, r)
  fig.poligono(w,h, [[x,y],...])       fig.deTexto(["..##..", ".####."])
  fig.deBuffer(buf)                    -> la silueta de lo ya dibujado

ÁLGEBRA
  fig.une(a,b,...)  fig.resta(a,b)  fig.corta(a,b)     (intersección)
  fig.crece(k,n)    fig.encoge(k,n) fig.borde(k)       (anillo exterior)
  fig.mueve(k,dx,dy) fig.espeja(k,eje) fig.simetrica(k,eje)
  fig.centra(k,apoya)  fig.limites(k) -> {x,y,w,h}   fig.cuantos(k)
  fig.en(k,x,y) -> 0|1

PINTAR
  fig.cuerpo(buf, mascara, {rampa, luz, grosor, amplitud, base, contorno})
      lo normal: rellena, sombrea y contornea de una vez.
      luz: "N","S","E","O","NE","NO","SE","SO" o [x,y].  Por defecto "NO".
      grosor: ancho en píxeles de la banda sombreada (3-4 va bien).
      amplitud: escalones de rampa arriba/abajo. 1 = tres tonos, 2 = cinco.
      contorno: false lo quita; un color lo fuerza; por defecto el más oscuro.
  fig.pinta(buf,k,color)   fig.sombrea(buf,k,opts)   fig.perfila(buf,k,color)
  fig.borra(buf,k)

RAMPAS
  fig.rampa("#7040c0", 5)   -> rampa generada, de oscuro a claro
  pinza.rampa(0) / pinza.rampa("cálidos")  -> una rampa de la paleta del pack

LEER
  fig.aTexto(buf) -> {filas, leyenda}    fig.deTextoColor(filas, leyenda)
  fig.analiza(buf) -> caja, centro, simetría, perfil, rampas y CONTORNO
  fig.contornoDe(buf) -> qué colores forman el borde, por posición
  fig.rampasDe(buf) -> los colores agrupados en las rampas con que se pintó
  fig.mosaico(celdas, w, h, hueco) -> todas las celdas juntas, para medirlas
  fig.solape(a, b) -> cuánto se parecen dos siluetas, de 0 a 1

EL DOCUMENTO (`pinza`)
  pinza.doc -> {nombre,ancho,alto,capas,fotogramas,orientaciones,contrato}
  pinza.celda(capa, fotograma, orientacion)  -> el búfer, se escribe directo
      sin argumentos: la celda activa.
  pinza.compuesto(f,o)   pinza.capaNueva(nombre)   pinza.fotogramaNuevo(copia)
  pinza.paraCada(fn)     recorre TODAS las celdas: fn(buf,capa,f,o)
  pinza.pon(buf,x,y,color)  pinza.lee(buf,x,y)  pinza.color("#rrggbb")
  pinza.primario / pinza.secundario / pinza.rampas
  pinza.log(...)  -> vuelve en la respuesta

Las coordenadas son (0,0) arriba a la izquierda. El eje Y crece hacia abajo.
""".strip()

HERRAMIENTAS = [
    {
        "name": "pinza_estado",
        "description":
            "Qué hay abierto en el editor: geometría, capas, fotogramas, "
            "orientaciones, contrato del pack, paleta con sus rampas y la "
            "criatura si la hay. Es lo primero que conviene mirar: el ancho, "
            "el alto y las rampas disponibles condicionan todo lo demás.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "pinza_ver",
        "description":
            "Devuelve una IMAGEN de lo que hay dibujado ahora mismo, para "
            "poder juzgarlo y corregirlo. Úsalo después de cada cambio: "
            "dibujar sin mirar es dibujar a ciegas.\n"
            "`que`: 'compuesto' (el fotograma actual con todas sus capas), "
            "'celda' (sólo la capa activa) u 'hoja' (todos los fotogramas × "
            "todas las orientaciones de un vistazo, para ver si una cara se ha "
            "quedado atrás).\n"
            "La escala se recorta sola para no devolver una imagen enorme. El "
            "fondo de ajedrez marca lo transparente — sin él no se distingue "
            "un hueco de un píxel negro.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "que": {"type": "string", "enum": ["compuesto", "celda", "hoja"],
                        "description": "qué componer. Por defecto 'compuesto'."},
                "escala": {"type": "integer",
                           "description": "aumento por vecino más próximo. Por defecto 8."},
                "fotograma": {"type": "integer"},
                "orientacion": {"type": "integer"},
                "fondo": {"type": "string",
                          "description": "'ajedrez' (por defecto), 'ninguno' o un #rrggbb."},
            },
        },
    },
    {
        "name": "pinza_dibuja",
        "description":
            "Corre JavaScript contra el documento abierto: es la herramienta "
            "con la que se dibuja. Todo lo que haga entra en el historial como "
            "UN paso con el nombre que le des, así que un Ctrl+Z lo deshace "
            "entero y se puede probar sin miedo. Si el guion revienta a mitad, "
            "no deja rastro.\n\n"
            "No pongas píxeles a mano salvo para un retoque suelto: describe "
            "la figura con `pinza.fig` y deja que la regla de luz ponga el "
            "sombreado. Sale mejor y se corrige cambiando un número.\n\n"
            "Antes de escribir el guion, tres cosas que se olvidan y no dan "
            "error:\n"
            "· MIDE TODAS LAS CELDAS, no la que tienes delante. `pinza.paraCada` "
            "las recorre, y `fig.mosaico` las junta para medirlas de una vez. "
            "Lo que midas en una celda lo vas a aplicar a cuarenta.\n"
            "· NO TOQUES EL CONTORNO. `fig.analiza(...).contorno.colores` te "
            "dice cuál es, detectado por posición y no por color.\n"
            "· SI HAY UNA CRIATURA ABIERTA, esto es UNA de sus acciones. "
            "Recórrelas con pinza_criatura.\n\n"
            "Y después: pinza_ver para mirarlo, pinza_verifica para leer el "
            "disco.\n\n" + API,
        "inputSchema": {
            "type": "object",
            "properties": {
                "codigo": {"type": "string",
                           "description": "el guion. Recibe `pinza` como variable."},
                "nombre": {"type": "string",
                           "description": "cómo se llamará el paso en el historial."},
            },
            "required": ["codigo"],
        },
    },
    {
        "name": "pinza_rejilla",
        "description":
            "El dibujo como rejilla de caracteres con su leyenda de colores. "
            "Complementa a pinza_ver: la imagen sirve para juzgar el conjunto, "
            "esto para hablar de píxeles concretos ('la fila 12 sobra') y para "
            "saber exactamente qué color hay en cada sitio.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "que": {"type": "string", "enum": ["compuesto", "celda", "hoja"]},
                "fotograma": {"type": "integer"},
                "orientacion": {"type": "integer"},
            },
        },
    },
    {
        "name": "pinza_crear",
        "description":
            "Un documento nuevo. Con `contrato` sale con la geometría, los "
            "fotogramas y las orientaciones que manda el pack, que es la "
            "diferencia entre un lienzo suelto y algo que el juego sabrá leer "
            "al exportarlo. Los contratos disponibles salen en pinza_estado.\n"
            "OJO: sustituye lo que hubiera abierto. Si había algo sin guardar, "
            "pregunta antes.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "nombre": {"type": "string"},
                "ancho": {"type": "integer"},
                "alto": {"type": "integer"},
                "fotogramas": {"type": "integer"},
                "orientaciones": {"type": "array", "items": {"type": "string"},
                                  "description": "etiquetas de cara, p.ej. [\"S\",\"SE\",\"E\"]"},
                "contrato": {"type": "string", "description": "id de un contrato del pack"},
            },
        },
    },
    {
        "name": "pinza_medidas",
        "description":
            "Lo que se puede MEDIR del dibujo en vez de mirarlo: dónde apoyan "
            "los pies, cuánto ocupa la silueta, sus límites, los colores que "
            "hay de verdad y cómo va contra la guía de estilo del pack. Es la "
            "forma barata de comprobar el trabajo — 'catorce filas vacías bajo "
            "la figura' es un número, no una impresión.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "pinza_hoja",
        "description":
            "Trocea una hoja de sprites que YA existe y la abre como "
            "documento: las columnas son fotogramas y las filas "
            "orientaciones. Es la puerta de entrada para trabajar sobre algo "
            "hecho —una variante, un recolor, un rediseño— en vez de dibujarlo "
            "otra vez.\n"
            "Con `contrato` las filas se quedan con los nombres de cara del "
            "pack en vez de d0…d7, que es la diferencia entre ocho filas y "
            "ocho ORIENTACIONES: sin eso el editor no sabe cuál es el sur.\n"
            "OJO: sustituye lo que hubiera abierto.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "ruta": {"type": "string"},
                "ancho": {"type": "integer", "description": "ancho de celda. Por defecto 32."},
                "alto": {"type": "integer", "description": "alto de celda. Por defecto 32."},
                "contrato": {"type": "string", "description": "id de contrato del pack"},
                "orientaciones": {"type": "boolean",
                                  "description": "las filas son caras. Por defecto sí."},
                "nombre": {"type": "string"},
            },
            "required": ["ruta"],
        },
    },
    {
        "name": "pinza_referencia",
        "description":
            "Mete una imagen como CAPA DE CALCO: se ve mientras dibujas y no "
            "se exporta nunca. Úsala cuando te pidan una variante, un rediseño "
            "o «algo al estilo de X» — tener el original delante arregla las "
            "proporciones, que es lo único que no se puede deducir de una "
            "descripción.\n"
            "`fuente` admite tres cosas: una ruta local, una URL, o "
            "`pokeapi:pidgey` para traer un sprite de PokeAPI (se cachea en "
            "disco; la generación v es la que mejor pixel art tiene).\n"
            "Se recorta a lo dibujado y se reescala para caber en el lienzo, "
            "apoyada abajo — dos bichos comparten el suelo, no el centro.\n"
            "Después de meterla, mide con pinza_analiza y compara con "
            "pinza_compara: los números valen más que mirarla. Y no la calques "
            "píxel a píxel: sácale las proporciones y las rampas, y genera con "
            "pinza_dibuja.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "fuente": {"type": "string",
                           "description": "ruta local, URL, o pokeapi:nombre"},
                "generacion": {"type": "string", "enum": ["iii", "iv", "v"],
                               "description": "sólo para pokeapi. Por defecto v."},
                "dorso": {"type": "boolean", "description": "el sprite de espaldas"},
                "brillante": {"type": "boolean", "description": "la variante shiny"},
                "opacidad": {"type": "number", "description": "0 a 1. Por defecto 0.45."},
                "anclaje": {"type": "string", "enum": ["abajo", "centro"]},
                "nombre": {"type": "string"},
            },
            "required": ["fuente"],
        },
    },
    {
        "name": "pinza_analiza",
        "description":
            "Los números de un dibujo: caja, densidad, simetría, centro de "
            "masa, dónde apoyan los pies, el perfil de anchura por franjas "
            "—normalizado, así que compara entre tamaños distintos—, el "
            "histograma de valores y los colores AGRUPADOS EN RAMPAS.\n"
            "Las rampas son lo que hace posible una variante: una rampa se "
            "sustituye entera y el dibujo conserva su estructura de valores. "
            "Una lista de colores sueltos, no.\n"
            "`que`: 'todo' MIDE TODAS LAS CELDAS a la vez y es lo que quieres "
            "casi siempre — 'compuesto' mide sólo la que tienes delante, y un "
            "color que sólo salga en otro fotograma o en otra cara se te "
            "quedará sin tocar. También 'celda', 'capa' (con `capa`) y "
            "'referencia'.\n"
            "Trae el CONTORNO ya detectado, por posición y no por color: los "
            "píxeles con algún vecino transparente. `manda` dice cuánto pesa "
            "el color principal del borde; si es bajo, este dibujo no tiene un "
            "contorno claro y conviene mirarlo antes de fiarse.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "que": {"type": "string",
                        "enum": ["todo", "compuesto", "celda", "capa", "referencia", "hoja"],
                        "description": "'todo' son todas las celdas. Empieza por ahí."},
                "capa": {"type": "integer"},
                "fotograma": {"type": "integer"},
                "orientacion": {"type": "integer"},
                "franjas": {"type": "integer", "description": "franjas del perfil. Por defecto 16."},
            },
        },
    },
    {
        "name": "pinza_compara",
        "description":
            "Cuánto se parecen dos siluetas, en un número del 0 al 1. Por "
            "defecto compara lo que has dibujado contra la capa de calco.\n"
            "Escala una a la altura de la otra sin deformarla, así que "
            "compara FORMA y no tamaño, y devuelve además la relación de "
            "aspecto de cada una y la diferencia de anchura franja a franja — "
            "que es lo accionable: dice DÓNDE discrepan, no sólo que "
            "discrepan.\n"
            "Es la herramienta del ajuste fino: cambia un parámetro, vuelve a "
            "dibujar, vuelve a comparar, quédate con el que sube. Sin un "
            "número, ajustar es opinar.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "a": {"type": "object", "description": "{que, capa, fotograma, orientacion}"},
                "b": {"type": "object", "description": "idem. Por defecto la referencia."},
                "franjas": {"type": "integer"},
            },
        },
    },
    {
        "name": "pinza_criatura",
        "description":
            "Las criaturas: varias acciones —Idle, Walk, Attack…— cada una con "
            "su geometría, sus fotogramas y sus ocho caras. Trabajar sobre una "
            "criatura es trabajar sobre TODAS sus acciones; un recolor que "
            "sólo llega a una deja un bicho que cambia de color al pararse.\n"
            "`que`: 'catalogo' lista lo que el pack tiene bajado · 'traer' se "
            "baja una entera por su dex · 'acciones' dice cuáles tiene la "
            "abierta y en cuál estás · 'cambiar' salta a una (guardando sola "
            "la que dejas, así que se pueden recorrer en bucle) · 'guardar' "
            "recoge y guarda entera.\n"
            "Para aplicar algo a toda la criatura: 'acciones', y luego por "
            "cada una 'cambiar' + pinza_dibuja. Al final 'guardar'.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "que": {"type": "string",
                        "enum": ["catalogo", "traer", "acciones", "cambiar", "guardar"]},
                "dex": {"type": "integer", "description": "para 'traer'"},
                "nombre": {"type": "string"},
                "destino": {"type": "string",
                            "description": "carpeta donde dejarla. Se le añade el .especie."},
                "accion": {"type": "string", "description": "para 'cambiar'"},
            },
            "required": ["que"],
        },
    },
    {
        "name": "pinza_verifica",
        "description":
            "Lee los PNG YA ESCRITOS y dice qué está mal. Lo que se ve en el "
            "editor no es lo que sale: eso sólo lo dice el disco, y los fallos "
            "que importan no dan error en ningún sitio.\n"
            "Comprueba: colores fuera de la paleta que le des —un color sin "
            "sustituir en una variante—, celdas cuyo borde no es el contorno "
            "que esperas, celdas con contenido TOCANDO el borde del lienzo "
            "—algo recortado, o un dibujo que no cabe— y celdas vacías.\n"
            "Vale para un proyecto .pinza o para una criatura .especie entera. "
            "Hazlo siempre después de guardar una variante.\n"
            "Si es una variante, pásale `base` con el original: así sólo se te "
            "acusa de lo que has añadido tú. Sin eso te avisa de lo que ya "
            "venía en el material, y un aviso que salta siempre deja de "
            "leerse.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "ruta": {"type": "string", "description": "un .pinza o un .especie"},
                "paleta": {"type": "array", "items": {"type": "string"},
                           "description": "los #rrggbb que SÍ deben aparecer"},
                "contorno": {"type": "array", "items": {"type": "string"},
                             "description": "los #rrggbb que deben mandar en el borde"},
                "base": {"type": "string",
                         "description": "el proyecto del que salió esto. Con él sólo "
                                        "se te acusa de lo que has añadido tú."},
            },
            "required": ["ruta"],
        },
    },
    {
        "name": "pinza_convenciones",
        "description":
            "Qué reglas sigue de hecho el arte que YA existe en una carpeta: "
            "de qué color es el contorno, cuántos colores gasta un sprite, de "
            "qué tamaño son las hojas.\n"
            "Un pack trae una guía escrita, pero las convenciones que mandan "
            "están en los ficheros. Pregúntaselo al arte existente antes de "
            "decidir que lo mejoras: teñir un contorno negro que es negro en "
            "los ciento cincuenta y ocho bichos del juego hace que el tuyo "
            "cante desde lejos, y eso no se ve mirando el tuyo solo.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "carpeta": {"type": "string", "description": "dónde está el arte del juego"},
                "cuantos": {"type": "integer", "description": "cuántos ficheros mirar. Por defecto 8."},
            },
            "required": ["carpeta"],
        },
    },
    {
        "name": "pinza_capa",
        "description":
            "Las capas, por ÍNDICE. `que`: 'lista', 'elige' o 'borra'.\n"
            "Las órdenes del editor trabajan sobre la capa ACTIVA, que es lo "
            "correcto para una persona con el panel delante y una trampa para "
            "un programa: pedir «borra la capa» creyendo que se llevará el "
            "calco y que se lleve el dibujo es un error de una línea que no "
            "avisa. Aquí hay que decir cuál.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "que": {"type": "string", "enum": ["lista", "elige", "borra"]},
                "capa": {"type": "integer"},
            },
        },
    },
    {
        "name": "pinza_campos",
        "description":
            "Los campos que pide el contrato del pack: descripción, familia, a "
            "qué movimiento pertenece… Sin argumentos los lee; con un objeto "
            "los pone.\n"
            "Importan porque son lo que hace que el fichero exportado se dé de "
            "alta solo en el manifiesto del juego: un efecto sin su campo de "
            "movimiento es un PNG que nadie sabe de quién es. Rellénalos ANTES "
            "de exportar.",
        "inputSchema": {"type": "object", "properties": {
            "valores": {"type": "object", "description": "campo -> valor"}}},
    },
    {
        "name": "pinza_ordenes",
        "description":
            "Todas las órdenes del editor con su id, su título y si se pueden "
            "ahora mismo. Es el catálogo para pinza_orden.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "pinza_orden",
        "description":
            "Ejecuta una orden del editor por su id (voltearH, girar90, "
            "recortar, contornear, capaNueva, fotogramaNuevo, deshacer, "
            "espejoOrientacion…). Lo mismo que haría una persona con Ctrl+K.",
        "inputSchema": {
            "type": "object",
            "properties": {"id": {"type": "string"}},
            "required": ["id"],
        },
    },
    {
        "name": "pinza_abrir",
        "description":
            "Abre un proyecto .pinza, una criatura .especie o un PNG suelto. "
            "Se decide por la extensión.",
        "inputSchema": {
            "type": "object",
            "properties": {"ruta": {"type": "string"}},
            "required": ["ruta"],
        },
    },
    {
        "name": "pinza_guardar",
        "description":
            "Guarda. Con `ruta` guarda ahí (una carpeta .pinza); sin ella, "
            "donde ya estuviera. No exporta: para eso está pinza_exportar.",
        "inputSchema": {
            "type": "object",
            "properties": {"ruta": {"type": "string"}},
        },
    },
    {
        "name": "pinza_exportar",
        "description":
            "Exporta según el contrato del pack: escribe las hojas con el "
            "nombre y en la carpeta que el contrato manda.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def texto(t):
    return {"content": [{"type": "text", "text": t}]}


def fallo(t):
    return {"content": [{"type": "text", "text": t}], "isError": True}


def ejecuta(nombre, args):
    args = args or {}

    if nombre == "pinza_estado":
        return texto(json.dumps(pideJson("ficha"), ensure_ascii=False, indent=1))

    if nombre == "pinza_ver":
        spec = {k: args[k] for k in ("que", "escala", "fotograma", "orientacion", "fondo")
                if k in args}
        datos, r = imagen(spec)
        if datos is None:
            return fallo(r)
        pie = "%dx%d del original, a ×%d" % (
            r["origen"]["ancho"], r["origen"]["alto"], r["escala"])
        return {"content": [
            {"type": "image", "data": datos, "mimeType": "image/png"},
            {"type": "text", "text": pie},
        ]}

    if nombre == "pinza_dibuja":
        codigo = args.get("codigo") or ""
        if not codigo.strip():
            return fallo("no hay código que correr")
        r = pideJson("guion", codigo, args.get("nombre") or "la IA")
        if not r.get("bien"):
            linea = r.get("linea")
            return fallo("el guion falló%s: %s" % (
                (" en la línea %s" % linea) if linea else "", r.get("error")))
        salida = (r.get("salida") or "").strip()
        return texto("hecho, un paso en el historial"
                     + (("\n" + salida) if salida else ""))

    if nombre == "pinza_rejilla":
        spec = {k: args[k] for k in ("que", "fotograma", "orientacion") if k in args}
        r = pideJson("rejilla", json.dumps(spec))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo leer"))
        lineas = ["%dx%d" % (r["ancho"], r["alto"]), ""]
        lineas += r["filas"]
        lineas += ["", "leyenda ('.' es transparente):"]
        lineas += ["  %s = %s" % (k, v) for k, v in r["leyenda"].items()]
        if r.get("sinNombre"):
            lineas.append("  ? = %d píxeles de colores que no cupieron en la leyenda"
                          % r["sinNombre"])
        return texto("\n".join(lineas))

    if nombre == "pinza_crear":
        spec = {k: args[k] for k in
                ("nombre", "ancho", "alto", "fotogramas", "orientaciones", "contrato")
                if k in args}
        r = pideJson("crear", json.dumps(spec))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo crear"))
        return texto("«%s», %dx%d" % (r["nombre"], r["ancho"], r["alto"]))

    if nombre == "pinza_medidas":
        r = pideJson("medidas")
        if not r.get("bien"):
            return fallo(r.get("error", "no hay nada abierto"))
        return texto(json.dumps(r, ensure_ascii=False, indent=1))

    if nombre == "pinza_hoja":
        spec = {k: args[k] for k in
                ("ruta", "ancho", "alto", "contrato", "orientaciones", "nombre") if k in args}
        r = pideJson("hoja", json.dumps(spec))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo trocear"))
        #  Trocear lee un PNG, que es asíncrono: se espera a ver el documento
        #  en la ficha en vez de contestar un «hecho» que aún no es verdad.
        limite = time.time() + 20
        while time.time() < limite:
            d = (pideJson("ficha").get("documento")) or {}
            if d and d.get("ancho") == (args.get("ancho") or 32):
                return texto("%s · %dx%d · %d fotogramas · %d orientaciones"
                             % (d["nombre"], d["ancho"], d["alto"],
                                len(d["fotogramas"]), len(d["orientaciones"])))
            time.sleep(0.15)
        return fallo("la hoja no llegó a abrirse")

    if nombre == "pinza_referencia":
        try:
            ruta, origen = aFicheroLocal(args.get("fuente", ""),
                                         args.get("generacion"),
                                         bool(args.get("dorso")),
                                         bool(args.get("brillante")))
        except Exception as e:                          # noqa: BLE001
            return fallo("no he podido traer la referencia: %s" % e)
        etiqueta = args.get("nombre") or os.path.splitext(os.path.basename(ruta))[0]
        spec = {"ruta": ruta, "nombre": etiqueta}
        for k in ("opacidad", "anclaje"):
            if k in args:
                spec[k] = args[k]
        r = pideJson("referencia", json.dumps(spec))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo meter la referencia"))
        #  La capa se crea leyendo el PNG, que es asíncrono: se espera a verla
        #  en la ficha en vez de devolver un «hecho» que aún no es verdad.
        limite = time.time() + 15
        while time.time() < limite:
            f = pideJson("ficha")
            capas = ((f.get("documento") or {}).get("capas")) or []
            if any(c.get("tipo") == "referencia" for c in capas):
                return texto("calco «%s» puesto, desde %s.\n"
                             "No se exporta. Mídelo con pinza_analiza "
                             "{\"que\":\"referencia\"}." % (etiqueta, origen))
            time.sleep(0.15)
        return fallo("la referencia no llegó a aparecer como capa")

    if nombre == "pinza_analiza":
        spec = {k: args[k] for k in
                ("que", "capa", "fotograma", "orientacion", "franjas") if k in args}
        r = pideJson("analiza", json.dumps(spec))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo medir"))
        return texto(json.dumps(r, ensure_ascii=False, indent=1))

    if nombre == "pinza_compara":
        spec = {k: args[k] for k in ("a", "b", "franjas") if k in args}
        r = pideJson("compara", json.dumps(spec))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo comparar"))
        return texto(json.dumps(r, ensure_ascii=False, indent=1))

    if nombre == "pinza_criatura":
        que = args.get("que")
        if que == "catalogo":
            r = pideJson("catalogo")
            if r.get("leyendo"):
                limite = time.time() + 20
                while time.time() < limite:
                    time.sleep(0.3)
                    r = pideJson("catalogo")
                    if not r.get("leyendo"):
                        break
            if not r.get("bien"):
                return fallo(r.get("error") or "no se pudo leer el catálogo")
            return texto("%d criaturas:\n%s" % (r["cuantas"], ", ".join(
                "%s (%d)" % (c["nombre"], c["dex"]) for c in r["criaturas"])))

        if que == "traer":
            if args.get("dex") is None:
                return fallo("hace falta un dex; míralos con que:'catalogo'")
            spec = {k: args[k] for k in ("dex", "nombre", "destino") if k in args}
            r = pideJson("traer", json.dumps(spec))
            if not r.get("bien"):
                return fallo(r.get("error", "no se pudo traer"))
            #  Importar son ocho proyectos escritos a disco; se espera a que la
            #  ficha diga que hay criatura y a que aparezcan las carpetas.
            limite = time.time() + 120
            while time.time() < limite:
                f = pideJson("ficha")
                c = f.get("criatura")
                if c and c.get("ruta") and os.path.isdir(os.path.expanduser(c["ruta"])):
                    import glob as _g
                    if _g.glob(os.path.join(os.path.expanduser(c["ruta"]), "*.pinza")):
                        return texto("«%s» en %s · acciones: %s"
                                     % (c["nombre"], c["ruta"], ", ".join(c["acciones"])))
                time.sleep(0.5)
            return fallo("la criatura no llegó a escribirse entera")

        if que == "acciones":
            r = pideJson("accion", "")
            if not r.get("bien"):
                return fallo(r.get("error", "no hay criatura"))
            return texto("acciones: %s\nahora en: %s"
                         % (", ".join(r["acciones"]), r["accion"] or "(ninguna)"))

        if que == "cambiar":
            a = args.get("accion")
            if not a:
                return fallo("hace falta una acción")
            r = pideJson("accion", a)
            if not r.get("bien"):
                return fallo(r.get("error", "no se pudo cambiar"))
            limite = time.time() + 60
            while time.time() < limite:
                f = pideJson("ficha")
                if ((f.get("criatura") or {}).get("accion") == a) and f.get("documento"):
                    d = f["documento"]
                    return texto("%s · %dx%d · %d fotogramas · %d caras"
                                 % (a, d["ancho"], d["alto"],
                                    len(d["fotogramas"]), len(d["orientaciones"])))
                time.sleep(0.3)
            return fallo("la acción «%s» no llegó a abrirse" % a)

        if que == "guardar":
            r = pideJson("guardarCriatura")
            if not r.get("bien"):
                return fallo(r.get("error", "no se pudo guardar"))
            time.sleep(1.5)
            return texto("guardada en " + r["ruta"])

        return fallo("no sé qué es «%s»" % que)

    if nombre == "pinza_verifica":
        try:
            inf = verifica(args.get("ruta", ""), args.get("paleta"),
                           args.get("contorno"), args.get("base"))
        except Exception as e:                          # noqa: BLE001
            return fallo("no se pudo verificar: %s" % e)
        lineas, limpio = [], True
        for r in inf:
            partes = []
            if r["coloresFuera"]:
                limpio = False
                partes.append("colores fuera de la paleta: "
                              + " ".join(c for c, _ in r["coloresFuera"][:6]))
            if r["contornoRaro"]:
                limpio = False
                partes.append("contorno distinto en %d celdas (p.ej. %s -> %s)"
                              % (len(r["contornoRaro"]), r["contornoRaro"][0][0],
                                 r["contornoRaro"][0][1]))
            if r["tocanElBorde"]:
                limpio = False
                partes.append("%d celdas tocan el borde del lienzo%s (%s…)"
                              % (len(r["tocanElBorde"]),
                                 " QUE ANTES NO" if r.get("conBase") else "",
                                 r["tocanElBorde"][0]))
            elif r.get("yaTocaban"):
                partes.append("%d tocaban el borde ya en el original" % r["yaTocaban"])
            if r["vacias"]:
                partes.append("%d celdas vacías" % r["vacias"])
            lineas.append("%-10s %3d celdas · %s"
                          % (r["accion"], r["celdas"],
                             " · ".join(partes) if partes else "sin nada que decir"))
            lineas.append("           borde: " + " ".join("%s(%d)" % (c, n) for c, n in r["anillo"]))
        cabeza = ("todo en orden" if limpio else
                  "HAY COSAS QUE MIRAR — lo de abajo está en el disco, no en la pantalla")
        return texto(cabeza + "\n\n" + "\n".join(lineas))

    if nombre == "pinza_convenciones":
        try:
            c = convenciones(args.get("carpeta", ""), args.get("cuantos") or 8)
        except Exception as e:                          # noqa: BLE001
            return fallo("no se pudo mirar: %s" % e)
        return texto(
            "mirados %d ficheros\n"
            "contorno de la casa: %s\n"
            "colores por hoja: de %d a %d\n"
            "tamaños: %s"
            % (c["ficheros"],
               " · ".join("%s %.0f%% del borde" % (x["color"], x["delAnillo"] * 100)
                          for x in c["contorno"]),
               c["coloresPorHoja"]["minimo"], c["coloresPorHoja"]["maximo"],
               ", ".join("%s (x%d)" % (t, n) for t, n in c["tamaños"])))

    if nombre == "pinza_capa":
        spec = {k: args[k] for k in ("que", "capa") if k in args}
        r = pideJson("capa", json.dumps(spec))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo"))
        if "capas" in r:
            return texto("\n".join(
                "%d  %-16s %-11s %s" % (c["i"], c["nombre"], c["tipo"],
                                        "<- activa" if c.get("activa") else "")
                for c in r["capas"]))
        return texto("capa %d: %s" % (r["capa"], r["nombre"]))

    if nombre == "pinza_campos":
        r = pideJson("campos", json.dumps(args.get("valores") or {}))
        if not r.get("bien"):
            return fallo(r.get("error", "no se pudo"))
        lin = ["%-14s %s" % (k, "—" if v in (None, "") else v)
               for k, v in (r["campos"] or {}).items()]
        if r.get("ignorados"):
            lin.append("IGNORADOS (el contrato no los pide): "
                       + ", ".join(r["ignorados"]))
        return texto("\n".join(lin) or "este contrato no pide campos")

    if nombre == "pinza_ordenes":
        r = pideJson("ordenes")
        if not isinstance(r, list):
            return fallo("no se pudo leer la lista")
        return texto("\n".join(
            "%-22s %-44s %s" % (o["id"], o["titulo"],
                                "" if o["disponible"] else "(ahora no)")
            for o in r))

    if nombre == "pinza_orden":
        return texto(pide("orden", args.get("id", "")))

    if nombre == "pinza_abrir":
        ruta = args.get("ruta", "")
        verbo = ("especie" if ruta.endswith(".especie")
                 else "imagen" if os.path.splitext(ruta)[1].lower() in
                 (".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp")
                 else "abrir")
        return texto(pide(verbo, ruta))

    if nombre == "pinza_guardar":
        if args.get("ruta"):
            r = pideJson("guardarEn", args["ruta"])
            if not r.get("bien"):
                return fallo(r.get("error", "no se pudo guardar"))
            return texto("guardando en " + r["ruta"])
        return texto(pide("guardar"))

    if nombre == "pinza_exportar":
        return texto(pide("exportar"))

    return fallo("no existe la herramienta «%s»" % nombre)


# ═══════════════════════════════════════════════════════════════
# el protocolo
# ═══════════════════════════════════════════════════════════════

def responde(id_, resultado=None, error=None):
    m = {"jsonrpc": "2.0", "id": id_}
    if error is not None:
        m["error"] = error
    else:
        m["result"] = resultado
    sys.stdout.write(json.dumps(m, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main():
    for linea in sys.stdin:
        linea = linea.strip()
        if not linea:
            continue
        try:
            m = json.loads(linea)
        except json.JSONDecodeError:
            continue

        metodo = m.get("method")
        id_ = m.get("id")

        #  Sin id es una notificación y no lleva respuesta. Contestarlas es la
        #  forma más rápida de que un cliente estricto corte la conexión.
        if id_ is None:
            continue

        if metodo == "initialize":
            quiere = (m.get("params") or {}).get("protocolVersion")
            responde(id_, {
                "protocolVersion": quiere if quiere in VERSIONES else VERSIONES[0],
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "pinza", "version": "2.0.0"},
                "instructions": GUIA,
            })
        elif metodo == "tools/list":
            responde(id_, {"tools": HERRAMIENTAS})
        elif metodo == "tools/call":
            p = m.get("params") or {}
            try:
                responde(id_, ejecuta(p.get("name"), p.get("arguments")))
            except SinVentana as e:
                responde(id_, fallo("Pinza no está abierta y no he podido "
                                    "abrirla: %s" % e))
            except Exception as e:                      # noqa: BLE001
                responde(id_, fallo("%s: %s" % (type(e).__name__, e)))
        elif metodo in ("resources/list", "resources/templates/list"):
            responde(id_, {"resources": [], "resourceTemplates": []})
        elif metodo == "prompts/list":
            responde(id_, {"prompts": []})
        elif metodo == "ping":
            responde(id_, {})
        else:
            responde(id_, error={"code": -32601,
                                 "message": "método desconocido: %s" % metodo})


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass

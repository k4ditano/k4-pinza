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
            "sombreado. Sale mejor y se corrige cambiando un número.\n\n" + API,
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
            "`que`: 'compuesto', 'celda', 'capa' (con `capa`) o 'referencia'.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "que": {"type": "string",
                        "enum": ["compuesto", "celda", "capa", "referencia", "hoja"]},
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
                "serverInfo": {"name": "pinza", "version": "1.0.0"},
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

# pinza

Un editor de pixel art en [Quickshell](https://quickshell.org/) que sabe qué
estás dibujando antes de que empieces.

    qs -p ~/Proyectos/pinza

## La idea

LibreSprite y Aseprite dibujan píxeles muy bien. Lo que ninguno de los dos sabe
es **qué** estás dibujando: que este objeto mide 32×32 salvo cuando se levanta y
entonces 48 de alto; que si es rectangular necesita cuatro ficheros llamados
`_N`, `_E`, `_S` y `_W` y que girarlo también gira su huella; que una hoja de
criatura es columnas × 8 filas en un orden de orientaciones que no se puede
equivocar, con una duración por fotograma medida en tics de 1/60 s.

Todo eso vive normalmente en tu cabeza y en un manifiesto que editas a mano
después de exportar. Aquí el **contrato es lo primero que eliges** y todo lo
demás sale de ahí: el tamaño del lienzo, cuántos fotogramas, cuántas
orientaciones, cómo se llama el fichero, dónde se copia y qué línea se escribe
en el manifiesto.

Los contratos los trae un **pack**. El pack «genérico» no impone nada y es el que
sale por defecto, así que esto sirve para cualquier juego. El pack de
[crabh](https://github.com/k4ditano/crabh) trae los cinco perfiles de ese juego
concreto. Escribir uno nuevo es un JSON.

**No hay límites de color en ninguna parte.** Un pack puede traer una guía —el de
crabh la trae— pero es un cuentakilómetros, no una barrera: te dice dónde estás y
se apaga en Ajustes.

## Lo que tiene

**Tres ejes.** Una celda se direcciona con capa × fotograma × **orientación**.
Aseprite tiene dos y por eso una hoja de ocho caras hay que montarla a mano; aquí
la orientación es un eje de primera clase, y para un icono simplemente vale uno y
el compás ni se enseña.

**El compás.** Las orientaciones en su disposición geográfica, con enlace de
espejo: dibujas el este y el oeste se genera volteado. Un punto bajo las caras
que todavía están en blanco.

**La tira.** Cada fotograma **mide lo que dura**, en tics de 1/60 s, con una
regla debajo. Arrastrando su borde derecho se retima la animación mirándola. Ver
que el fotograma de impacto dura cuatro tics y el de recuperación doce es lo que
hace que un golpe se sienta bien, y con un diálogo por fotograma eso no se ve.

**Rampas, no una rejilla de colores.** La unidad de trabajo es sombra → cuerpo →
brillo, que es como se piensa dibujando. La tinta de sombreado mueve cada píxel
un paso por *su* rampa en vez de aplastarlo con un color plano; lo que no está en
ninguna rampa no lo toca.

**Medidas de silueta.** Un juego que lee de los píxeles dónde apoyan los pies y
cuánto mide la silueta merece verlas mientras dibujas: tres filas vacías de más
cambian dónde pisa el bicho y en el lienzo eso no se nota. Van sobre el dibujo y
en la previa.

**Previa en juego.** El sprite animándose a ×1, ×2 y ×3 sobre un suelo, con su
sombra. Lo que importa no es cómo se ve al 800 % de zoom.

**Modo baldosa de verdad.** El lienzo envuelve: dibujas cruzando la costura y el
trazo sale por el otro lado, con las ocho repeticiones alrededor.

**Mapa de prueba.** Un tileset no se juzga mirando la hoja: se juzga viéndolo
repartido por un campo, que es donde salen las costuras y donde se ve que la flor
que parecía bonita, puesta cada tres casillas, convierte el prado en una
alfombra. El reparto no está inventado — es el mismo que hace el juego: sólo
casillas enteras opacas y no blancas, ordenadas por varianza de luminancia, el
40 % más plano como suelo y el resto salpicado.

**Guiones en JavaScript.** El mismo idioma en el que ya está escrito el
programa, así que no hay otro intérprete ni una traducción del modelo por medio.
Un guión recibe un objeto `pinza` y trabaja contra el documento abierto; todo lo
que haga entra en el historial como **un** paso, para que se pueda probar sin
miedo. Vienen tres de ejemplo: contornear la silueta en todas las orientaciones,
centrar cada celda, y apoyar la figura en el suelo con el mismo hueco en todos
los fotogramas.

**Sin menús y sin diálogos modales.** `Ctrl+K` para cualquier orden, buscando por
trozos sueltos («vol h» encuentra «Voltear en horizontal») y enseñando sólo lo
que se puede hacer ahora. Botón derecho sostenido sobre el lienzo para la rueda
de herramientas, que sale alrededor del cursor. Todo lo demás son hojas que
entran por la derecha y dejan el lienzo a la vista.

Y lo de siempre: selección por marco, elipse, lazo, lazo poligonal, varita y
color, con sumar/restar/cortar; lápiz con trazo perfecto, goma, cubo,
cuentagotas, líneas, rectángulos, elipses, degradado tramado, difuminar,
manchar, aclarar, quemar, sustituir color; pinceles a medida desde una
selección; dieciocho modos de fusión, grupos anidables, bloqueo de alfa, capas de
referencia;
voltear, girar, escalar por vecino cercano o con suavizado tipo RotSprite,
sesgar, recortar al contenido; piel de cebolla teñida, etiquetas con ida, vuelta
y vaivén, celdas enlazadas; simetría, rejilla de píxel y de casilla; paletas
`.gpl`, `.hex` y desde PNG; cuantizar; GIF y APNG; historial visible al que se
salta de un clic.

## Cómo está hecho

    shell.qml          la ventana; reparte el sitio y nada más
    core/              el motor y las piezas de interfaz
      pixeles.js       búferes, mezcla, formas, transformaciones, paleta
      herramientas.js  qué hace cada herramienta
    servicios/         el estado, en singletons
      Documento.qml    capas × fotogramas × orientaciones
      Historial.qml    deshacer por comandos, no por instantáneas
      Ordenes.qml      todo lo que el programa sabe hacer, en una lista
      Proyecto.qml     guardar, abrir, exportar
      Guiones.qml      correr JavaScript contra el documento
      Forja.qml        el único sitio que lanza procesos
    vistas/            lienzo, compás, tira, paneles, hojas
    packs/             genérico.json, crabh.json — y los tuyos
    forja/forja.py     lo que toca ficheros
    cata/              las cinco cosas que había que probar antes de empezar
    pruebas/           todo lo demás, en seco

El dibujo vive en un objeto JS dentro de `PersistentProperties` y no en un árbol
de propiedades QML, por dos razones que importan las dos: Quickshell **recarga la
configuración cada vez que guardas un `.qml`**, y sin eso tocar el código
mientras dibujas se lleva el dibujo por delante; y QML no avisa cuando mutas por
dentro un `property var`, así que en vez de pelearse con eso hay dos contadores
—`rev` y `revPixeles`— a los que se enganchan las vistas. Separarlos es lo que
hace que un trazo no reconstruya la lista de capas sesenta veces por segundo.

Cómo se apilan las capas lo sabe **una sola función**, `Documento.componEn`. La
usan el lienzo —que sólo recompone el rectángulo que ensució el trazo— y la
exportación, que lo hace entero. Tenerlo dos veces sería tener dos respuestas
distintas a «cómo se ve esto», y la que saldría por el PNG no tendría por qué ser
la que ves.

El zoom no lo hace el Canvas: el Canvas está siempre a 1:1 con el sprite y quien
lo agranda es la GPU, sin suavizar. Por eso da igual dibujar al 100 % o al
3200 %, el trabajo de la CPU es el mismo. Y lo que se repinta es sólo el
rectángulo que ensució el trazo.

### Dos cosas de Qt que conviene saber antes de tocar el lienzo

Están comprobadas en `cata/cata.qml`, que se sigue ejecutando con las demás
pruebas para que nos enteremos el día que dejen de ser verdad.

- **`putImageData` de tres argumentos no hace nada.** Se traga los píxeles sin
  quejarse. La forma de siete —`putImageData(img, 0, 0, x, y, w, h)`— sí
  funciona, y es la única que se usa en todo el programa.
- **`Canvas.save()` devuelve `false` y no escribe.** Exportar es `toDataURL` y
  que la forja escriba el fichero. Leer va al revés y **no** por el Canvas:
  cargar una imagen y leerla con `getImageData` depende de que esté lista justo
  cuando toca pintar, y al arrancar no lo está — devolvía capas vacías sin dar
  ningún error. Las imágenes entran por la forja, con Pillow.

## El formato de proyecto

Una carpeta con un JSON y un PNG por celda:

    Cangrejito.pinza/
      proyecto.json          contrato, capas, fotogramas, duraciones, enlaces
      celdas/c1.0.3.png      capa . fotograma . orientación
      paleta.gpl

Nada de un binario propio, y por tres razones que se notan a diario: se ve en un
`git diff`, se puede abrir un fotograma suelto en cualquier otro editor mientras
a pinza le falte una herramienta, y si mañana el programa no arranca el arte
sigue estando ahí.

## Guiones

    ~/.config/pinza/guiones/*.js

Un guión recibe `pinza` y trabaja contra el documento abierto:

```js
pinza.paraCada((buf, capa, fotograma, orientacion) => {
  pinza.paraCadaPixel(buf, (c, x, y) => {
    if (c[3] === 0) return
    return pinza.color('#D66C34')
  })
})
pinza.log('listo')
```

`pinza.px` es el motor de píxeles entero, por si hace falta algo que la API no
trae — pero entonces te toca a ti no romper nada. Un guión que revienta a mitad
se cancela sin dejar rastro en el historial.

## Packs

Los del programa están en `packs/`. Los tuyos van en
`~/.config/pinza/packs/*.json` y ganan si repiten `id`, que es la forma de
retocar uno de serie sin tocar el repositorio. Un pack declara sus paletas en
rampas, sus contratos —lienzo, ejes, patrón de nombre, carpeta de salida— y, si
quiere, un manifiesto que parchear y una guía de estilo informativa.

La raíz del repositorio de un pack se puede reapuntar desde el propio programa:
el pack se comparte, la ruta a tu copia del juego no.

## Pruebas

    ./pruebas/correr            todas
    ./pruebas/correr Motor      sólo una

Se corren con `QT_QPA_PLATFORM=offscreen`, así que valen por SSH o en un gancho
de git. El motor de píxeles y las herramientas son JavaScript puro y se
comprueban sin abrir nada; la ida y la vuelta entera —dibujar, guardar, cerrar,
abrir, exportar— se comprueba con Pillow leyendo los PNG desde fuera, que es la
única forma de saber que lo que se ve es lo que sale.

## Hace falta

Quickshell, Qt 6 (`qt6-base`, `qt6-declarative`), Python 3 con Pillow, y las
fuentes `Adwaita Sans` y `MesloLGS Nerd Font Mono` para la interfaz.

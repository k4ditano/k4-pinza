# K4 Pinza

Un editor de pixel art en [Quickshell](https://quickshell.org/) que sabe qué
estás dibujando antes de que empieces.

    ./instalar          # y luego, desde donde sea:
    pinza

El programa se llama **K4 Pinza**. El comando es `pinza` a secas, y también lo
son la extensión de los ficheros y la carpeta de ajustes: eso no es el nombre,
es lo que se teclea.

*(In English: [README.en.md](README.en.md))*

![El editor](capturas/editor.png)

| | |
|---|---|
| ![La previa en juego](capturas/previa.png) | ![El color](capturas/color.png) |
| **La previa en juego.** El sprite sobre el suelo a ×1, ×2 y ×3, con su sombra y las medidas que el juego saca de los píxeles — y el aviso de que catorce filas vacías bajo la figura son catorce píxeles de aire donde debería apoyar. | **El color.** Rampas de nueve tonos, no de tres, y la rueda dentro del panel: elegir un color no debería taparte el dibujo que estás mirando para decidirlo. |

![La paleta de comandos](capturas/comandos.png)

Sin menús: `Ctrl+K` y se busca por trozos sueltos. Sólo sale lo que se puede
hacer ahora mismo.

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

**Cambiar un color en toda la criatura.** Sustituir color pregunta hasta dónde
llega: esta celda, todos los fotogramas de esta cara, o todos los fotogramas de
las ocho — y opcionalmente todas las capas. Recolorear un bicho celda a celda en
una hoja de once fotogramas por ocho filas son ochenta y ocho clics, y basta
fallar uno para que la animación parpadee. Todo el cambio es **un** paso del
historial. Respeta la selección si la hay.

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

**La muestra, a tamaño real.** Flotando sobre el lienzo y arrastrable a donde
estorbe menos. Dibujando estás siempre a ×8 o a ×16, y a ese aumento cualquier
cosa parece bien: los contornos se leen, las sombras se separan, todo respira. A
tamaño real la mitad de eso desaparece, y sin verlo mientras dibujas te enteras
al exportar. Enseña ×1, ×2 y ×3 —los que quepan— y se anima con la tira.

La reproducción va **al ritmo que dice ir**: la manda el reloj de pared, no el
temporizador. Antes cada disparo avanzaba un tic exacto, así que la animación
iba a la velocidad a la que Qt lograra disparar — medido, un 39 % lenta. Como el
sentido de todo esto es que lo que ves aquí sea lo que se ve en el juego, ir
lento no es un defecto de acabado: es que la herramienta miente.

**Previa en juego.** El sprite animándose sobre un suelo, con su sombra y las
medidas que el juego saca de los píxeles. Lo que importa no es cómo se ve al
800 % de zoom.

**Lo marcado se transforma solo.** Voltear, girar y escalar respetan la
selección: si hay algo marcado tocan sólo eso y dejan el resto del dibujo donde
estaba, y la marca se transforma con el dibujo para poder encadenar sin volver a
seleccionar. Es la mitad del trabajo de animar — marcas un brazo, lo volteas;
copias una pata, la pegas en el fotograma siguiente y la mueves. Lo pegado queda
seleccionado y con la herramienta de mover ya puesta.

**Girar y escalar a ojo** (`Ctrl+T`), con el resultado a la vista mientras mueves
el mando. Cada cambio se rehace **desde el estado de partida**, nunca sobre el
anterior: girar cinco grados cinco veces no es girar veinticinco, es deshacer el
dibujo remuestreando lo ya remuestreado. Y probar veinte ángulos deja **una** sola
entrada en el historial, la del que aceptaste.

El giro y el escalado pasan por RotSprite: agrandar ×8 limpiando las escaleras,
transformar, y volver a encoger quedándose con el color que más se repite en cada
bloque. Promediar sería lo fácil y es justo lo que estropea un giro en pixel art,
porque mete colores que no están en la paleta.

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

**Se ve cuando está trabajando.** Importar una criatura son ocho proyectos y
quinientas celdas: sale un anillo de píxeles con lo que está haciendo y por
dónde va. Aparece con retardo a propósito —guardar un icono tarda cincuenta
milisegundos y un parpadeo de rueda en cada guardado cansa más que informar— y
si algo se atasca deja de bloquear, porque una pantalla de carga que no se va es
peor que un fallo.

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

### Lo que este Qt hace mal, y hay que saber antes de tocar el lienzo

Están comprobadas en `cata/cata.qml`, que se sigue ejecutando con las demás
pruebas para que nos enteremos el día que dejen de ser verdad. Ninguna da error:
todas fallan en silencio, que es lo que las hace caras.

- **`putImageData` de tres argumentos no hace nada.** Se traga los píxeles sin
  quejarse. La forma de siete —`putImageData(img, 0, 0, x, y, w, h)`— sí
  funciona, y es la única que se usa en todo el programa.
- **En la de siete, el origen sucio tiene que ser `(0,0)`.** Pasarle el lienzo
  entero con un rectángulo sucio en `(10,10)` tampoco pinta nada, otra vez sin
  quejarse. Hay que recortar un `ImageData` del tamaño de la zona sucia y
  colocarlo con `dx,dy`. Esto costó caro: el lienzo repinta por zona sucia, así
  que un trazo no llegaba nunca a la pantalla y aparecía de golpe cuando algo
  forzaba un repintado entero — «dibujo y sale al lado».
- **`putImageData` mezcla en vez de reemplazar**, que es justo lo contrario de
  lo que dice su definición. Un píxel transparente encima de uno opaco no lo
  borra: lo deja igual. Con eso, la goma no borraba nada y deshacer no deshacía
  nada — a la vista, porque por dentro las dos funcionaban perfectamente. Hay
  que limpiar la zona antes de volcarla.
- **`Canvas.save()` devuelve `false` y no escribe.** Y aunque `toDataURL`
  funciona, escribir por ahí cuesta **un repintado por fichero**: una criatura
  de PMD son quinientas celdas y eran ocho segundos de programa bloqueado. Los
  píxeles van a la forja en base64 y los escribe Pillow, todos en un mensaje. Exportar es `toDataURL` y
  que la forja escriba el fichero. Leer va al revés y **no** por el Canvas:
  cargar una imagen y leerla con `getImageData` depende de que esté lista justo
  cuando toca pintar, y al arrancar no lo está — devolvía capas vacías sin dar
  ningún error. Las imágenes entran por la forja, con Pillow.
- **`createImageData` envenena el motor.** Cada llamada engorda algo que la
  recogida de basura no suelta, y a partir de unas cuarenta el motor entra en
  marcado continuo: **cualquier** reserva de memoria —un objeto, un texto, un
  búfer— pasa de ser gratis a costar medio milisegundo. No se cura con `gc()`,
  ni cerrando el documento, ni soltando las referencias; sólo recargando el
  motor entero. El síntoma era cambiar de acción tres veces en una criatura y
  que a partir de ahí **todo** el programa fuera lento, para siempre. Por eso
  cada lienzo tiene **un** `ImageData` que sólo crece (`P.lienzoImg`): uno más
  grande que la zona vale igual si cada fila se escribe con su paso.
- **`String.fromCharCode.apply` con un array de tipado devuelve caracteres
  nulos.** Sin error y con la longitud correcta: el texto sale entero y todo a
  cero. Codificar a base64 con un `Uint16Array` de códigos guardaba ficheros en
  blanco sin que nada se quejara.

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

## Criaturas enteras

Una criatura no es una hoja: es **una por acción** —quieto, andar, atacar,
dolerse, cargar, brincar, dormir, disparar— más el `AnimData.xml` que las ata y
la ficha que la da de alta en el juego. Los tres tienen que estar de acuerdo, y
ese acuerdo es justo lo que se rompe haciéndolo a mano.

`Ctrl+Shift+E`, o «Especie» en la paleta de comandos. Dos formas de empezar:

**Traer una del juego y retocarla.** Lee lo que crabh tiene bajado —las 158 que
haya— y trocea sus hojas con la geometría **de verdad**: el tamaño de fotograma,
las duraciones en tics y los fotogramas de golpe salen de `species.json`, que a
su vez sale del `AnimData.xml` original. Adivinar la rejilla de una hoja PMD sale
mal —hay acciones de dos fotogramas y de once— y adivinar las duraciones sale mal
siempre. Cada acción queda como un proyecto normal, con sus capas y su deshacer.

**Empezar una en blanco.** Nacen las ocho acciones vacías pero con la geometría
**puesta**: cada una con su tamaño, sus fotogramas, sus duraciones y sus
fotogramas de golpe, y las ocho filas en el orden que lee el juego. Si eso hay
que teclearlo, la plantilla no sirve de nada.

Mientras la dibujas, el panel de **acciones** dice en cuál estás, cuáles tienen
ya algo dibujado y salta de una a otra de un clic (o con `Alt+←` / `Alt+→`).
Cambiar de acción guarda antes la que dejas.

Un proyecto de especie es una carpeta:

    Cangrejito.especie/
      especie.json      quién es: dex, papel, sombra, y qué acción tiene qué
      Idle.pinza/       cada una es un proyecto normal
      Walk.pinza/
      Attack.pinza/

Y exportar escribe las tres cosas de golpe: una hoja por acción en
`assets/species/<nombre>/`, el `AnimData.xml` con todas, y
`assets/species/<nombre>.json` con su mitad de pokédex — tipos y habilidades como
cadenas normales, para que una criatura tuya lea la misma tabla de tipos que una
de verdad y no sea un caso especial en ninguna parte.

## Efectos de ataque

La animación que sale al usar un movimiento, con su perfil propio. Lo que importa
ahí es el **nombre del fichero**, porque de él saca el juego la rejilla:

| | |
|---|---|
| una orientación | `Mordisco_Feroz.8.png` — una tira de 8 fotogramas |
| ocho orientaciones | `Rayo_Guiado.Dir8.png` — 8 filas, una por dirección |

Equivocarse no da error: da un efecto que se reproduce a trozos. Aquí lo decide
el contrato a partir de cuántas orientaciones tenga el documento, y exportar
escribe además la entrada del manifiesto con su tipo y el movimiento al que
pertenece.

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

Pulsar, arrastrar y soltar son funciones normales del lienzo y el ratón sólo las
llama, así que `pruebas/Puntero.qml` puede pinchar en coordenadas de la vista y
comprobar dos cosas distintas: que el píxel entra en la capa correcta, y que
además **se ve** en pantalla. No es lo mismo, y el día que dejaron de serlo el
programa parecía dibujar «al lado», la goma no borraba y deshacer no deshacía —
las tres cosas con el modelo perfecto por dentro.

## Instalar

    ./instalar          instalar o actualizar
    ./instalar --quitar deshacerlo

No copia nada: lo que instala son **enlaces**. El código se queda donde está, así
que seguir desarrollando aquí es seguir usando lo instalado, sin volver a
instalar. Todo va a tu directorio — nada de `sudo`, nada fuera de `$HOME`:

| | |
|---|---|
| `~/.local/bin/pinza` | el lanzador |
| `~/.local/share/applications/pinza.desktop` | para que salga en el menú |
| `~/.local/share/icons/hicolor/*/apps/pinza.png` | el icono, que lo dibuja `tools/icono.py` |
| `~/.config/quickshell/pinza` | un enlace al repositorio, para `qs -c pinza` |

Desinstalar no toca tus proyectos, tus packs ni tus guiones: eso vive en
`~/.config/pinza/`.

### El lanzador

    pinza                    abrir el editor
    pinza Bicho.pinza        abrir ese proyecto
    pinza dibujo.png         importarlo como capa
    pinza --nuevo            la hoja de documento nuevo
    pinza --estado           qué hay abierto ahora mismo
    pinza --mostrar          devolver la ventana si la cerraste

Si ya hay una ventana abierta, **se le habla en vez de arrancar otra**. Dos
instancias no se llevan mal —cada una tiene su documento— pero se pisarían los
ajustes, y sobre todo no es lo que espera nadie al hacer doble clic en un
proyecto. Por debajo es el IPC de Quickshell, que también sirve desde un guion:

    qs -c pinza ipc call pinza estado
    qs -c pinza ipc call pinza abrir /ruta/al/proyecto.pinza
    qs -c pinza ipc call pinza exportar
    qs -c pinza ipc call pinza orden deshacer     # cualquier orden, por su id

### El icono

Es pixel art, como debe ser: la silueta se escribe a mano en una rejilla de 32×32
en `tools/icono.py` y el sombreado sale de una regla —contorno en el borde,
brillo donde roza el fondo por arriba y por la izquierda, sombra por abajo y por
la derecha— que es un foco arriba a la izquierda, como el arte del juego. Se
escala por vecino más próximo a 32, 64, 128 y 256, todos múltiplos enteros para
que ninguno salga con píxeles a medias.

## Hace falta

Quickshell, Qt 6 (`qt6-base`, `qt6-declarative`), Python 3 con Pillow, y las
fuentes `Adwaita Sans` y `MesloLGS Nerd Font Mono` para la interfaz. `./instalar`
lo comprueba y te lo dice antes de hacer nada.

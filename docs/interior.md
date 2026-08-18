# Por dentro

Notas para quien vaya a tocar el código. Lo que hay aquí no está en el README a
propósito: al que sólo quiere dibujar no le sirve de nada, y al que va a abrir
`vistas/Lienzo.qml` le ahorra una tarde.

## Cómo está repartido

    shell.qml          la ventana; reparte el sitio y nada más
    core/              el motor y las piezas de interfaz
      pixeles.js       búferes, mezcla, formas, transformaciones, paleta
      herramientas.js  qué hace cada herramienta
    servicios/         el estado, en singletons
      Documento.qml    capas × fotogramas × orientaciones
      Historial.qml    deshacer por comandos, no por instantáneas
      Ordenes.qml      todo lo que el programa sabe hacer, en una lista
      Proyecto.qml     guardar, abrir, exportar
      Especie.qml      personajes de varias acciones
      Guiones.qml      correr JavaScript contra el documento
      Forja.qml        el único sitio que lanza procesos
    vistas/            lienzo, compás, tira, paneles, hojas
    packs/             los contratos y las paletas
    forja/forja.py     lo que toca ficheros
    cata/              las trampas de Qt, como aserciones
    pruebas/           todo lo demás, en seco

El dibujo vive en un objeto JS dentro de `PersistentProperties` y no en un árbol
de propiedades QML, por dos razones que importan las dos: Quickshell **recarga
la configuración cada vez que guardas un `.qml`**, y sin eso tocar el código
mientras dibujas se lleva el dibujo por delante; y QML no avisa cuando mutas por
dentro un `property var`, así que en vez de pelearse con eso hay dos contadores
—`rev` y `revPixeles`— a los que se enganchan las vistas. Separarlos es lo que
hace que un trazo no reconstruya la lista de capas sesenta veces por segundo.

Cómo se apilan las capas lo sabe **una sola función**, `Documento.componEn`. La
usan el lienzo —que sólo recompone el rectángulo que ensució el trazo— y la
exportación, que lo hace entero. Tenerlo dos veces sería tener dos respuestas
distintas a «cómo se ve esto», y la que saldría por el PNG no tendría por qué
ser la que ves.

El zoom no lo hace el Canvas: el Canvas está siempre a 1:1 con el sprite y quien
lo agranda es la GPU, sin suavizar. Por eso da igual dibujar al 100 % o al
3200 %, el trabajo de la CPU es el mismo.

La reproducción va **al ritmo que dice ir**: la manda el reloj de pared, no el
temporizador. Antes cada disparo avanzaba un tic exacto, así que la animación
iba a la velocidad a la que Qt lograra disparar — medido, un 39 % lenta. Como el
sentido de todo esto es que lo que ves aquí sea lo que se ve en el juego, ir
lento no es un defecto de acabado: es que la herramienta miente.

## Lo que este Qt hace mal

Están comprobadas en `cata/cata.qml`, que se sigue ejecutando con las demás
pruebas para que nos enteremos el día que dejen de ser verdad. Ninguna da error:
**todas fallan en silencio**, que es lo que las hace caras.

**1 · `putImageData` de tres argumentos no hace nada.** Se traga los píxeles sin
quejarse. La forma de siete —`putImageData(img, dx, dy, 0, 0, w, h)`— sí
funciona, y es la única que se usa en todo el programa.

**1b · En la de siete, el origen sucio tiene que ser `(0,0)`.** Pasarle el
lienzo entero con un rectángulo sucio en `(10,10)` tampoco pinta nada, otra vez
sin quejarse. Hay que escribir la zona pegada a la esquina del `ImageData` y
colocarla con `dx,dy`. Esto costó caro: el lienzo repinta por zona sucia, así
que un trazo no llegaba nunca a la pantalla y aparecía de golpe cuando algo
forzaba un repintado entero — «dibujo y sale al lado».

**2 · `putImageData` mezcla en vez de reemplazar**, que es justo lo contrario de
lo que dice su definición. Un píxel transparente encima de uno opaco no lo
borra: lo deja igual. Con eso la goma no borraba nada y deshacer no deshacía
nada — a la vista, porque por dentro las dos funcionaban perfectamente. Hay que
limpiar la zona antes de volcarla.

**3 · `Canvas.save()` devuelve `false` y no escribe.** Y aunque `toDataURL`
funciona, escribir por ahí cuesta **un repintado por fichero**: un personaje de
ocho acciones son quinientas celdas y eran ocho segundos de programa bloqueado.
Los píxeles van a la forja en base64 y los escribe Pillow, todos en un mensaje.
Leer va igual y **no** por el Canvas: cargar una imagen y leerla con
`getImageData` depende de que esté lista justo cuando toca pintar, y al arrancar
no lo está — devolvía capas vacías sin dar ningún error.

**4 · `createImageData` envenena el motor.** Cada llamada engorda algo que la
recogida de basura no suelta, y a partir de unas cuarenta el motor entra en
marcado continuo: **cualquier** reserva de memoria —un objeto, un texto, un
búfer— pasa de ser gratis a costar medio milisegundo. No se cura con `gc()`, ni
cerrando el documento, ni soltando las referencias; sólo recargando el motor
entero. El síntoma era cambiar de acción tres veces en un personaje y que a
partir de ahí **todo** el programa fuera lento, para siempre. Por eso cada
lienzo tiene **un** `ImageData` que sólo crece (`P.lienzoImg`): uno más grande
que la zona vale igual si cada fila se escribe con su paso (`P.vuelcaZona`).

**5 · `String.fromCharCode.apply` con un array de tipado devuelve caracteres
nulos.** Sin error y con la longitud correcta: el texto sale entero y todo a
cero. Codificar a base64 con un `Uint16Array` de códigos guardaba ficheros en
blanco sin que nada se quejara.

## Guardar

Todo lo que se escribe pasa por la forja, y la forja escribe con temporal y
`rename`: si se corta la luz a mitad no queda un fichero roto.

Guardar **no puede mentir**. Si las celdas no llegan al disco, no se escribe el
`proyecto.json`, no se quita el punto de «sin guardar» y se dice el fallo. Un
guardado a medias que además te deja cerrar tranquilo es peor que no guardar,
porque el aviso que te habría salvado ya no sale.

Y un `proyecto.json` que no describa un documento no se abre: entraba igual y
dejaba un fantasma de 0×0 que decía estar abierto, y el siguiente guardado
escribía ese fantasma encima de las celdas buenas. `Documento.esDocumento` es el
guardián, y se usa también al arrancar, porque una recarga que **falla** a
medias deja la memoria persistente a medio restaurar.

Hay dos relojes de autoguardado. El periódico cubre estar dibujando sin parar;
el otro salta a los seis segundos de que **pares**. Hace falta porque cerrar la
ventana no avisa a nadie —ni `closed` ni `visible` se enteran en este
Quickshell— y matar el proceso menos, así que la única defensa es no tener nunca
mucho sin escribir.

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

`pruebas/Lastre.qml` vigila el hallazgo 4: pasa por catorce documentos de
tamaños distintos con las vistas que pintan delante y mide lo que cuesta
reservar memoria. Con el fallo puesto da 71 ms; sin él, 0.

## El IPC

Si ya hay una ventana abierta se le habla en vez de arrancar otra. Por debajo es
el IPC de Quickshell, que también sirve desde un guion:

    qs -c pinza ipc call pinza estado
    qs -c pinza ipc call pinza abrir /ruta/al/proyecto.pinza
    qs -c pinza ipc call pinza exportar
    qs -c pinza ipc call pinza orden deshacer     # cualquier orden, por su id
    qs -c pinza ipc call pinza mostrar            # devolver la ventana

## El icono

Es pixel art, como debe ser: la silueta se escribe a mano en una rejilla de
32×32 en `tools/icono.py` y el sombreado sale de una regla —contorno en el
borde, brillo donde roza el fondo por arriba y por la izquierda, sombra por
abajo y por la derecha— que es un foco arriba a la izquierda. Se escala por
vecino más próximo a 32, 64, 128 y 256, todos múltiplos enteros para que ninguno
salga con píxeles a medias.

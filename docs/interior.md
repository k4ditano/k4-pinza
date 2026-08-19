# Por dentro

Notas para quien vaya a tocar el código. Lo que hay aquí no está en el README a
propósito: al que sólo quiere dibujar no le sirve de nada, y al que va a abrir
`vistas/Lienzo.qml` le ahorra una tarde.

## Cómo está repartido

    shell.qml          la ventana; reparte el sitio y nada más
    core/              el motor y las piezas de interfaz
      pixeles.js       búferes, mezcla, formas, transformaciones, paleta
      herramientas.js  qué hace cada herramienta
      figura.js        dibujar por descripción: masas y una regla de luz
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
    mcp/pinza-mcp.py   el puerto por el que dibuja una IA
    cata/              las trampas de Qt, como aserciones
    pruebas/           todo lo demás, en seco

Quickshell recarga la configuración cuando cambia un **`.qml`**, y **no** cuando
cambia un `.js`. Tocar `pixeles.js`, `herramientas.js` o `figura.js` y probar
por IPC contra la ventana abierta te contesta con el código de antes, sin
avisar de nada — que es media hora buscando un fallo que ya habías arreglado.
Hace falta tocar un `.qml` de verdad (un `touch` no basta: mira el contenido,
no la fecha) o reabrir el programa.

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

Y guardar **poda**. Escribía las celdas de ahora y se dejaba las de antes:
borrar una capa la quitaba de la memoria y del `proyecto.json`, pero sus PNG se
quedaban en `celdas/` para siempre. No corrompía nada —al abrir, el contador de
ids arranca en el máximo más uno, así que una capa nueva no reutiliza el id de
una muerta— pero la carpeta crecía sin parar y un `git diff` enseñaba ficheros
que no eran de nadie, que es justo lo que este formato promete no hacer.

El orden importa y es lo único delicado que tiene: se poda **al final**, cuando
las celdas y el `proyecto.json` ya están escritos y concuerdan. Podando antes,
una escritura que falle te deja sin lo viejo y sin lo nuevo. Y un fallo al
podar **no** estropea el guardado: lo que hay en el disco es correcto, que
sobren ficheros es cosmético, y decir que un guardado bueno ha fallado sería
mentir en la otra dirección pero mentir igual.

La forja se niega a podar si no le dan nada que conservar. Una poda así
vaciaría la carpeta entera y eso no es nunca lo que alguien quiso: es un fallo
aguas arriba. Distinguirlo cuesta una línea y quita la única forma que tiene
esto de perder trabajo.

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

## Dibujar por descripción

`core/figura.js` es la otra forma de poner píxeles: en vez de ponerlos, se
declaran **masas** —elipses, cápsulas, polígonos—, se unen en una silueta con
álgebra booleana, y el sombreado sale de **una regla**: una dirección de luz y
una rampa. Es lo que ya hacía `tools/icono.py` para el icono del programa,
sacado de sus 32×32 y puesto sobre cualquier dibujo.

No es un segundo motor. Las máscaras son booleanas y los únicos sitios que
escriben color —`pinta` y `sombrea`— van por `P.pon`. Lo que sale es un búfer
normal que el resto del programa no distingue de uno pintado a mano.

La normal de cada píxel **no** sale del gradiente de un mapa de distancias, que
a 32×32 es ruido: sale de dónde está la masa alrededor. Para cada píxel se mira
un disco de radio `grosor` y se calcula el centro de gravedad de lo que cae
dentro de la silueta; el vector que va del píxel a ese centro apunta hacia
dentro, y la normal exterior es ese vector cambiado de signo. Tiene dos
propiedades que el gradiente no da y que son justo las que hacen falta:

- En mitad de una masa el centro de gravedad cae encima del propio píxel, el
  vector se queda en nada y el color no se toca. **El interior es color base**,
  que es lo que separa esto de un degradado.
- La **longitud** del vector mide cuánto de borde es el píxel, así que sirve de
  peso sin calcular nada más. Un borde recto da 0.42 del radio —el centro de
  gravedad de un semicírculo—, y por eso se normaliza por ahí.

Y el sombreado mueve cada píxel **por su rampa**, arriba o abajo, en vez de
echarle gris encima: es la misma decisión que toma la tinta de sombreado del
editor, y la razón de que un sprite generado así siga teniendo los colores del
juego y se pueda recolorear después. Un tono intermedio inventado no pertenece
a ninguna rampa y se queda atrás cuando cambias el color.

`pruebas/Figura.qml` comprueba lo que no se ve: que con la luz al noroeste el
noroeste sale **más claro**, que girando la luz al sureste se invierte, que el
interior se queda en el color base, que no se pinta un píxel fuera de la
silueta, que no aparece ningún color que no esté en la rampa, y que el contorno
—que va por dentro— no engorda la figura. Un sombreado fijo pasaría la primera
de esas pruebas igual de bien; por eso están las seis.

## Referencia y medida

Dibujar por descripción tiene un agujero: la descripción sale de la cabeza de
quien la escribe, y las **proporciones** no se deducen de nada. Se puede
razonar que un pájaro tiene cresta; no se puede razonar que mide cinco píxeles
y se echa atrás treinta grados.

Ese agujero lo tapa una referencia — pero no mirándola, **midiéndola**.

`referencia` mete una imagen como capa de calco. No se exporta y no puede
hacerlo: `compuesto()` compone con `conReferencia` en falso y la exportación
pasa por ahí, así que lo que entre por ese verbo no acaba en un PNG ni por
accidente. Se recorta a lo dibujado y se reescala para caber, porque una
referencia viene del tamaño que viene —un sprite de 96 contra un contrato de
40— y superponerla a pelo no sirve de nada. Y se apoya abajo y no al centro:
dos bichos comparten el suelo.

`analiza` le saca los números: caja, densidad, simetría, centro de masa, el
perfil de anchura por franjas —**normalizado por su propia caja**, que es lo
que permite comparar un sprite de 96 con uno de 40 número a número— y los
colores agrupados en **rampas**. Lo de las rampas importa para hacer variantes:
una rampa se sustituye entera y el dibujo conserva su estructura de valores;
una lista de colores sueltos, no.

Agrupar por tono tiene una trampa que costó encontrar porque no fallaba
siempre: **el tono es un ángulo**. Promediarlo como un número normal parece
funcionar hasta que entra un rojo —que está a la vez en 350 y en 10— y la media
sale en 120, en pleno verde; a partir de ahí el grupo deja de atraer a los
suyos y empieza a robarle colores a otro. Lo peor es que dependía del ORDEN de
llegada de los colores, así que daba un resultado en el motor de QML y otro
distinto en node. Se promedia sumando senos y cosenos.

`hoja` trocea una hoja de sprites que ya existe y la abre como documento: las
columnas son fotogramas y las filas orientaciones, que es como las escribe el
juego. Con un contrato encima, las filas se quedan con los nombres de cara del
pack en vez de `d0…d7` — que es la diferencia entre ocho filas y ocho
**orientaciones**: sin eso el editor no sabe cuál es el sur y el compás no
puede colocarlas.

`compara` convierte «se parece» en un número. Escala una silueta a la altura de
la otra **sin deformarla** —estirar cada una hasta llenar la misma caja parece
lo cómodo y es justo lo que no se quiere: una figura alta y estrecha y una baja
y ancha salen idénticas después de estirarlas, y la proporción se pierde por el
camino— y devuelve el solape, la relación de aspecto de cada una y la
diferencia de anchura franja a franja, que es lo accionable: dice **dónde**
discrepan y no sólo que discrepan.

Con eso el ajuste deja de ser una opinión y pasa a ser una búsqueda: mueves un
parámetro del aparejo, vuelves a dibujar, vuelves a medir, te quedas con el que
sube.

Con las rampas extraídas, una **variante** deja de dibujarse. Un sprite tiene
una estructura de valores —qué es sombra, qué es medio, qué es brillo— y esa
estructura es lo que hace reconocible la silueta. Se coloca cada color en su
rampa, se mira en qué escalón cae por luminancia, y se sustituye por el que
ocupa ese mismo escalón en la rampa de destino: la sombra sigue siendo sombra.
Repintar a ojo destroza eso, y entonces no es el mismo bicho de otro color, es
otro bicho peor.

Pero antes de sustituir nada hay que saber **qué es contorno**, y eso no se
puede preguntar por el color. Agrupando la paleta por tono, el negro del
contorno y el blanco de un brillo caen los dos en «los neutros»; separarlos por
luminancia parece que funciona hasta que un bicho tiene el contorno marrón
oscuro, o un ojo casi negro. **El contorno no es un color: es una posición** —
los píxeles opacos con algún vecino transparente— y por eso `contornoDe` lo
mide en vez de adivinarlo, y `analiza` lo trae de serie: lo que no se pide por
defecto se olvida.

El contorno son el color que más manda en el anillo y los que le hagan sombra
de verdad, no los que hagan falta para llegar a un porcentaje. Acumular hasta
cubrir el 90 % parecía razonable y era una trampa: **en un sprite pequeño casi
todo el dibujo está a un píxel del borde**, así que colores del cuerpo entran
en el anillo con un 20 % cada uno y se colaban como contorno. En el `Hurt` de
Pidgey —un bicho de doscientos píxeles en un lienzo de 48×48— el negro es el
60 % del anillo y otros dos rondan el 20 %: no son contorno, son borde del
cuerpo. Y un color protegido por error es un color que el recolor no toca:
media variante sin recolorear y ninguna queja. Un contorno de dos tonos sí
existe —matizado por el lado de la luz— pero entonces los dos pesan parecido.

De cada color se devuelven dos fracciones que contestan preguntas distintas y
hacen falta las dos: `delAnillo` es cuánto del contorno es ese color —alto
significa «este color ES el contorno»— y `suyoFuera` es cuánto de ese color
está en el contorno —bajo significa que además se usa por dentro—. En el Pidgey
de crabh el negro da 1.000 y 0.646: es todo el contorno, y aun así un tercio
del negro del dibujo está en los ojos y en las líneas de dentro. Ninguna regla
por luminancia distingue esas dos cosas.

Esto se aprendió tiñendo el contorno «para que no pareciera un agujero
recortado». Medido después: en crabh el **100 % del borde de la silueta es
negro puro en todos los bichos**. No era un gusto que mejorar, era la
convención de la casa — y un solo bicho con el contorno teñido canta desde
lejos al lado de los demás. Un pack puede tener otra, y por eso la regla no es
«el contorno es negro» sino «el contorno es el que ya había».

Y si algún día se tiñe a propósito, la otra mitad de la lección sigue en pie:
**el contorno tiene que seguir siendo lo más oscuro del dibujo**. Mapeando el
cuerpo a la rampa entera, su tono más oscuro caía en el mismo carbón que el
contorno y la forma de dentro desaparecía. Los números decían que la luminancia
había SUBIDO, así que no era cuestión de aclarar: era que el contorno había
dejado de ser el suelo del dibujo.

Y una variante se hace sobre la CRIATURA, no sobre una hoja suya. `traer` se
baja una del catálogo del pack con todas sus acciones —cada una con su
geometría y sus duraciones— y `accion` salta entre ellas guardando sola la que
dejas, que es lo que permite recorrerlas en un bucle. Un recolor que sólo llega
a `Walk` deja un bicho que cambia de color al pararse, y eso no se ve
dibujando: se ve jugando.

El mismo fallo tiene un piso más abajo, y es más fácil de cometer: **medir el
compuesto que tienes delante es medir UNA celda**. Un color que sólo sale en
otro fotograma o en otra cara no entra en el mapa de sustitución y se queda sin
tocar. Se miden todas las celdas juntas, en un mosaico con dos píxeles de hueco
entre ellas — pegadas, dos siluetas vecinas se tocan y sus bordes dejan de ser
borde, y entonces el contorno, que se detecta por posición, se detecta mal.

**Y ahí hay una trampa que conviene saber antes de usarlo.** El solape es un
sustituto, no el objetivo. Ajustando el ancho del Pidey contra un Pidgey de
verdad, el máximo de solape estaba en ×1.45 — y a ×1.45 el bicho sale
rechoncho y peor que a ×1.18, que puntúa algo menos. Maximizar el parecido con
la silueta de OTRA criatura no es lo mismo que hacer un buen sprite. Los
números sirven para saber en qué dirección moverse y cuánto margen hay; quien
decide dónde parar sigue siendo quien mira.

## El puerto de la IA

`mcp/pinza-mcp.py` es un servidor MCP sin dependencias —ciento cincuenta líneas
de JSON-RPC por la entrada estándar— que deja a un modelo conducir el editor:
crear un documento, dibujar con `figura.js`, **mirar** lo que le ha salido y
corregirlo.

Lo de mirar no es un adorno. Sin devolver la imagen no hay bucle y el modelo
dibuja a ciegas; con ella cada paso se puede juzgar y arreglar, que es como
dibuja cualquiera. Por eso `previa` compone sobre un fondo de ajedrez: sin él,
lo transparente y lo negro son el mismo píxel para quien mira la imagen.

Por debajo no hace nada por su cuenta — todo pasa por el IPC contra la
instancia que ya está abierta. Eso son tres cosas que en realidad son la misma:
no hay un segundo motor de píxeles, no hay una segunda respuesta a «cómo se ve
esto», y **ves lo que hace mientras lo hace**, en la ventana que ya tenías
delante. Y como el verbo de dibujar pasa por `Guiones`, lo que haga entra en el
historial como **un** paso: un Ctrl+Z deshace la intervención entera.

El servidor entrega una **guía** en el `initialize`, que es el único sitio
donde caben instrucciones que no van pegadas a una herramienta. Lleva el orden
de trabajo, y cada línea de ese orden es un fallo que ya se cometió una vez:
mira qué hay abierto —si es una criatura, el trabajo es sobre todas sus
acciones—, mide **todo** y no la celda que tienes delante, no toques el
contorno, describe en vez de poner píxeles, mira lo que ha salido, y verifica
en el disco. Más dos avisos: un número no es el objetivo, y las órdenes del
editor trabajan sobre la capa **activa**.

`pinza_verifica` lee los PNG ya escritos y dice qué está mal: colores fuera de
la paleta, celdas cuyo borde no es el contorno que esperabas, contenido tocando
el filo del lienzo, celdas vacías. Es la regla de las pruebas del programa
—Pillow leyendo los ficheros desde fuera— aplicada a lo que dibuja una IA, y
por el mismo motivo: los fallos que importan no dan error en ningún sitio. Con
`base` se compara contra el original del que salió la variante y sólo se cuenta
lo añadido; sin eso te acusa de lo que ya venía en el material —el `Charge` de
un Pidgey tiene treinta celdas tocando el filo antes de que nadie lo toque— y
un aviso que salta siempre deja de leerse a la tercera vez.

`pinza_convenciones` mira el arte que YA existe en una carpeta y dice qué
reglas sigue de hecho: de qué color es el contorno, cuántos colores gasta una
hoja, de qué tamaños son. Un pack trae una guía escrita, pero las convenciones
que mandan están en los ficheros.

Los verbos nuevos del IPC contestan en JSON y no en prosa, que es la diferencia
entre ellos y los de arriba: `ficha`, `previa`, `rejilla`, `medidas`,
`ordenes`, `guion`, `crear` y `guardarEn`. «0054 · 40x40 · 1 fotogramas» está
bien para una persona en una terminal y obliga a cada cliente a inventarse un
analizador que se rompe el día que alguien mueve un punto medio de sitio.

`rejilla` merece una nota: devuelve el dibujo como caracteres con su leyenda de
colores. Un PNG en base64 no le dice nada a un modelo de lenguaje y un volcado
de hexadecimales son cuatro mil símbolos para un sprite de 32×32; esto son mil,
y sobre todo es **editable** — se puede decir «la fila 12 columna 7 sobra» y que
la frase signifique algo.

## Lo que el servidor le cuenta al modelo

MCP deja al servidor entregar unas instrucciones al conectarse, y es el único
sitio donde caben cosas que no van pegadas a una herramienta. Ahí va el ORDEN
DE TRABAJO, y no es burocracia: cada línea de esa guía es un fallo que ya se
cometió una vez y que **no dio ningún error**.

    mira qué hay · mide TODO antes de tocar · no toques el contorno ·
    dibuja describiendo · mira lo que ha salido · verifica en el disco

Las tres herramientas que salieron de tropezar:

`pinza_verifica` lee los PNG **ya escritos** y dice qué está mal: colores fuera
de la paleta —un color sin sustituir en una variante—, celdas cuyo borde no es
el contorno que esperas, celdas con contenido tocando el filo del lienzo, y
celdas vacías. Es la misma regla con la que se prueba el programa —Pillow
leyendo los ficheros desde fuera— aplicada a lo que dibuja una IA, y por la
misma razón: lo que se ve en el editor no es lo que sale.

Y lleva `base`, que importa más de lo que parece. Sin ella te acusa de lo que
ya venía en el material: el `Charge` de un Pidgey tiene treinta celdas tocando
el filo antes de que nadie lo toque, y **un aviso que salta siempre deja de
leerse a la tercera vez**. Con la base sólo se cuenta lo que has añadido tú.

`pinza_convenciones` mira el arte que YA existe en una carpeta y dice de qué
color es el contorno de la casa, cuántos colores gasta un sprite y de qué
tamaño son las hojas. Un pack trae una guía escrita, pero las convenciones que
mandan están en los ficheros: en crabh el contorno es negro puro en el 98 % del
borde de todo lo que hay. Preguntárselo al arte cuesta una llamada; no
preguntárselo costó teñir un contorno y no enterarse.

`pinza_criatura` trabaja al nivel que importa —catálogo, traer, acciones,
cambiar, guardar— porque una variante es de la criatura entera.

Y `pinza_capa` toca capas **por índice**. Las órdenes del editor trabajan sobre
la capa activa, que es lo correcto para alguien con el panel delante y una
trampa para un programa: pedir «borra la capa» creyendo que se llevará el calco
y que se lleve el dibujo es un error de una línea que no avisa de nada.

## El IPC

Si ya hay una ventana abierta se le habla en vez de arrancar otra. Por debajo es
el IPC de Quickshell, que también sirve desde un guion:

    qs -c pinza ipc call pinza estado
    qs -c pinza ipc call pinza abrir /ruta/al/proyecto.pinza
    qs -c pinza ipc call pinza exportar
    qs -c pinza ipc call pinza orden deshacer     # cualquier orden, por su id
    qs -c pinza ipc call pinza mostrar            # devolver la ventana

Y los que contestan en JSON, que son los que usa el servidor MCP:

    qs -c pinza ipc call pinza ficha              # todo el estado
    qs -c pinza ipc call pinza medidas            # silueta, colores, guía
    qs -c pinza ipc call pinza rejilla '{}'       # el dibujo en caracteres
    qs -c pinza ipc call pinza previa '{"ruta":"/tmp/x.png","escala":8}'
    qs -c pinza ipc call pinza guion 'pinza.log(pinza.doc.ancho)' prueba
    qs -c pinza ipc call pinza referencia '{"ruta":"/tmp/ref.png"}'
    qs -c pinza ipc call pinza analiza '{"que":"referencia"}'
    qs -c pinza ipc call pinza compara '{}'      # lo tuyo contra el calco

## El icono

Es pixel art, como debe ser: la silueta se escribe a mano en una rejilla de
32×32 en `tools/icono.py` y el sombreado sale de una regla —contorno en el
borde, brillo donde roza el fondo por arriba y por la izquierda, sombra por
abajo y por la derecha— que es un foco arriba a la izquierda. Se escala por
vecino más próximo a 32, 64, 128 y 256, todos múltiplos enteros para que ninguno
salga con píxeles a medias.

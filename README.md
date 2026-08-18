<img src="capturas/icono.png" width="64" alt="">

# K4 Pinza

Un editor de pixel art que sabe **qué** estás dibujando, no sólo que estás
dibujando píxeles.

*(In English: [README.en.md](README.en.md))*

![El editor](capturas/editor.png)

Dibujar el sprite es la parte fácil. Lo que cansa es todo lo de alrededor: que
este objeto mide 32×32 salvo cuando se levanta y entonces 48 de alto; que si es
rectangular necesita cuatro ficheros con el sufijo correcto y que girarlo
también gira su huella; que una hoja de personaje son columnas × 8 filas en un
orden de orientaciones que no se puede equivocar, con una duración por fotograma
medida en tics.

Eso normalmente vive en tu cabeza y en un manifiesto que editas a mano después
de exportar. Aquí lo declaras **una vez** —en un fichero JSON que se llama
pack— y de ahí sale todo lo demás: el tamaño del lienzo, cuántos fotogramas,
cuántas orientaciones, cómo se llama el fichero y dónde se copia al exportar.

El pack de serie no impone nada, así que sirve igual para dibujar un icono
suelto.

## Instalar

    git clone https://github.com/k4ditano/k4-pinza
    cd k4-pinza
    ./instalar.sh

Deja el programa en el menú de aplicaciones con su icono, un comando `pinza` en
la terminal, y se ofrece en el «abrir con» de cualquier PNG para traértelo como
capa. **No copia nada y no pide `sudo`**: instala enlaces dentro de tu carpeta
personal, así que actualizar es un `git pull`.

    ./instalar.sh --quitar      deshacerlo

Desinstalar no toca tus dibujos, tus packs ni tus guiones.

Hace falta [Quickshell](https://quickshell.org/), Qt 6 (`qt6-base`,
`qt6-declarative`), Python 3 con Pillow, y las fuentes `Adwaita Sans` y
`MesloLGS Nerd Font Mono`. El instalador lo comprueba y te lo dice antes de
tocar nada.

## Para empezar

    pinza                    abrir el editor
    pinza Bicho.pinza        abrir ese proyecto
    pinza dibujo.png         importarlo como capa

`Ctrl+K` abre la paleta de comandos y ahí está **todo**, buscando por trozos
sueltos: «vol h» encuentra «Voltear en horizontal». No hay menús que recorrer.

![La paleta de comandos](capturas/comandos.png)

## Lo que lo diferencia

**Tres ejes, no dos.** Una celda es capa × fotograma × **orientación**. En los
demás editores una hoja de ocho caras se monta a mano; aquí la orientación es un
eje de primera clase, con un compás que las coloca en su sitio geográfico y
enlace de espejo: dibujas el este y el oeste sale volteado. Para un icono
simplemente vale una y el compás ni aparece.

**Cada fotograma mide lo que dura.** La tira de abajo no son cuadraditos
iguales: cada fotograma es tan ancho como tics ocupa, con su regla. Arrastrando
su borde derecho retimas la animación mirándola, que es como se decide si un
golpe se siente bien.

**La muestra, a tamaño real.** Dibujando estás siempre a ×8 o a ×16, y a ese
aumento cualquier cosa parece bien: los contornos se leen, las sombras se
separan. A tamaño real la mitad de eso desaparece, y sin verlo mientras dibujas
te enteras al exportar. Flota sobre el lienzo, se arrastra a donde estorbe menos
y se anima con la tira.

| | |
|---|---|
| ![La previa](capturas/previa.png) | ![El color](capturas/color.png) |
| **Previa en juego.** El sprite sobre un suelo, con su sombra, y las medidas que un juego saca de los píxeles: dónde apoyan los pies, cuánto ocupa la silueta. Catorce filas vacías bajo la figura son catorce píxeles de aire donde debería pisar, y en el lienzo eso no se ve. | **Rampas, no una rejilla.** La unidad de trabajo es sombra → cuerpo → brillo, que es como se piensa dibujando. La tinta de sombreado mueve cada píxel un paso por *su* rampa en vez de aplastarlo con un color plano. La rueda va dentro del panel: elegir un color no debería taparte el dibujo. |

**Cambiar un color en todo el personaje.** Sustituir color pregunta hasta dónde
llega: esta celda, todos los fotogramas de esta cara, o los de las ocho. Hacerlo
a mano en una hoja de once fotogramas por ocho filas son ochenta y ocho clics, y
basta fallar uno para que la animación parpadee. Todo el cambio es **un** paso
del historial.

**Modo baldosa de verdad y mapa de prueba.** El lienzo envuelve: dibujas
cruzando la costura y el trazo sale por el otro lado. Y un tileset no se juzga
mirando la hoja, sino repartido por un campo — que es donde salen las costuras y
donde se ve que la flor que parecía bonita, cada tres casillas, convierte el
prado en una alfombra.

**Girar y escalar a ojo** (`Ctrl+T`), con el resultado a la vista. Cada cambio
se rehace desde el estado de partida, nunca sobre el anterior: girar cinco
grados cinco veces no es girar veinticinco, es destrozar el dibujo remuestreando
lo ya remuestreado. Y probar veinte ángulos deja **una** entrada en el historial.

**Personajes enteros.** Si el pack lo declara, un personaje no es una hoja sino
una por acción —quieto, andar, atacar…— y el editor las trata como un solo
proyecto: saltas de una a otra de un clic, cada una con su geometría ya puesta,
y exportar escribe las hojas, el fichero de animación que las ata y la ficha que
lo da de alta, los tres de acuerdo entre sí.

**Guiones en JavaScript**, en `~/.config/pinza/guiones/*.js`. Reciben el
documento abierto y todo lo que hagan entra en el historial como **un** paso,
para poder probarlos sin miedo.

Y lo de siempre, sin sorpresas: selecciones de todo tipo con sumar, restar y
cortar; lápiz con trazo perfecto, goma, cubo, cuentagotas, formas, degradado
tramado, difuminar, manchar, aclarar, quemar; pinceles a medida; dieciocho modos
de fusión, grupos, bloqueo de alfa, capas de referencia; piel de cebolla,
etiquetas, celdas enlazadas; simetría y rejillas; paletas `.gpl`, `.hex` y desde
PNG; GIF y APNG.

**Sin límites de color.** Un pack puede traer una guía de estilo, pero es un
cuentakilómetros y no una barrera: te dice dónde estás y se apaga.

## El formato

Una carpeta con un JSON y un PNG por celda:

    Bicho.pinza/
      proyecto.json          capas, fotogramas, duraciones, enlaces
      celdas/c1.0.3.png      capa . fotograma . orientación
      paleta.gpl

Nada de un binario propio, y se nota a diario: se ve en un `git diff`, puedes
abrir un fotograma suelto en cualquier otro editor, y si mañana el programa no
arranca el arte sigue estando ahí.

## Packs

Un pack es un JSON: declara sus paletas, sus contratos —lienzo, ejes, patrón de
nombre, carpeta de salida— y, si quiere, un manifiesto que parchear y una guía
de estilo. Los del programa están en `packs/`; los tuyos en
`~/.config/pinza/packs/*.json`, y ganan si repiten `id`, que es como se retoca
uno de serie sin tocar el repositorio.

## Por dentro

Está escrito en QML sobre [Quickshell](https://quickshell.org/), con el motor de
píxeles en JavaScript puro. Si vas a tocarlo, [docs/interior.md](docs/interior.md)
cuenta cómo está repartido, por qué, y las seis cosas que este Qt hace mal y hay
que saber antes de acercarse al lienzo.

    ./pruebas/correr            las pruebas, sin abrir una ventana

# K4 Pinza

A pixel art editor built on [Quickshell](https://quickshell.org/) that knows
what you are drawing before you start.

    ./instalar          # then, from anywhere:
    pinza

The program is called **K4 Pinza**. The command is plain `pinza`, and so are the
file extension and the settings folder: that is not the name, it is what you
type.

*(En español: [README.md](README.md) — the source, the comments and the UI are
in Spanish. This translation is here so the design decisions can be read by
people who do not speak it.)*

![The editor](capturas/editor.png)

| | |
|---|---|
| ![In-game preview](capturas/previa.png) | ![Colour](capturas/color.png) |
| **In-game preview.** The sprite on the ground at ×1, ×2 and ×3, with its shadow and the measurements the game reads out of the pixels — plus the warning that fourteen empty rows under the figure are fourteen pixels of air where it should be standing. | **Colour.** Ramps of nine tones, not three, and the wheel inside the panel: picking a colour should not cover the drawing you are looking at in order to decide. |

![Command palette](capturas/comandos.png)

No menus: `Ctrl+K` and search by loose fragments. Only what can be done right
now shows up.

## The idea

LibreSprite and Aseprite draw pixels very well. What neither of them knows is
**what** you are drawing: that this object is 32×32 except when it stands up and
then it is 48 tall; that if it is rectangular it needs four files called `_N`,
`_E`, `_S` and `_W` and that turning it also turns its footprint; that a
creature sheet is columns × 8 rows in an order of facings you cannot get wrong,
with one duration per frame measured in ticks of 1/60 s.

All of that normally lives in your head and in a manifest you hand-edit after
exporting. Here the **contract is the first thing you choose** and everything
else follows from it: canvas size, how many frames, how many facings, what the
file is called, where it is copied and what line gets written into the manifest.

Contracts come in a **pack**. The "generic" pack imposes nothing and is the
default, so this works for any game. The [crabh](https://github.com/k4ditano/crabh)
pack brings that particular game's profiles. Writing a new one is a JSON file.

**There are no colour limits anywhere.** A pack may bring a guide — crabh's does
— but it is an odometer, not a barrier: it tells you where you are and it can be
switched off in Settings.

## What it has

**Three axes.** A cel is addressed by layer × frame × **facing**. Aseprite has
two, which is why an eight-facing sheet has to be assembled by hand; here the
facing is a first-class axis, and for an icon it is simply one and the compass
never shows up.

**The compass.** The facings laid out geographically, with mirror linking: you
draw east and west is generated flipped. A dot under the faces still blank.

**Change one colour across the whole creature.** Replace colour asks how far it
reaches: this cel, every frame of this facing, or every frame of all eight — and
optionally every layer. Recolouring a creature cel by cel across an
eleven-frame, eight-row sheet is eighty-eight clicks, and missing one is enough
to make the animation flicker. The whole change is **one** history step. It
respects the selection if there is one.

**The timeline.** Each frame **is as wide as it is long**, in ticks of 1/60 s,
with a ruler underneath. Dragging its right edge retimes the animation while you
watch it. Seeing that the impact frame lasts four ticks and the recovery one
twelve is what makes a hit feel right, and with one dialog per frame you cannot
see that.

**Ramps, not a grid of colours.** The working unit is shadow → body → highlight,
which is how you think while drawing. The shading ink moves each pixel one step
along *its* ramp instead of flattening it with a solid colour; anything that is
not in a ramp it leaves alone.

**Silhouette measurements.** A game that reads from the pixels where the feet
land and how tall the silhouette is deserves to have them visible while you
draw: three extra empty rows change where the creature stands, and on the canvas
that does not show. They go over the drawing and in the preview.

**The swatch, at real size.** Floating over the canvas and draggable to wherever
it is least in the way. While drawing you are always at ×8 or ×16, and at that
magnification anything looks fine: outlines read, shadows separate, everything
breathes. At real size half of that disappears, and without seeing it while you
draw you find out on export. It shows ×1, ×2 and ×3 — whichever fit — and
animates along with the timeline.

Playback runs **at the speed it claims to**: the wall clock drives it, not the
timer. Before, each tick advanced exactly one frame-tick, so the animation ran
at whatever rate Qt managed to fire — measured, 39 % slow. Since the whole point
is that what you see here is what you see in the game, running slow is not a
finishing defect: it means the tool is lying.

**In-game preview.** The sprite animating on a floor, with its shadow and the
measurements the game reads from the pixels. What matters is not how it looks at
800 % zoom.

**What is selected transforms on its own.** Flip, rotate and scale respect the
selection: if something is marked they touch only that and leave the rest of the
drawing where it was, and the mask transforms along with the content so you can
chain operations without reselecting. That is half the work of animating — you
mark an arm and flip it; you copy a leg, paste it into the next frame and move
it. What you paste comes out selected and with the move tool already active.

**Rotate and scale by eye** (`Ctrl+T`), with the result visible while you drag
the handle. Every change is redone **from the starting state**, never on top of
the previous one: rotating five degrees five times is not rotating twenty-five,
it is destroying the drawing by resampling what was already resampled. And
trying twenty angles leaves **one** history entry, the one you accepted.

Rotation and scaling go through RotSprite: upscale ×8 cleaning up the stairs,
transform, then shrink back keeping the most frequent colour in each block.
Averaging would be the easy way and it is exactly what ruins a pixel art
rotation, because it introduces colours that are not in the palette.

**Real tile mode.** The canvas wraps: you draw across the seam and the stroke
comes out the other side, with the eight repetitions around it.

**Test map.** A tileset is not judged by looking at the sheet: it is judged by
seeing it spread across a field, which is where the seams show and where you
notice that the flower that looked pretty, placed every three tiles, turns the
meadow into a carpet. The layout is not invented — it is the same one the game
does: only whole opaque non-white tiles, sorted by luminance variance, the
flattest 40 % as floor and the rest sprinkled.

**Scripts in JavaScript.** The same language the program is already written in,
so there is no second interpreter and no translation of the model in between. A
script receives a `pinza` object and works against the open document; everything
it does enters the history as **one** step, so it can be tried without fear.
Three come as examples: outline the silhouette across every facing, centre every
cel, and rest the figure on the ground with the same gap in every frame.

**You can see when it is working.** Importing a creature is eight projects and
five hundred cels: a pixel ring appears saying what it is doing and how far
along it is. It shows up with a delay on purpose — saving an icon takes fifty
milliseconds and a spinner flash on every save is more tiring than informative —
and if something gets stuck it stops blocking, because a loading screen that
never leaves is worse than an error.

**No menus and no modal dialogs.** `Ctrl+K` for any command, searching by loose
fragments ("fl h" finds "Flip horizontally") and showing only what can be done
right now. Hold right-click over the canvas for the tool wheel, which appears
around the cursor. Everything else is sheets that slide in from the right and
leave the canvas visible.

And the usual: marquee, ellipse, lasso, polygonal lasso, wand and colour
selection, with add/subtract/intersect; pencil with pixel-perfect strokes,
eraser, bucket, eyedropper, lines, rectangles, ellipses, dithered gradient,
blur, smudge, dodge, burn, replace colour; custom brushes from a selection;
eighteen blend modes, nestable groups, alpha lock, reference layers; flip,
rotate, scale by nearest neighbour or with RotSprite-style smoothing, shear,
crop to content; tinted onion skin, tags with forward, reverse and ping-pong,
linked cels; symmetry, pixel and tile grids; `.gpl`, `.hex` and from-PNG
palettes; quantise; GIF and APNG; a visible history you can jump around with one
click.

## How it is built

    shell.qml          the window; it allocates space and nothing else
    core/              the engine and the interface pieces
      pixeles.js       buffers, blending, shapes, transforms, palette
      herramientas.js  what each tool does
    servicios/         the state, in singletons
      Documento.qml    layers × frames × facings
      Historial.qml    undo by commands, not by snapshots
      Ordenes.qml      everything the program knows how to do, in one list
      Proyecto.qml     save, open, export
      Guiones.qml      run JavaScript against the document
      Forja.qml        the only place that spawns processes
    vistas/            canvas, compass, timeline, panels, sheets
    packs/             generico.json, crabh.json — and yours
    forja/forja.py     whatever touches files
    cata/              the things that had to be tested before starting
    pruebas/           everything else, headless

The drawing lives in a JS object inside `PersistentProperties` and not in a tree
of QML properties, for two reasons that both matter: Quickshell **reloads the
configuration every time you save a `.qml`**, and without that, touching the
code while you draw takes the drawing with it; and QML does not notify when you
mutate a `property var` internally, so instead of fighting that there are two
counters — `rev` and `revPixeles` — that the views hook into. Separating them is
what keeps a stroke from rebuilding the layer list sixty times a second.

How layers stack is known by **one single function**, `Documento.componEn`. It
is used by the canvas — which only recomposes the rectangle the stroke dirtied —
and by export, which does the whole thing. Having it twice would mean having two
different answers to "how does this look", and the one that came out of the PNG
would not have to be the one you see.

The zoom is not done by the Canvas: the Canvas is always 1:1 with the sprite and
the GPU is what magnifies it, without smoothing. That is why drawing at 100 % or
at 3200 % costs the CPU the same. And what gets repainted is only the rectangle
the stroke dirtied.

### What this Qt gets wrong, and you need to know before touching the canvas

These are asserted in `cata/cata.qml`, which keeps running alongside the other
tests so we find out the day they stop being true. None of them raises an error:
they all fail silently, which is what makes them expensive.

- **Three-argument `putImageData` does nothing.** It swallows the pixels without
  complaint. The seven-argument form — `putImageData(img, 0, 0, x, y, w, h)` —
  does work, and it is the only one used anywhere in the program.
- **In the seven-argument form, the dirty origin has to be `(0,0)`.** Passing
  the whole canvas with a dirty rectangle at `(10,10)` also paints nothing,
  again without complaint. You have to cut an `ImageData` the size of the dirty
  area and place it with `dx,dy`. This one was expensive: the canvas repaints by
  dirty area, so a stroke never reached the screen and appeared all at once when
  something forced a full repaint — "I draw and it comes out somewhere else".
- **`putImageData` blends instead of replacing**, which is the exact opposite of
  what its definition says. A transparent pixel over an opaque one does not
  erase it: it leaves it alone. With that, the eraser erased nothing and undo
  undid nothing — visually, because internally both worked perfectly. You have
  to clear the area before dumping into it.
- **`Canvas.save()` returns `false` and writes nothing.** And although
  `toDataURL` works, writing that way costs **one repaint per file**: a PMD
  creature is five hundred cels and that was eight seconds of frozen program.
  Pixels go to the forge as base64 and Pillow writes them, all in one message.
  Reading goes the other way and **not** through the Canvas: loading an image
  and reading it with `getImageData` depends on it being ready exactly when it
  is time to paint, and at startup it is not — it returned empty layers without
  any error. Images come in through the forge, with Pillow.
- **`createImageData` poisons the engine.** Each call grows something the
  garbage collector does not release, and after about forty the engine enters
  continuous marking: **any** allocation — an object, a string, a buffer — goes
  from free to half a millisecond. It is not cured by `gc()`, nor by closing the
  document, nor by dropping references; only by reloading the whole engine. The
  symptom was switching action three times on a creature and from then on
  **everything** in the program being slow, forever. That is why each canvas has
  **one** `ImageData` that only grows (`P.lienzoImg`): one larger than the area
  works just as well as long as each row is written with its own stride.
- **`String.fromCharCode.apply` with a typed array returns null characters.** No
  error and with the right length: the string comes out complete and all zeroes.
  Encoding base64 with a `Uint16Array` of char codes saved blank files without
  anything complaining.

## The project format

A folder with one JSON and one PNG per cel:

    Cangrejito.pinza/
      proyecto.json          contract, layers, frames, durations, links
      celdas/c1.0.3.png      layer . frame . facing
      paleta.gpl

No custom binary, for three reasons you notice daily: it shows up in a `git
diff`, you can open a single frame in any other editor for as long as pinza is
missing a tool, and if tomorrow the program does not start the art is still
there.

## Whole creatures

A creature is not a sheet: it is **one per action** — idle, walk, attack, hurt,
charge, hop, sleep, shoot — plus the `AnimData.xml` that ties them together and
the record that registers it in the game. All three have to agree, and that
agreement is exactly what breaks when it is done by hand.

`Ctrl+Shift+E`, or "Especie" in the command palette. Two ways to start:

**Bring one in from the game and rework it.** It reads what crabh has
downloaded — all 158 of them — and slices their sheets with the **real**
geometry: frame size, durations in ticks and hit frames come from
`species.json`, which in turn comes from the original `AnimData.xml`. Guessing
the grid of a PMD sheet goes wrong — there are two-frame actions and eleven-frame
ones — and guessing durations goes wrong always. Each action ends up as a normal
project, with its layers and its undo.

**Start a blank one.** The eight actions are born empty but with the geometry
**already set**: each with its size, its frames, its durations and its hit
frames, and the eight rows in the order the game reads. If you have to type that
in, the template is worth nothing.

While you draw it, the **actions** panel says which one you are in, which ones
already have something drawn, and jumps between them with one click (or with
`Alt+←` / `Alt+→`). Switching action saves the one you are leaving first.

A species project is a folder:

    Cangrejito.especie/
      especie.json      who it is: dex, role, shadow, and which action has what
      Idle.pinza/       each one is a normal project
      Walk.pinza/
      Attack.pinza/

And exporting writes all three things at once: one sheet per action in
`assets/species/<name>/`, the `AnimData.xml` with all of them, and
`assets/species/<name>.json` with its half of the pokédex — types and abilities
as plain strings, so that a creature of yours reads the same type table as a
real one and is not a special case anywhere.

## Attack effects

The animation that plays when a move is used, with its own profile. What matters
there is the **file name**, because that is where the game gets the grid from:

| | |
|---|---|
| one facing | `Mordisco_Feroz.8.png` — a strip of 8 frames |
| eight facings | `Rayo_Guiado.Dir8.png` — 8 rows, one per direction |

Getting it wrong does not raise an error: it produces an effect that plays in
pieces. Here the contract decides it from how many facings the document has, and
exporting also writes the manifest entry with its type and the move it belongs
to.

## Scripts

    ~/.config/pinza/guiones/*.js

A script receives `pinza` and works against the open document:

```js
pinza.paraCada((buf, capa, fotograma, orientacion) => {
  pinza.paraCadaPixel(buf, (c, x, y) => {
    if (c[3] === 0) return
    return pinza.color('#D66C34')
  })
})
pinza.log('done')
```

`pinza.px` is the whole pixel engine, in case you need something the API does
not offer — but then it is on you not to break anything. A script that blows up
halfway is cancelled without leaving a trace in the history.

## Packs

The built-in ones live in `packs/`. Yours go in `~/.config/pinza/packs/*.json`
and win if they repeat an `id`, which is how you tweak a stock one without
touching the repository. A pack declares its palettes as ramps, its contracts —
canvas, axes, naming pattern, output folder — and, if it wants, a manifest to
patch and an informational style guide.

The root of a pack's repository can be repointed from inside the program: the
pack is shared, the path to your copy of the game is not.

## Tests

    ./pruebas/correr            all of them
    ./pruebas/correr Motor      just one

They run with `QT_QPA_PLATFORM=offscreen`, so they work over SSH or in a git
hook. The pixel engine and the tools are plain JavaScript and are checked
without opening anything; the whole round trip — draw, save, close, open, export
— is checked with Pillow reading the PNGs from outside, which is the only way to
know that what you see is what comes out.

Press, drag and release are ordinary functions of the canvas and the mouse only
calls them, so `pruebas/Puntero.qml` can click at view coordinates and check two
different things: that the pixel lands in the right layer, and that it is also
**visible** on screen. Those are not the same thing, and the day they stopped
being the same the program looked like it was drawing "next to" where you
clicked, the eraser did not erase and undo did not undo — all three with a
perfect model underneath.

## Install

    ./instalar          install or update
    ./instalar --quitar undo it

It copies nothing: what it installs are **symlinks**. The code stays where it
is, so carrying on developing here is carrying on using what is installed,
without reinstalling. Everything goes into your home directory — no `sudo`,
nothing outside `$HOME`:

| | |
|---|---|
| `~/.local/bin/pinza` | the launcher |
| `~/.local/share/applications/pinza.desktop` | so it shows in the menu |
| `~/.local/share/icons/hicolor/*/apps/pinza.png` | the icon, drawn by `tools/icono.py` |
| `~/.config/quickshell/pinza` | a link to the repository, for `qs -c pinza` |

Uninstalling does not touch your projects, your packs or your scripts: those
live in `~/.config/pinza/`.

### The launcher

    pinza                    open the editor
    pinza Bicho.pinza        open that project
    pinza dibujo.png         import it as a layer
    pinza --nuevo            the new-document sheet
    pinza --estado           what is open right now
    pinza --mostrar          bring the window back if you closed it

If a window is already open, **it is talked to instead of starting another
one**. Two instances get along fine — each has its own document — but they would
tread on each other's settings, and above all it is not what anyone expects when
double-clicking a project. Underneath it is Quickshell's IPC, which also works
from a script:

    qs -c pinza ipc call pinza estado
    qs -c pinza ipc call pinza abrir /path/to/project.pinza
    qs -c pinza ipc call pinza exportar
    qs -c pinza ipc call pinza orden deshacer     # any command, by its id

### The icon

It is pixel art, as it should be: the silhouette is written by hand on a 32×32
grid in `tools/icono.py` and the shading comes out of a rule — outline at the
edge, highlight where it meets the background above and to the left, shadow
below and to the right — which is a light source at the top left, like the
game's art. It is scaled by nearest neighbour to 32, 64, 128 and 256, all whole
multiples so none of them comes out with half pixels.

## Requirements

Quickshell, Qt 6 (`qt6-base`, `qt6-declarative`), Python 3 with Pillow, and the
`Adwaita Sans` and `MesloLGS Nerd Font Mono` fonts for the interface.
`./instalar` checks and tells you before doing anything.

<img src="capturas/icono.png" width="64" alt="">

# K4 Pinza

A pixel art editor that knows **what** you are drawing, not just that you are
drawing pixels.

*(En español: [README.es.md](README.es.md) — the code, the comments and the
interface are in Spanish.)*

![The editor](capturas/editor.png)

Drawing the sprite is the easy part. What wears you down is everything around
it: that this object is 32×32 except when it stands up and then it is 48 tall;
that if it is rectangular it needs four files with the right suffix and that
turning it also turns its footprint; that a character sheet is columns × 8 rows
in an order of facings you cannot get wrong, with one duration per frame
measured in ticks.

That normally lives in your head and in a manifest you hand-edit after
exporting. Here you declare it **once** — in a JSON file called a pack — and
everything else follows: canvas size, how many frames, how many facings, what
the file is called and where it is copied on export.

The stock pack imposes nothing, so this works just as well for drawing a single
icon.

## Install

    git clone https://github.com/k4ditano/k4-pinza
    cd k4-pinza
    ./instalar.sh

It puts the program in your applications menu with its icon, a `pinza` command
in the terminal, and offers itself in the "open with" menu of any PNG so you can
bring it in as a layer. **It copies nothing and asks for no `sudo`**: it
installs symlinks inside your home directory, so updating is a `git pull`.

    ./instalar.sh --quitar      undo it

Uninstalling does not touch your drawings, your packs or your scripts.

You need [Quickshell](https://quickshell.org/), Qt 6 (`qt6-base`,
`qt6-declarative`), Python 3 with Pillow, and the `Adwaita Sans` and
`MesloLGS Nerd Font Mono` fonts. The installer checks and tells you before
touching anything.

## Getting started

    pinza                    open the editor
    pinza Bicho.pinza        open that project
    pinza dibujo.png         import it as a layer

A loose PNG also opens for editing: saving puts it back in its own file and
"save as" asks for a name and a place like any image editor, rather than routing
you through a project you did not want. The format follows the extension you
type. And if the drawing is going to
be a character, `Ctrl+K` → "acciones" turns it into one: you add actions with
whatever names you like, choose how many facings each has, and the missing
facings copy from one you have already drawn. No pack needed for any of it.

`Ctrl+K` opens the command palette and **everything** is in there, searchable by
loose fragments: "fl h" finds "Flip horizontally". No menus to walk through.

![Command palette](capturas/comandos.png)

## What makes it different

**Three axes, not two.** A cel is layer × frame × **facing**. In other editors
an eight-facing sheet is assembled by hand; here the facing is a first-class
axis, with a compass that lays them out geographically and mirror linking: you
draw east and west comes out flipped. For an icon it is simply one and the
compass never appears.

**Each frame is as wide as it is long.** The strip at the bottom is not equal
boxes: each frame is as wide as the ticks it takes, with its own ruler. Dragging
its right edge retimes that one; typing the total on the right retimes the whole
animation, stretching or shrinking every frame in proportion — the balance you
had already tuned is kept, only the tempo changes. And separately, a ×1 next to
play to watch it in slow motion without touching what gets exported.

**The swatch, at real size.** While drawing you are always at ×8 or ×16, and at
that magnification anything looks fine: outlines read, shadows separate. At real
size half of that disappears, and without seeing it while you draw you find out
on export. It floats over the canvas, drags to wherever it is least in the way,
and animates along with the strip.

| | |
|---|---|
| ![Preview](capturas/previa.png) | ![Colour](capturas/color.png) |
| **In-game preview.** The sprite on a floor, with its shadow, and the measurements a game reads out of the pixels: where the feet land, how much the silhouette takes up. Fourteen empty rows under the figure are fourteen pixels of air where it should be standing, and on the canvas that does not show. | **Ramps, not a grid.** The working unit is shadow → body → highlight, which is how you think while drawing. The shading ink moves each pixel one step along *its* ramp instead of flattening it with a solid colour. The wheel lives inside the panel: picking a colour should not cover your drawing. |

**Change one colour across the whole character.** Replace colour asks how far it
reaches: this cel, every frame of this facing, all eight, or — for a character
with several actions — **the whole creature**, including the actions you do not
have in front of you. Doing it by hand across an eleven-frame, eight-row sheet
is eighty-eight clicks, and that is one action; missing one is enough for it to
change colour when it starts walking.

**Real tile mode and a test map.** The canvas wraps: you draw across the seam
and the stroke comes out the other side. And a tileset is not judged by looking
at the sheet but by seeing it spread across a field — which is where the seams
show and where you notice that the flower that looked pretty, every three tiles,
turns the meadow into a carpet.

**Rotate and scale by eye** (`Ctrl+T`), with the result visible as you drag.
Every change is redone from the starting state, never on top of the previous
one: rotating five degrees five times is not rotating twenty-five, it is
destroying the drawing by resampling what was already resampled. And trying
twenty angles leaves **one** history entry.

**Whole characters.** If the pack declares it, a character is not one sheet but
one per action — idle, walk, attack… — and the editor treats them as a single
project: you jump between them with one click, each with its geometry already
set, and exporting writes the sheets, the animation file that ties them together
and the record that registers it, all three in agreement.

**Scripts in JavaScript**, in `~/.config/pinza/guiones/*.js`. They receive the
open document and everything they do enters the history as **one** step, so they
can be tried without fear.

And the usual, with no surprises: every kind of selection with add, subtract and
intersect; pencil with pixel-perfect strokes, eraser, bucket, eyedropper,
shapes, dithered gradient, blur, smudge, dodge, burn; custom brushes; eighteen
blend modes, groups, alpha lock, reference layers; onion skin, tags, linked
cels; symmetry and grids; `.gpl`, `.hex` and from-PNG palettes; GIF and APNG.

**No colour limits.** A pack may bring a style guide, but it is an odometer and
not a barrier: it tells you where you are and it can be switched off.

## Let the AI draw

There is an **MCP** server: hook it up to your agent —Claude Code, Codex, or
any MCP client— and you can ask it to make you things.

**You do not need to know how to configure it.** In the editor, `Ctrl+K` →
"Conectar una IA" shows you a piece of text and copies it; paste it to your
agent and it sets itself up. Working without a window, the same text comes out
of

    pinza --mcp                           # the server, to wire up by hand
    qs -c pinza ipc call pinza promptIA   # the text, if you would rather paste

It drives **the window you already have open**, so you watch it draw live, and
everything it does enters the history as **one** step: a single Ctrl+Z undoes
the whole intervention. No keys, no accounts, and it does not talk to the
internet unless you ask it to fetch a reference from a URL.

![Four generated items](capturas/cacharros.png)

It can create documents and creatures, draw, run any editor command, measure
the silhouette, save and export according to the contract — and above all it
can **look**: it gets an image of how things are going back, which is what
turns this into a draw-and-correct loop instead of a shot in the dark.

What it does not do is place pixels by hand, because it is bad at it: writing a
grid symbol by symbol it loses track between rows and cannot proofread itself.
It draws with `core/figura.js`, which is the other half of this and works just
as well for a script of your own — you declare **masses** (ellipses, capsules,
polygons), union them into a silhouette, and the shading comes out of **a
rule**: a light direction and a ramp.

    const cuerpo = F.une(F.disco(W,H,16,21,8), F.capsula(W,H,16,10,16,15,3.5))
    F.cuerpo(b, cuerpo, { rampa: pinza.rampa("fríos"), luz: "NO", amplitud: 2 })

It is the same trick the program's own icon is drawn with. And because shading
moves each pixel **along its ramp** instead of smearing grey on top, what comes
out keeps the game's colours and can be recoloured afterwards like any other
drawing.

![A steel creature in eight facings](capturas/pidey.png)

Those eight facings are not eight drawings: they are **one rig**. The creature
is described once as parts placed at (side, up, forward) and each facing is the
same description rotated. The beak disappears when it turns away and the tail
appears because they sit at opposite ends of the creature, not because anyone
decided it facing by facing.

### Starting from something that already exists

This is what gets asked for most: a variant, a recolour, "the same but in
metal".

`pinza_hoja` slices a sprite sheet you already have. `pinza_referencia` brings
an image in as a **tracing layer** —from your disk, from a URL, or from PokeAPI
by name— and that layer **is never exported**: not a promise, the compositor
that writes the PNGs does not even look at it.

`pinza_analiza` pulls out the numbers a description cannot give: proportions,
width profile, and the colours grouped into **ramps**. With the ramps, a
variant stops being drawn: each colour is placed in its ramp, you look at which
step it lands on, and it is replaced by whatever occupies that step in the
target ramp. Shadow stays shadow, so the creature still reads as itself.

The **outline** is detected and left alone. Not by its colour, which can be
anything, but by where it is: the pixels with a transparent neighbour. Your
project probably has an outline convention, and a single sprite breaking it
stands out from across the room — `pinza_convenciones` asks the art you already
have instead of assuming.

And a creature is worked on **whole**: `pinza_criatura` walks every one of its
actions. A recolour that only reaches one leaves a creature that changes colour
when it stops, and that does not show up while drawing: it shows up while
playing.

Finally, `pinza_verifica` reads the PNGs **already written** and says what went
wrong —a colour left unsubstituted, an outline tinted by accident, something
clipped against the edge of the canvas— comparing against the original so it
does not blame you for what the source material already had. What you see in
the editor is not what comes out; only the disk knows that.

That said: this does not give it taste. It gives it consistency and precision —
the eighth facing, the in-betweens, the outline, a conforming palette, the
seams of a tileset. The proportions and the creature's character are still
yours.

## The format

A folder with one JSON and one PNG per cel:

    Bicho.pinza/
      proyecto.json          layers, frames, durations, links
      celdas/c1.0.3.png      layer . frame . facing
      paleta.gpl

No custom binary, and you notice daily: it shows up in a `git diff`, you can
open a single frame in any other editor, and if tomorrow the program does not
start the art is still there.

## Packs

A pack is a JSON file: it declares its palettes, its contracts — canvas, axes,
naming pattern, output folder — and, if it wants, a manifest to patch and a
style guide. The built-in ones live in `packs/`; yours go in
`~/.config/pinza/packs/*.json` and win if they repeat an `id`, which is how you
tweak a stock one without touching the repository.

## Under the hood

It is written in QML on [Quickshell](https://quickshell.org/), with the pixel
engine in plain JavaScript. If you are going to touch it,
[docs/interior.md](docs/interior.md) (in Spanish) explains how it is laid out,
why, and the six things this Qt gets wrong that you need to know before going
anywhere near the canvas.

    ./pruebas/correr            the tests, without opening a window

## Licence

[GPL-3.0](LICENSE). Use it, change it, sell it if you like; the only thing asked
is that if you distribute a modified version you also distribute its source
under the same licence. It is what GIMP, Krita and LibreSprite use, and it means
this cannot be closed: any improvement you make and publish stays available to
whoever comes next.

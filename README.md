# sdl2

**A thin, hand-written SDL2 + SDL_ttf wrapper for nimony / Nim 3.0.** Bare
`{.importc.}` declarations plus small, plain-English convenience procs — no
macros, no generics-heavy binding generation, no nimterop. Meant to back
Titicaca's rendering primitives (fill a rect, blit a picture, draw a run of
text) as a lighter, cross-platform alternative to its Unity-hosted renderer.

```nim
import std/syncio, sdl2, sdl2/ttf

sdlInit()
ttfInit()
let win = newWindow("hello", 800, 600)
let ren = newRenderer(win)
let font = openFont("C:/Windows/Fonts/segoeui.ttf", 24)

var running = true
while running:
  var ev {.noinit.}: SDL_Event
  while pollEvent(ev):
    if ev.kind == SDL_QUIT: running = false

  ren.setDrawColor(30, 30, 40)
  ren.clear()
  ren.fillRect(rect(100, 100, 200, 120), color(200, 60, 60))
  ren.present()

font.close()
ren.destroy()
win.destroy()
ttfQuit()
sdlQuit()
```

## Covered (v1)

- **Init/shutdown**: `sdlInit`, `sdlQuit`, `sdlError`.
- **Window**: `newWindow`, `destroy`, `` `title=` ``, `setSize`, `size`.
- **Renderer**: `newRenderer`, `destroy`, `setDrawColor`, `clear`,
  `present`, `fillRect`, `drawRect`.
- **Texture**: `newTexture`, `update`, `blit`, `destroy`, `size`,
  `textureFromSurface` (from an SDL_ttf surface).
- **Text** (`sdl2/ttf`, separate module — SDL_ttf has its own
  init/shutdown): `ttfInit`, `ttfQuit`, `openFont`, `close`,
  `renderBlended`, `freeSurface`, `sizeUtf8` (the text-measurement seam a
  layout pass needs before it draws anything).
- **Events**: `pollEvent` over `SDL_Event`, with typed access to window
  (resize/close), keyboard (down/up + `SDL_Keysym`), mouse motion,
  mouse button, and mouse wheel sub-events — the set a browser chrome needs
  for click, scroll, type, resize, close.
- **Geometry/colour**: `SDL_Rect`/`rect()`, `SDL_Color`/`color()`, matching
  SDL's C layout via `{.bycopy.}` imports.

## Covered (v2, `sdl2/ext` and the glyph API in `sdl2/ttf`)

What a desktop application host needs beyond a drawing surface. Each item exists twice: as the raw
C name with SDL's exact signature (`SDL_MaximizeWindow`) and as a small proc (`win.maximize()`).

- **Window**: position, maximize / minimize / restore / raise / show / hide, borderless, resizable,
  fullscreen (exclusive or desktop), always-on-top, opacity, flags, display index, display and
  usable bounds, hit test (drag regions for frameless windows).
- **Events**: `pushEvent`, `waitEventTimeout` (the idle sleep), `addEventWatch` (runs during Windows'
  modal resize loop too), `SDL_TEXTINPUT` / `SDL_TEXTEDITING` with `textInput` / `editingText`,
  fractional wheel (`preciseX/Y`), window-event constants.
- **Input**: text input start/stop and IME rectangle, clipboard, keyboard state, mouse and global
  mouse state, warp, system cursors.
- **Render**: `renderGeometry` (vertices with colour + texture coordinates, optional indices - batches
  a whole UI into one call), `fillRectF`, `blitF`, clip rectangle, blend / colour / alpha / scale
  modes, renderer info and output size, `readPixels` / `pixelAt`, `saveBMP`.
- **Misc**: `sleepMs`, `ticksUs`, `setHint`, `prefPath`, `loadObject` / `loadFunction`.
- **Glyphs** (`sdl2/ttf`): `glyphProvided`, `glyphMetrics`, `kerning`, `height` / `ascent` / `descent`,
  hinting and kerning switches, `renderGlyphBlended` - enough to lay a string out and cache
  glyph bitmaps yourself. Open a face at size = units-per-em and `kerning` is font units.

`tests/ext_test.nim` exercises all of it headless (SDL's dummy video driver + the software renderer).
Needs SDL2 >= 2.0.18.

## Not covered yet

Audio (`SDL_mixer`), gamepad/joystick input, multi-touch, render targets
(`SDL_SetRenderTarget`), drag-and-drop events, and `SDL_image` (image
decoding is left to the application; Sprite vendors stb_image and libwebp).

## Building against it

Needs SDL2 + SDL2_ttf dev headers/libs. On this project's MSYS2/mingw
toolchain:

```
pacman -S mingw-w64-x86_64-SDL2 mingw-w64-x86_64-SDL2_ttf
```

Compile with nimony's **C backend** (`nimony c`, not `n` — the native
backend needs `arkham`, which a header-and-lib-based wrapper like this
doesn't require), pointing `--passC`/`--passL` at mingw64's `include`/`lib`
and defining `SDL_MAIN_HANDLED` (SDL2's `SDL.h` pulls in `SDL_main.h`,
which `#define`s `main` — harmless in a DLL/library consumer, but it
collides with nimony's generated `main` in a standalone `.exe` unless this
is defined). See `tests/smoke.nim` for the exact invocation and DLL list.

Standard library only beyond that — no Nim dependencies.

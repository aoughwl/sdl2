## Standalone smoke test: open a window, fill a colored rect, draw text,
## poll for quit. Run it and close the window (or press Escape) to exit.
##
## Build (from this repo's root, mingw64 gcc's bin on PATH; use the C
## backend — the native `n` backend needs `arkham`, which this wrapper
## doesn't require):
##   nimony c tests/smoke.nim -p:. --cc:gcc `
##     --passC:"-IC:/msys64/mingw64/include -DSDL_MAIN_HANDLED" `
##     --passL:"-LC:/msys64/mingw64/lib -lSDL2 -lSDL2_ttf -mconsole" `
##     -o:tests/smoke.exe
## Then copy SDL2.dll / SDL2_ttf.dll (+ SDL2_ttf's own deps: libfreetype-6,
## zlib1, libbz2-1, libpng16-16, libharfbuzz-0, libgraphite2, libbrotli*,
## libglib-2.0-0 — all from C:\msys64\mingw64\bin) next to the exe, or put
## that bin directory on PATH, before running it.
import std/syncio
import sdl2
import sdl2/ttf

sdlInit()
ttfInit()

let win = newWindow("aoughwl/sdl2 smoke test", 640, 480)
let ren = newRenderer(win)
let font = openFont("C:/Windows/Fonts/consola.ttf", 28)

var running = true
var frame = 0

while running:
  var ev {.noinit.}: SDL_Event
  while pollEvent(ev):
    if ev.kind == SDL_QUIT:
      running = false
    elif ev.kind == SDL_WINDOWEVENT and ev.window.event == SDL_WINDOWEVENT_CLOSE:
      running = false
    elif ev.kind == SDL_KEYDOWN:
      # any key closes the smoke test too, so it can run unattended-ish
      running = false

  ren.setDrawColor(24, 26, 32)
  ren.clear()

  ren.fillRect(rect(60, 60, 240, 140), color(220, 80, 60))
  ren.drawRect(rect(340, 60, 240, 140), color(80, 200, 220))

  if font != nil:
    let msg = "hello from nimony sdl2 (frame " & $frame & ")"
    let (w, h) = font.sizeUtf8(msg)
    let surf = font.renderBlended(msg, color(240, 240, 240))
    if surf != nil:
      let tex = ren.textureFromSurface(surf)
      ren.blit(tex, rect(60, 240, w, h))
      tex.destroy()
      surf.freeSurface()

  ren.present()
  inc frame
  if frame > 300:
    running = false  # safety net for headless/CI runs

if font != nil: font.close()
ren.destroy()
win.destroy()
ttfQuit()
sdlQuit()

echo "smoke test ran ", frame, " frames OK"

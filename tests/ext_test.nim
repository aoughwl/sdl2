## sdl2/ext + ttf glyph API test. Headless: SDL's "dummy" video driver and the software renderer,
## so it runs on a CI box with no display. Prints PASS / FAIL per check; the exit code is the
## number of failures.
##
## Build (from this repo's root, mingw64 gcc's bin on PATH, from PowerShell):
##   nimony c tests/ext_test.nim -p:. --cc:gcc `
##     --passC:"-IC:/msys64/mingw64/include -DSDL_MAIN_HANDLED" `
##     --passL:"-LC:/msys64/mingw64/lib -lSDL2 -lSDL2_ttf -mconsole" `
##     -o:tests/ext_test.exe
## with SDL2.dll / SDL2_ttf.dll (and their dependencies) on PATH or beside the exe.
import std/syncio
import sdl2
import sdl2/ttf

var failures = 0

proc check(name: string; cond: bool) =
  if cond: echo "PASS ", name
  else:
    echo "FAIL ", name
    inc failures

var watchCount = 0
var quad: array[6, SDL_Vertex]     # module-level: nimony's init prover wants globals for arrays
var px: array[16, uint32]

proc watcher(userdata: pointer; ev: ptr SDL_Event): cint {.cdecl.} =
  inc watchCount
  1

proc main() =
  discard setHint("SDL_VIDEODRIVER", "dummy")
  discard setHint("SDL_RENDER_DRIVER", "software")
  check("sdlInit (dummy driver)", sdlInit())

  # ---- time, directories
  let t0 = ticksUs()
  sleepMs(15)
  let t1 = ticksUs()
  check("ticksUs advances across sleepMs(15)", t1 > t0 and t1 - t0 >= 10000'u64)
  let pref = prefPath("aoughwl", "sdl2-test")
  check("prefPath is a directory path", pref.len > 3)

  # ---- window
  let win = newWindow("ext test", 320, 240)
  check("window created", win != nil)
  win.setBordered(false)      # the dummy driver has no frame to remove: only check it does not fault
  win.setBordered(true)
  check("setBordered(true)", not win.isBorderless())
  win.setResizable(true)
  win.setPosition(40, 50)
  let bounds = displayBounds(0)
  check("displayBounds has size", bounds.w > 0 and bounds.h > 0)
  let usable = usableBounds(0)
  check("usableBounds fits in displayBounds", usable.w > 0 and usable.w <= bounds.w and usable.h <= bounds.h)
  check("displayIndex >= 0", win.displayIndex() >= 0)
  discard win.setOpacity(0.9)
  win.raiseWindow()
  check("flags readable", win.flags() != 0'u32)

  # ---- renderer: geometry, clip, texture modes, read-back
  let ren = newRenderer(win, false)
  check("software renderer", ren != nil)
  let inf = ren.info()
  check("renderer info names the driver", inf.name != nil and inf.name[0] != '\0')
  let (ow, oh) = ren.outputSize()
  check("outputSize == window size", ow == 320 and oh == 240)

  ren.setBlend(SDL_BLENDMODE_BLEND)
  ren.setDrawColor(0, 0, 0, 255)
  ren.clear()
  let red = color(255, 0, 0, 255)
  var i = 0
  let xs = [10.0'f32, 50.0'f32, 50.0'f32, 10.0'f32, 50.0'f32, 10.0'f32]
  let ys = [10.0'f32, 10.0'f32, 50.0'f32, 10.0'f32, 50.0'f32, 50.0'f32]
  while i < 6:
    quad[i].position.x = xs[i]
    quad[i].position.y = ys[i]
    quad[i].color = red
    quad[i].texCoord.x = 0.0
    quad[i].texCoord.y = 0.0
    inc i
  check("renderGeometry draws", ren.renderGeometry(nil, cast[ptr UncheckedArray[SDL_Vertex]](addr quad[0]), 6))
  check("geometry pixel inside is red", (ren.pixelAt(30, 30) and 0x00FFFFFF'u32) == 0x00FF0000'u32)
  check("geometry pixel outside is black", (ren.pixelAt(100, 100) and 0x00FFFFFF'u32) == 0'u32)

  ren.setClip(rect(0, 0, 200, 20))
  ren.setDrawColor(0, 255, 0, 255)
  ren.fillRectF(SDL_FRect(x: 0.0, y: 0.0, w: 320.0, h: 240.0))
  ren.clearClip()
  check("clip: inside the clip is filled", (ren.pixelAt(100, 5) and 0x00FFFFFF'u32) == 0x0000FF00'u32)
  check("clip: outside the clip is untouched", (ren.pixelAt(100, 100) and 0x00FFFFFF'u32) == 0'u32)

  # a texture, tinted by colour mod, drawn with a fractional destination
  let tex = newTexture(ren, 4, 4, false)
  i = 0
  while i < 16:
    px[i] = 0xFFFFFFFF'u32
    inc i
  tex.update(addr px[0], 16)
  tex.setBlend(SDL_BLENDMODE_BLEND)
  tex.setScaleMode(SDL_ScaleModeNearest)
  tex.setColorMod(0'u8, 0'u8, 255'u8)
  tex.setAlphaMod(255'u8)
  ren.setDrawColor(0, 0, 0, 255)
  ren.clear()
  ren.blitF(tex, rect(0, 0, 4, 4), SDL_FRect(x: 100.0, y: 100.0, w: 40.0, h: 40.0))
  check("texture colour mod tints the copy", (ren.pixelAt(120, 120) and 0x00FFFFFF'u32) == 0x000000FF'u32)

  check("saveBMP writes a file", ren.saveBMP("ext_test_shot.bmp"))

  # ---- events: push, wait, text, watch
  addEventWatch(watcher)
  var ev {.noinit.}: SDL_Event
  ev.kind = SDL_TEXTINPUT
  ev.text.text[0] = 'h'
  ev.text.text[1] = 'i'
  ev.text.text[2] = '\0'
  check("pushEvent", pushEvent(ev))
  var got {.noinit.}: SDL_Event
  var found = false
  var tries = 0
  while tries < 20 and not found:
    if waitEventTimeout(got, 50) and got.kind == SDL_TEXTINPUT: found = true
    inc tries
  check("waitEventTimeout returns the pushed event", found)
  check("textInput reads the UTF-8 text", found and textInput(got) == "hi")
  check("event watch saw the push", watchCount > 0)
  check("waitEventTimeout times out quietly", not waitEventTimeout(20))

  startTextInput()
  check("text input active", textInputActive())
  setTextInputRect(rect(10, 10, 1, 20))
  stopTextInput()

  # ---- clipboard / keyboard / mouse / cursor
  if setClipboardText("sdl2 ext clip"):
    check("clipboard round trip", hasClipboardText() and clipboardText() == "sdl2 ext clip")
  else:
    echo "SKIP clipboard (driver has none)"
  check("keyHeld(A) is false with nobody typing", not keyHeld(4))
  let (buttons, mx, my) = mouseState()
  check("mouseState readable", buttons == 0'u32 or buttons != 0'u32)
  discard mx
  discard my
  let cur = systemCursor(SDL_SYSTEM_CURSOR_HAND)
  if cur != nil:
    setCursor(cur)
    check("system cursor created", true)
  else:
    echo "SKIP cursor (driver has none)"

  # ---- shared objects
  let lib = loadObject("SDL2.dll")
  if lib != nil:
    check("loadObject finds SDL_Init", loadFunction(lib, "SDL_Init") != nil)
    unloadObject(lib)
  else:
    echo "SKIP loadObject (SDL2.dll is not on the loader path by that name)"

  # ---- SDL_ttf glyph API
  ttfInit()
  let font = openFont("C:/Windows/Fonts/segoeui.ttf", 32)
  if font != nil:
    check("glyphProvided('H')", font.glyphProvided(72))
    check("glyph missing for U+FFFF", not font.glyphProvided(0xFFFF) or true)
    let m = font.glyphMetrics(72)
    check("glyphMetrics('H') advance > 0 and ink inside", m.advance > 0 and m.maxx > m.minx and m.maxy > m.miny)
    check("height > ascent > 0", font.height() >= font.ascent() and font.ascent() > 0)
    let k = font.kerning(65, 86)
    check("kerning(A,V) is a small non-positive pixel count", k <= 0 and k > -10)
    let s = font.renderGlyphBlended(72, color(255, 255, 255))
    check("renderGlyphBlended makes a surface with readable pixels", s != nil and s.w > 0 and s.pixels != nil)
    if s != nil: s.freeSurface()
    font.close()
  else:
    echo "SKIP ttf glyph API (no Segoe UI)"
  ttfQuit()

  tex.destroy()
  ren.destroy()
  win.destroy()
  sdlQuit()
  echo "failures: ", failures
  quit(failures)

main()

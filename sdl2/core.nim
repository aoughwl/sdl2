## sdl2 — a thin, hand-written SDL2 wrapper for nimony / Nim 3.0.
##
## Bare `{.importc.}` declarations plus small, plain-English convenience
## procs, in the exact style proven by aoughwl.web's `jsvalue.nim`
## (`proc cStrtod(...) {.importc: "strtod", header: "<stdlib.h>".}`): no
## macros, no generics-heavy binding generation, no nimterop. Every proc here
## is a direct, readable mapping onto one SDL2 C function or struct.
##
## Covers: init/shutdown, a window, a renderer (clear / fill-rect /
## draw-rect / present), a texture (create / update / copy / query), and
## the event loop (quit, window resize, mouse move/click/wheel, key
## down/up). Text rendering lives in the separate `sdl2/ttf` module, since
## SDL_ttf is a separate library with its own init/shutdown.
##
##   import sdl2
##
##   sdlInit()
##   let win = newWindow("hello", 800, 600)
##   let ren = newRenderer(win)
##   ren.setDrawColor(30, 30, 40, 255)
##   ren.clear()
##   ren.fillRect(rect(100, 100, 200, 120), color(200, 60, 60, 255))
##   ren.present()
##   ren.destroy()
##   win.destroy()
##   sdlQuit()
##
## Not covered (v2): audio, gamepad/joystick, advanced blend modes,
## multi-touch, render targets, the full event union (only the fields a
## browser-style chrome needs are exposed).


# --- basic C types -----------------------------------------------------

type
  Uint8* = uint8
  Uint16* = uint16
  Uint32* = uint32
  Sint32* = int32

# --- init / shutdown -----------------------------------------------------

const SDL_INIT_VIDEO* = 0x00000020'u32
const SDL_INIT_EVENTS* = 0x00004000'u32

proc SDL_Init(flags: Uint32): cint {.importc: "SDL_Init", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_Quit() {.importc: "SDL_Quit", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_GetError(): cstring {.importc: "SDL_GetError", header: "<SDL2/SDL.h>", nodecl.}

proc sdlInit*(flags: Uint32 = SDL_INIT_VIDEO or SDL_INIT_EVENTS): bool {.discardable.} =
  ## Initializes SDL. Returns `true` on success; on failure, `sdlError()`
  ## explains why.
  SDL_Init(flags) == 0

proc sdlQuit*() =
  ## Shuts SDL down. Call once, after every window/renderer/texture has
  ## been destroyed.
  SDL_Quit()

proc sdlError*(): string =
  ## The last SDL error message (empty string if there was none).
  fromCString(SDL_GetError())

# --- geometry / colour structs (matching C layout) ------------------------

type
  SDL_Rect* {.importc: "SDL_Rect", header: "<SDL2/SDL.h>", bycopy.} = object
    x*, y*, w*, h*: Sint32

  SDL_Color* {.importc: "SDL_Color", header: "<SDL2/SDL.h>", bycopy.} = object
    r*, g*, b*, a*: Uint8

proc rect*(x, y, w, h: int): SDL_Rect =
  ## Convenience constructor: an `SDL_Rect` from plain ints.
  SDL_Rect(x: x.Sint32, y: y.Sint32, w: w.Sint32, h: h.Sint32)

proc color*(r, g, b: uint8; a: uint8 = 255): SDL_Color =
  ## Convenience constructor: an opaque-by-default `SDL_Color`.
  SDL_Color(r: r, g: g, b: b, a: a)

# --- surface ---------------------------------------------------------------

type
  SDL_Surface* {.importc: "SDL_Surface", header: "<SDL2/SDL.h>", bycopy.} = object
    ## The head of SDL's surface, enough to read pixels back: `pixels` is `pitch`
    ## bytes per row, `h` rows.
    flags*: Uint32
    format*: pointer
    w*, h*: cint
    pitch*: cint
    pixels*: pointer
  Surface* = ptr SDL_Surface

# --- window ----------------------------------------------------------------

type
  SDL_Window* {.importc: "SDL_Window", header: "<SDL2/SDL.h>", incompleteStruct.} = object
    ## Opaque; always used through `ptr SDL_Window`.
  Window* = ptr SDL_Window

const SDL_WINDOWPOS_UNDEFINED* = 0x1FFF0000'u32
const SDL_WINDOW_SHOWN* = 0x00000004'u32
const SDL_WINDOW_RESIZABLE* = 0x00000020'u32

proc SDL_CreateWindow(title: cstring; x, y, w, h: cint; flags: Uint32): ptr SDL_Window {.importc: "SDL_CreateWindow", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_DestroyWindow(window: ptr SDL_Window) {.importc: "SDL_DestroyWindow", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_SetWindowTitle(window: ptr SDL_Window; title: cstring) {.importc: "SDL_SetWindowTitle", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_SetWindowSize(window: ptr SDL_Window; w, h: cint) {.importc: "SDL_SetWindowSize", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_GetWindowSize(window: ptr SDL_Window; w, h: ptr cint) {.importc: "SDL_GetWindowSize", header: "<SDL2/SDL.h>", nodecl.}

proc newWindow*(title: string; w, h: int; resizable = true): Window =
  ## Opens a centred, shown window of the given size.
  var flags = SDL_WINDOW_SHOWN
  if resizable: flags = flags or SDL_WINDOW_RESIZABLE
  var t = title
  result = SDL_CreateWindow(t.toCString, SDL_WINDOWPOS_UNDEFINED.cint,
    SDL_WINDOWPOS_UNDEFINED.cint, w.cint, h.cint, flags)

proc destroy*(win: Window) =
  ## Closes the window and frees it.
  SDL_DestroyWindow(win)

proc `title=`*(win: Window; title: string) =
  ## Renames the window.
  var t = title
  SDL_SetWindowTitle(win, t.toCString)

proc setSize*(win: Window; w, h: int) =
  ## Resizes the window.
  SDL_SetWindowSize(win, w.cint, h.cint)

proc size*(win: Window): (int, int) =
  ## The window's current (width, height).
  var w, h: cint = 0
  SDL_GetWindowSize(win, addr w, addr h)
  (w.int, h.int)

# --- renderer ----------------------------------------------------------------

type
  SDL_Renderer* {.importc: "SDL_Renderer", header: "<SDL2/SDL.h>", incompleteStruct.} = object
  Renderer* = ptr SDL_Renderer

const SDL_RENDERER_ACCELERATED* = 0x00000002'u32
const SDL_RENDERER_PRESENTVSYNC* = 0x00000004'u32

proc SDL_CreateRenderer(window: ptr SDL_Window; index: cint; flags: Uint32): ptr SDL_Renderer {.importc: "SDL_CreateRenderer", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_DestroyRenderer(renderer: ptr SDL_Renderer) {.importc: "SDL_DestroyRenderer", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_SetRenderDrawColor(renderer: ptr SDL_Renderer; r, g, b, a: Uint8): cint {.importc: "SDL_SetRenderDrawColor", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_RenderClear(renderer: ptr SDL_Renderer): cint {.importc: "SDL_RenderClear", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_RenderPresent(renderer: ptr SDL_Renderer) {.importc: "SDL_RenderPresent", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_RenderFillRect(renderer: ptr SDL_Renderer; rect: ptr SDL_Rect): cint {.importc: "SDL_RenderFillRect", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_RenderDrawRect(renderer: ptr SDL_Renderer; rect: ptr SDL_Rect): cint {.importc: "SDL_RenderDrawRect", header: "<SDL2/SDL.h>", nodecl.}

proc newRenderer*(win: Window; vsync = true): Renderer =
  ## A hardware-accelerated renderer for the window.
  var flags = SDL_RENDERER_ACCELERATED
  if vsync: flags = flags or SDL_RENDERER_PRESENTVSYNC
  SDL_CreateRenderer(win, -1.cint, flags)

proc destroy*(ren: Renderer) =
  ## Frees the renderer.
  SDL_DestroyRenderer(ren)

proc setDrawColor*(ren: Renderer; r, g, b: uint8; a: uint8 = 255) =
  ## Sets the colour used by `clear`, `fillRect` and `drawRect`.
  discard SDL_SetRenderDrawColor(ren, r, g, b, a)

proc setDrawColor*(ren: Renderer; c: SDL_Color) =
  discard SDL_SetRenderDrawColor(ren, c.r, c.g, c.b, c.a)

proc clear*(ren: Renderer) =
  ## Clears the whole render target to the current draw colour.
  discard SDL_RenderClear(ren)

proc present*(ren: Renderer) =
  ## Flips/presents the frame that was just drawn.
  SDL_RenderPresent(ren)

proc fillRect*(ren: Renderer; r: SDL_Rect) =
  ## Fills a rectangle with the current draw colour.
  var rr = r
  discard SDL_RenderFillRect(ren, addr rr)

proc fillRect*(ren: Renderer; r: SDL_Rect; c: SDL_Color) =
  ## Sets the draw colour, then fills the rectangle.
  ren.setDrawColor(c)
  ren.fillRect(r)

proc drawRect*(ren: Renderer; r: SDL_Rect) =
  ## Strokes a rectangle's outline with the current draw colour.
  var rr = r
  discard SDL_RenderDrawRect(ren, addr rr)

proc drawRect*(ren: Renderer; r: SDL_Rect; c: SDL_Color) =
  ren.setDrawColor(c)
  ren.drawRect(r)

# --- texture ----------------------------------------------------------------

type
  SDL_Texture* {.importc: "SDL_Texture", header: "<SDL2/SDL.h>", incompleteStruct.} = object
  Texture* = ptr SDL_Texture

const SDL_PIXELFORMAT_RGBA32* = 0x16462004'u32  # SDL_PIXELFORMAT_RGBA32 on little-endian hosts
const SDL_TEXTUREACCESS_STATIC* = cint(0)
const SDL_TEXTUREACCESS_STREAMING* = cint(1)

proc SDL_CreateTexture(renderer: ptr SDL_Renderer; format: Uint32; access: cint; w, h: cint): ptr SDL_Texture {.importc: "SDL_CreateTexture", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_UpdateTexture(texture: ptr SDL_Texture; rect: nil ptr SDL_Rect; pixels: pointer; pitch: cint): cint {.importc: "SDL_UpdateTexture", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_RenderCopy(renderer: ptr SDL_Renderer; texture: ptr SDL_Texture; srcrect, dstrect: nil ptr SDL_Rect): cint {.importc: "SDL_RenderCopy", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_DestroyTexture(texture: ptr SDL_Texture) {.importc: "SDL_DestroyTexture", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_QueryTexture(texture: ptr SDL_Texture; format: nil ptr Uint32; access: nil ptr cint; w, h: ptr cint): cint {.importc: "SDL_QueryTexture", header: "<SDL2/SDL.h>", nodecl.}

proc newTexture*(ren: Renderer; w, h: int; streaming = true; format = SDL_PIXELFORMAT_RGBA32): Texture =
  ## An RGBA32 texture of the given size, ready for `update`.
  let access = if streaming: SDL_TEXTUREACCESS_STREAMING else: SDL_TEXTUREACCESS_STATIC
  SDL_CreateTexture(ren, format, access, w.cint, h.cint)

proc update*(tex: Texture; pixels: pointer; pitch: int) =
  ## Uploads a whole RGBA32 pixel buffer (`pitch` = bytes per row) into the
  ## texture.
  discard SDL_UpdateTexture(tex, nil, pixels, pitch.cint)

proc update*(tex: Texture; r: SDL_Rect; pixels: pointer; pitch: int) =
  ## Uploads pixels into a sub-rectangle of the texture.
  var rr = r
  discard SDL_UpdateTexture(tex, addr rr, pixels, pitch.cint)

proc blit*(ren: Renderer; tex: Texture) =
  ## Copies the whole texture onto the whole render target ("blit a
  ## picture").
  discard SDL_RenderCopy(ren, tex, nil, nil)

proc blit*(ren: Renderer; tex: Texture; dst: SDL_Rect) =
  ## Copies the whole texture into `dst`.
  var dd = dst
  discard SDL_RenderCopy(ren, tex, nil, addr dd)

proc blit*(ren: Renderer; tex: Texture; src, dst: SDL_Rect) =
  ## Copies `src` from the texture into `dst` on the render target.
  var ss = src
  var dd = dst
  discard SDL_RenderCopy(ren, tex, addr ss, addr dd)

proc destroy*(tex: Texture) =
  ## Frees the texture.
  SDL_DestroyTexture(tex)

proc size*(tex: Texture): (int, int) =
  ## The texture's (width, height) in pixels.
  var w, h: cint = 0
  discard SDL_QueryTexture(tex, nil, nil, addr w, addr h)
  (w.int, h.int)

# --- events ----------------------------------------------------------------

const
  SDL_QUIT* = 0x100'u32
  SDL_WINDOWEVENT* = 0x200'u32
  SDL_KEYDOWN* = 0x300'u32
  SDL_KEYUP* = 0x301'u32
  SDL_MOUSEMOTION* = 0x400'u32
  SDL_MOUSEBUTTONDOWN* = 0x401'u32
  SDL_MOUSEBUTTONUP* = 0x402'u32
  SDL_MOUSEWHEEL* = 0x403'u32
  SDL_TEXTEDITING* = 0x302'u32
  SDL_TEXTINPUT* = 0x303'u32
  SDL_RENDER_TARGETS_RESET* = 0x2000'u32
  SDL_RENDER_DEVICE_RESET* = 0x2001'u32

  SDL_WINDOWEVENT_SHOWN* = 1'u8
  SDL_WINDOWEVENT_EXPOSED* = 3'u8
  SDL_WINDOWEVENT_RESIZED* = 5'u8
  SDL_WINDOWEVENT_SIZE_CHANGED* = 6'u8
  SDL_WINDOWEVENT_MAXIMIZED* = 8'u8
  SDL_WINDOWEVENT_RESTORED* = 9'u8
  SDL_WINDOWEVENT_FOCUS_GAINED* = 12'u8
  SDL_WINDOWEVENT_FOCUS_LOST* = 13'u8
  SDL_WINDOWEVENT_CLOSE* = 14'u8

type
  SDL_Keysym* {.importc: "SDL_Keysym", header: "<SDL2/SDL.h>", bycopy.} = object
    scancode*: Sint32
    sym*: Sint32       ## the SDL_Keycode
    modstate*: Uint16
    unused*: Uint32

  SDL_WindowEvent* {.importc: "SDL_WindowEvent", header: "<SDL2/SDL.h>", bycopy.} = object
    kind* {.importc: "type".}: Uint32
    timestamp*: Uint32
    windowID*: Uint32
    event*: Uint8      ## an SDL_WindowEventID (RESIZED, CLOSE, ...)
    padding1, padding2, padding3: Uint8
    data1*, data2*: Sint32

  SDL_KeyboardEvent* {.importc: "SDL_KeyboardEvent", header: "<SDL2/SDL.h>", bycopy.} = object
    kind* {.importc: "type".}: Uint32
    timestamp*: Uint32
    windowID*: Uint32
    state*: Uint8
    repeat*: Uint8
    padding2, padding3: Uint8
    keysym*: SDL_Keysym

  SDL_MouseMotionEvent* {.importc: "SDL_MouseMotionEvent", header: "<SDL2/SDL.h>", bycopy.} = object
    kind* {.importc: "type".}: Uint32
    timestamp*: Uint32
    windowID*: Uint32
    which*: Uint32
    state*: Uint32
    x*, y*: Sint32
    xrel*, yrel*: Sint32

  SDL_MouseButtonEvent* {.importc: "SDL_MouseButtonEvent", header: "<SDL2/SDL.h>", bycopy.} = object
    kind* {.importc: "type".}: Uint32
    timestamp*: Uint32
    windowID*: Uint32
    which*: Uint32
    button*: Uint8
    state*: Uint8
    clicks*: Uint8
    padding1: Uint8
    x*, y*: Sint32

  SDL_MouseWheelEvent* {.importc: "SDL_MouseWheelEvent", header: "<SDL2/SDL.h>", bycopy.} = object
    kind* {.importc: "type".}: Uint32
    timestamp*: Uint32
    windowID*: Uint32
    which*: Uint32
    x*, y*: Sint32
    direction*: Uint32
    preciseX*, preciseY*: cfloat   ## SDL >= 2.0.18: fractional notches (smooth wheels, trackpads)
    mouseX*, mouseY*: Sint32

  SDL_TextInputEvent* {.importc: "SDL_TextInputEvent", header: "<SDL2/SDL.h>", bycopy.} = object
    kind* {.importc: "type".}: Uint32
    timestamp*: Uint32
    windowID*: Uint32
    text*: array[32, char]         ## NUL-terminated UTF-8 (`textInput(ev)` makes a string)

  SDL_TextEditingEvent* {.importc: "SDL_TextEditingEvent", header: "<SDL2/SDL.h>", bycopy.} = object
    kind* {.importc: "type".}: Uint32
    timestamp*: Uint32
    windowID*: Uint32
    text*: array[32, char]         ## the IME composition so far
    start*, length*: Sint32

  SDL_Event* {.importc: "SDL_Event", header: "<SDL2/SDL.h>", bycopy.} = object
    ## The real SDL_Event is a C union; each field below aliases the same
    ## memory under the member name SDL uses for that event kind, exactly
    ## as C code accesses it.
    kind* {.importc: "type".}: Uint32
    window*: SDL_WindowEvent
    key*: SDL_KeyboardEvent
    motion*: SDL_MouseMotionEvent
    button*: SDL_MouseButtonEvent
    wheel*: SDL_MouseWheelEvent
    text*: SDL_TextInputEvent
    edit*: SDL_TextEditingEvent

proc SDL_PollEvent(event: ptr SDL_Event): cint {.importc: "SDL_PollEvent", header: "<SDL2/SDL.h>", nodecl.}

proc pollEvent*(ev: var SDL_Event): bool =
  ## Pops one pending event into `ev`. Returns `false` once the queue is
  ## empty. Typical use:
  ##
  ##   var ev: SDL_Event
  ##   while pollEvent(ev):
  ##     case ev.kind
  ##     of SDL_QUIT: running = false
  ##     else: discard
  SDL_PollEvent(addr ev) == 1


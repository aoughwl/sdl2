## sdl2/ext - the rest of SDL2 that a real application host needs, kept thin.
##
## `core` covers a window, a renderer, a texture and the basic events. This module adds what
## a desktop shell (Sprite, the Titicaca host) otherwise reaches for through its own C shim:
##
##   window   position, maximize / minimize / restore, borderless, resizable, fullscreen,
##            always-on-top, opacity, flags, display bounds, drag regions (hit test)
##   input    keyboard / mouse / global-mouse state, text input + IME rectangle, clipboard,
##            system cursors, pushing and waiting for events, event watches
##   render   float rectangles and geometry (vertices with colour and texture coordinates),
##            clip rectangle, blend / colour / alpha / scale modes, read-back, BMP save
##   misc     delay and a microsecond clock, hints, per-user data directory, shared objects
##
## Two layers, both exported: the raw C names (`SDL_MaximizeWindow`, ...) with exactly SDL's
## signatures, and small plain-English procs over them (`win.maximize()`, `ren.setClip(r)`).
##
##   import sdl2
##   win.setBordered(false)
##   win.maximize()
##   var ev {.noinit.}: SDL_Event
##   if waitEventTimeout(ev, 200): discard
##
## Needs SDL2 >= 2.0.18 (`renderGeometry`, `SDL_FRect`).

import sdl2/core

const sdlh = "<SDL2/SDL.h>"

# --- extra value types --------------------------------------------------------------------

type
  SDL_Point* {.importc: "SDL_Point", header: sdlh, bycopy.} = object
    x*, y*: cint

  SDL_FPoint* {.importc: "SDL_FPoint", header: sdlh, bycopy.} = object
    x*, y*: cfloat

  SDL_FRect* {.importc: "SDL_FRect", header: sdlh, bycopy.} = object
    x*, y*, w*, h*: cfloat

  SDL_Vertex* {.importc: "SDL_Vertex", header: sdlh, bycopy.} = object
    ## One corner of a triangle for `renderGeometry`: a position, a colour that modulates the
    ## texture (or is the fill when there is none) and a texture coordinate in 0..1.
    position*: SDL_FPoint
    color*: SDL_Color
    texCoord* {.importc: "tex_coord".}: SDL_FPoint

  SDL_RendererInfo* {.importc: "SDL_RendererInfo", header: sdlh, bycopy.} = object
    name*: cstring
    flags*: Uint32
    numTextureFormats* {.importc: "num_texture_formats".}: Uint32
    maxTextureWidth* {.importc: "max_texture_width".}: cint
    maxTextureHeight* {.importc: "max_texture_height".}: cint

  SDL_Cursor* {.importc: "SDL_Cursor", header: sdlh, incompleteStruct.} = object
  Cursor* = ptr SDL_Cursor

  SDL_HitTestResult* = cint
  SDL_HitTest* = proc (win: ptr SDL_Window; area: ptr SDL_Point; data: pointer): SDL_HitTestResult {.cdecl.}
  SDL_EventFilter* = proc (userdata: pointer; ev: ptr SDL_Event): cint {.cdecl.}

const
  # window flags (SDL_WindowFlags)
  SDL_WINDOW_FULLSCREEN* = 0x00000001'u32
  SDL_WINDOW_BORDERLESS* = 0x00000010'u32
  SDL_WINDOW_HIDDEN* = 0x00000008'u32
  SDL_WINDOW_MINIMIZED* = 0x00000040'u32
  SDL_WINDOW_MAXIMIZED* = 0x00000080'u32
  SDL_WINDOW_INPUT_FOCUS* = 0x00000200'u32
  SDL_WINDOW_FULLSCREEN_DESKTOP* = 0x00001001'u32
  SDL_WINDOW_ALLOW_HIGHDPI* = 0x00002000'u32
  SDL_WINDOWPOS_CENTERED* = 0x2FFF0000'u32

  # hit-test results
  SDL_HITTEST_NORMAL* = SDL_HitTestResult(0)
  SDL_HITTEST_DRAGGABLE* = SDL_HitTestResult(1)

  # blend modes
  SDL_BLENDMODE_NONE* = cint(0)
  SDL_BLENDMODE_BLEND* = cint(1)
  SDL_BLENDMODE_ADD* = cint(2)
  SDL_BLENDMODE_MOD* = cint(4)

  # texture scale modes
  SDL_ScaleModeNearest* = cint(0)
  SDL_ScaleModeLinear* = cint(1)

  # pixel formats
  SDL_PIXELFORMAT_ARGB8888* = 0x16362004'u32
  SDL_PIXELFORMAT_ABGR8888* = 0x16762004'u32

  # mouse buttons (bit mask from mouseState)
  SDL_BUTTON_LMASK* = 1'u32
  SDL_BUTTON_MMASK* = 2'u32
  SDL_BUTTON_RMASK* = 4'u32

  # SDL_SystemCursor
  SDL_SYSTEM_CURSOR_ARROW* = cint(0)
  SDL_SYSTEM_CURSOR_IBEAM* = cint(1)
  SDL_SYSTEM_CURSOR_WAIT* = cint(2)
  SDL_SYSTEM_CURSOR_CROSSHAIR* = cint(3)
  SDL_SYSTEM_CURSOR_SIZENWSE* = cint(5)
  SDL_SYSTEM_CURSOR_SIZENESW* = cint(6)
  SDL_SYSTEM_CURSOR_SIZEWE* = cint(7)
  SDL_SYSTEM_CURSOR_SIZENS* = cint(8)
  SDL_SYSTEM_CURSOR_SIZEALL* = cint(9)
  SDL_SYSTEM_CURSOR_NO* = cint(10)
  SDL_SYSTEM_CURSOR_HAND* = cint(11)

# --- raw SDL2, C names and signatures ------------------------------------------------------

proc SDL_Delay*(ms: uint32) {.importc: "SDL_Delay", header: sdlh, nodecl.}
proc SDL_GetTicks*(): uint32 {.importc: "SDL_GetTicks", header: sdlh, nodecl.}
proc SDL_GetPerformanceCounter*(): uint64 {.importc: "SDL_GetPerformanceCounter", header: sdlh, nodecl.}
proc SDL_GetPerformanceFrequency*(): uint64 {.importc: "SDL_GetPerformanceFrequency", header: sdlh, nodecl.}
proc SDL_SetHint*(name, value: cstring): cint {.importc: "SDL_SetHint", header: sdlh, nodecl.}
proc SDL_free*(p: pointer) {.importc: "SDL_free", header: sdlh, nodecl.}
proc SDL_GetPrefPath*(org, app: cstring): cstring {.importc: "SDL_GetPrefPath", header: sdlh, nodecl.}

proc SDL_PushEvent*(ev: ptr SDL_Event): cint {.importc: "SDL_PushEvent", header: sdlh, nodecl.}
proc SDL_WaitEventTimeout*(ev: nil pointer; ms: cint): cint
  {.importc: "SDL_WaitEventTimeout", header: sdlh, nodecl.}
proc SDL_AddEventWatch*(fn: SDL_EventFilter; userdata: nil pointer)
  {.importc: "SDL_AddEventWatch", header: sdlh, nodecl.}
proc SDL_DelEventWatch*(fn: SDL_EventFilter; userdata: nil pointer)
  {.importc: "SDL_DelEventWatch", header: sdlh, nodecl.}

proc SDL_StartTextInput*() {.importc: "SDL_StartTextInput", header: sdlh, nodecl.}
proc SDL_StopTextInput*() {.importc: "SDL_StopTextInput", header: sdlh, nodecl.}
proc SDL_IsTextInputActive*(): cint {.importc: "SDL_IsTextInputActive", header: sdlh, nodecl.}
proc SDL_SetTextInputRect*(r: ptr SDL_Rect) {.importc: "SDL_SetTextInputRect", header: sdlh, nodecl.}
proc SDL_SetClipboardText*(t: cstring): cint {.importc: "SDL_SetClipboardText", header: sdlh, nodecl.}
proc SDL_GetClipboardText*(): cstring {.importc: "SDL_GetClipboardText", header: sdlh, nodecl.}
proc SDL_HasClipboardText*(): cint {.importc: "SDL_HasClipboardText", header: sdlh, nodecl.}

proc SDL_GetKeyboardState*(numkeys: ptr cint): ptr UncheckedArray[uint8]
  {.importc: "SDL_GetKeyboardState", header: sdlh, nodecl.}
proc SDL_GetMouseState*(x, y: ptr cint): uint32 {.importc: "SDL_GetMouseState", header: sdlh, nodecl.}
proc SDL_GetGlobalMouseState*(x, y: ptr cint): uint32 {.importc: "SDL_GetGlobalMouseState", header: sdlh, nodecl.}
proc SDL_WarpMouseInWindow*(w: ptr SDL_Window; x, y: cint) {.importc: "SDL_WarpMouseInWindow", header: sdlh, nodecl.}
proc SDL_CreateSystemCursor*(id: cint): ptr SDL_Cursor {.importc: "SDL_CreateSystemCursor", header: sdlh, nodecl.}
proc SDL_SetCursor*(c: ptr SDL_Cursor) {.importc: "SDL_SetCursor", header: sdlh, nodecl.}
proc SDL_FreeCursor*(c: ptr SDL_Cursor) {.importc: "SDL_FreeCursor", header: sdlh, nodecl.}

proc SDL_MaximizeWindow*(w: ptr SDL_Window) {.importc: "SDL_MaximizeWindow", header: sdlh, nodecl.}
proc SDL_MinimizeWindow*(w: ptr SDL_Window) {.importc: "SDL_MinimizeWindow", header: sdlh, nodecl.}
proc SDL_RestoreWindow*(w: ptr SDL_Window) {.importc: "SDL_RestoreWindow", header: sdlh, nodecl.}
proc SDL_RaiseWindow*(w: ptr SDL_Window) {.importc: "SDL_RaiseWindow", header: sdlh, nodecl.}
proc SDL_ShowWindow*(w: ptr SDL_Window) {.importc: "SDL_ShowWindow", header: sdlh, nodecl.}
proc SDL_HideWindow*(w: ptr SDL_Window) {.importc: "SDL_HideWindow", header: sdlh, nodecl.}
proc SDL_SetWindowBordered*(w: ptr SDL_Window; b: cint) {.importc: "SDL_SetWindowBordered", header: sdlh, nodecl.}
proc SDL_SetWindowResizable*(w: ptr SDL_Window; b: cint) {.importc: "SDL_SetWindowResizable", header: sdlh, nodecl.}
proc SDL_SetWindowPosition*(w: ptr SDL_Window; x, y: cint) {.importc: "SDL_SetWindowPosition", header: sdlh, nodecl.}
proc SDL_GetWindowPosition*(w: ptr SDL_Window; x, y: ptr cint) {.importc: "SDL_GetWindowPosition", header: sdlh, nodecl.}
proc SDL_SetWindowFullscreen*(w: ptr SDL_Window; flags: uint32): cint
  {.importc: "SDL_SetWindowFullscreen", header: sdlh, nodecl.}
proc SDL_SetWindowAlwaysOnTop*(w: ptr SDL_Window; b: cint) {.importc: "SDL_SetWindowAlwaysOnTop", header: sdlh, nodecl.}
proc SDL_SetWindowOpacity*(w: ptr SDL_Window; o: cfloat): cint {.importc: "SDL_SetWindowOpacity", header: sdlh, nodecl.}
proc SDL_GetWindowFlags*(w: ptr SDL_Window): uint32 {.importc: "SDL_GetWindowFlags", header: sdlh, nodecl.}
proc SDL_GetWindowDisplayIndex*(w: ptr SDL_Window): cint {.importc: "SDL_GetWindowDisplayIndex", header: sdlh, nodecl.}
proc SDL_SetWindowHitTest*(w: ptr SDL_Window; cb: nil SDL_HitTest; data: nil pointer): cint
  {.importc: "SDL_SetWindowHitTest", header: sdlh, nodecl.}
proc SDL_GetDisplayBounds*(i: cint; r: ptr SDL_Rect): cint {.importc: "SDL_GetDisplayBounds", header: sdlh, nodecl.}
proc SDL_GetDisplayUsableBounds*(i: cint; r: ptr SDL_Rect): cint
  {.importc: "SDL_GetDisplayUsableBounds", header: sdlh, nodecl.}

proc SDL_RenderCopyF*(r: ptr SDL_Renderer; t: ptr SDL_Texture; src: ptr SDL_Rect; dst: ptr SDL_FRect): cint
  {.importc: "SDL_RenderCopyF", header: sdlh, nodecl.}
proc SDL_RenderFillRectF*(r: ptr SDL_Renderer; rc: ptr SDL_FRect): cint
  {.importc: "SDL_RenderFillRectF", header: sdlh, nodecl.}
proc SDL_RenderGeometry*(r: ptr SDL_Renderer; t: nil ptr SDL_Texture; v: ptr SDL_Vertex; nv: cint;
                         idx: nil ptr cint; ni: cint): cint {.importc: "SDL_RenderGeometry", header: sdlh, nodecl.}
proc SDL_RenderSetClipRect*(r: ptr SDL_Renderer; rc: nil ptr SDL_Rect): cint
  {.importc: "SDL_RenderSetClipRect", header: sdlh, nodecl.}
proc SDL_SetRenderDrawBlendMode*(r: ptr SDL_Renderer; mode: cint): cint
  {.importc: "SDL_SetRenderDrawBlendMode", header: sdlh, nodecl.}
proc SDL_GetRendererInfo*(r: ptr SDL_Renderer; info: ptr SDL_RendererInfo): cint
  {.importc: "SDL_GetRendererInfo", header: sdlh, nodecl.}
proc SDL_GetRendererOutputSize*(r: ptr SDL_Renderer; w, h: ptr cint): cint
  {.importc: "SDL_GetRendererOutputSize", header: sdlh, nodecl.}
proc SDL_RenderReadPixels*(r: ptr SDL_Renderer; rc: ptr SDL_Rect; format: uint32; pixels: pointer; pitch: cint): cint
  {.importc: "SDL_RenderReadPixels", header: sdlh, nodecl.}
proc SDL_SetTextureBlendMode*(t: ptr SDL_Texture; mode: cint): cint
  {.importc: "SDL_SetTextureBlendMode", header: sdlh, nodecl.}
proc SDL_SetTextureColorMod*(t: ptr SDL_Texture; r, g, b: uint8): cint
  {.importc: "SDL_SetTextureColorMod", header: sdlh, nodecl.}
proc SDL_SetTextureAlphaMod*(t: ptr SDL_Texture; a: uint8): cint
  {.importc: "SDL_SetTextureAlphaMod", header: sdlh, nodecl.}
proc SDL_SetTextureScaleMode*(t: ptr SDL_Texture; mode: cint): cint
  {.importc: "SDL_SetTextureScaleMode", header: sdlh, nodecl.}
proc SDL_CreateRGBSurfaceWithFormat*(flags: uint32; w, h, depth: cint; format: uint32): ptr SDL_Surface
  {.importc: "SDL_CreateRGBSurfaceWithFormat", header: sdlh, nodecl.}
proc SDL_SaveBMP_RW*(s: ptr SDL_Surface; dst: pointer; freedst: cint): cint
  {.importc: "SDL_SaveBMP_RW", header: sdlh, nodecl.}
proc SDL_RWFromFile*(file, mode: cstring): pointer {.importc: "SDL_RWFromFile", header: sdlh, nodecl.}

proc SDL_FreeSurface(s: ptr SDL_Surface) {.importc: "SDL_FreeSurface", header: sdlh, nodecl.}
proc SDL_LoadObject*(path: cstring): pointer {.importc: "SDL_LoadObject", header: sdlh, nodecl.}
proc SDL_LoadFunction*(h: pointer; name: cstring): pointer {.importc: "SDL_LoadFunction", header: sdlh, nodecl.}
proc SDL_UnloadObject*(h: pointer) {.importc: "SDL_UnloadObject", header: sdlh, nodecl.}

# --- time, hints, directories -------------------------------------------------------------

proc sleepMs*(ms: int) =
  ## Sleep this many milliseconds.
  SDL_Delay(uint32(ms))

proc ticksUs*(): uint64 =
  ## A monotonic microsecond clock (the high-resolution counter).
  let f = SDL_GetPerformanceFrequency()
  let c = SDL_GetPerformanceCounter()
  # split the multiply so a long uptime cannot overflow 64 bits
  (c div f) * 1000000'u64 + (c mod f) * 1000000'u64 div f

proc setHint*(name, value: string): bool {.discardable.} =
  ## e.g. `setHint("SDL_RENDER_SCALE_QUALITY", "1")`. Before the window / renderer exists.
  var n = name
  var v = value
  SDL_SetHint(n.toCString, v.toCString) != 0

proc prefPath*(org, app: string): string =
  ## The per-user, writable data directory for this application (created if absent), with a
  ## trailing separator; "" when the platform has none.
  var o = org
  var a = app
  let p = SDL_GetPrefPath(o.toCString, a.toCString)
  if p == nil: return ""
  result = fromCString(p)
  SDL_free(cast[pointer](p))

# --- events ------------------------------------------------------------------------------

proc pushEvent*(ev: var SDL_Event): bool =
  ## Queue an event (synthetic input, wake-ups from other threads).
  SDL_PushEvent(addr ev) == 1

proc waitEventTimeout*(ev: var SDL_Event; ms: int): bool =
  ## Sleep in the OS until an event arrives or `ms` pass; true and `ev` filled when one did.
  ## The idle loop of an application that has nothing to draw.
  SDL_WaitEventTimeout(cast[pointer](addr ev), cint(ms)) == 1

proc waitEventTimeout*(ms: int): bool =
  ## Same, leaving the event in the queue for `pollEvent`.
  SDL_WaitEventTimeout(nil, cint(ms)) == 1

proc addEventWatch*(fn: SDL_EventFilter; data: nil pointer = nil) =
  ## `fn` runs for every event, on the thread that produced it - including from inside
  ## Windows' modal resize loop, where `pollEvent` is not being called.
  SDL_AddEventWatch(fn, data)

proc textInput*(ev: SDL_Event): string =
  ## The UTF-8 text of an SDL_TEXTINPUT event.
  result = ""
  var i = 0
  while i < 31 and ev.text.text[i] != '\0':
    result.add ev.text.text[i]
    inc i

proc editingText*(ev: SDL_Event): string =
  ## The IME composition of an SDL_TEXTEDITING event.
  result = ""
  var i = 0
  while i < 31 and ev.edit.text[i] != '\0':
    result.add ev.edit.text[i]
    inc i

proc startTextInput*() = SDL_StartTextInput()
proc stopTextInput*() = SDL_StopTextInput()
proc textInputActive*(): bool = SDL_IsTextInputActive() != 0

proc setTextInputRect*(r: SDL_Rect) =
  ## Where the IME candidate window should appear (the caret, in window coordinates).
  var rr = r
  SDL_SetTextInputRect(addr rr)

# --- clipboard, keyboard, mouse, cursors -----------------------------------------------------

proc clipboardText*(): string =
  let p = SDL_GetClipboardText()
  if p == nil: return ""
  result = fromCString(p)
  SDL_free(cast[pointer](p))

proc setClipboardText*(s: string): bool {.discardable.} =
  var t = s
  SDL_SetClipboardText(t.toCString) == 0

proc hasClipboardText*(): bool = SDL_HasClipboardText() != 0

proc keyHeld*(scancode: int): bool =
  ## Is this scancode down right now (`SDL_Scancode` value)?
  var n: cint = 0
  let k = SDL_GetKeyboardState(addr n)
  k != nil and scancode >= 0 and scancode < int(n) and k[scancode] != 0'u8

proc mouseState*(): (uint32, int, int) =
  ## (button mask, x, y) in window coordinates.
  var x, y: cint = 0
  let b = SDL_GetMouseState(addr x, addr y)
  (b, int(x), int(y))

proc globalMouseState*(): (uint32, int, int) =
  ## (button mask, x, y) in desktop coordinates, even outside the window.
  var x, y: cint = 0
  let b = SDL_GetGlobalMouseState(addr x, addr y)
  (b, int(x), int(y))

proc warpMouse*(win: Window; x, y: int) = SDL_WarpMouseInWindow(win, cint(x), cint(y))

proc systemCursor*(id: cint): Cursor =
  ## Create (once; keep it) a system cursor: `SDL_SYSTEM_CURSOR_HAND`, `_IBEAM`, `_SIZEWE`, ...
  SDL_CreateSystemCursor(id)

proc setCursor*(c: Cursor) = SDL_SetCursor(c)

# --- window ------------------------------------------------------------------------------

proc position*(win: Window): (int, int) =
  var x, y: cint = 0
  SDL_GetWindowPosition(win, addr x, addr y)
  (int(x), int(y))

proc setPosition*(win: Window; x, y: int) = SDL_SetWindowPosition(win, cint(x), cint(y))
proc center*(win: Window) =
  SDL_SetWindowPosition(win, cint(SDL_WINDOWPOS_CENTERED), cint(SDL_WINDOWPOS_CENTERED))

proc flags*(win: Window): uint32 = SDL_GetWindowFlags(win)
proc isMaximized*(win: Window): bool = (SDL_GetWindowFlags(win) and SDL_WINDOW_MAXIMIZED) != 0'u32
proc isMinimized*(win: Window): bool = (SDL_GetWindowFlags(win) and SDL_WINDOW_MINIMIZED) != 0'u32
proc isBorderless*(win: Window): bool = (SDL_GetWindowFlags(win) and SDL_WINDOW_BORDERLESS) != 0'u32
proc hasFocus*(win: Window): bool = (SDL_GetWindowFlags(win) and SDL_WINDOW_INPUT_FOCUS) != 0'u32

proc maximize*(win: Window) = SDL_MaximizeWindow(win)
proc minimize*(win: Window) = SDL_MinimizeWindow(win)
proc restore*(win: Window) = SDL_RestoreWindow(win)
proc raiseWindow*(win: Window) = SDL_RaiseWindow(win)
proc show*(win: Window) = SDL_ShowWindow(win)
proc hide*(win: Window) = SDL_HideWindow(win)

proc setBordered*(win: Window; on: bool) = SDL_SetWindowBordered(win, cint(ord(on)))
proc setResizable*(win: Window; on: bool) = SDL_SetWindowResizable(win, cint(ord(on)))
proc setAlwaysOnTop*(win: Window; on: bool) = SDL_SetWindowAlwaysOnTop(win, cint(ord(on)))

proc setOpacity*(win: Window; opacity: float): bool {.discardable.} =
  ## Whole-window opacity 0..1 (not per-pixel transparency).
  SDL_SetWindowOpacity(win, cfloat(opacity)) == 0

proc setFullscreen*(win: Window; mode: uint32): bool {.discardable.} =
  ## `0` windowed, `SDL_WINDOW_FULLSCREEN` exclusive, `SDL_WINDOW_FULLSCREEN_DESKTOP` borderless.
  SDL_SetWindowFullscreen(win, mode) == 0

proc displayIndex*(win: Window): int = int(SDL_GetWindowDisplayIndex(win))

proc displayBounds*(index: int = 0): SDL_Rect =
  ## The whole monitor. Zero rectangle when SDL cannot say.
  result = rect(0, 0, 0, 0)
  if SDL_GetDisplayBounds(cint(index), addr result) != 0: result = rect(0, 0, 0, 0)

proc usableBounds*(index: int = 0): SDL_Rect =
  ## The monitor minus the taskbar / dock: where a maximized window goes.
  result = rect(0, 0, 0, 0)
  if SDL_GetDisplayUsableBounds(cint(index), addr result) != 0: result = rect(0, 0, 0, 0)

proc setHitTest*(win: Window; fn: nil SDL_HitTest; data: nil pointer = nil): bool {.discardable.} =
  ## Make parts of a frameless window drag it (`SDL_HITTEST_DRAGGABLE`). `fn` nil clears it.
  SDL_SetWindowHitTest(win, fn, data) == 0

# --- render ------------------------------------------------------------------------------

proc setBlend*(ren: Renderer; mode: cint) = discard SDL_SetRenderDrawBlendMode(ren, mode)

proc setClip*(ren: Renderer; r: SDL_Rect) =
  ## Everything drawn afterwards is cut to this rectangle (device pixels).
  var rr = r
  discard SDL_RenderSetClipRect(ren, addr rr)

proc clearClip*(ren: Renderer) = discard SDL_RenderSetClipRect(ren, nil)

proc fillRectF*(ren: Renderer; r: SDL_FRect) =
  ## A fractional-pixel filled rectangle in the current draw colour and blend mode.
  var rr = r
  discard SDL_RenderFillRectF(ren, addr rr)

proc blitF*(ren: Renderer; tex: Texture; src: SDL_Rect; dst: SDL_FRect) =
  ## `blit` with a fractional destination.
  var ss = src
  var dd = dst
  discard SDL_RenderCopyF(ren, tex, addr ss, addr dd)

proc renderGeometry*(ren: Renderer; tex: nil Texture; verts: ptr UncheckedArray[SDL_Vertex]; count: int;
                     indices: nil ptr UncheckedArray[cint] = nil; indexCount: int = 0): bool {.discardable.} =
  ## Triangles with per-vertex colour and texture coordinates: one call draws any number of
  ## them, which is how a whole UI is batched. `tex` may be nil (flat colour); `indices` nil
  ## means the vertices are a plain triangle list.
  SDL_RenderGeometry(ren, tex, cast[ptr SDL_Vertex](verts), cint(count), cast[ptr cint](indices),
                     cint(indexCount)) == 0

proc info*(ren: Renderer): SDL_RendererInfo =
  result = SDL_RendererInfo(name: "", flags: 0'u32, numTextureFormats: 0'u32, maxTextureWidth: 0, maxTextureHeight: 0)
  discard SDL_GetRendererInfo(ren, addr result)

proc outputSize*(ren: Renderer): (int, int) =
  var w, h: cint = 0
  discard SDL_GetRendererOutputSize(ren, addr w, addr h)
  (int(w), int(h))

proc readPixels*(ren: Renderer; r: SDL_Rect; pixels: pointer; pitch: int;
                 format: uint32 = SDL_PIXELFORMAT_ARGB8888): bool =
  ## Copy back part of what has been drawn (after the draws, before `present`).
  var rr = r
  SDL_RenderReadPixels(ren, addr rr, format, pixels, cint(pitch)) == 0

proc pixelAt*(ren: Renderer; x, y: int): uint32 =
  ## One back-buffer pixel as 0xAARRGGBB; 0 when it cannot be read.
  var px = 0'u32
  if ren.readPixels(rect(x, y, 1, 1), addr px, 4): px else: 0'u32

proc setBlend*(tex: Texture; mode: cint) = discard SDL_SetTextureBlendMode(tex, mode)
proc setColorMod*(tex: Texture; r, g, b: uint8) = discard SDL_SetTextureColorMod(tex, r, g, b)
proc setAlphaMod*(tex: Texture; a: uint8) = discard SDL_SetTextureAlphaMod(tex, a)
proc setScaleMode*(tex: Texture; mode: cint) = discard SDL_SetTextureScaleMode(tex, mode)

proc saveBMP*(ren: Renderer; path: string): bool =
  ## Write the current back buffer to a .bmp (verification screenshots).
  let (w, h) = ren.outputSize()
  if w <= 0 or h <= 0: return false
  let s = SDL_CreateRGBSurfaceWithFormat(0'u32, cint(w), cint(h), 32, SDL_PIXELFORMAT_ARGB8888)
  if s == nil: return false
  var whole = rect(0, 0, w, h)
  var ok = SDL_RenderReadPixels(ren, addr whole, SDL_PIXELFORMAT_ARGB8888, s.pixels, s.pitch) == 0
  if ok:
    var p = path
    ok = SDL_SaveBMP_RW(s, SDL_RWFromFile(p.toCString, "wb"), 1) == 0
  SDL_FreeSurface(s)
  ok

# --- shared objects ------------------------------------------------------------------------

proc loadObject*(path: string): pointer =
  ## dlopen / LoadLibrary. nil when it cannot be opened (`sdlError()` says why).
  var p = path
  SDL_LoadObject(p.toCString)

proc loadFunction*(lib: pointer; name: string): pointer =
  var n = name
  SDL_LoadFunction(lib, n.toCString)

proc unloadObject*(lib: pointer) = SDL_UnloadObject(lib)

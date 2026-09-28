## sdl2/ttf — SDL_ttf bindings: font loading, text rendering, and the
## text-measurement seam (`sizeUtf8`) a layout engine needs before it draws
## anything. Same bare-`{.importc.}` style as `sdl2.nim`.
##
## SDL_ttf has its own init/shutdown, independent of `sdlInit`/`sdlQuit`.
##
##   import sdl2, sdl2/ttf
##
##   ttfInit()
##   let font = openFont("C:/Windows/Fonts/segoeui.ttf", 24)
##   let (w, h) = font.sizeUtf8("Hello, Titicaca")
##   let surf = font.renderBlended("Hello, Titicaca", color(255, 255, 255))
##   let tex = ren.textureFromSurface(surf)
##   ren.blit(tex, rect(10, 10, w, h))
##   surf.freeSurface()
##   tex.destroy()
##   font.close()
##   ttfQuit()

import sdl2/core


type
  TTF_Font* {.importc: "TTF_Font", header: "<SDL2/SDL_ttf.h>", incompleteStruct.} = object
  Font* = ptr TTF_Font

  SDL_Surface* {.importc: "SDL_Surface", header: "<SDL2/SDL.h>", incompleteStruct.} = object
  Surface* = ptr SDL_Surface

proc TTF_Init(): cint {.importc: "TTF_Init", header: "<SDL2/SDL_ttf.h>", nodecl.}
proc TTF_Quit() {.importc: "TTF_Quit", header: "<SDL2/SDL_ttf.h>", nodecl.}
proc TTF_OpenFont(file: cstring; ptsize: cint): ptr TTF_Font {.importc: "TTF_OpenFont", header: "<SDL2/SDL_ttf.h>", nodecl.}
proc TTF_CloseFont(font: ptr TTF_Font) {.importc: "TTF_CloseFont", header: "<SDL2/SDL_ttf.h>", nodecl.}
proc TTF_RenderUTF8_Blended(font: ptr TTF_Font; text: cstring; fg: SDL_Color): ptr SDL_Surface {.importc: "TTF_RenderUTF8_Blended", header: "<SDL2/SDL_ttf.h>", nodecl.}
proc TTF_SizeUTF8(font: ptr TTF_Font; text: cstring; w, h: ptr cint): cint {.importc: "TTF_SizeUTF8", header: "<SDL2/SDL_ttf.h>", nodecl.}

proc SDL_FreeSurface(surface: ptr SDL_Surface) {.importc: "SDL_FreeSurface", header: "<SDL2/SDL.h>", nodecl.}
proc SDL_CreateTextureFromSurface(renderer: ptr SDL_Renderer; surface: ptr SDL_Surface): ptr SDL_Texture {.importc: "SDL_CreateTextureFromSurface", header: "<SDL2/SDL.h>", nodecl.}

proc ttfInit*(): bool {.discardable.} =
  ## Initializes SDL_ttf. Call once, after `sdlInit`.
  TTF_Init() == 0

proc ttfQuit*() =
  ## Shuts SDL_ttf down, before `sdlQuit`.
  TTF_Quit()

proc openFont*(path: string; ptSize: int): Font =
  ## Loads a `.ttf`/`.otf` font file at the given point size.
  var p = path
  TTF_OpenFont(p.toCString, ptSize.cint)

proc close*(font: Font) =
  ## Frees the font.
  TTF_CloseFont(font)

proc renderBlended*(font: Font; text: string; fg: SDL_Color): Surface =
  ## Renders one line of UTF-8 text to a new, alpha-blended surface. Pass
  ## the result to `textureFromSurface` to draw it.
  var t = text
  TTF_RenderUTF8_Blended(font, t.toCString, fg)

proc freeSurface*(surf: Surface) =
  ## Frees a surface returned by `renderBlended`.
  SDL_FreeSurface(surf)

proc textureFromSurface*(ren: Renderer; surf: Surface): Texture =
  ## Uploads a surface (e.g. from `renderBlended`) as a GPU texture, ready
  ## for `Renderer.blit`.
  SDL_CreateTextureFromSurface(ren, surf)

proc sizeUtf8*(font: Font; text: string): (int, int) =
  ## The (width, height) in pixels that `text` would occupy when rendered
  ## with `font` — the measurement seam a layout pass needs before it
  ## draws anything.
  var w, h: cint = 0
  var t = text
  discard TTF_SizeUTF8(font, t.toCString, addr w, addr h)
  (w.int, h.int)


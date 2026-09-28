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

# --- glyph-level access: what a text painter needs to lay a string out itself ---------------

const ttfh = "<SDL2/SDL_ttf.h>"

proc TTF_GlyphIsProvided32*(f: Font; ch: uint32): cint {.importc: "TTF_GlyphIsProvided32", header: ttfh, nodecl.}
proc TTF_GlyphMetrics32*(f: Font; ch: uint32; minx, maxx, miny, maxy, adv: ptr cint): cint
  {.importc: "TTF_GlyphMetrics32", header: ttfh, nodecl.}
proc TTF_GetFontKerningSizeGlyphs32*(f: Font; previous, ch: uint32): cint
  {.importc: "TTF_GetFontKerningSizeGlyphs32", header: ttfh, nodecl.}
proc TTF_RenderGlyph32_Blended*(f: Font; ch: uint32; fg: SDL_Color): Surface
  {.importc: "TTF_RenderGlyph32_Blended", header: ttfh, nodecl.}
proc TTF_FontHeight*(f: Font): cint {.importc: "TTF_FontHeight", header: ttfh, nodecl.}
proc TTF_FontAscent*(f: Font): cint {.importc: "TTF_FontAscent", header: ttfh, nodecl.}
proc TTF_FontDescent*(f: Font): cint {.importc: "TTF_FontDescent", header: ttfh, nodecl.}
proc TTF_SetFontHinting*(f: Font; hinting: cint) {.importc: "TTF_SetFontHinting", header: ttfh, nodecl.}
proc TTF_SetFontKerning*(f: Font; allowed: cint) {.importc: "TTF_SetFontKerning", header: ttfh, nodecl.}

const
  TTF_HINTING_NORMAL* = cint(0)
  TTF_HINTING_LIGHT* = cint(1)
  TTF_HINTING_MONO* = cint(2)
  TTF_HINTING_NONE* = cint(3)

proc glyphProvided*(font: Font; codepoint: int): bool =
  ## Does the face have a glyph for this code point (astral ones included)?
  TTF_GlyphIsProvided32(font, uint32(codepoint)) != 0

proc glyphMetrics*(font: Font; codepoint: int): tuple[minx, maxx, miny, maxy, advance: int] =
  ## Pixel metrics at this font's size. `advance` is what a pen moves by; minx/maxx are the ink's
  ## horizontal extent from the pen, miny/maxy its vertical extent from the baseline. All zero
  ## when the face has no such glyph.
  var a, b, c, d, e: cint = 0
  if TTF_GlyphMetrics32(font, uint32(codepoint), addr a, addr b, addr c, addr d, addr e) != 0:
    return (0, 0, 0, 0, 0)
  (int(a), int(b), int(c), int(d), int(e))

proc kerning*(font: Font; previous, codepoint: int): int =
  ## Pixels to add to the pen between this pair (negative pulls them together), from the face's
  ## legacy `kern` table at this font's size. Open the face at size = units-per-em and this is
  ## the adjustment in font units.
  int(TTF_GetFontKerningSizeGlyphs32(font, uint32(previous), uint32(codepoint)))

proc height*(font: Font): int = int(TTF_FontHeight(font))
proc ascent*(font: Font): int = int(TTF_FontAscent(font))
proc descent*(font: Font): int = int(TTF_FontDescent(font))
proc setHinting*(font: Font; hinting: cint) = TTF_SetFontHinting(font, hinting)
proc setKerning*(font: Font; on: bool) = TTF_SetFontKerning(font, cint(ord(on)))

proc renderGlyphBlended*(font: Font; codepoint: int; fg: SDL_Color): Surface =
  ## One glyph as an alpha-blended surface (advance-wide, line-high, ink in place).
  TTF_RenderGlyph32_Blended(font, uint32(codepoint), fg)

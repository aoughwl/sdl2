## sdl2 - a thin, hand-written SDL2 wrapper for nimony / Nim 3.0.
##
## `import sdl2` for init/window/renderer/texture/events (`sdl2/core`) and the rest of what an
## application host needs - window control, input, clipboard, cursors, geometry batching,
## read-back, clocks (`sdl2/ext`);
## `import sdl2/ttf` for text (a separate module, since SDL_ttf is a
## separate library with its own init/shutdown).
##
## See `sdl2/core.nim`, `sdl2/ext.nim` and `sdl2/ttf.nim` for the full surface and docs.
import sdl2/core
export core
import sdl2/ext
export ext

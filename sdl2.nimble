# Package
version     = "0.2.0"
author      = "aoughwl"
description = "A thin, hand-written SDL2 + SDL_ttf wrapper for nimony / Nim 3.0: window, renderer, texture, events, text. No dependencies beyond SDL2 itself."
license     = "MIT"
srcDir      = "."

# Plain FFI (bare {.importc.} procs, no macros) against the system SDL2 /
# SDL2_ttf headers and libs. Nothing else required.

## equinox_comp
## A Wayland compositor to temporarily fix a lot of Waydroid's images' limitations
import std/[os, logging]
import pkg/[colored_logger, cppstl/std_smartptrs, louvre]
import compositor/[core]

type CompInitFailed* = object of Defect

proc main() {.inline.} =
  addHandler(newColoredLogger())
  debug "comp: starting up."

  when not defined(release):
    putEnv("LOUVRE_DEBUG", "4")

  putEnv("XDG_CURRENT_DESKTOP", "equinox")
  putEnv("XDG_SESSION_TYPE", "wayland")
  putEnv("LOUVRE_WAYLAND_DISPLAY", "equinox-comp")
    # This is important so we don't conflict with other compositors. Equinox will always redirect the display for Wayland's hwcomposer HAL to this.

  var equi = makeUnique(Equi)

  if not equi.start():
    raise newException(CompInitFailed, "Cannot start compositor!")

  while equi.getState() != CompositorState.Uninitialized:
    equi.processLoop(-1)

  debug "comp: goodbye."

when isMainModule:
  main()

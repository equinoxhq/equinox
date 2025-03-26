import std/[os, logging]

type XdgEnv* = object
  runtimeDir*: string
  waylandDisplay*: string
  equinoxCompPath*: string
  user*: string
  equinoxPath*: string

proc getXdgEnv*(): XdgEnv =
  let equinoxPath =
    when defined(release):
      findExe("equinox")
    else:
      getCurrentDir() / "equinox"

  let equinoxCompPath =
    when defined(release):
      findExe("equinox_comp")
    else:
      getCurrentDir() / "equinox_comp"

  XdgEnv(
    runtimeDir: getEnv("XDG_RUNTIME_DIR"),
    waylandDisplay: getEnv("WAYLAND_DISPLAY"),
    user: getEnv("USER"),
    equinoxPath: equinoxPath,
    equinoxCompPath: equinoxCompPath
  )

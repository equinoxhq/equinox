# Package

version = "0.1.0"
author = "xTrayambak"
description = "Waydroid approach"
license = "GPL-3.0-or-later"
srcDir = "src"
backend = "cpp"
bin = @["equinox", "equinox_gui", "equinox_comp"]

# Dependencies

requires "nim >= 2.2.2"
requires "colored_logger >= 0.1.0"
requires "nimsimd >= 1.3.2"
requires "curly >= 1.1.1"
requires "jsony >= 1.1.5"
requires "glob >= 0.11.3"
requires "pretty >= 0.2.0"
requires "mimalloc >= 0.3.1"
requires "noise >= 0.1.10"
requires "crunchy >= 0.1.11"
requires "zippy >= 0.10.16"
requires "zip >= 0.3.1"
requires "owlkettle >= 3.0.0"
requires "gtk2 >= 1.3"
requires "db_connector >= 0.1.0"
requires "https://github.com/xTrayambak/nim-louvre >= 2.13.0"
requires "vmath >= 2.0.0"
requires "cppstl >= 0.7.0"
requires "opengl >= 1.2.9"

task buildCompBackend, "Build the custom compositor backend":
  exec "cd src/compositor/backend && meson compile -C build"
  exec "mv src/compositor/backend/build/equinoxwl.so backend/graphic/"

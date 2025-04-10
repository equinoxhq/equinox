## equinox gui integration
import std/[os, osproc, logging, posix]
import pkg/[colored_logger]
import ./gui/[onboard, icons, launcher, envparser, desktop_files, apk_install]
import ./container/[apk_fetcher]
import ./[argparser]

proc isFirstRun*(input: Input): bool =
  not dirExists(getHomeDir() / ".local" / "share" / "equinox") or
    input.enabled("force-first-run", "F")

proc needsApkUpdate*(): bool =
  not dirExists("/var" / "lib" / "equinox" / "apk" / SelectedVersion)

proc showOnboardingGui(input: Input) =
  debug "gui: showing onboarding gui"
  runOnboardingApp(input)

proc showLauncher(input: Input) =
  debug "gui: launcher gui spawned"
  runLauncher(input)

proc showApkUpdater(input: Input) =
  debug "gui: apk updater spawned"
  runApkFetcher(input)

proc main() {.inline.} =
  addHandler(newColoredLogger())
  setLogFilter(lvlInfo)
  let input = parseInput()
  if input.enabled("verbose", "v"):
    setLogFilter(lvlAll)

  installIcons()
  createDesktopEntries()
  createMimeHandlerEntry()

  case input.command
  of "onboarding":
    showOnboardingGui(input)
  of "launcher":
    if needsApkUpdate() and not input.enabled("skip-apk-updates", "X"):
      showApkUpdater(input)
      quit(0)
        # TODO: make the launcher show afterwards without a restart of the app. Right now it just.... closes immediately after the updater is done
        # probably has something to do with how owlkettle handles the closing of a window?

    showLauncher(input)
  of "mime-handler":
    let env = getXdgEnv(input)
    discard execCmd(
      "pkexec " & env.equinoxPath & " launch-game-uri " & input.arguments[0] & " --user:" &
        env.user & " --uid:" & $getuid() & " --gid:" & $getgid() & " --wayland-display:" &
        env.waylandDisplay & " --xdg-runtime-dir:" & env.runtimeDir
    )
  of "auto":
    if not dirExists(getHomeDir() / ".local" / "share" / "equinox"):
      showOnboardingGui(input)
    else:
      if needsApkUpdate() and not input.enabled("skip-apk-updates", "X"):
        showApkUpdater(input)
      else:
        showLauncher(input)
  of "updater":
    showApkUpdater(input)
  else:
    error "equinox-gui: invalid command: " & input.command

when isMainModule:
  main()

## Launcher GUI
import std/[os, logging, options, osproc, posix]
import pkg/owlkettle, pkg/owlkettle/[playground, adw]

import ../envparser

const
  NimblePkgVersion {.strdefine.} = "???"
  License = staticRead("../../LICENSE")

viewable Launcher:
  description:
    string = "This is Equinox"
  iconName:
    string = "weather-clear-symbolic"
  title:
    string = "Equinox"
  active:
    bool = false
  sensitive:
    bool = true
  toggle:
    bool
  offset:
    tuple[x, y: int] = (0, 0)
  subtitle:
    string = "uuuuuh"
  tooltip:
    string = "man..."
  sizeRequest:
    tuple[x, y: int] = (-1, -1)
  position:
    PopoverPosition = PopoverBottom

let env = getXdgEnv()

method view(app: LauncherState): Widget =
  result = gui:
    Window:
      defaultSize = (500, 400)
      title = app.title
      HeaderBar {.addTitlebar.}:
        style = [HeaderBarFlat]
        insert(app.toAutoFormMenu(sizeRequest = (600, 500))) {.addRight.}
          # for tweaking or whatever

        MenuButton {.addLeft.}:
          icon = "open-menu"
          style = [ButtonFlat]

          PopoverMenu:
            sensitive = app.sensitive
            sizeRequest = app.sizeRequest
            offset = app.offset
            position = app.position

            Box {.name: "main".}:
              orient = OrientY
              margin = 4
              spacing = 3

              ModelButton:
                text = "Tools"
                menuName = "tools"
                proc clicked() =
                  debug "gui: opened the tooling section"

              Separator()

              ModelButton:
                text = "Preferences"
                proc clicked() =
                  echo "WIP"

              ModelButton:
                text = "About Equinox"
                proc clicked() =
                  discard app.open:
                    gui:
                      AboutWindow:
                        applicationName = "Equinox"
                        developerName = "The EquinoxHQ Team"
                        version = NimblePkgVersion
                        supportUrl = "https://discord.gg/Z5m3n9fjcU"
                        issueUrl = "https://github.com/equinoxhq/equinox/issues"
                        website = "https://github.com/equinoxhq/equinox/"
                        copyright =
                          """
Copyright (C) 2025 xTrayambak and the EquinoxHQ Team
The Roblox logo and branding are registered trademarks of Roblox Corporation.
                        """
                        license = License
                        licenseType = LicenseMIT_X11
                        applicationIcon = "equinox"
                        developers = @["Trayambak (xTrayambak)"]
                        designers = @["Adrien (AshtakaOOf)"]
                        artists = @[]
                        documenters = @[]
                        credits = @{"APK Fetcher by": @["Kirby (k1yrix)"]}

            Box {.name: "tools".}:
              orient = OrientY
              margin = 4
              spacing = 3

              ModelButton:
                text = "Uninstall Equinox"
                proc clicked() =
                  echo "Not a feature yet"

              ModelButton:
                text = "Open Config file"
                proc clicked() =
                  echo "Not a feature yet"

      Clamp:
        maximumSize = 500
        margin = 12

        Box:
          orient = OrientY
          spacing = 12

          PreferencesGroup {.expand: false.}:
            #title = app.title
            #description = "app.description"

            ActionRow:
              title = "Make sure to follow the README instructions."
              subtitle = "This software is experimental and may break."

            ActionRow:
              title =
                "Please make sure that you agree to the EquinoxHQ Terms of Service before you begin."
              subtitle = "The Equinox team is not responsible for any damages."

            Label:
              text = "Welcome to the Equinox launcher."
              margin = 24

          Box {.hAlign: AlignCenter, vAlign: AlignCenter.}:
            orient = OrientX
            spacing = 12

            Button:
              style = [ButtonPill, ButtonSuggested]
              text = "Launch Roblox"
              tooltip = "This will start Roblox through Equinox."
              proc clicked() =
                let cmd =
                  findExe("pkexec") & ' ' & env.equinoxPath & " run --xdg-runtime-dir:" &
                  env.runtimeDir & " --wayland-display:equinox-comp" &
                  " --user:" & env.user & " --uid:" & $getuid() & " --gid:" & $getgid()

                app.closeWindow()
                
                let compPid = fork()
                if compPid == 0:
                  debug "launcher: we're the forked child"
                  discard execCmd(env.equinoxCompPath)
                  quit(0)
                else:
                  debug "launcher: we're the parent, executing equinox"

                let pid = fork()

                if pid == 0:
                  debug "launcher: we're the forked child"
                  discard execCmd(cmd)
                  quit(0)
                else:
                  debug "launcher: we're the parent"
                  quit(0)

            Button:
              style = [ButtonPill, ButtonDestructive]
              text = "Stop Equinox"
              tooltip = "Gracefully shut down the Equinox container."
              proc clicked() =
                let cmd = findExe("pkexec") & ' ' & env.equinoxPath & " halt"
                let pid = fork()

                if pid == 0:
                  debug "launcher: we're the forked child"
                  discard execCmd(cmd)
                  quit(0)
                else:
                  debug "launcher: we're the parent"
                  warn "launcher: TODO: add a spinner or smt"

proc runLauncher*() =
  adw.brew(gui(Launcher()))

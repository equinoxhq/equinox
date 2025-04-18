## Onboarding GUI + Setup flow
import std/[browsers, logging, os, osproc, options, posix]
import pkg/owlkettle, pkg/owlkettle/[playground, adw]
import
  ../[argparser],
  ./envparser,
  ../container/[lxc, gpu, sugar, certification],
  ../container/utils/exec,
  ../bindings/libadwaita,
  ./clipboard

type
  CantMakeSocketPair = object of OSError

  OnboardMagic {.pure, size: sizeof(uint8).} = enum
    InitEquinox = 0 ## Call the Equinox initialization command
    InitSuccess = 1 ## Successful initialization has taken place
    InitFailure = 2 ## Failed initialization
    GoogleAuthPhase = 3 ## Copy the GSF ID and open the cert site
    Die = 4 ## Kill yourself.

viewable OnboardingApp:
  consentFail:
    string = ""

  sock:
    cint

  env:
    XdgEnv

  showSpinner:
    bool = false

proc gpuCheck(app: OnboardingAppState): bool =
  let node = getDriNode()
  if node.isSome:
    return true

  app.showSpinner = false
  discard app.redraw()
  discard app.open:
    gui:
      Window:
        title = "No GPU detected"
        defaultSize = (200, 300)

        HeaderBar {.addTitlebar.}:
          style = [HeaderBarFlat]

        Box:
          orient = OrientY
          Box {.hAlign: AlignCenter, vAlign: AlignStart.}:
            Icon:
              name = "emblem-important"
              pixelSize = 200

          Box {.hAlign: AlignCenter, vAlign: AlignCenter.}:
            Label:
              text =
                "Equinox could not detect a compatible GPU. Nvidia GPUs are not supported yet.\nIf you believe that this is not true, file a bug report."
              margin = 24

  false

method view(app: OnboardingAppState): Widget =
  proc waitForInit(): bool =
    var readfds: TFdSet
    var timeout: Timeval

    FD_ZERO(readfds)
    FD_SET(app.sock, readfds)
    var ret = select(app.sock + 1.cint, readfds.addr, nil, nil, timeout.addr)
    if ret < 0 or not bool(FD_ISSET(app.sock, readfds)):
      return true

    var buff: array[1, uint8]
    discard read(app.sock, buff[0].addr, 1)

    case (OnboardMagic) buff[0]
    of OnboardMagic.InitEquinox, OnboardMagic.Die, OnboardMagic.GoogleAuthPhase:
      discard
    of OnboardMagic.InitFailure:
      app.showSpinner = false
      discard app.redraw()
      discard app.open:
        gui:
          Window:
            title = "An error has occurred"
            defaultSize = (300, 450)

            HeaderBar {.addTitlebar.}:
              style = [HeaderBarFlat]

            Box:
              orient = OrientY
              Box {.hAlign: AlignCenter, vAlign: AlignStart.}:
                Icon:
                  name = "abrt-symbolic"
                  pixelSize = 200

              Box {.hAlign: AlignCenter, vAlign: AlignCenter.}:
                Label:
                  text =
                    "Equinox has failed to initialize the container. Please run this launcher from your terminal and send the logs to the Lucem Discord server."
                  margin = 24
    of OnboardMagic.InitSuccess:
      buff[0] = (uint8) OnboardMagic.GoogleAuthPhase
      discard write(app.sock, buff[0].addr, 1)

      discard app.open:
        gui:
          Window:
            title = "Setup Flow"
            defaultSize = (300, 450)
            HeaderBar {.addTitlebar.}:
              style = [HeaderBarFlat]

            Clamp:
              maximumSize = 450
              margin = 12

              Box:
                orient = OrientY
                spacing = 12

                ActionRow:
                  title =
                    "You're about to interact with Google's Play Store, and as such, you will be subject to their terms of service."
                  subtitle =
                    "Make sure you've read the Google Play Terms of Service. It has just been opened in your browser."

                Label:
                  text =
                    "Equinox's GSF ID has been copied to your clipboard. Paste it in your browser and complete the Captcha to continue."
                  margin = 24

                Box {.hAlign: AlignCenter, vAlign: AlignCenter.}:
                  Button:
                    style = [ButtonPill, ButtonSuggested]
                    text = "Complete Setup"
                    tooltip =
                      "Click this button when you are done with the steps above. You can then launch Equinox."

                    proc clicked() =
                      app.closeWindow()

    return false

  result = gui:
    Window:
      defaultSize = (300, 400)
      title = "Equinox"
      HeaderBar {.addTitlebar.}:
        style = [HeaderBarFlat]

      Clamp:
        maximumSize = 500
        margin = 12

        Box:
          orient = OrientY
          spacing = 12

          Label:
            text =
              "Welcome to Equinox. Press the button below to start the setup.\nKeep in mind that this can take a minute."
            margin = 24

          PreferencesGroup {.expand: false.}:
            ActionRow:
              title = "Thank you for installing Equinox."
              subtitle =
                "Please keep in mind that Equinox is experimental software and is prone to bugs, errors and certain limitations. We intend to fix these eventually."

            ActionRow:
              title = "Your account could be moderated for using Equinox."
              subtitle =
                "Whilst very unlikely, it is not out of the question that Roblox accidentally temporarily bans your account for using Equinox due to how it works and how it can possibly trigger the anticheat in ways we are unaware of."

            ActionRow:
              title = "Privacy Policy"
              subtitle =
                "Equinox is libre software and does NOT collect any data about you, excluding crash dumps. The different services it interacts with might, though."

          if app.showSpinner:
            AdwSpinner()

          Label:
            text = app.consentFail
            margin = 12
            style = [StyleClass("warning-label")]

          Box {.hAlign: AlignCenter, vAlign: AlignCenter.}:
            orient = OrientX
            spacing = 12

            Button:
              style = [ButtonPill, ButtonSuggested]
              text = "Start Setup"
              proc clicked() =
                app.consentFail = ""

                if not gpuCheck(app):
                  return

                # Init command
                var buff: array[1, uint8]
                buff[0] = (uint8) OnboardMagic.InitEquinox
                discard write(app.sock, buff[0].addr, 1)

                app.showSpinner = true
                discard addGlobalIdleTask(waitForInit)

proc waitForCommands*(env: XdgEnv, fd: cint) =
  var running = true
  while running:
    debug "launcher/child: waiting for opcode"
    var opcode: array[1, byte]
    if (let status = read(fd, opcode[0].addr, 1); status != 1):
      error "launcher/child: read() returned " & $status & ": " & $strerror(errno) &
        " (errno " & $errno & ')'
      error "launcher/child: i think the launcher has crashed or something idk"
      break

    var op = cast[OnboardMagic](cast[uint8](opcode[0]))
    debug "launcher/child: opcode -> " & $op

    case op
    of OnboardMagic.InitEquinox:
      var buff: array[1, uint8]
      if runCmd(
        "pkexec",
        env.equinoxPath & " init --xdg-runtime-dir:" & env.runtimeDir &
          " --verbose --wayland-display:" & env.waylandDisplay & " --user:" & env.user &
          " --uid:" & $getuid() & " --gid:" & $getgid(),
      ):
        buff[0] = (uint8) OnboardMagic.InitSuccess
      else:
        buff[0] = (uint8) OnboardMagic.InitFailure

      discard write(fd, buff[0].addr, 1)
    of OnboardMagic.GoogleAuthPhase:
      let gsfId =
        &readOutput("pkexec", env.equinoxPath & " get-gsf-id --user:" & env.user)

      debug "gui/onboard: gsf id = " & gsfId

      openDefaultBrowser("https://play.google.com/about/play-terms/index.html")
      openDefaultBrowser("https://www.google.com/android/uncertified")
      copyText(gsfId)
    of OnboardMagic.InitFailure, OnboardMagic.InitSuccess:
      discard
    of OnboardMagic.Die:
      running = false

proc runOnboardingApp*(input: Input) =
  var pair: array[2, cint]
  if (let status = socketpair(AF_UNIX, SOCK_STREAM, 0, pair); status != 0):
    raise newException(
      CantMakeSocketPair,
      "socketpair() returned " & $status & ": " & $strerror(errno) & " (errno " & $errno &
        ')',
    )

  let pid = fork()
  let env = getXdgEnv(input)

  if pid == 0:
    waitForCommands(env, pair[0])
  else:
    adw.brew(
      gui(OnboardingApp(sock = pair[1], env = env)),
      stylesheets = [
        newStylesheet(
          """
.warning-label {
  color: #ff938b;
}

.spinner {
  min-width: 300px;
  min-height: 300px;
}
      """
        )
      ],
    )
    var buff: array[1, uint8]
    buff[0] = (uint8) OnboardMagic.Die
    discard pair[1].write(buff[0].addr, 1)

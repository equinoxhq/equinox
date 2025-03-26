## Onboarding GUI + Setup flow
import std/[browsers, logging, os, osproc, posix]
import pkg/owlkettle, pkg/owlkettle/[playground, adw]
import
  ../[argparser, envparser],
  ../container/[lxc, sugar, certification],
  ../container/utils/exec,
  ./clipboard

viewable OnboardingApp:
  description:
    string = "This is Equinox"
  iconName:
    string = "weather-clear-symbolic"
  title:
    string = "Equinox"
  active:
    bool = false
  subtitle:
    string = "uuuuuh"
  sensitive:
    bool = true
  tooltip:
    string = "man..."
  sizeRequest:
    tuple[x, y: int] = (-1, -1)

  consentedTOS:
    bool
  consentedPrivacy:
    bool
  consentFail:
    string = ""

  #my code sucks
  erm_guh:
    string =
      "equinox init --xdg-runtime-dir:A --wayland-display:B --user:C --uid:D --gid:E"
  runtime:
    string = "--xdg-runtime-dir:"
  wayland:
    string = "--wayland-display:"
  user:
    string = "--user:"

let env = getXdgEnv()

method view(app: OnboardingAppState): Widget =
  result = gui:
    Window:
      defaultSize = (300, 400)
      title = app.title
      HeaderBar {.addTitlebar.}:
        style = [HeaderBarFlat]

      Clamp:
        maximumSize = 500
        margin = 12

        Box:
          orient = OrientY
          spacing = 12

          PreferencesGroup {.expand: false.}:
            title = "Onboarding"
            #description = "Losing it"

            ActionRow:
              title = "I Consent"
              subtitle = "To the Equinox Terms of Service"
              Switch() {.addSuffix.}:
                proc changed(active: bool) =
                  app.consentedTOS = active
                  if app.consentedTOS:
                    debug "gui: user has consented to TOS"
                  else:
                    debug "gui: user no longer consents to TOS"

            ActionRow:
              title = "I Consent"
              subtitle = "To the Equinox Privacy Policy"
              Switch() {.addSuffix.}:
                proc changed(active: bool) =
                  app.consentedPrivacy = active
                  if app.consentedPrivacy:
                    debug "gui: user has consented to privacy policy"
                  else:
                    debug "gui: user no longer consents to privacy policy"

          Label:
            text =
              "Welcome to Equinox. Press the button below to start the setup.\nKeep in mind that this can take upwards of 10 minutes, depending on your internet connection.\nThis application will be fully unresponsive until it is done. Do not exit it!"
            margin = 24

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
                let consent = app.consentedPrivacy and app.consentedTOS
                if not consent:
                  app.consentFail =
                    "Please consent to our Terms of Service and Privacy Policy to continue."
                  return

                # Init command
                runCmd(
                  "pkexec",
                  env.equinoxPath & " init --xdg-runtime-dir:" & env.runtimeDir &
                    " --wayland-display:" & env.waylandDisplay & " --user:" & env.user &
                    " --uid:" & $getuid() & " --gid:" & $getgid(),
                )

                var exception: ref Exception
                let gsfId =
                  &readOutput(
                    "pkexec", env.equinoxPath & " get-gsf-id --user:" & env.user
                  )
                debug "gui/onboard: gsf id = " & gsfId

                openDefaultBrowser(
                  "https://play.google.com/about/play-terms/index.html"
                )
                openDefaultBrowser("https://www.google.com/android/uncertified")
                copyText(gsfId)

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
                                "Click this button when you are done with the steps above."

                              proc clicked() =
                                startLxcContainer(default(Input), authAgent = "pkexec")
                                warn "onboarding: FIXME: use a better way to be notified of when the container is ready"
                                sleep(35000) # FIXME: please fix this :^(
                                discard runCmd(
                                  "pkexec",
                                  env.equinoxPath & " install --consented --user:" &
                                    env.user,
                                )

            #[ Button:
              style = [ButtonPill]
              icon = "applications-system-symbolic"
              #tooltip = "config"
              proc clicked() =
                echo "losing it" ]#

proc runOnboardingApp*() =
  adw.brew(
    gui(OnboardingApp()),
    stylesheets = [
      newStylesheet(
        """
      .warning-label {
        color: #ff938b;
      }
    """
      )
    ],
  )

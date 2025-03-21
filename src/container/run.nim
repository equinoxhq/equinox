import std/[os, logging, strutils, posix]
import ./[lxc, configuration, cpu, drivers, hal, trayperion, platform, network, sugar]
import ../argparser
import ./utils/[exec, mount]

proc mountRootfs*(input: Input, imagesDir: string) =
  info "equinox: mounting rootfs"

  debug "container/run: mounting system image"
  mount(imagesDir / "system.img", config.rootfs, umount = true)

  debug "container/run: mounting vendor image"
  mount(imagesDir / "vendor.img", config.rootfs / "vendor")

  makeBaseProps(input)
  mountFile(config.work / "equinox.prop", config.rootfs / "vendor" / "waydroid.prop")

proc showUI*() =
  var platform = getIPlatformService()
  platform.launchApp("com.roblox.client")
  platform.setProperty("waydroid.active_apps", "com.roblox.client")

proc startAndroidRuntime*(input: Input) =
  info "equinox: starting android runtime"
  debug "equinox: starting prep for android runtime"

  mountRootfs(input, config.imagesPath)
  setLenUninit()
  generateSessionLxcConfig()

  if getLxcStatus() == "RUNNING":
    debug "equinox: container is already running"
    showUI()
  else:
    startLxcContainer(input)

    var platform = getIPlatformService()
    platform.launchApp("com.roblox.client")

    let pid = block:
      var pidClient: uint

      while true:
        try:
          pidClient =(&readOutput("pidof", "com.roblox.client")).strip().split(' ')[0].parseUint()  # FIXME: please fix this PEAK code to be less PEAK (it probably shits itself on non systemd distros)
          break
        except ValueError:
          platform.launchApp("com.roblox.client")

      pidClient

    platform.setProperty("waydroid.active_apps", "com.roblox.client")
    setLenUninit()
  
    debug "equinox: waiting for com.roblox.client to exit: pid=" & $pid
    var status: cint
    while kill(Pid(pid), 0) == 0 or errno != ESRCH:
      sleep(100)

    if WIFEXITED(status):
      info "equinox: runtime has been stopped."
    else:
      warn "equinox: runtime stopped abnormally."

    stopNetworkService()

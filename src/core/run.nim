import std/[os, logging, strutils, sequtils, posix, tables, json]
import
  ../container/[
    lxc, configuration, cpu, drivers, hal, platform, network, sugar, hardware_service,
    rootfs, app_config, fflags, properties, drivers
  ]
import pkg/[discord_rpc]
import ../argparser
import ../container/utils/[exec, mount]
import ./event_manager/[types, dispatcher]
import ./[discord_rpc, fflag_patches, ro_opt_patches, roblox_logs]

proc showUI*(launch: bool = true) =
  var platform = getIPlatformService()
  if launch:
    platform.launchApp("com.roblox.client")

  platform.setProperty("waydroid.active_apps", "com.roblox.client")

proc startRobloxClient*(platform: var IPlatform) =
  while isEmptyOrWhitespace(&readOutput("pidof", "com.roblox.client")):
    # FIXME: please don't do this
    platform.launchApp("com.roblox.client")
    sleep(100)

  startLogWatcher()

proc processEvents*(dispatcher: var EventDispatcher, rpc: DiscordRPC) =
  let (event, exhausted) = dispatcher.poll()
  if exhausted:
    return

  case event.kind
  of Event.GameJoin:
    info "equinox: user joined game; id=" & event.id
    handleGameRPC(rpc, event.id)
  of Event.GameLeave:
    info "equinox: user left game."
    handleIdleRPC(rpc)

proc startAndroidRuntime*(input: Input, launchRoblox: bool = true) =
  info "equinox: starting android runtime"
  debug "equinox: starting prep for android runtime"

  destroyAllLogs()
  mountRootfs(input, config.imagesPath)
  discard setupBinderNodes()

  var settings = loadAppConfig(input)

  debug "equinox: applying config"

  if *settings.maxFps:
    settings.fflags["DFIntTaskSchedulerTargetFps"] = newJInt(int(&settings.maxFps))

  settings.fflags["FFlagUserFyosDetectionHorseFly"] = newJBool(true) # for shy :3

  applyFflagPatches(settings.fflags)
  setFflags(settings.fflags)
  generateSessionLxcConfig()

  var dispatcher = initEventDispatcher()

  if getLxcStatus() == "RUNNING":
    debug "equinox: container is already running"
    showUI()
  else:
    startLxcContainer(input)

    var platform = getIPlatformService()
    platform.setProperty("waydroid.active_apps", "com.roblox.client")

    if launchRoblox:
      startRobloxClient(platform)

      let pid = parseUint(&readOutput("pidof", "com.roblox.client"))
      debug "equinox: waiting for roblox to exit: pid=" & $pid

      putEnv("XDG_RUNTIME_DIR", &input.flag("xdg-runtime-dir"))
        # Fixes a crash because we don't have that defined since we run as root.
      var rpc = newDiscordRpc(RPCApplicationId)

      try:
        let res = rpc.connect()
        info "equinox: connected to Discord RPC."
        info "equinox: CDN host = " & res.config.cdnHost & ", API endpoint = " &
          res.config.apiEndpoint & ", env = " & res.config.environment
        info "equinox: logged in as " & res.user.username & " (" & $res.user.id & ")"
      except OSError as exc:
        debug "equinox: cannot connect to Discord RPC: " & exc.msg
        rpc = nil

      rpc.handleIdleRPC()

      patchProperties()

      while kill(Pid(pid), 0) == 0 or errno != ESRCH:
        sleep(100)
        processEvents(dispatcher, rpc)

      stopLogWatcher()
      stopNetworkService()
      stopLxcContainer()
      umountAll(config.rootfs)
    # deinitHardwareService(hwsvc)

type PlaceURI* = distinct string

proc launchRobloxGame*(input: Input, id: PlaceURI | string) =
  info "equinox: sending VIEW intent to roblox client"

  if getLxcStatus() != "RUNNING":
    startAndroidRuntime(input, launchRoblox = false)
  else:
    showUI(launch = false)

  var platform = getIPlatformService()

  while isEmptyOrWhitespace(&readOutput("pidof", "com.roblox.client")):
    # FIXME: please don't do this
    when id is string:
      platform.launchIntent("android.intent.action.VIEW", "roblox://placeId=" & id)
    else:
      platform.launchIntent("android.intent.action.VIEW", cast[string](id))

  platform.setProperty("waydroid.active_apps", "com.roblox.client")

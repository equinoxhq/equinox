import std/[os, logging]
import
  ./[
    lxc, configuration, cpu, drivers, image_downloader, hal, rootfs, configuration,
    network,
  ]
import ../argparser

proc setupConfig*(input: Input): bool =
  loadConfig(input)
  config.arch = getHost().maybeRemap()

  let driverList = setupBinderNodes()

  debug "init: binder = " & driverList.binder
  debug "init: vndbinder = " & driverList.vndbinder
  debug "init: hwbinder = " & driverList.hwbinder
  config.binder = driverList.binder
  config.vndbinder = driverList.vndbinder
  config.hwbinder = driverList.hwbinder

  return true

proc initialize*(input: Input) =
  var status = "STOPPED"

  if not setupConfig(input):
    return

  if status != "STOPPED" and not input.enabled("ignore-container-state", "I"):
    error "init: TODO: stopping container"
    return

  discard existsOrCreateDir(config.work)
  discard existsOrCreateDir(config.equinoxData)
  discard existsOrCreateDir(config.hostPerms)
  discard existsOrCreateDir(config.rootfs)
  discard existsOrCreateDir(config.overlay)
  discard existsOrCreateDir(config.overlay / "vendor")
  discard existsOrCreateDir(config.overlayRw)
  discard existsOrCreateDir(config.overlayRw / "system")
  discard existsOrCreateDir(config.overlayRw / "vendor")
  discard existsOrCreateDir(config.work / "images")
  discard existsOrCreateDir(config.lxc)
  discard existsOrCreateDir(config.lxc / "equinox")

  initNetworkService()
  mountRootfs(input, config.imagesPath)
  generateSessionLxcConfig()
  setLxcConfig()
  startLxcContainer(input)

  let imagesExist =
    fileExists(config.imagesPath / "system.img") and
    fileExists(config.imagesPath / "vendor.img")
  if not imagesExist and not input.enabled("no-img-download", "Z"):
    let pair = getImages()
    pair.downloadImages()

  waitForContainerBoot()
  makeBaseProps(input)
  runCmdInContainer("pm uninstall --user 0 com.android.inputmethod.latin")
  stopLxcContainer() # stop it afterwards
  stopNetworkService()
  info "Initialized Equinox successfully."

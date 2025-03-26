import std/[os, sequtils]
import ../argparser, ./[sugar]
import pkg/[glob]

type Config* = object
  arch*: string
  work*: string
  vendorType*: string
  systemDatetime*: uint64
  vendorDatetime*: uint64
  preinstalledImagePaths*: seq[string]
  suspendAction*: string
  mount_overlays*: string
  autoAdb*: string
  containerXdgRuntimeDir*: string
  containerWaylandDisplay*: string

  imagesPath*: string
  rootfs*: string
  overlay*: string
  overlayRw*: string
  overlayWork*: string
  data*: string
  lxc*: string
  hostPerms*: string

  containerPulseRuntimePath*: string
  hostXdgRuntimeDir*: string
  equinoxData*: string

  systemOta*: string
  vendorOta*: string

  romType*: string
  systemType*: string

  binder*, vndbinder*, hwbinder*: string

var config*: Config

proc loadConfig*(input: Input) {.sideEffect.} =
  config = Config(
    arch: "x86_64",
    work: "/var" / "lib" / "equinox",
    vendorType: "MAINLINE",
    preinstalledImagePaths: @["/var" / "lib" / "equinox" / "images"],
    suspendAction: "freeze",
    mountOverlays: "true",
    containerXdgRuntimeDir: "/run/xdg",
    hostXdgRuntimeDir: "/run/user/1000",
    containerWaylandDisplay: if *input.flag("wayland-display"): &input.flag("wayland-display") else: "wayland-0",
  )
  config.imagesPath = config.work / "images"
  config.rootfs = config.work / "rootfs"
  config.overlay = config.work / "overlay"
  config.overlayRw = config.work / "overlay_rw"
  config.overlayWork = config.work / "overlay_work"
  config.data = config.work / "data"
  config.lxc = config.work / "lxc"
  config.hostPerms = config.work / "host-permissions"
  config.containerPulseRuntimePath = config.containerXdgRuntimeDir / "pulse"

  let defEquinoxData =
    if *input.flag("user"):
      "/home" / &input.flag("user") / ".local" / "share" / "equinox"
    else:
      "/"

  config.equinoxData = getEnv("XDG_DATA_HOME", defEquinoxData)

  config.vendorOta = "https://ota.waydro.id/vendor"
  config.romType = "lineage"
  config.systemType = "GAPPS"
  config.systemOta = "https://ota.waydro.id/system"

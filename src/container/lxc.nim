import std/[os, options, logging, strutils, tables, posix]
import pkg/[glob, shakar]
import ./[lxc_config, cpu, gpu, paths, drivers, mac], ./utils/exec, ../argparser

type BinaryNotFound* = object of Defect

var exeCache: Table[string, string]

const ANDROID_ENV = toTable {
  "PATH":
    "/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/system_ext/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin",
  "ANDROID_ROOT": "/system",
  "ANDROID_DATA": "/data",
  "ANDROID_STORAGE": "/storage",
  "ANDROID_ART_ROOT": "/apex/com.android.art",
  "ANDROID_I18N_ROOT": "/apex/com.android.i18n",
  "ANDROID_TZDATA_ROOT": "/apex/com.android.tzdata",
  "ANDROID_RUNTIME_ROOT": "/apex/com.android.runtime",
  "BOOTCLASSPATH":
    "/apex/com.android.art/javalib/core-oj.jar:/apex/com.android.art/javalib/core-libart.jar:/apex/com.android.art/javalib/core-icu4j.jar:/apex/com.android.art/javalib/okhttp.jar:/apex/com.android.art/javalib/bouncycastle.jar:/apex/com.android.art/javalib/apache-xml.jar:/system/framework/framework.jar:/system/framework/ext.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/ims-common.jar:/system/framework/framework-atb-backward-compatibility.jar:/apex/com.android.conscrypt/javalib/conscrypt.jar:/apex/com.android.media/javalib/updatable-media.jar:/apex/com.android.mediaprovider/javalib/framework-mediaprovider.jar:/apex/com.android.os.statsd/javalib/framework-statsd.jar:/apex/com.android.permission/javalib/framework-permission.jar:/apex/com.android.sdkext/javalib/framework-sdkextensions.jar:/apex/com.android.wifi/javalib/framework-wifi.jar:/apex/com.android.tethering/javalib/framework-tethering.jar",
}

proc findBin*(cmd: string): string =
  debug "lxc: finding LXC related binary: " & cmd

  if cmd in exeCache:
    debug "lxc: findBin hit the cache"
    return exeCache[cmd]
  else:
    debug "lxc: findBin missed the cache"
    let path = findExe(cmd)
    if path.len < 1:
      raise newException(BinaryNotFound, "Couldn't find binary: " & path)

    debug "lxc: " & cmd & " -> " & path
    exeCache[cmd] = path
    return path

proc getLxcVersion*(): string {.inline.} =
  &readOutput("lxc-info", "--version")

proc getLxcMajor*(): uint {.inline, raises: [ValueError, Exception].} =
  getLxcVersion().split('.')[0].parseUint()

proc addNodeEntry*(
    nodes: var seq[string],
    src: string,
    dest: Option[string],
    mntType, options: string,
    check: bool,
): bool {.discardable.} =
  if check and not fileExists(src) and not devExists(src) and not dirExists(src):
    return false

  var entry = "lxc.mount.entry = "
  entry &= src & ' '
  if not *dest:
    entry &= src[1 ..< src.len] & ' '
  else:
    entry &= &dest & ' '

  entry &= mntType & ' '
  entry &= options
  nodes &= ensureMove(entry)

  true

proc generateNodesLxcConfig*(): seq[string] =
  var nodes: seq[string]

  proc entry(
      src: string,
      dest: Option[string] = none(string),
      mntType: string = "none",
      options: string = "bind,create=file,optional 0 0",
      check: bool = true,
  ): bool {.discardable.} =
    addNodeEntry(nodes, src, dest, mntType, options, check)

  let drivers = probeBinderDriver()

  entry "tmpfs", some("dev"), "tmpfs", "nosuid 0 0", false
  entry "/dev/zero"
  entry "/dev/null"
  entry "/dev/full"
  entry "/dev/ashmem"
  entry "/dev/fuse"
  entry "/dev/ion"
  entry "/dev/tty"
  entry("/dev/char", options = "bind,create=dir,optional 0 0")

  for gfxNode in [
    "/dev/kgsl-3d0", "/dev/mali0", "/dev/pvr_sync", "/dev/pmsg0", "/dev/dxg"
  ]:
    entry gfxNode

  let noded = getDriNode()
  if not *noded:
    error "container/gpu: no suitable GPU found. If you believe that this is an error, please open a bug ticket in the Lucem Discord server with the output of `lspci`"
    raise newException(Defect, "No suitable GPU found.")

  let node = &noded

  entry node.dev
  entry node.gpu

  for node in glob("/dev/fb*").walkGlob:
    entry node, check = false

  for node in glob("/dev/graphics/fb*").walkGlob:
    entry node

  for node in glob("/dev/video*").walkGlob:
    entry node

  when defined(equinoxExposeDmaHeap):
    for node in glob("/dev/dma_heap/*").walkGlob:
      entry node

  entry "/dev" / &drivers.binder, some("dev/binder"), check = false
  entry "/dev" / &drivers.vndbinder, some("dev/vndbinder"), check = false
  entry "/dev" / &drivers.hwbinder, some("dev/hwbinder"), check = false

  entry "none",
    some("dev/pts"),
    "devpts",
    "defaults,mode=644,ptmxmode=666,create=dir 0 0",
    check = false
  entry "/dev/uhid"
  # entry config.hostPerms, some("vendor/etc/host-permissions"), options = "bind,create=dir,optional 0 0"

  entry "/sys/module/lowmemorykiller", options = "bind,create=dir,optional 0 0"
  entry "/dev/sw_sync"
  entry "/sys/kernel/debug", options = "rbind,create=dir,optional 0 0"

  entry "/dev/Vcodec"
  entry "/dev/MTK_SMI"
  entry "/dev/mdp_sync"
  entry "/dev/mtk_cmdq"

  entry "tmpfs", some("mnt_extra"), "tmpfs", "nodev 0 0", false
  entry "tmpfs", some("tmp"), "tmpfs", "nodev 0 0", false
  entry "tmpfs", some("var"), "tmpfs", "nodev 0 0", false
  entry "tmpfs", some("run"), "tmpfs", "nodev 0 0", false

  nodes

proc setLxcConfig*(input: Input) =
  info "lxc: setting up configuration"
  debug "lxc: working directory = " & getWorkPath()
  debug "lxc: LXCARCH = " & getArchStr()
  let lxcMajor = getLxcMajor()
  let lxcPath = getEquinoxLxcConfigPath()

  let substituteTable = {
    "LXCARCH": getArchStr(),
    "WORKING": getWorkPath(),
    "WLDISPLAY": getWaylandDisplay(input),
  }

  var configs = @[CONFIG_BASE.multiReplace(substituteTable)]
  if lxcMajor <= 2:
    configs &= CONFIG_1
  else:
    for ver in 3 .. 4:
      if lxcMajor >= ver.uint:
        configs &=
          (
            case ver
            of 3: CONFIG_3
            of 4: CONFIG_4
            else:
              assert(false, "Unreachable")
              ""
          ).multiReplace(substituteTable)

        configs &= getLXCConfigForMAC(detectMACKind())

  discard existsOrCreateDir(getEquinoxLxcConfigPath())

  debug "lxc: creating LXC path"
  discard existsOrCreateDir(lxcPath)

  debug "lxc: writing LXC config"
  writeFile(lxcPath / "config", configs.join("\n"))

  debug "lxc: writing LXC seccomp profile"
  writeFile(lxcPath / "equinox.seccomp", SECCOMP_POLICY)

  let nodes = generateNodesLxcConfig()

  var buffer: string
  for node in nodes:
    buffer &= node & '\n'

  writeFile(lxcPath / "config_nodes", ensureMove(buffer))

  # Write an empty file to config_session. It'll be overwritten every run.
  writeFile(lxcPath / "config_session", newString(0))

proc generateSessionLxcConfig*(input: Input) =
  ## Generate session-specific LXC configurations

  var nodes: seq[string]
  proc entry(
      src: string,
      dest: Option[string] = none(string),
      mntType: string = "none",
      options = "rbind,create=file 0 0",
  ): bool {.discardable.} =
    for x in src:
      if x in {'\n', '\r'}:
        warn "lxc: user-provided mount path contains illegal character: " & x.repr
        return false

    # if not *dist and (not (fileExists(src) or dirExists(src) or devExists(src)))

    addNodeEntry(nodes, src, dest, mntType, options, check = false)

  if not entry("tmpfs", some(getContainerXdgRuntimeDir()), options = "create=dir 0 0"):
    fatal "lxc: failed to create runtime dir mount point. We'll now crash. :("
    raise newException(OSError, "Failed to create XDG_RUNTIME_DIR mount point!")

  let
    waylandContainerSocket =
      absolutePath(getContainerXdgRuntimeDir() / getWaylandDisplay(input))
    waylandHostSocket = absolutePath(getXdgRuntimeDir(input) / getWaylandDisplay(input))

  if not entry(
    waylandHostSocket, waylandContainerSocket[1 ..< waylandContainerSocket.len].some
  ):
    fatal "equinox: failed to bind Wayland socket!"
    raise newException(
      OSError,
      "Cannot bind Wayland socket.\nContainer = " & waylandContainerSocket & "\nHost = " &
        waylandHostSocket,
    )

  let
    pulseHostSocket = getXdgRuntimeDir(input) / "pulse" / "native"
    pulseContainerSocket = getContainerPulseRuntimePath() / "native"

  entry pulseHostSocket, pulseContainerSocket[1 ..< pulseContainerSocket.len].some

  if not entry(
    getEquinoxLocalPath(&input.flag("user")), "data".some, options = "rbind 0 0"
  ):
    raise newException(OSError, "Failed to bind userdata")

  nodes &= "lxc.environment=WAYLAND_DISPLAY=" & getWaylandDisplay(input)

  var buffer: string
  for node in nodes:
    buffer &= node & '\n'

  writeFile(getEquinoxLxcConfigPath() / "config_session", ensureMove(buffer))

proc getLxcStatus*(authAgent: string = "sudo"): string =
  let value =
    readOutput(authAgent & " lxc-info", "-P " & getLxcPath() & " -n equinox -sH")

  if not *value:
    return "STOPPED"

  &value

proc startLxcContainer*(input: Input, authAgent: string = "sudo") =
  debug "lxc: starting container"

  var debugLog = input.flag("log-file")

  runCmd(
    authAgent & " lxc-start",
    "-l DEBUG -P " & getLxcPath() & (if *debugLog: " -o " & &debugLog else: "") &
      " -n equinox -- /init",
  )

  if *debugLog:
    runCmd("sudo chown", "1000 " & &debugLog)

proc stopLxcContainer*(force: bool = true) =
  info "equinox: stopping container"

  if getLxcStatus() == "STOPPED":
    warn "lxc: container has already stopped"
    return

  runCmd(
    "sudo lxc-stop", "-P " & getLxcPath() & " -n equinox" & (if force: " -k" else: "")
  )

  info "equinox: stopped container."

proc waitForContainerBoot*(maxAttempts: uint64 = 32'u64) =
  ## Block this thread until the container boots up.
  debug "lxc: waiting for container to boot up"

  var attempts: uint64
  while getLxcStatus() != "RUNNING":
    if attempts > maxAttempts:
      break

    debug "lxc: wait #" & $attempts
    inc attempts
    sleep(80) # professional locking mechanism

  if getLxcStatus() != "RUNNING":
    raise newException(
      Defect,
      "The container did not start after " & $maxAttempts &
        " iterations. It might be deadlocked.\nConsider running the following command to forcefully kill it:\nsudo equinox halt -F\n",
    )

  info "lxc: container booted up after " & $(attempts + 1) & " attempts."

proc androidEnvAttachOptions(): string =
  var buffer: string
  for env, value in ANDROID_ENV:
    buffer &= "--set-var " & env & '=' & value & ' '

  move(buffer)

proc runCmdInContainer*(cmd: string): Option[string] =
  readOutput(
    "sudo lxc-attach",
    "-P " & getLxcPath() & " -n equinox --clear-env " & androidEnvAttachOptions() & "-- " &
      cmd,
  )

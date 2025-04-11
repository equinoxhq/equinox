import std/[os, logging, strutils, posix]
import ./utils/exec 

const
  BINDER_DRIVERS = ["anbox-binder", "puddlejumper", "bonder", "binder"]
  VNDBINDER_DRIVERS = ["anbox-vndbinder", "vndpuddlejumper", "vndbonder", "vndbinder"]
  HWBINDER_DRIVERS = ["anbox-hwbinder", "hwpuddlejumper", "hwbonder", "hwbinder"]

type Drivers* = object
  binder*, vndbinder*, hwbinder*: string

proc devExists*(file: string): bool =
  var sb: Stat

  if stat(file, sb) == 0.cint:
    if S_ISCHR(sb.stMode):
      debug "drivers: character device found: " & file
      return true
    else:
      warn "drivers: path exists but is NOT a character device: " & file
  else:
    debug "drivers: device does not exist: " & file

  return false

type
  BinderNode = object
    name: array[256, char]
    ctl0, ctl1: uint32

proc ioctl(fd: cint, request: uint, data: pointer): cint {.importc, header: "<sys/ioctl.h>".}

proc isBinderfsLoaded*(): bool =
  for line in readFile(
    "/proc/filesystems"
  ).splitLines():
    let words = line.split()
    if words.len >= 2 and words[1] == "binder":
      return true

  false

proc allocBinderNodes*(binderDevNodes: openArray[string]) =
  debug "drivers: allocating binder nodes"
  const
    NumBits = 8
    TypeBits = 8
    SizeBits = 14
    NumShift = 0
    TypeShift = NumShift + NumBits
    SizeShift = TypeShift + TypeBits
    DirShift = SizeShift + SizeBits
    Write = 0x1
    Read = 0x2

  func ioc(direction, typ, num, size: uint): uint {.inline.} =
    (direction shl DirShift) or (typ shl TypeShift) or (num shl NumShift) or (size shl SizeShift)

  func iowr(typ, num, size: uint): uint {.inline.} =
    ioc(Read or Write, typ, num, size)
  
  let binderCtlAdd = iowr(98, 1, 264)
  var binderCtlFd = open("/dev/binderfs/binder-control", O_RDONLY)
  if binderCtlFd < 0:
    error "drivers: cannot open /dev/binderfs/binder-control: " & $strerror(errno)
    error "drivers: hint: does your kernel not have binder support?"
    raise newException(Defect, "Cannot allocate binder nodes")

  for node in binderDevNodes:
    var nodeStruct = BinderNode(ctl0: 0, ctl1: 0)
    for i, c in node:
      if i >= 256:
        break

      nodeStruct.name[i] = c

    if ioctl(binderCtlFd, binderCtlAdd, nodeStruct.addr) < 0 and errno != EEXIST:
      error "drivers: an error occured while allocating binder node: " & node
      raise newException(Defect, "Cannot allocate binder node `" & node & "`: " & $strerror(errno))
  
  debug "drivers: allocated binder nodes successfully"
  discard close(binderCtlFd)

proc probeBinderDriver*() =
  if isBinderfsLoaded():
    debug "drivers: creating /dev/binderfs"
    discard existsOrCreateDir("/dev/binderfs")

    debug "drivers: mounting binder at /dev/binderfs"
    discard runCmd("sudo", "mount -t binder binder /dev/binderfs")

    allocBinderNodes(["binder", "hwbinder", "vndbinder"])

    debug "drivers: linking /dev/binderfs/binder to /dev/binder"
    discard runCmd("sudo", "ln -s /dev/binderfs/binder /dev/binder") # TODO: use proper POSIX C functions here
    discard runCmd("sudo", "ln -s /dev/binderfs/hwbinder /dev/hwbinder") # TODO: use proper POSIX C functions here
    discard runCmd("sudo", "ln -s /dev/binderfs/vndbinder /dev/vndbinder") # TODO: use proper POSIX C functions here

proc setupBinderNodes*(): Drivers =
  probeBinderDriver()
  var hasBinder = false
  for node in BINDER_DRIVERS:
    if devExists("/dev" / node):
      debug "drivers: found binder driver: " & node
      hasBinder = true
      result.binder = node

  if not hasBinder:
    raise newException(Defect, "Cannot find binder node \"binder\"")

  var hasVndbinder = false
  for node in VNDBINDER_DRIVERS:
    if devExists("/dev" / node):
      debug "drivers: found VND binder driver: " & node
      hasVndbinder = true
      result.vndbinder = node

  if not hasVndbinder:
    raise newException(Defect, "Cannot find VND Binder node")

  var hasHwbinder = false
  for node in HWBINDER_DRIVERS:
    if devExists("/dev" / node):
      debug "drivers: found HW binder driver: " & node
      hasHwbinder = true
      result.hwbinder = node

  if not hasHwbinder:
    raise newException(Defect, "Cannot find HW Binder node")

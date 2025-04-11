## Roblox logs manager
import std/[atomics, inotify, logging, os, posix, strutils]
import pkg/[colored_logger]
import ../container/[configuration]
import ./event_manager/[types, dispatcher]

type
  NoLogTargetFound* = object of CatchableError
  INotifyInitFail* = object of Defect
  WatcherInitFail* = object of Defect

const EquinoxLogPreallocBufferSize {.intdefine.} = 512

var watcher {.threadvar.}: Thread[string]
var running: Atomic[bool]

proc getLogDir(): string =
  config.equinoxData / "data" / "com.roblox.client" / "files" / "appData" / "logs"

proc destroyAllLogs*() =
  info "Clearing all previous logs"
  for kind, path in walkDir(getLogDir()):
    if kind != pcFile:
      continue

    removeFile(path)

proc checkLineForEvents*(line: string) =
  if line.contains("! Joining game"):
    let gameId = line.split("place ")[1].split(" at")[0]

    chan.send(EventPayload(kind: Event.GameJoin, id: gameId))
  elif line.contains("Client:Disconnect") or line.contains("Destroying MegaReplicator."):
    chan.send(EventPayload(kind: Event.GameLeave))

proc findTargetLog*(): string =
  info "equinox: finding latest log file"

  var iters = 0
  while iters < int(uint16.high):
    for kind, path in walkDir(getLogDir()):
      if kind != pcFile:
        continue
      info "Target Roblox log file: " & path

      return path

    sleep(100) # FIXME: replace this with a better mechanism (inotify probably?)
    inc iters

  raise newException(
    NoLogTargetFound, "Log directory does not have any eligible Roblox logs to track"
  )

proc readLastLine(filename: string): string =
  var file = open(filename, fmRead).getOsFileHandle()
  if file == -1:
    error "watcher: cannot read last line: " & $strerror(errno) & " (" & $errno & ')'
    return

  var pos = int(lseek(file, -1.Off, SEEK_END))
  assert(pos != -1, $strerror(errno))

  var ch: char
  var numNewlines = 0
  while pos > 0:
    discard file.read(ch.addr, 1)
    if ch == '\n':
      inc numNewlines
      if numNewlines == 2:
        break

    dec pos
    discard lseek(file, pos, SEEK_SET)

  var buffer = newString(EquinoxLogPreallocBufferSize)
  buffer.setLen(file.read(buffer[0].addr, buffer.len))
  discard file.close()

  ensureMove(buffer)

proc watcherFunc(target: string) =
  addHandler(newColoredLogger())
  setLogFilter(lvlInfo)

  debug "watcher: initializing inotify fd"
  var fd = inotify_init()
  if fd == -1:
    raise newException(
      INotifyInitFail,
      "inotify_init() returned -1; errno = " & $errno & " (" & $strerror(errno) & ')',
    )

  var watch = inotify_add_watch(fd, target, IN_MODIFY)
  if watch == -1:
    raise newException(
      WatcherInitFail,
      "inotify_add_watch() returned -1; errno = " & $errno & " (" & $strerror(errno) &
        ')',
    )

  debug "watcher: entering loop to block until changes are detected"

  let size = sizeof(INotifyEvent) + PC_NAME_MAX + 1
  var buf = cast[ptr UncheckedArray[byte]](alloc(size))
  while running.load():
    let len = read(fd, buf[0].addr, size)
    if len == -1:
      error "watcher: read() returned -1: errno = " & $errno & " (" & $strerror(errno) &
        ')'
      break

    var event = cast[ptr INotifyEvent](buf)
    if bool(event.mask and IN_MODIFY):
      debug "watcher: log file has changed"
      let line = readLastLine(target)
      stdout.write line
      checkLineForEvents(line)

  dealloc(buf)
  debug "watcher: thread is exiting loop"

proc startLogWatcher*() =
  info "Starting log watcher thread"
  try:
    let target = findTargetLog()
    running.store(true)
    createThread(watcher, watcherFunc, (ensureMove(target)))
  except NoLogTargetFound as exc:
    error "Cannot find target log: " & exc.msg
    error "Log watcher thread will not be started."
    return

proc stopLogWatcher*() =
  info "Stopping log watcher thread"
  running.store(false)
  info "Stopped log watcher thread"

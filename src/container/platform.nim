import std/[os, logging, strutils, times, options]
import ./[configuration, drivers]
import ../bindings/[gbinder]

const
  InterfaceName = "lineageos.waydroid.IPlatform"
  ServiceName = "waydroidplatform"

type
  Transaction* {.pure, size: sizeof(uint32).} = enum
    GetProp = 1
    SetProp = 2
    GetAppsInfo = 3
    GetAppInfo = 4
    InstallApp = 5
    RemoveApp = 6
    LaunchApp = 7
    GetAppName = 8
    SettingsPutString = 9
    SettingsGetString = 10
    SettingsPutInt = 11
    SettingsGetInt = 12
    LaunchIntent = 13

  IPlatform* = object
    client*: pointer

proc `=destroy`*(platform: var IPlatform) =
  if platform.client == nil:
    return

  gbinder_client_unref(cast[ptr GBinderClient](platform.client))

proc installApp*(iface: var IPlatform, path: string) =
  debug "platform: installing APK from: " & path

  debug "platform: copying APK to data/install.apk"
  copyFile(path, config.equinoxData / "install.apk")

  var request = gbinder_client_new_request(cast[ptr GBinderClient](iface.client))
  discard gbinder_local_request_append_string16(
    request, cstring("/data" / "install.apk")
  ) # ~/.local/share/equinox is mounted at /data for the container

  var status: int32
  let reply = gbinder_client_transact_sync_reply(
    cast[ptr GBinderClient](iface.client),
    uint32(Transaction.InstallApp),
    request,
    status.addr,
  )

  debug "platform: gbinder_client_transact_sync_reply() returned: " & $status

  if reply == nil:
    error "platform: reply == NULL; request has failed"
  else:
    debug "platform: got reply successfully"

proc launchApp*(iface: var IPlatform, id: string) =
  debug "platform: launching app: " & id

  var request = gbinder_client_new_request(cast[ptr GBinderClient](iface.client))
  discard gbinder_local_request_append_string16(request, cstring(id))

  var status: int32
  let reply = gbinder_client_transact_sync_reply(
    cast[ptr GBinderClient](iface.client),
    uint32(Transaction.LaunchApp),
    request,
    status.addr,
  )

  debug "platform: gbinder_client_transact_sync_reply() returned: " & $status

  if reply == nil:
    error "platform: reply == NULL; request has failed"
  else:
    debug "platform: got reply successfully"

proc setProperty*(iface: var IPlatform, name: string, prop: string) =
  debug "platform: setting property: " & name & " = " & prop

  var request = gbinder_client_new_request(cast[ptr GBinderClient](iface.client))
  discard gbinder_local_request_append_string16(request, cstring(name))
  discard gbinder_local_request_append_string16(request, cstring(prop))

  var status: int32
  let reply = gbinder_client_transact_sync_reply(
    cast[ptr GBinderClient](iface.client),
    uint32(Transaction.SetProp),
    request,
    status.addr,
  )

  if reply == nil:
    error "platform: reply == NULL; request has failed! (" & $status & ')'

proc getProperty*(iface: var IPlatform, name: string): Option[string] =
  debug "platform: getting property: " & name

  var request = gbinder_client_new_request(cast[ptr GBinderClient](iface.client))
  discard gbinder_local_request_append_string16(request, cstring(name))

  var status: int32
  let reply = gbinder_client_transact_sync_reply(
    cast[ptr GBinderClient](iface.client),
    uint32(Transaction.SetProp),
    request,
    status.addr,
  )

  if reply == nil:
    error "platform: reply == NULL; request has failed! (" & $status & ')'
    return

  var reader: GBinderReader
  gbinder_remote_reply_init_reader(reply, reader.addr)

  var readI32Status: int32
  let success = gbinder_reader_read_int32(reader.addr, readI32Status.addr)

  if not success:
    error "platform: gbinder_reader_read_int32() failed."

  if readI32Status == 0'i32:
    let prop = gbinder_reader_read_string16(reader.addr)
    return some($prop)
  else:
    error "platform: reply status code was " & $readI32Status &
      "! Cannot fetch property."

proc waitForManager*(mgr: ptr GBinderServiceManager): bool =
  for _ in 0 .. 4096:
    if gbinder_servicemanager_is_present(mgr):
      debug "platform: service manager is present!"
      return true

    sleep(10)

  false

proc getIPlatformService*(): IPlatform =
  let driverList = setupBinderNodes()

  debug "init: binder = " & driverList.binder
  debug "init: vndbinder = " & driverList.vndbinder
  debug "init: hwbinder = " & driverList.hwbinder
  config.binder = driverList.binder
  config.vndbinder = driverList.vndbinder
  config.hwbinder = driverList.hwbinder

  var serviceMgr = gbinder_servicemanager_new2(
    cstring("/dev" / config.binder), "aidl3".cstring, "aidl3".cstring
  )

  if not gbinder_servicemanager_is_present(serviceMgr):
    info "platform: waiting for binder service manager"

    if not serviceMgr.waitForManager:
      error "platform: binder service manager never initialized itself"

  var status: int32
  var remote = gbinder_servicemanager_get_service_sync(
    serviceMgr, ServiceName.cstring, status.addr
  )

  var tries = 1000
  while remote == nil:
    if tries < 0:
      warn "platform: failed to get service: " & ServiceName & " in 1000 tries"
      raise newException(Defect, "Cannot get service: " & ServiceName)
    else:
      warn "platform: failed to get service: " & ServiceName & "; retrying"
      sleep(1)
      remote = gbinder_servicemanager_get_service_sync(
        serviceMgr, ServiceName.cstring, status.addr
      )
    dec tries

  IPlatform(client: cast[pointer](gbinder_client_new(remote, InterfaceName)))

## Fetch Roblox's APK from Kirbix's Github endpoint
import std/[os, tables, logging]
import pkg/[jsony, shakar]
import ../container/[platform, paths], ../container/utils/[http], ../argparser

const
  APKEndpoint* = "https://equinoxhq.github.io/equinox-json/equinox.json"
  SelectedVersion* {.strdefine: "RobloxVersionTarget".} = "2.676.531"

type
  APKNotFound* = object of ValueError
  APKDownloadFailed* = object of IOError

  APKVersion* = object
    expired*: bool
    base*, split*: string

  APKEndpointResponse* = object
    version*: Table[string, APKVersion]

proc fetchRobloxApk*(): APKVersion =
  debug "apk: fetching data from endpoint: " & APKEndpoint
  let resp = httpGet(APKEndpoint).body.fromJson(APKEndpointResponse)

  if SelectedVersion notin resp.version:
    error "apk: endpoint did not provide requested version: " & SelectedVersion
    raise newException(APKNotFound, "No such version: " & SelectedVersion)

  return resp.version[SelectedVersion]

proc downloadApks*(pkg: APKVersion, input: Input, ver: string = SelectedVersion) =
  debug "apk: downloading packages"
  assert(
    pkg.expired,
    "Cannot download expired APK! It'll probably just cause Roblox to not work.",
  )

  discard existsOrCreateDir(getApkStorePath())

  let apkDir = getApkStorePathForVersion(ver)
  discard existsOrCreateDir(apkDir)

  let
    baseApkPath = apkDir / "base.apk"
    splitApkPath = apkDir / "split.apk"

  let baseApk = download(pkg.base, baseApkPath)

  if not baseApk:
    raise newException(APKDownloadFailed, "Failed to download base APK")

  let splitApk = download(pkg.split, splitApkPath)

  if not splitApk:
    raise newException(APKDownloadFailed, "Failed to download split APK")

  installSplitApp(baseApkPath, splitApkPath, &input.flag("user"))

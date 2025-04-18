## Roblox thumbnails API wrapper
## Copyright (C) 2024 Trayambak Rai
## Copyright (C) 2025 the EquinoxHQ team
import std/[strutils, logging]
import pkg/[curly, jsony]
import ./games

var curl = newCurly()

type
  ThumbnailState* {.pure.} = enum
    Error = "Error"
    Completed = "Completed"
    InReview = "InReview"
    Pending = "Pending"
    Blocked = "Blocked"
    TemporarilyUnavailable = "TemporarilyAvailable"

  ReturnPolicy* = enum
    Placeholder = "PlaceHolder"
    AutoGenerated = "AutoGenerated"
    ForceAutoGenerated = "ForceAutoGenerated"

  ThumbnailFormat* = enum
    Png = "png"
    Jpeg = "Jpeg"

  Thumbnail* = object
    targetId*: int64
    state*: ThumbnailState
    imageUrl*, version*: string

proc getGameIcon*(id: UniverseID): Thumbnail =
  let
    url =
      "https://thumbnails.roblox.com/v1/games/icons?universeIds=$1&returnPolicy=PlaceHolder&size=512x512&format=Png&isCircular=false" %
      [$id]
    resp = curl.get(url).body

  debug "getGameIcon($1): $2 ($3)" % [$id, resp, url]

  let payload = fromJson(resp, StubData[Thumbnail]).data[0]

  payload

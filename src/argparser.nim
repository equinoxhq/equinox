## Argument parser for Lucem, based on `std/parseopt`
## Copyright (C) 2024 Trayambak Rai
import std/[os, options, parseopt, logging, tables]

type Input* = object
  command*: string
  arguments*: seq[string]
  flags: Table[string, string]
  switches: seq[string]

proc enabled*(input: Input, switch: string): bool {.inline.} =
  input.switches.contains(switch)

proc enabled*(input: Input, switchBig, switchSmall: string): bool {.inline.} =
  input.switches.contains(switchBig) or input.switches.contains(switchSmall)

proc flag*(input: Input, value: string): Option[string] {.inline.} =
  if input.flags.contains(value):
    return some(input.flags[value])

proc parseInput*(): Input {.inline.} =
  var
    foundCmd = false
    input: Input

  let params = commandLineParams()

  debug "argparser: params string is `" & params & "`"

  var parser = initOptParser(params)
  while true:
    parser.next()
    case parser.kind
    of cmdEnd:
      debug "argparser: hit end of argument stream"
      break
    of cmdShortOption, cmdLongOption:
      if parser.val.len < 1:
        debug "argparser: found switch: " & parser.key
        input.switches &= parser.key
      else:
        debug "argparser: found flag: " & parser.key & '=' & parser.val
        input.flags[parser.key] = parser.val
    of cmdArgument:
      if not foundCmd:
        debug "argparser: found command: " & parser.key
        input.command = parser.key
        foundCmd = true
      else:
        debug "argparser: found argument: " & parser.key
        input.arguments &= parser.key

  if input.command.len < 1:
    error "equinox: expected command, got none. Run `equinox help` for more information."
    quit(1)

  input

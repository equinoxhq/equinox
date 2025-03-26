## Base compositor code
import std/[os, logging]
import pkg/[louvre, colored_logger, vmath]

type Equi* = object of Compositor

proc createObjectRequest(equi: ptr Equi, objectType: FactoryObjectType, params {.codegenDecl: "const $1 $2".}: pointer): ptr FactoryObject {.virtual.} =
  debug "comp: createObjectRequest -> " & $objectType

  case objectType
  of LSurface:
    for surface in Compositor(equi[]).getSurfaces():
      let outputs = surface.getOutputs()
      if outputs.len < 1:
        warn "comp: BUG: Surface appears on no outputs???"
        continue

      surface.resize(outputs[0][].size)
      surface.raiseSurface()
  else: discard

proc initialized(equi: ptr Equi) {.virtual.} =
  debug "comp: initialized compositor successfully."

  var comp = (ptr Compositor) equi
  info "comp: using louvre " & $comp[].getVersion()

  comp.initialized()

  let outputs = comp[].getOutputs()

  debug "comp: initializing all outputs"
  var totalWidth: int
  for i, pOutput in outputs:
    if pOutput[].isNonDesktop:
      pOutput.leasable = true
      continue

    info "comp: Monitor #" & $i
    info "comp: Name: " & pOutput[].name
    info "comp: Manufacturer: " & pOutput[].manufacturer
    info "comp: Description: " & pOutput[].description

    pOutput.vsync = false
    pOutput.scale = (if pOutput[].dpi >= 200: 2f else: 1f)
    pOutput.position = vec2(totalWidth.float, 0'f).toPoint()
    totalWidth += pOutput[].size.x()

    try:
      debug "comp: adding output " & $i
      comp.addOutput(pOutput)
    except louvre.CannotAddOutput as exc:
      error "comp: while adding output: " & exc.msg

    debug "comp: forcing output repaint"
    pOutput.repaint()

  debug "comp: initialization completed!"

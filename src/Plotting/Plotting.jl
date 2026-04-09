# Plotting.jl — WGLMakie support via WasmTargetWGLMakieExt
#
# Plotting uses WGLMakie overlays compiled to WASM via WasmTargetWGLMakieExt.
# Users write standard Makie API code:
#
#   import WGLMakie as Mke
#   @island function MyPlot(...)
#       fig = Mke.Figure()
#       ax = Mke.Axis(fig)
#       Mke.lines!(ax, x, y)
#       display(fig)
#   end
#
# The WasmTargetWGLMakieExt extension (in WasmTarget.jl) overlays Makie calls
# to WASM imports that invoke Three.js rendering in the browser.

# Generic Canvas2D provider protocol (WASMMAKIE E-002).
#
# Therapy knows NOTHING about specific plotting packages: a provider hands
# over (a) its wasm import surface and (b) the JS glue implementing it.
# Any package exposing `import_specs()` + `js_glue()` (the WasmMakie
# embedding contract — WasmPlot adapts through the same shape) registers via
# `register_canvas_provider!`. With no registration, the legacy WasmPlot
# autoload keeps working during the transition (E-005 retires it).

"""
    CanvasProvider(name, import_specs, js_glue)

`import_specs()` returns an iterable of specs; each spec is either a
4-tuple `(func_ref, import_name, arg_types::Tuple, return_type)` or any
object with `func`/`name`/`arg_types`/`return_type` properties (the
WasmMakie `import_specs()` shape). `js_glue()` returns JS source defining
`canvas2d_imports(canvas_or_ctx) -> import object`.
"""
struct CanvasProvider
    name::String
    import_specs::Function
    js_glue::Function
end

const _CANVAS_PROVIDER = Ref{Union{CanvasProvider, Nothing}}(nothing)

"""
    register_canvas_provider!(; name, import_specs, js_glue) -> CanvasProvider

Install the page-wide Canvas2D provider, e.g.

    Therapy.register_canvas_provider!(name = "WasmMakie",
        import_specs = WasmMakie.import_specs, js_glue = WasmMakie.js_glue)
"""
function register_canvas_provider!(; name::AbstractString,
                                   import_specs::Function, js_glue::Function)
    p = CanvasProvider(String(name), import_specs, js_glue)
    _CANVAS_PROVIDER[] = p
    return p
end

"Normalize a provider spec to `(func_ref, import_name, arg_types, return_type)`."
function _normalize_canvas_spec(spec)
    spec isa Tuple && length(spec) == 4 && return spec
    return (spec.func, String(spec.name), Tuple(spec.arg_types), spec.return_type)
end

# the legacy WasmPlot glue (was inline in WasmRuntime.jl) — kept ONLY as the
# transition fallback; new providers ship their own canvas2d_imports
const _LEGACY_WASMPLOT_GLUE = """
function canvas2d_imports(target){var _ctx=(target&&target.getContext)?target.getContext('2d'):target;return{begin_path:function(){if(_ctx)_ctx.beginPath();return 0n;},close_path:function(){if(_ctx)_ctx.closePath();return 0n;},move_to:function(x,y){if(_ctx)_ctx.moveTo(x,y);return 0n;},line_to:function(x,y){if(_ctx)_ctx.lineTo(x,y);return 0n;},arc:function(x,y,r,sa,ea){if(_ctx)_ctx.arc(x,y,r,sa,ea);return 0n;},stroke:function(){if(_ctx)_ctx.stroke();return 0n;},fill:function(){if(_ctx)_ctx.fill();return 0n;},fill_rect:function(x,y,w,h){if(_ctx)_ctx.fillRect(x,y,w,h);return 0n;},clear_rect:function(x,y,w,h){if(_ctx)_ctx.clearRect(x,y,w,h);return 0n;},stroke_rect:function(x,y,w,h){if(_ctx)_ctx.strokeRect(x,y,w,h);return 0n;},set_stroke_rgb:function(r,g,b){if(_ctx)_ctx.strokeStyle='rgb('+r+','+g+','+b+')';return 0n;},set_fill_rgb:function(r,g,b){if(_ctx)_ctx.fillStyle='rgb('+r+','+g+','+b+')';return 0n;},set_fill_rgba:function(r,g,b,a){if(_ctx)_ctx.fillStyle='rgba('+r+','+g+','+b+','+a+')';return 0n;},set_line_width:function(w){if(_ctx)_ctx.lineWidth=w;return 0n;},set_font_size:function(s){if(_ctx)_ctx.font=s+'px sans-serif';return 0n;},fill_text_char:function(c,x,y){if(_ctx)_ctx.fillText(String.fromCharCode(c),x,y);return 0n;},save:function(){if(_ctx)_ctx.save();return 0n;},restore:function(){if(_ctx)_ctx.restore();return 0n;},translate:function(x,y){if(_ctx)_ctx.translate(x,y);return 0n;},rotate:function(a){if(_ctx)_ctx.rotate(a);return 0n;},set_line_dash_solid:function(){if(_ctx)_ctx.setLineDash([]);return 0n;},set_line_dash_dashed:function(){if(_ctx)_ctx.setLineDash([6,4]);return 0n;},set_line_dash_dotted:function(){if(_ctx)_ctx.setLineDash([2,3]);return 0n;}};}
"""

"Legacy transition path: autoload WasmPlot and adapt CANVAS2D_STUBS + the old inline glue."
function _legacy_wasmplot_provider()
    try
        wp = Base.require(Base.PkgId(Base.UUID("c1c0b9ed-8be2-478a-b5eb-22e4f5885b7b"), "WasmPlot"))
        stubs = getfield(wp, :CANVAS2D_STUBS)
        return CanvasProvider("WasmPlot (legacy autoload)",
                              () -> stubs, () -> _LEGACY_WASMPLOT_GLUE)
    catch e
        @debug "no canvas provider registered and WasmPlot not available" exception = e
        return nothing
    end
end

"""
    active_canvas_provider() -> Union{CanvasProvider, Nothing}

The registered provider, falling back to the legacy WasmPlot autoload.
"""
function active_canvas_provider()
    _CANVAS_PROVIDER[] !== nothing && return _CANVAS_PROVIDER[]
    return _legacy_wasmplot_provider()
end

"The active provider's `canvas2d_imports` JS, or `nothing` without a provider."
function canvas_glue_js()
    p = active_canvas_provider()
    p === nothing && return nothing
    return p.js_glue()
end

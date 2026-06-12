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

"""
    active_canvas_provider() -> Union{CanvasProvider, Nothing}

The registered provider, or `nothing`. Providers register explicitly via
`register_canvas_provider!` (WASMMAKIE E-005: the legacy WasmPlot autoload
is retired — WasmPlot is superseded by WasmMakie).
"""
active_canvas_provider() = _CANVAS_PROVIDER[]

"The active provider's `canvas2d_imports` JS, or `nothing` without a provider."
function canvas_glue_js()
    p = active_canvas_provider()
    p === nothing && return nothing
    return p.js_glue()
end

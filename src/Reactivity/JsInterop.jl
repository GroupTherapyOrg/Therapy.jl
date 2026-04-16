# JsInterop.jl - Escape hatch for raw JavaScript in compiled @island code
#
# js("code") emits the string as raw JS inside compiled handlers/effects.
# js("template with \$1", val) substitutes \$1 with the compiled JS for val.
# In Julia, it's a no-op. JST recognizes it by name and emits the string content.
#
# Examples:
#   js("document.documentElement.classList.toggle('dark')")
#   js("Plotly.react(el, [{x: \$1, y: \$2}])", x_data(), y_data())

# Mutable sink prevents Julia from dead-code-eliminating the call
const _JS_INTEROP_SINK = Ref{Any}(nothing)

"""
    js(code::String, args...) -> Nothing

Emit raw JavaScript code inside a compiled @island handler or effect.

In Julia, this is a no-op. When compiled to WASM via WasmTarget.jl,
the string content is emitted directly as JavaScript code.

Use `\$1`, `\$2`, etc. to interpolate compiled signal values:

```julia
create_effect(() -> begin
    js("document.getElementById('plot').textContent = \$1", count())
end)
```
"""
@noinline function js(code::String, args...)::Nothing
    _JS_INTEROP_SINK[] = (code, args)
    return nothing
end

"""
    set_shared!(name::AbstractString, value)

Set a cross-island shared signal from Julia / from raw JS context. Must
be called from outside an `@island` body (e.g. from a top-level
`<script>` block, or a WS-receive handler in user code that wants to
push state into all islands subscribing to `name`).

In Julia this is a no-op (server-side rendering doesn't need it). At
runtime the JS side calls `window.__therapy.set(name, value)` which the
SignalRuntime pub/sub broadcasts to every island that registered via
`window.__therapy.reg(name, …)` — i.e. every island whose body reads
the same module-scope `create_signal(…)`.
"""
@noinline function set_shared!(name::AbstractString, value)
    _JS_INTEROP_SINK[] = (:set_shared, name, value)
    return nothing
end

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

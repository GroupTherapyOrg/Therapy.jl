# JsInterop.jl - Escape hatch for raw JavaScript in compiled @island code
#
# js("code") emits the string as raw JS inside compiled handlers/effects.
# In Julia, it's a no-op. JST recognizes it by name and emits the string content.
#
# Example:
#   create_effect(() -> js("document.documentElement.classList.toggle('dark')"))
#   Button(:on_click => () -> js("localStorage.setItem('theme', 'dark')"))

# Mutable sink prevents Julia from dead-code-eliminating the call
const _JS_INTEROP_SINK = Ref{Any}(nothing)

"""
    js(code::String) -> Nothing

Emit raw JavaScript code inside a compiled @island handler or effect.

In Julia, this is a no-op. When compiled to JS via JavaScriptTarget.jl,
the string content is emitted directly as JavaScript code.

# Examples
```julia
@island function DarkModeToggle()
    is_dark, set_dark = create_signal(0)
    Button(:on_click => () -> begin
        set_dark(1 - is_dark())
        js("document.documentElement.classList.toggle('dark')")
    end, "Toggle")
end
```
"""
@noinline function js(code::String)::Nothing
    _JS_INTEROP_SINK[] = code
    return nothing
end

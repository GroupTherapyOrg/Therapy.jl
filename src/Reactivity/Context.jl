# Context.jl - Dependency tracking context for reactivity
# Also implements the Context API for component data sharing (leptos-style)

#==============================================================================#
# Part 1: Effect/Dependency Tracking Context
#==============================================================================#

"""
Global context for tracking which effect is currently running.
This enables automatic dependency tracking when signals are read.
"""
const EFFECT_STACK = Any[]

"""
Batch depth counter and pending updates queue.
When batching, signal updates are queued instead of immediately triggering effects.
Depth counting supports nested batches (including implicit batches from notify_subscribers!).
"""
const BATCH_DEPTH = Ref{Int}(0)
const PENDING_UPDATES = Set{Any}()

"""
Push an effect onto the tracking stack.
Called when an effect starts running.
"""
function push_effect_context!(effect)
    push!(EFFECT_STACK, effect)
end

"""
Pop the current effect from the tracking stack.
Called when an effect finishes running.
"""
function pop_effect_context!()
    pop!(EFFECT_STACK)
end

"""
Get the currently running effect, or nothing if none.
"""
function current_effect()
    isempty(EFFECT_STACK) ? nothing : last(EFFECT_STACK)
end

"""
Check if we're currently inside an effect context.
"""
function in_effect_context()::Bool
    !isempty(EFFECT_STACK)
end

"""
Start batch mode - updates will be queued.
Supports nesting: each start_batch! must be paired with end_batch!.
"""
function start_batch!()
    BATCH_DEPTH[] += 1
end

"""
End batch mode - run all queued updates when outermost batch completes.
Handles cascaded updates: if running an effect triggers more signal updates,
those are processed in subsequent iterations of the while loop.
"""
function end_batch!()
    BATCH_DEPTH[] -= 1
    if BATCH_DEPTH[] == 0
        # Process all pending effects, including cascaded updates
        while !isempty(PENDING_UPDATES)
            effects = collect(PENDING_UPDATES)
            empty!(PENDING_UPDATES)
            for effect in effects
                run_effect!(effect)
            end
        end
    end
end

"""
Check if we're in batch mode.
"""
function is_batching()::Bool
    BATCH_DEPTH[] > 0
end

"""
Queue an effect to run after batch completes.
"""
function queue_update!(effect)
    push!(PENDING_UPDATES, effect)
end

#==============================================================================#
# Part 2: Context API for Component Data Sharing (leptos-style)
#==============================================================================#

"""
    Context{T}

A typed context that can be provided to a component subtree and retrieved
by any descendant component. Follows the leptos pattern for dependency injection.

The type parameter T specifies the type of value the context holds.

# Example
```julia
# Define a theme context type
struct ThemeContext
    name::String
    primary_color::String
end

# The context is identified by its type
ctx = Context{ThemeContext}()
```
"""
struct Context{T}
    # The Context type itself is a marker type that identifies the context
    # by its type parameter. The actual value is stored in the context stack.
end

"""
    ContextProvider{T}

A provider that supplies a context value to its component subtree.
Used internally by provide_context.

# Fields
- `context::Context{T}`: The context type being provided
- `value::T`: The value to provide
"""
struct ContextProvider{T}
    context::Context{T}
    value::T
end

# Global context stack - maps context types to their values
# Each entry is a Dict mapping type => value, allowing nested contexts
const CONTEXT_STACK = Vector{Dict{DataType, Any}}()

"""
    push_context_scope!()

Push a new context scope onto the stack. Called when entering a provider block.
"""
function push_context_scope!()
    push!(CONTEXT_STACK, Dict{DataType, Any}())
end

"""
    pop_context_scope!()

Pop the current context scope from the stack. Called when exiting a provider block.
"""
function pop_context_scope!()
    if !isempty(CONTEXT_STACK)
        pop!(CONTEXT_STACK)
    end
end

"""
    set_context_value!(::Type{T}, value::T) where T

Set a context value in the current scope.
"""
function set_context_value!(::Type{T}, value::T) where T
    if isempty(CONTEXT_STACK)
        push_context_scope!()
    end
    CONTEXT_STACK[end][T] = value
end

"""
    get_context_value(::Type{T}) where T -> Union{T, Nothing}

Get a context value, searching from innermost to outermost scope.
Returns nothing if the context is not found.
"""
function get_context_value(::Type{T})::Union{T, Nothing} where T
    # Search from innermost to outermost scope
    for i in length(CONTEXT_STACK):-1:1
        if haskey(CONTEXT_STACK[i], T)
            return CONTEXT_STACK[i][T]::T
        end
    end
    return nothing
end

"""
    provide_context(f, ::Type{T}, value::T) where T
    provide_context(f, value::T) where T

Provide a context value to a component subtree. The context is available
to any descendant component that calls `use_context(T)` within the block.

The context is automatically cleaned up when the block exits, ensuring
proper scoping of context values.

# Arguments
- `f`: A function (or do-block) that represents the component subtree
- `T`: The type that identifies the context (can be inferred from value)
- `value`: The value to provide

# Example
```julia
# Define a theme type
struct Theme
    name::String
    primary::String
end

# Provide context to subtree
provide_context(Theme("dark", "#1a1a2e")) do
    # Child components can access the theme via use_context(Theme)
    render_app()
end

# Or with explicit type
provide_context(Theme, Theme("light", "#ffffff")) do
    render_app()
end

# Nested contexts work correctly - inner shadows outer
provide_context(Theme("outer", "#000")) do
    provide_context(Theme("inner", "#fff")) do
        # use_context(Theme) returns Theme("inner", "#fff") here
    end
    # use_context(Theme) returns Theme("outer", "#000") here
end
```

# Notes
- Context is scoped to the block - it's automatically cleaned up on exit
- Nested provides of the same type shadow outer provides
- If an exception occurs in the block, the context is still cleaned up
"""
function provide_context(f, ::Type{T}, value::T) where T
    push_context_scope!()
    try
        set_context_value!(T, value)
        return f()
    finally
        pop_context_scope!()
    end
end

# Convenience method that infers the type from the value
function provide_context(f, value::T) where T
    provide_context(f, T, value)
end

"""
    use_context(::Type{T}) where T -> Union{T, Nothing}

Retrieve a context value from the nearest ancestor provider.
Returns `nothing` if no provider for the given type is found.

This function searches the context stack from innermost to outermost scope,
returning the first value found for the given type.

# Arguments
- `T`: The type that identifies the context to retrieve

# Returns
- The context value of type `T` if found, or `nothing` if no provider exists

# Example
```julia
# Define a theme type
struct Theme
    name::String
    primary::String
end

# Inside a component tree with a Theme provider
function ThemedButton()
    theme = use_context(Theme)
    if theme === nothing
        # Fallback when no provider
        return Button("Click me")
    end
    Button(:style => "background: \$(theme.primary)", "Click me")
end

# Usage with provider
provide_context(Theme("dark", "#1a1a2e")) do
    # use_context(Theme) returns Theme("dark", "#1a1a2e") here
    render(ThemedButton())
end

# Without provider
render(ThemedButton())  # use_context(Theme) returns nothing
```

# Notes
- Always check if the result is `nothing` when the context might not be provided
- Works with nested contexts - returns the nearest (innermost) provider's value
- The search is performed at call time, so context changes affect subsequent calls
"""
function use_context(::Type{T})::Union{T, Nothing} where T
    return get_context_value(T)
end

#==============================================================================#
# Part 3: Symbol-Keyed Context API (for @island parent→child communication)
#==============================================================================#

# Separate stack for Symbol-keyed context (used in @island bodies)
# This enables provide_context(:dialog_open, signal) / use_context(:dialog_open)
const SYMBOL_CONTEXT_STACK = Vector{Dict{Symbol, Any}}()

"""
    provide_context(key::Symbol, value)

Provide a context value by Symbol key within an @island body.
Used for parent→child island communication without tree walking.

Unlike the type-based API, this does NOT create a new scope — it stores
in the current scope (or creates one if none exists). This matches
Leptos's provide_context behavior within a component body.

# Example
```julia
@island function Dialog(; children...)
    is_open, set_open = create_signal(Int32(0))
    provide_context(:dialog_open, is_open)
    provide_context(:dialog_set_open, set_open)
    Div(children...)
end
```
"""
function provide_context(key::Symbol, value)
    if isempty(SYMBOL_CONTEXT_STACK)
        push!(SYMBOL_CONTEXT_STACK, Dict{Symbol, Any}())
    end
    SYMBOL_CONTEXT_STACK[end][key] = value
end

"""
    use_context(key::Symbol) -> Any

Retrieve a context value by Symbol key, searching from innermost scope outward.
Returns `nothing` if no provider for the given key is found.

# Example
```julia
@island function DialogTrigger(; children...)
    is_open = use_context(:dialog_open)
    set_open = use_context(:dialog_set_open)
    Button(:on_click => () -> set_open(Int32(1) - is_open()), children...)
end
```
"""
function use_context(key::Symbol)
    for i in length(SYMBOL_CONTEXT_STACK):-1:1
        if haskey(SYMBOL_CONTEXT_STACK[i], key)
            return SYMBOL_CONTEXT_STACK[i][key]
        end
    end
    return nothing
end

"""
    provide_context(f, key::Symbol, value)

Provide a scoped Symbol-keyed context value. The context is available within
the block and automatically cleaned up on exit.

# Example
```julia
provide_context(:theme, "dark") do
    use_context(:theme)  # returns "dark"
end
use_context(:theme)  # returns nothing
```
"""
function provide_context(f, key::Symbol, value)
    push!(SYMBOL_CONTEXT_STACK, Dict{Symbol, Any}())
    try
        SYMBOL_CONTEXT_STACK[end][key] = value
        return f()
    finally
        pop!(SYMBOL_CONTEXT_STACK)
    end
end

"""
    use_context_signal(key::Symbol, initial) -> (getter, setter)

Retrieve a signal pair from Symbol-keyed context, or create a new signal as fallback.

Used in child @island bodies to read the parent's signal via context.
In SSR mode: returns the parent's (getter, setter) tuple from context.
In Wasm compilation: treated as create_signal(initial) by IslandTransform.

# Example
```julia
@island function Dialog(; children...)
    is_open, set_open = create_signal(Int32(0))
    provide_context(:dialog, (is_open, set_open))
    Div(children...)
end

@island function DialogTrigger(; children...)
    is_open, set_open = use_context_signal(:dialog, Int32(0))
    Button(:on_click => () -> set_open(Int32(1) - is_open()), children...)
end
```
"""
function use_context_signal(key::Symbol, initial)
    ctx = use_context(key)
    if ctx isa Tuple && length(ctx) == 2
        return ctx
    end
    return create_signal(initial)
end

"""
    push_symbol_context_scope!()

Push a new Symbol context scope. Used during SSR rendering of @island trees.
"""
function push_symbol_context_scope!()
    push!(SYMBOL_CONTEXT_STACK, Dict{Symbol, Any}())
end

"""
    pop_symbol_context_scope!()

Pop the current Symbol context scope.
"""
function pop_symbol_context_scope!()
    if !isempty(SYMBOL_CONTEXT_STACK)
        pop!(SYMBOL_CONTEXT_STACK)
    end
end

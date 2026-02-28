# Signal.jl - Core reactive primitive

# Global signal ID counter
const SIGNAL_ID_COUNTER = Ref{UInt64}(0)

function next_signal_id()::UInt64
    SIGNAL_ID_COUNTER[] += 1
    return SIGNAL_ID_COUNTER[]
end

# Analysis mode tracking (set by Compiler/Analysis.jl)
const SIGNAL_ANALYSIS_MODE = Ref{Bool}(false)
const ANALYZED_SIGNALS = Ref{Vector{Any}}(Any[])
const SIGNAL_GETTER_MAP = Ref{Dict{Any, UInt64}}(Dict{Any, UInt64}())

# Handler tracing mode - records what operations handlers perform
const HANDLER_TRACING_MODE = Ref{Bool}(false)
const TRACED_OPERATIONS = Ref{Vector{Any}}(Any[])

# Operation types that handlers can perform on signals
@enum SignalOperation begin
    OP_INCREMENT    # signal + 1
    OP_DECREMENT    # signal - 1
    OP_SET          # signal = constant
    OP_ADD          # signal + n
    OP_SUB          # signal - n
    OP_MUL          # signal * n
    OP_NEGATE       # -signal
    OP_TOGGLE       # signal = signal == 0 ? 1 : 0 (boolean toggle)
    OP_UNKNOWN      # couldn't determine operation
end

"""
Represents a traced operation from a handler.
"""
struct TracedOperation
    signal_id::UInt64
    operation::SignalOperation
    operand::Any  # The constant operand for SET, ADD, SUB, MUL
end

"""
Enable handler tracing mode.
"""
function enable_handler_tracing!()
    HANDLER_TRACING_MODE[] = true
    TRACED_OPERATIONS[] = Any[]
end

"""
Disable handler tracing and return traced operations.
"""
function disable_handler_tracing!()
    HANDLER_TRACING_MODE[] = false
    ops = TRACED_OPERATIONS[]
    TRACED_OPERATIONS[] = Any[]
    return ops
end

is_handler_tracing() = HANDLER_TRACING_MODE[]

"""
Record an operation during handler tracing.
"""
function record_traced_operation!(signal_id::UInt64, old_value, new_value)
    op = detect_operation(old_value, new_value)
    push!(TRACED_OPERATIONS[], TracedOperation(signal_id, op.operation, op.operand))
end

"""
Detect what operation was performed based on old and new values.
"""
function detect_operation(old_value::T, new_value::T) where T <: Number
    diff = new_value - old_value

    if diff == 1
        return (operation=OP_INCREMENT, operand=nothing)
    elseif diff == -1
        return (operation=OP_DECREMENT, operand=nothing)
    elseif diff > 0
        return (operation=OP_ADD, operand=diff)
    elseif diff < 0
        return (operation=OP_SUB, operand=-diff)
    elseif old_value != 0 && new_value % old_value == 0
        return (operation=OP_MUL, operand=new_value ÷ old_value)
    elseif new_value == -old_value
        return (operation=OP_NEGATE, operand=nothing)
    else
        return (operation=OP_SET, operand=new_value)
    end
end

function detect_operation(old_value, new_value)
    # For non-numeric types, it's always a SET
    return (operation=OP_SET, operand=new_value)
end

"""
Enable signal analysis mode.
"""
function enable_signal_analysis!()
    SIGNAL_ANALYSIS_MODE[] = true
    ANALYZED_SIGNALS[] = Any[]
    SIGNAL_GETTER_MAP[] = Dict{Any, UInt64}()
end

"""
Disable signal analysis mode and return collected signals.
"""
function disable_signal_analysis!()
    SIGNAL_ANALYSIS_MODE[] = false
    signals = ANALYZED_SIGNALS[]
    getter_map = SIGNAL_GETTER_MAP[]
    ANALYZED_SIGNALS[] = Any[]
    SIGNAL_GETTER_MAP[] = Dict{Any, UInt64}()
    return signals, getter_map
end

"""
Check if we're in signal analysis mode.
"""
is_signal_analysis_mode() = SIGNAL_ANALYSIS_MODE[]

"""
Get the signal ID for a getter (during analysis).
"""
function get_signal_id_for_getter(getter)
    get(SIGNAL_GETTER_MAP[], getter, nothing)
end

# ============================================================================
# Struct-based Signal Accessors
# ============================================================================
# These are callable structs that:
# 1. Work like functions (getter() and setter(val))
# 2. Have a :signal field for WasmTarget pattern matching
# 3. Are @noinline to prevent Julia from inlining their bodies
# This enables direct Wasm compilation without tracing.

"""
Signal getter struct - callable, has :signal field, doesn't inline.
"""
struct SignalGetter{T}
    signal::Signal{T}
end

"""
Read the signal value with effect tracking.
@noinline prevents Julia from inlining this, keeping IR clean for Wasm.
"""
@noinline function (g::SignalGetter{T})()::T where T
    # Track dependency if inside an effect
    effect = current_effect()
    if effect !== nothing
        push!(g.signal.subscribers, effect)
        push!(effect.dependencies, g.signal)
    end
    return g.signal.value
end

"""
Signal setter struct - callable, has :signal field, doesn't inline.
"""
struct SignalSetter{T}
    signal::Signal{T}
end

"""
Write the signal value with tracing and notification.
@noinline prevents Julia from inlining this, keeping IR clean for Wasm.
"""
@noinline function (s::SignalSetter{T})(new_value)::T where T
    old_value = s.signal.value

    # Record operation if in handler tracing mode
    if is_handler_tracing()
        record_traced_operation!(s.signal.id, old_value, new_value)
    end

    if old_value != new_value
        s.signal.value = new_value
        notify_subscribers!(s.signal)
    end
    return new_value
end

"""
    create_signal(initial::T) -> (getter, setter)

Create a new reactive signal with an initial value.

Returns a tuple of (getter, setter) callable structs:
- `getter()`: Returns the current value and tracks dependencies
- `setter(value)`: Updates the value and notifies subscribers

# Examples
```julia
count, set_count = create_signal(0)
count()           # => 0
set_count(5)
count()           # => 5
```

Implementation note: The getter and setter are struct-based callables
(not closures) with @noinline methods. This produces clean IR that
WasmTarget can compile directly without tracing.
"""
function create_signal(initial::T) where T
    signal = Signal{T}(next_signal_id(), initial, Set{Any}())

    # Use struct-based accessors instead of closures
    # These produce clean IR for Wasm compilation
    getter = SignalGetter{T}(signal)
    setter = SignalSetter{T}(signal)

    # Record signal if in analysis mode
    if is_signal_analysis_mode()
        push!(ANALYZED_SIGNALS[], (id=signal.id, initial=initial, type=T, getter=getter, setter=setter))
        SIGNAL_GETTER_MAP[][getter] = signal.id
    end

    return (getter, setter)
end

"""
    create_signal(initial::T, transform::Function) -> (getter, setter)

Create a signal with a transform function applied on set.

# Examples
```julia
name, set_name = create_signal("", uppercase)
set_name("hello")
name()  # => "HELLO"
```
"""
function create_signal(initial::T, transform::Function) where T
    signal = Signal{T}(next_signal_id(), transform(initial), Set{Any}())

    getter = function()
        effect = current_effect()
        if effect !== nothing
            push!(signal.subscribers, effect)
            push!(effect.dependencies, signal)
        end
        return signal.value
    end

    setter = function(new_value)
        transformed = transform(new_value)
        if signal.value != transformed
            signal.value = transformed
            notify_subscribers!(signal)
        end
        return transformed
    end

    return (getter, setter)
end

"""
Notify all subscribers that the signal's value has changed.

Uses implicit batching to ensure effects are deduplicated when a signal
change affects both a memo and a direct effect subscriber. This matches
Leptos's glitch-free reactive propagation model.
"""
function notify_subscribers!(signal::Signal)
    was_batching = is_batching()
    if !was_batching
        start_batch!()
    end
    try
        for subscriber in collect(signal.subscribers)
            if subscriber isa MemoSubscriber
                mark_memo_dirty!(subscriber.memo)
            elseif subscriber isa Effect
                queue_update!(subscriber)
            end
            # TrackingContext and other types are ignored (they're for dependency tracking only)
        end
    finally
        if !was_batching
            end_batch!()
        end
    end
end

"""
    batch(fn::Function)

Batch multiple signal updates together.
Effects will only run once after all updates complete.

# Examples
```julia
count, set_count = create_signal(0)
name, set_name = create_signal("")

batch() do
    set_count(1)
    set_count(2)
    set_name("hello")
end
# Effects depending on count or name run once here
```
"""
function batch(fn::Function)
    start_batch!()
    try
        fn()
    finally
        end_batch!()
    end
end

# ============================================================================
# Compilable Signal Accessors
# ============================================================================
# These are simple read/write functions that compile to clean IR.
# Used by the Wasm compiler to generate efficient code without
# runtime overhead (no tracing, no notifications - those happen
# in the Wasm DOM update injection phase).

"""
    _signal_read(signal::Signal{T}) -> T

Simple signal read that compiles to clean IR.
Just returns the signal's value without any runtime tracking.
"""
@inline function _signal_read(signal::Signal{T})::T where T
    return signal.value
end

"""
    _signal_write(signal::Signal{T}, value::T) -> T

Simple signal write that compiles to clean IR.
Just sets the signal's value without any runtime tracking or notification.
Returns the written value.
"""
@inline function _signal_write(signal::Signal{T}, value::T)::T where T
    signal.value = value
    return value
end

"""
A compilable wrapper that holds a reference to the underlying Signal.
Used to create handlers that compile to efficient Wasm code.
"""
struct CompilableSignal{T}
    signal::Signal{T}
end

# Make CompilableSignal callable like a getter
@inline function (cs::CompilableSignal{T})()::T where T
    return _signal_read(cs.signal)
end

"""
A compilable setter wrapper.
"""
struct CompilableSetter{T}
    signal::Signal{T}
end

# Make CompilableSetter callable like a setter
@inline function (cs::CompilableSetter{T})(value::T)::T where T
    return _signal_write(cs.signal, value)
end

"""
    create_compilable_signal(initial::T) -> (CompilableSignal{T}, CompilableSetter{T}, Signal{T})

Create a signal with compilable accessors for Wasm compilation.

Returns:
- getter: CompilableSignal that can be called to read the value
- setter: CompilableSetter that can be called to write the value
- signal: The underlying Signal object (for analysis)

The getter and setter are designed to compile to clean IR without
runtime overhead (tracing, notifications, etc.).

# Example
```julia
count, set_count, signal = create_compilable_signal(0)
count()         # => 0
set_count(5)    # => 5
count()         # => 5
```
"""
function create_compilable_signal(initial::T) where T
    signal = Signal{T}(next_signal_id(), initial, Set{Any}())
    getter = CompilableSignal{T}(signal)
    setter = CompilableSetter{T}(signal)
    return (getter, setter, signal)
end

# ============================================================================
# BindBool — Boolean signal-to-attribute binding
# ============================================================================

"""
    BindBool(getter, off_value, on_value)

A boolean signal binding that maps signal values to string attribute values.
When the signal is 0/false, renders as `off_value`; when non-zero/true, renders as `on_value`.

Used in @island components to bind signals to HTML attributes like data-state and aria-pressed.
The Wasm compiler detects BindBool props and auto-injects DOM updates when the signal changes.

# Examples
```julia
is_pressed, set_pressed = create_signal(Int32(0))
Button(
    Symbol("data-state") => BindBool(is_pressed, "off", "on"),
    :aria_pressed => BindBool(is_pressed, "false", "true"),
    :on_click => () -> set_pressed(Int32(1) - is_pressed())
)
```
"""
struct BindBool
    getter::Any      # Signal getter (SignalGetter or Function)
    off_value::String  # Value when signal is 0/false
    on_value::String   # Value when signal is non-zero/true
end

# For SSR: convert to string based on current signal value
function Base.string(b::BindBool)
    val = b.getter()
    return (val isa Number && val > 0) || val === true ? b.on_value : b.off_value
end

Base.print(io::IO, b::BindBool) = print(io, string(b))

# ============================================================================
# BindModal — Modal behavior binding (scroll lock, focus trap, dismiss)
# ============================================================================

"""
    BindModal(getter, mode)

A modal behavior binding that manages scroll lock, focus trap, dismiss handlers,
and show/hide with animation when a signal changes.

When the signal transitions to 1 (open): lock scroll, install focus guards,
focus first tabbable element, install Escape/click-outside dismiss handlers.
When the signal transitions to 0 (close): unlock scroll, uninstall focus guards,
hide elements after close animation, return focus to trigger.

`mode` controls dismiss behavior:
- `Int32(0)` = dialog: Escape key and click-outside dismiss
- `Int32(1)` = alert_dialog: no Escape, no click-outside dismiss

Used in @island components for Dialog, AlertDialog, Sheet, Drawer, etc.

# Examples
```julia
is_open, set_open = create_signal(Int32(0))
Div(
    Symbol("data-modal") => BindModal(is_open, Int32(0)),  # dialog mode
    # ... dialog content ...
)
```
"""
struct BindModal
    getter::Any      # Signal getter (SignalGetter or Function)
    mode::Int32      # 0=dialog (Escape+outside dismiss), 1=alert_dialog (no dismiss)
end

# For SSR: renders as empty string (marker prop, no visible value)
Base.string(b::BindModal) = ""
Base.print(io::IO, b::BindModal) = print(io, "")

# ============================================================================
# ShowDescendants — Signal-driven show/hide binding for descendants
# ============================================================================

"""
    ShowDescendants(getter)

A signal-driven binding that toggles `display` and `data-state` on descendant
elements when the signal value changes.

When signal transitions to 1 (open): sets `data-state="open"` and removes
`display:none` on all descendants with `[data-state]`.
When signal transitions to 0 (close): sets `data-state="closed"` and restores
`display:none` after CSS close animation (300ms timeout or animationend).

Replaces BindModal for visual toggle. Behavioral logic (scroll lock, focus
management, Escape dismiss) is handled inline in trigger @island bodies.

# Examples
```julia
is_open, set_open = create_signal(Int32(0))
Div(Symbol("data-show") => ShowDescendants(is_open),
    children...)
```
"""
struct ShowDescendants
    getter::Any  # Signal getter (SignalGetter or Function)
end

# For SSR: renders as empty string (marker prop, no visible value)
Base.string(b::ShowDescendants) = ""
Base.print(io::IO, b::ShowDescendants) = print(io, "")

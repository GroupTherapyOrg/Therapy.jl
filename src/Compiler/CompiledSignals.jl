# CompiledSignals.jl - Signal compilation primitives for Leptos-style full-body compilation
#
# Maps create_signal() calls to Wasm globals via WasmGlobal{T, IDX}.
# Builds dom_bindings spec for trigger_bindings auto-injection after global.set.
#
# Design: ralph_loops/research/therapy/compiled-signals-protocol.md (THERAPY-3104)
# Implementation: THERAPY-3107

using WasmTarget: WasmGlobal

# ─── Import Indices (frozen) ───
const IMPORT_SET_DATA_STATE_BOOL = UInt32(53)
const IMPORT_SET_ARIA_BOOL       = UInt32(54)
const IMPORT_MODAL_STATE         = UInt32(55)
const IMPORT_TRIGGER_BINDINGS    = UInt32(66)
const IMPORT_GET_PROP_COUNT      = UInt32(67)
const IMPORT_GET_PROP_I32        = UInt32(68)
const IMPORT_GET_PROP_F64        = UInt32(69)
const IMPORT_GET_PROP_STRING_ID  = UInt32(70)

# ─── Signal Allocator ───

"""
    SignalAllocator

Tracks Wasm global index allocation for compiled signals.
Position global is always index 0; signal globals start at index 1.
"""
mutable struct SignalAllocator
    next_index::Int32
    signals::Vector{NamedTuple{(:index, :type, :initial), Tuple{Int32, Type, Any}}}
end

"""
    SignalAllocator()

Create a new allocator. Global 0 is reserved for cursor position.
"""
SignalAllocator() = SignalAllocator(Int32(1), [])

"""
    allocate_signal!(alloc::SignalAllocator, T::Type, initial) -> Int32

Allocate a Wasm global for a signal and return its global index.
"""
function allocate_signal!(alloc::SignalAllocator, T::Type, initial)::Int32
    idx = alloc.next_index
    push!(alloc.signals, (index=idx, type=T, initial=initial))
    alloc.next_index += Int32(1)
    return idx
end

"""
    signal_count(alloc::SignalAllocator) -> Int

Number of signals allocated (not counting position global).
"""
signal_count(alloc::SignalAllocator) = length(alloc.signals)

"""
    total_globals(alloc::SignalAllocator) -> Int

Total globals needed (1 position + N signals).
"""
total_globals(alloc::SignalAllocator) = 1 + signal_count(alloc)

# ─── DOM Bindings Builder ───

"""
    DOMBindingEntry

One auto-injected import call after a global.set.
"""
struct DOMBindingEntry
    import_idx::UInt32
    const_args::Vector{Int32}
end

"""
    build_dom_bindings(alloc::SignalAllocator) -> Dict{UInt32, Vector{DOMBindingEntry}}

Build the dom_bindings specification for WasmTarget's auto-injection.
For each signal at global index G, auto-inject trigger_bindings(G, new_value)
after every global.set G.
"""
function build_dom_bindings(alloc::SignalAllocator)::Dict{UInt32, Vector{DOMBindingEntry}}
    bindings = Dict{UInt32, Vector{DOMBindingEntry}}()
    for sig in alloc.signals
        G = UInt32(sig.index)
        bindings[G] = [DOMBindingEntry(IMPORT_TRIGGER_BINDINGS, Int32[sig.index])]
    end
    return bindings
end

"""
    add_bool_binding!(bindings, signal_idx::Int32, hk::Int32, mode::Int32)

Add a BindBool data-state binding to a signal's dom_bindings.
Uses existing import 53 (set_data_state_bool).
"""
function add_bool_binding!(bindings::Dict{UInt32, Vector{DOMBindingEntry}},
                          signal_idx::Int32, hk::Int32, mode::Int32)
    G = UInt32(signal_idx)
    if !haskey(bindings, G)
        bindings[G] = DOMBindingEntry[]
    end
    push!(bindings[G], DOMBindingEntry(IMPORT_SET_DATA_STATE_BOOL, Int32[hk, mode]))
end

"""
    add_aria_binding!(bindings, signal_idx::Int32, hk::Int32, attr_code::Int32)

Add a BindBool aria binding to a signal's dom_bindings.
Uses existing import 54 (set_aria_bool).
"""
function add_aria_binding!(bindings::Dict{UInt32, Vector{DOMBindingEntry}},
                          signal_idx::Int32, hk::Int32, attr_code::Int32)
    G = UInt32(signal_idx)
    if !haskey(bindings, G)
        bindings[G] = DOMBindingEntry[]
    end
    push!(bindings[G], DOMBindingEntry(IMPORT_SET_ARIA_BOOL, Int32[hk, attr_code]))
end

"""
    add_modal_binding!(bindings, signal_idx::Int32, hk::Int32, mode::Int32)

Add a BindModal binding to a signal's dom_bindings.
Uses existing import 55 (modal_state).
"""
function add_modal_binding!(bindings::Dict{UInt32, Vector{DOMBindingEntry}},
                           signal_idx::Int32, hk::Int32, mode::Int32)
    G = UInt32(signal_idx)
    if !haskey(bindings, G)
        bindings[G] = DOMBindingEntry[]
    end
    push!(bindings[G], DOMBindingEntry(IMPORT_MODAL_STATE, Int32[hk, mode]))
end

# ─── Globals Spec Builder ───

"""
    build_globals_spec(alloc::SignalAllocator) -> Vector{Tuple{Type, Any}}

Build the globals specification for compile_module.
Returns (Type, initial_value) pairs in order: [position, signal_1, signal_2, ...].
Global 0 is always the cursor position (Int32, initial=FIRST_CHILD=1).
"""
function build_globals_spec(alloc::SignalAllocator)::Vector{Tuple{Type, Any}}
    specs = Tuple{Type, Any}[]
    # Global 0: cursor position
    push!(specs, (Int32, Int32(1)))  # POSITION_FIRST_CHILD
    # Globals 1..N: signals
    for sig in alloc.signals
        T = sig.type === Bool ? Int32 : sig.type
        push!(specs, (T, signal_initial_value(sig.type, sig.initial)))
    end
    return specs
end

# ─── DOM Bindings Format Conversion ───

"""
    convert_dom_bindings_to_internal(bindings) -> Dict{UInt32, Vector{Tuple{UInt32, Vector{Int32}}}}

Convert DOMBindingEntry format to WasmTarget's internal dom_bindings format.
Used by compile_island_body (THERAPY-3110) to pass bindings to compile_handler/compile_closure_body.
"""
function convert_dom_bindings_to_internal(
    bindings::Dict{UInt32, Vector{DOMBindingEntry}}
)::Dict{UInt32, Vector{Tuple{UInt32, Vector{Int32}}}}
    result = Dict{UInt32, Vector{Tuple{UInt32, Vector{Int32}}}}()
    for (g, entries) in bindings
        result[g] = [(e.import_idx, e.const_args) for e in entries]
    end
    return result
end

# ─── Type Mapping ───

"""
Supported Wasm types for signal globals (Phase 1).
"""
const SIGNAL_WASM_TYPES = Dict{Type, Symbol}(
    Int32   => :i32,
    Int64   => :i64,
    Float32 => :f32,
    Float64 => :f64,
    Bool    => :i32,  # Bool encoded as i32 (0/1)
)

"""
    is_wasm_compatible_signal_type(T::Type) -> Bool

Check if a Julia type can be used as a Wasm signal global.
"""
is_wasm_compatible_signal_type(T::Type) = haskey(SIGNAL_WASM_TYPES, T)

"""
    signal_initial_value(T::Type, val) -> Any

Convert an initial value to the correct Wasm-compatible type.
"""
function signal_initial_value(T::Type, val)
    if T === Bool
        return Int32(val ? 1 : 0)
    end
    return T(val)
end

# ─── Signal Helper Functions for Compilation ───

"""
    SIGNAL_HELPER_FUNCTIONS

Helper functions that demonstrate signal read/write patterns for WasmTarget compilation.
These serve as reference implementations and compilation validation targets.
The actual signal functions in compiled islands are generated per-component by the AST
transform (THERAPY-3111), with explicit trigger_bindings calls after each signal write.
"""

"""
    compiled_signal_read_i32(position::WasmGlobal{Int32,0}, signal::WasmGlobal{Int32,1}) -> Int32

Read an Int32 signal global. Compiles to global.get.
"""
function compiled_signal_read_i32(position::WasmGlobal{Int32, 0}, signal::WasmGlobal{Int32, 1})::Int32
    return signal[]
end

"""
    compiled_signal_write_i32(position::WasmGlobal{Int32,0}, signal::WasmGlobal{Int32,1}, value::Int32) -> Nothing

Write an Int32 signal global and trigger DOM bindings.
Compiles to global.set + call trigger_bindings.
"""
function compiled_signal_write_i32(position::WasmGlobal{Int32, 0}, signal::WasmGlobal{Int32, 1}, value::Int32)::Nothing
    signal[] = value
    compiled_trigger_bindings(Int32(1), value)
    return nothing
end

"""
    compiled_signal_increment_i32(position::WasmGlobal{Int32,0}, signal::WasmGlobal{Int32,1}) -> Nothing

Increment an Int32 signal global by 1 and trigger DOM bindings.
This is the pattern used by Counter increment handlers.
"""
function compiled_signal_increment_i32(position::WasmGlobal{Int32, 0}, signal::WasmGlobal{Int32, 1})::Nothing
    new_val = signal[] + Int32(1)
    signal[] = new_val
    compiled_trigger_bindings(Int32(1), new_val)
    return nothing
end

"""
    compiled_signal_toggle_i32(position::WasmGlobal{Int32,0}, signal::WasmGlobal{Int32,1}) -> Nothing

Toggle an Int32 signal global between 0 and 1, then trigger DOM bindings.
This is the pattern used by boolean toggle handlers (Switch, Dialog open/close).
"""
function compiled_signal_toggle_i32(position::WasmGlobal{Int32, 0}, signal::WasmGlobal{Int32, 1})::Nothing
    new_val = Int32(1) - signal[]
    signal[] = new_val
    compiled_trigger_bindings(Int32(1), new_val)
    return nothing
end

# ─── Props Deserialization Stubs ───
# Import stubs for Wasm prop getter imports (67-70).
# These are registered at their import indices during compilation.

@noinline compiled_get_prop_count()::Int32 = _STUB_I32[]                         # import 67
@noinline compiled_get_prop_i32(idx::Int32)::Int32 = (_STUB_I32[] = idx; _STUB_I32[])   # import 68
@noinline compiled_get_prop_f64(idx::Int32)::Float64 = (_STUB_I32[] = idx; Float64(_STUB_I32[]))  # import 69
@noinline compiled_get_prop_string_id(idx::Int32)::Int32 = (_STUB_I32[] = idx; _STUB_I32[])  # import 70

# ─── Props Import Stub Registry ───

const PROPS_IMPORT_STUBS = ImportStubEntry[
    ImportStubEntry(compiled_get_prop_count,     "compiled_get_prop_count",     UInt32(67), (),       Int32),
    ImportStubEntry(compiled_get_prop_i32,       "compiled_get_prop_i32",       UInt32(68), (Int32,), Int32),
    ImportStubEntry(compiled_get_prop_f64,       "compiled_get_prop_f64",       UInt32(69), (Int32,), Float64),
    ImportStubEntry(compiled_get_prop_string_id, "compiled_get_prop_string_id", UInt32(70), (Int32,), Int32),
]

# ─── Props Spec Builder ───

"""
    PropsSpec

Compile-time specification of island props for Wasm compilation.
Props are sorted alphabetically by name; Wasm reads by index.
"""
struct PropsSpec
    names::Vector{Symbol}     # Alphabetically sorted
    types::Vector{Type}       # Wasm-compatible types
    defaults::Vector{Any}     # Default values (for SSR)
end

PropsSpec() = PropsSpec(Symbol[], Type[], Any[])

"""
    add_prop!(spec::PropsSpec, name::Symbol, T::Type, default)

Add a prop to the spec. Call in alphabetical order by name.
"""
function add_prop!(spec::PropsSpec, name::Symbol, T::Type, default)
    push!(spec.names, name)
    push!(spec.types, T)
    push!(spec.defaults, default)
end

"""
    build_props_spec(kwargs::Dict{Symbol, Any}) -> PropsSpec

Build a PropsSpec from island keyword arguments.
Sorts alphabetically and infers Wasm-compatible types.
"""
function build_props_spec(kwargs::Dict{Symbol, Any})::PropsSpec
    spec = PropsSpec()
    for name in sort(collect(keys(kwargs)), by=string)
        val = kwargs[name]
        T = _infer_prop_type(val)
        add_prop!(spec, name, T, val)
    end
    return spec
end

"""
    prop_index(spec::PropsSpec, name::Symbol) -> Int

Get the alphabetical index (0-based) of a prop by name.
Returns -1 if not found.
"""
function prop_index(spec::PropsSpec, name::Symbol)::Int
    idx = findfirst(==(name), spec.names)
    return idx === nothing ? -1 : idx - 1
end

# Infer Wasm-compatible type from a Julia value
function _infer_prop_type(val)
    # Bool must come before Integer since Bool <: Integer in Julia
    if val isa Bool
        return Bool
    elseif val isa Int32
        return Int32
    elseif val isa Integer
        return Int32  # Wrap to Int32 for Wasm
    elseif val isa Float64
        return Float64
    elseif val isa AbstractFloat
        return Float64
    elseif val isa AbstractString
        return String
    else
        return Int32  # Default to Int32
    end
end

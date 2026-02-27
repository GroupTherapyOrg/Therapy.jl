# CompiledElements.jl - Hydration element helpers for Leptos-style full-body compilation
#
# These Julia functions compile to Wasm via compile_module. They use WasmGlobal for
# position state and call import stubs that resolve to import indices during compilation.
#
# Design: ralph_loops/research/therapy/compiled-element-protocol.md (THERAPY-3103)
# Implementation: THERAPY-3106

using WasmTarget: WasmGlobal

# ─── Cursor Position Constants ───
const POSITION_CURRENT     = Int32(0)
const POSITION_FIRST_CHILD = Int32(1)
const POSITION_NEXT_CHILD  = Int32(2)

# ─── Event Type Constants ───
# Indices into _CURSOR_EVENT_NAMES JS array (from Hydration.jl)
const EVENT_CLICK       = Int32(0)
const EVENT_INPUT       = Int32(1)
const EVENT_CHANGE      = Int32(2)
const EVENT_KEYDOWN     = Int32(3)
const EVENT_KEYUP       = Int32(4)
const EVENT_POINTERDOWN = Int32(5)
const EVENT_POINTERMOVE = Int32(6)
const EVENT_POINTERUP   = Int32(7)
const EVENT_FOCUS       = Int32(8)
const EVENT_BLUR        = Int32(9)
const EVENT_SUBMIT      = Int32(10)
const EVENT_DBLCLICK    = Int32(11)
const EVENT_CONTEXTMENU = Int32(12)

# ─── Import Stubs ───
# These are registered in func_registry at their import indices during compilation.
# When helper functions call these, the compiler emits `call <import_idx>`.
#
# CRITICAL: Stubs must be opaque to Julia's optimizer (use Ref reads/writes).
# Without opacity, Julia constant-folds the return values or removes void calls,
# and the calls never appear in the IR for WasmTarget to resolve.
const _STUB_VOID = Ref{Nothing}(nothing)   # Side-effect barrier for void stubs
const _STUB_I32  = Ref{Int32}(Int32(0))    # Side-effect barrier for i32 stubs

@noinline compiled_cursor_child()::Nothing = (_STUB_VOID[] = nothing; nothing)                          # import 56
@noinline compiled_cursor_sibling()::Nothing = (_STUB_VOID[] = nothing; nothing)                        # import 57
@noinline compiled_cursor_parent()::Nothing = (_STUB_VOID[] = nothing; nothing)                         # import 58
@noinline compiled_cursor_current()::Int32 = _STUB_I32[]                                                # import 59
@noinline compiled_cursor_set(el::Int32)::Nothing = (_STUB_I32[] = el; nothing)                         # import 60
@noinline compiled_cursor_skip_children()::Nothing = (_STUB_VOID[] = nothing; nothing)                  # import 61
@noinline compiled_add_event_listener(el::Int32, event_type::Int32, handler_idx::Int32)::Nothing = (_STUB_I32[] = el; nothing)  # import 62
@noinline compiled_register_text_binding(el::Int32, signal_idx::Int32)::Nothing = (_STUB_I32[] = el; nothing)                   # import 63
@noinline compiled_register_visibility_binding(el::Int32, signal_idx::Int32)::Nothing = (_STUB_I32[] = el; nothing)             # import 64
@noinline compiled_register_attribute_binding(el::Int32, attr_id::Int32, signal_idx::Int32)::Nothing = (_STUB_I32[] = el; nothing)  # import 65
@noinline compiled_trigger_bindings(signal_idx::Int32, value::Int32)::Nothing = (_STUB_I32[] = signal_idx; nothing)             # import 66

# ─── Import Stub Registry ───
# Maps each stub function to its import index, argument types, and return type.
# Used by compile_island_body (THERAPY-3110) to pre-register in func_registry.

struct ImportStubEntry
    func::Function
    name::String
    import_idx::UInt32
    arg_types::Tuple
    return_type::Type
end

const HYDRATION_IMPORT_STUBS = ImportStubEntry[
    ImportStubEntry(compiled_cursor_child,                "compiled_cursor_child",                UInt32(56), (),                      Nothing),
    ImportStubEntry(compiled_cursor_sibling,              "compiled_cursor_sibling",              UInt32(57), (),                      Nothing),
    ImportStubEntry(compiled_cursor_parent,               "compiled_cursor_parent",               UInt32(58), (),                      Nothing),
    ImportStubEntry(compiled_cursor_current,              "compiled_cursor_current",              UInt32(59), (),                      Int32),
    ImportStubEntry(compiled_cursor_set,                  "compiled_cursor_set",                  UInt32(60), (Int32,),                Nothing),
    ImportStubEntry(compiled_cursor_skip_children,        "compiled_cursor_skip_children",        UInt32(61), (),                      Nothing),
    ImportStubEntry(compiled_add_event_listener,          "compiled_add_event_listener",          UInt32(62), (Int32, Int32, Int32),   Nothing),
    ImportStubEntry(compiled_register_text_binding,       "compiled_register_text_binding",       UInt32(63), (Int32, Int32),          Nothing),
    ImportStubEntry(compiled_register_visibility_binding, "compiled_register_visibility_binding", UInt32(64), (Int32, Int32),          Nothing),
    ImportStubEntry(compiled_register_attribute_binding,  "compiled_register_attribute_binding",  UInt32(65), (Int32, Int32, Int32),   Nothing),
    ImportStubEntry(compiled_trigger_bindings,            "compiled_trigger_bindings",            UInt32(66), (Int32, Int32),          Nothing),
]

# ─── Helper Functions ───
# These are compiled alongside the island body into the same Wasm module.
# They call import stubs which resolve to actual import calls during compilation.

"""
    hydrate_element_open(position::WasmGlobal{Int32, 0}) -> Int32

Navigate cursor to next element based on position state, register it, set position for children.
Returns element registry ID.

NOTE: Uses flattened if/elseif/else with return in each branch to work around
WasmTarget codegen bug where void calls in if-blocks before a non-void return
produce invalid stack heights.
"""
function hydrate_element_open(position::WasmGlobal{Int32, 0})::Int32
    pos = position[]
    if pos == POSITION_CURRENT
        # No navigation — cursor already at correct node (hydrate entry)
        el = compiled_cursor_current()
        position[] = POSITION_FIRST_CHILD
        return el
    elseif pos == POSITION_FIRST_CHILD
        compiled_cursor_child()
        el = compiled_cursor_current()
        position[] = POSITION_FIRST_CHILD
        return el
    else
        # POSITION_NEXT_CHILD or any other value
        compiled_cursor_sibling()
        el = compiled_cursor_current()
        position[] = POSITION_FIRST_CHILD
        return el
    end
end

"""
    hydrate_element_close(position::WasmGlobal{Int32, 0}, el::Int32) -> Nothing

Reset cursor back to element, set position to NEXT_CHILD (sibling expected).
"""
function hydrate_element_close(position::WasmGlobal{Int32, 0}, el::Int32)::Nothing
    compiled_cursor_set(el)
    position[] = POSITION_NEXT_CHILD
    return nothing
end

"""
    hydrate_add_listener(el::Int32, event_type::Int32, handler_idx::Int32) -> Nothing

Attach event listener to element during cursor walk.
"""
function hydrate_add_listener(el::Int32, event_type::Int32, handler_idx::Int32)::Nothing
    compiled_add_event_listener(el, event_type, handler_idx)
    return nothing
end

"""
    hydrate_text_binding(el::Int32, signal_global_idx::Int32) -> Nothing

Register a text content binding between element and signal global.
"""
function hydrate_text_binding(el::Int32, signal_global_idx::Int32)::Nothing
    compiled_register_text_binding(el, signal_global_idx)
    return nothing
end

"""
    hydrate_visibility_binding(el::Int32, signal_global_idx::Int32) -> Nothing

Register a visibility (Show) binding between element and signal global.
"""
function hydrate_visibility_binding(el::Int32, signal_global_idx::Int32)::Nothing
    compiled_register_visibility_binding(el, signal_global_idx)
    return nothing
end

"""
    hydrate_attribute_binding(el::Int32, attr_id::Int32, signal_global_idx::Int32) -> Nothing

Register an attribute binding between element, attribute, and signal global.
"""
function hydrate_attribute_binding(el::Int32, attr_id::Int32, signal_global_idx::Int32)::Nothing
    compiled_register_attribute_binding(el, attr_id, signal_global_idx)
    return nothing
end

# ─── Helper Function Registry ───
# List of helper functions with their signatures, for compile_island_body (THERAPY-3110).

struct HelperFunctionEntry
    func::Function
    name::String
    arg_types::Tuple
end

const HYDRATION_HELPER_FUNCTIONS = HelperFunctionEntry[
    HelperFunctionEntry(hydrate_element_open,        "hydrate_element_open",        (WasmGlobal{Int32, 0},)),
    HelperFunctionEntry(hydrate_element_close,        "hydrate_element_close",       (WasmGlobal{Int32, 0}, Int32)),
    HelperFunctionEntry(hydrate_add_listener,         "hydrate_add_listener",        (Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_text_binding,          "hydrate_text_binding",        (Int32, Int32)),
    HelperFunctionEntry(hydrate_visibility_binding,    "hydrate_visibility_binding",  (Int32, Int32)),
    HelperFunctionEntry(hydrate_attribute_binding,     "hydrate_attribute_binding",   (Int32, Int32, Int32)),
]

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
const EVENT_CLICK        = Int32(0)
const EVENT_INPUT        = Int32(1)
const EVENT_CHANGE       = Int32(2)
const EVENT_KEYDOWN      = Int32(3)
const EVENT_KEYUP        = Int32(4)
const EVENT_POINTERDOWN  = Int32(5)
const EVENT_POINTERMOVE  = Int32(6)
const EVENT_POINTERUP    = Int32(7)
const EVENT_FOCUS        = Int32(8)
const EVENT_BLUR         = Int32(9)
const EVENT_SUBMIT       = Int32(10)
const EVENT_DBLCLICK     = Int32(11)
const EVENT_CONTEXTMENU  = Int32(12)
const EVENT_POINTERENTER = Int32(13)
const EVENT_POINTERLEAVE = Int32(14)
const EVENT_DISMISS      = Int32(15)  # No DOM binding — DismissableLayer only

# ─── Import Stubs ───
# These are registered in func_registry at their import indices during compilation.
# When helper functions call these, the compiler emits `call <import_idx>`.
#
# CRITICAL: Stubs must be opaque to Julia's optimizer (use Ref reads/writes).
# Without opacity, Julia constant-folds the return values or removes void calls,
# and the calls never appear in the IR for WasmTarget to resolve.
const _STUB_VOID = Ref{Nothing}(nothing)   # Side-effect barrier for void stubs
const _STUB_I32  = Ref{Int32}(Int32(0))    # Side-effect barrier for i32 stubs
const _STUB_F64  = Ref{Float64}(0.0)       # Side-effect barrier for f64 stubs

# ─── DOM Update Import Stubs (imports 0, 15-16) ───
# update_text: set element's textContent to a numeric value (f64)
@noinline compiled_update_text(el::Int32, v::Float64)::Nothing = (_STUB_I32[] = el; _STUB_F64[] = v; nothing)  # import 0
# show_element: set element's display to '' (visible)
@noinline compiled_show_element(el::Int32)::Nothing = (_STUB_I32[] = el; nothing)                               # import 15
# hide_element: set element's display to 'none'
@noinline compiled_hide_element(el::Int32)::Nothing = (_STUB_I32[] = el; nothing)                               # import 16

# ─── Event Getter Import Stubs (existing T30 imports 34-40) ───
# These are registered in func_registry so handler bodies can call them.
@noinline compiled_get_key_code()::Int32 = _STUB_I32[]                                                    # import 34
@noinline compiled_get_modifiers()::Int32 = _STUB_I32[]                                                   # import 35
@noinline compiled_get_pointer_x()::Float64 = _STUB_F64[]                                                 # import 36
@noinline compiled_get_pointer_y()::Float64 = _STUB_F64[]                                                 # import 37
@noinline compiled_get_pointer_id()::Int32 = _STUB_I32[]                                                  # import 38
@noinline compiled_get_target_value_f64()::Float64 = _STUB_F64[]                                          # import 39
@noinline compiled_get_target_checked()::Int32 = _STUB_I32[]                                              # import 40

# ─── T31 Cursor/Binding Import Stubs (56-66) ───
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

# ─── BindBool/BindModal Import Stubs (71-73) ───
@noinline compiled_register_data_state_binding(el::Int32, signal_idx::Int32, mode::Int32)::Nothing = (_STUB_I32[] = el; nothing)   # import 71
@noinline compiled_register_aria_binding(el::Int32, signal_idx::Int32, attr_code::Int32)::Nothing = (_STUB_I32[] = el; nothing)    # import 72
@noinline compiled_register_modal_binding(el::Int32, signal_idx::Int32, mode::Int32)::Nothing = (_STUB_I32[] = el; nothing)        # import 73

# ─── Per-Child Pattern Import Stubs (74-75) ───
@noinline compiled_get_event_data_index()::Int32 = _STUB_I32[]                                                                     # import 74
@noinline compiled_register_match_binding(el::Int32, signal_idx::Int32, match_value::Int32)::Nothing = (_STUB_I32[] = el; nothing)  # import 75

# ─── Per-Child Match/Bit State Binding Import Stubs (76-79) ───
@noinline compiled_register_match_data_state_binding(el::Int32, signal_idx::Int32, match_value::Int32, mode::Int32)::Nothing = (_STUB_I32[] = el; nothing)  # import 76
@noinline compiled_register_match_aria_binding(el::Int32, signal_idx::Int32, match_value::Int32, attr_code::Int32)::Nothing = (_STUB_I32[] = el; nothing)   # import 77
@noinline compiled_register_bit_data_state_binding(el::Int32, signal_idx::Int32, bit_index::Int32, mode::Int32)::Nothing = (_STUB_I32[] = el; nothing)      # import 78
@noinline compiled_register_bit_aria_binding(el::Int32, signal_idx::Int32, bit_index::Int32, attr_code::Int32)::Nothing = (_STUB_I32[] = el; nothing)       # import 79

# ─── Storage/Dark Mode Import Stubs (2, 41-42) ───
# These exist in the T30 import table but need compiled stubs for the new pipeline.
@noinline compiled_set_dark_mode(value::Float64)::Nothing = (_STUB_F64[] = value; nothing)               # import 2
@noinline compiled_storage_get_i32(key::Int32)::Int32 = (_STUB_I32[] = key; _STUB_I32[])                 # import 41
@noinline compiled_storage_set_i32(key::Int32, value::Int32)::Nothing = (_STUB_I32[] = key; nothing)     # import 42

# ─── Clipboard Import Stub (43) ───
# copy_to_clipboard(string_id) → void: copy string from string table to clipboard
@noinline compiled_copy_to_clipboard(string_id::Int32)::Nothing = (_STUB_I32[] = string_id; nothing)     # import 43

# ─── Timer Import Stubs (48-49) ───
# set_timeout(handler_idx, ms) → timer_id; clear_timeout(timer_id) → void
@noinline compiled_set_timeout(handler_idx::Int32, ms::Int32)::Int32 = (_STUB_I32[] = handler_idx; _STUB_I32[])  # import 48
@noinline compiled_clear_timeout(timer_id::Int32)::Nothing = (_STUB_I32[] = timer_id; nothing)                    # import 49

# ─── Escape Dismiss Import Stubs (80-81) — Phase 6, Thaw-style ───
# push_escape_handler(handler_idx) → void: register Escape key handler on stack
# pop_escape_handler() → void: remove topmost Escape handler from stack
@noinline compiled_push_escape_handler(handler_idx::Int32)::Nothing = (_STUB_I32[] = handler_idx; nothing)  # import 80
@noinline compiled_pop_escape_handler()::Nothing = (_STUB_VOID[] = nothing; nothing)                         # import 81

# ─── Click-Outside Dismiss Import Stubs (82-83) — Phase 6, Thaw-style ───
# add_click_outside_listener(el_id, handler_idx) → void: listen for clicks outside element
# remove_click_outside_listener(el_id) → void: clean up listener
@noinline compiled_add_click_outside_listener(el_id::Int32, handler_idx::Int32)::Nothing = (_STUB_I32[] = el_id; nothing)  # import 82
@noinline compiled_remove_click_outside_listener(el_id::Int32)::Nothing = (_STUB_I32[] = el_id; nothing)                   # import 83

# ─── Scroll Lock Import Stubs (25-26) — T30 imports, Phase 6 stub wiring ───
# lock_scroll() → void: set body overflow hidden
# unlock_scroll() → void: restore body overflow
@noinline compiled_lock_scroll()::Nothing = (_STUB_VOID[] = nothing; nothing)      # import 25
@noinline compiled_unlock_scroll()::Nothing = (_STUB_VOID[] = nothing; nothing)    # import 26

# ─── Focus Management Import Stubs (21, 84-85) — Phase 6, modal focus ───
# focus_first_tabbable(el_id) → void: focus first focusable child element
@noinline compiled_focus_first_tabbable(el_id::Int32)::Nothing = (_STUB_I32[] = el_id; nothing)  # import 21
# store_active_element() → void: save current document.activeElement
# restore_active_element() → void: restore previously saved element focus
@noinline compiled_store_active_element()::Nothing = (_STUB_VOID[] = nothing; nothing)    # import 84
@noinline compiled_restore_active_element()::Nothing = (_STUB_VOID[] = nothing; nothing)  # import 85

# ─── ShowDescendants + Event Delegation Import Stubs (86-88) — Phase 7 ───
# show_descendants(el_id, signal_idx) → void: register binding to toggle display + data-state on descendants
@noinline compiled_show_descendants(el_id::Int32, signal_idx::Int32)::Nothing = (_STUB_I32[] = el_id + signal_idx; nothing)  # import 86
# get_event_closest_role() → i32: read data-role from event target or closest ancestor
@noinline compiled_get_event_closest_role()::Int32 = (_STUB_I32[] = Int32(0); _STUB_I32[])  # import 87
# get_parent_island_root() → i32: find parent therapy-island's root element, return ID
@noinline compiled_get_parent_island_root()::Int32 = (_STUB_I32[] = Int32(-1); _STUB_I32[])  # import 88

# ─── Auto-Register Descendants Import Stubs (90-91) — T32 ───
# register_match_descendants(signal_idx, mode) → void: walk DOM, register match bindings on [data-index] elements
# register_bit_descendants(signal_idx, mode) → void: walk DOM, register bit bindings on [data-index] elements
@noinline compiled_register_match_descendants(signal_idx::Int32, mode::Int32)::Nothing = (_STUB_I32[] = signal_idx + mode; nothing)  # import 90
@noinline compiled_register_bit_descendants(signal_idx::Int32, mode::Int32)::Nothing = (_STUB_I32[] = signal_idx + mode; nothing)    # import 91

# ─── Theme State Query Import Stub (92) ───
# get_is_dark_mode() → i32: read current dark mode state (localStorage + system preference)
@noinline compiled_get_is_dark_mode()::Int32 = _STUB_I32[]                                                                          # import 92

# ─── DismissableLayer Import Stubs (93-94) — Radix-style dismiss layer stack ───
# push_dismiss_layer(el_id, handler_idx) → void: register dismiss layer (click-outside + focus save)
# pop_dismiss_layer() → void: remove topmost dismiss layer (restore focus)
@noinline compiled_push_dismiss_layer(el_id::Int32, handler_idx::Int32)::Nothing = (_STUB_I32[] = el_id; nothing)  # import 93
@noinline compiled_pop_dismiss_layer()::Nothing = (_STUB_VOID[] = nothing; nothing)                                 # import 94

# ─── Elements Count Query Import Stub (95) ───
# get_elements_count() → i32: returns current state.elements.length
@noinline compiled_get_elements_count()::Int32 = _STUB_I32[]                                                   # import 95

# ─── Pointer Capture/Drag Import Stubs (44-47) ───
# These imports exist in the import table but lacked compiled stubs.
@noinline compiled_capture_pointer(el::Int32)::Nothing = (_STUB_I32[] = el; nothing)                            # import 44
@noinline compiled_release_pointer(el::Int32)::Nothing = (_STUB_I32[] = el; nothing)                            # import 45
@noinline compiled_get_bounding_rect_x(el::Int32)::Float64 = (_STUB_I32[] = el; _STUB_F64[])                   # import 28
@noinline compiled_get_bounding_rect_w(el::Int32)::Float64 = (_STUB_I32[] = el; _STUB_F64[])                   # import 30
@noinline compiled_get_drag_delta_x()::Float64 = _STUB_F64[]                                                    # import 46
@noinline compiled_get_drag_delta_y()::Float64 = _STUB_F64[]                                                    # import 47

# ─── Style Percent/Numeric Import Stubs (96-97) ───
# set_style_percent(el, prop, value): el.style[PROPS[prop]] = value + '%'
#   PROPS = [left, top, width, height, bottom, right]
@noinline compiled_set_style_percent(el::Int32, prop::Int32, value::Float64)::Nothing = (_STUB_I32[] = el; _STUB_F64[] = value; nothing)  # import 96
# set_style_numeric(el, prop, value): el.style[PROPS[prop]] = String(value)
#   PROPS = [flexGrow, opacity]
@noinline compiled_set_style_numeric(el::Int32, prop::Int32, value::Float64)::Nothing = (_STUB_I32[] = el; _STUB_F64[] = value; nothing)  # import 97

# ─── Focus Trap Import Stubs (52, 89) — Phase 7, inline focus cycling ───
# prevent_default() → void: call event.preventDefault() on current event (already import 52, adding stub)
@noinline compiled_prevent_default()::Nothing = (_STUB_VOID[] = nothing; nothing)  # import 52
# cycle_focus_in_current_target(direction) → void: cycle Tab focus within event.currentTarget
# direction: 0 = forward (Tab), 1 = backward (Shift+Tab)
@noinline compiled_cycle_focus_in_current_target(direction::Int32)::Nothing = (_STUB_I32[] = direction; nothing)  # import 89

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
    # Event getter stubs (T30 imports 34-40) — for handler bodies
    ImportStubEntry(compiled_get_key_code,                "compiled_get_key_code",                UInt32(34), (),                      Int32),
    ImportStubEntry(compiled_get_modifiers,               "compiled_get_modifiers",               UInt32(35), (),                      Int32),
    ImportStubEntry(compiled_get_pointer_x,               "compiled_get_pointer_x",               UInt32(36), (),                      Float64),
    ImportStubEntry(compiled_get_pointer_y,               "compiled_get_pointer_y",               UInt32(37), (),                      Float64),
    ImportStubEntry(compiled_get_pointer_id,              "compiled_get_pointer_id",              UInt32(38), (),                      Int32),
    ImportStubEntry(compiled_get_target_value_f64,        "compiled_get_target_value_f64",        UInt32(39), (),                      Float64),
    ImportStubEntry(compiled_get_target_checked,          "compiled_get_target_checked",          UInt32(40), (),                      Int32),
    # Cursor/binding stubs (T31 imports 56-66)
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
    # BindBool/BindModal stubs (T31 imports 71-73)
    ImportStubEntry(compiled_register_data_state_binding, "compiled_register_data_state_binding", UInt32(71), (Int32, Int32, Int32),   Nothing),
    ImportStubEntry(compiled_register_aria_binding,       "compiled_register_aria_binding",       UInt32(72), (Int32, Int32, Int32),   Nothing),
    ImportStubEntry(compiled_register_modal_binding,      "compiled_register_modal_binding",      UInt32(73), (Int32, Int32, Int32),   Nothing),
    # Per-child pattern stubs (T31 imports 74-75)
    ImportStubEntry(compiled_get_event_data_index,        "compiled_get_event_data_index",        UInt32(74), (),                      Int32),
    ImportStubEntry(compiled_register_match_binding,      "compiled_register_match_binding",      UInt32(75), (Int32, Int32, Int32),   Nothing),
    # Per-child match/bit state binding stubs (T31 imports 76-79)
    ImportStubEntry(compiled_register_match_data_state_binding, "compiled_register_match_data_state_binding", UInt32(76), (Int32, Int32, Int32, Int32), Nothing),
    ImportStubEntry(compiled_register_match_aria_binding,       "compiled_register_match_aria_binding",       UInt32(77), (Int32, Int32, Int32, Int32), Nothing),
    ImportStubEntry(compiled_register_bit_data_state_binding,   "compiled_register_bit_data_state_binding",   UInt32(78), (Int32, Int32, Int32, Int32), Nothing),
    ImportStubEntry(compiled_register_bit_aria_binding,         "compiled_register_bit_aria_binding",         UInt32(79), (Int32, Int32, Int32, Int32), Nothing),
    # Storage/Dark mode stubs (T30 imports 2, 41-42) — for ThemeToggle pattern
    ImportStubEntry(compiled_set_dark_mode,               "compiled_set_dark_mode",               UInt32(2),  (Float64,),              Nothing),
    ImportStubEntry(compiled_storage_get_i32,             "compiled_storage_get_i32",             UInt32(41), (Int32,),                Int32),
    ImportStubEntry(compiled_storage_set_i32,             "compiled_storage_set_i32",             UInt32(42), (Int32, Int32),          Nothing),
    # Clipboard stub (import 43) — for CodeBlock copy button
    ImportStubEntry(compiled_copy_to_clipboard,           "compiled_copy_to_clipboard",           UInt32(43), (Int32,),                Nothing),
    # Timer stubs (T30 imports 48-49) — for set_timeout/clear_timeout in handlers
    ImportStubEntry(compiled_set_timeout,                 "compiled_set_timeout",                 UInt32(48), (Int32, Int32),          Int32),
    ImportStubEntry(compiled_clear_timeout,               "compiled_clear_timeout",               UInt32(49), (Int32,),                Nothing),
    # Escape dismiss stubs (Phase 6 imports 80-81)
    ImportStubEntry(compiled_push_escape_handler,         "compiled_push_escape_handler",         UInt32(80), (Int32,),                Nothing),
    ImportStubEntry(compiled_pop_escape_handler,          "compiled_pop_escape_handler",          UInt32(81), (),                      Nothing),
    # Click-outside dismiss stubs (Phase 6 imports 82-83)
    ImportStubEntry(compiled_add_click_outside_listener,  "compiled_add_click_outside_listener",  UInt32(82), (Int32, Int32),          Nothing),
    ImportStubEntry(compiled_remove_click_outside_listener, "compiled_remove_click_outside_listener", UInt32(83), (Int32,),             Nothing),
    # Scroll lock stubs (T30 imports 25-26, Phase 6 stub wiring)
    ImportStubEntry(compiled_lock_scroll,                 "compiled_lock_scroll",                 UInt32(25), (),                      Nothing),
    ImportStubEntry(compiled_unlock_scroll,               "compiled_unlock_scroll",               UInt32(26), (),                      Nothing),
    # Focus management stubs (imports 21, 84-85)
    ImportStubEntry(compiled_focus_first_tabbable,        "compiled_focus_first_tabbable",        UInt32(21), (Int32,),                Nothing),
    ImportStubEntry(compiled_store_active_element,        "compiled_store_active_element",        UInt32(84), (),                      Nothing),
    ImportStubEntry(compiled_restore_active_element,      "compiled_restore_active_element",      UInt32(85), (),                      Nothing),
    # ShowDescendants + event delegation stubs (Phase 7 imports 86-88)
    ImportStubEntry(compiled_show_descendants,            "compiled_show_descendants",            UInt32(86), (Int32, Int32),          Nothing),
    ImportStubEntry(compiled_get_event_closest_role,      "compiled_get_event_closest_role",      UInt32(87), (),                      Int32),
    ImportStubEntry(compiled_get_parent_island_root,      "compiled_get_parent_island_root",      UInt32(88), (),                      Int32),
    # Focus trap stubs (imports 52, 89)
    ImportStubEntry(compiled_prevent_default,             "compiled_prevent_default",             UInt32(52), (),                      Nothing),
    ImportStubEntry(compiled_cycle_focus_in_current_target, "compiled_cycle_focus_in_current_target", UInt32(89), (Int32,), Nothing),
    # Auto-register descendants stubs (T32 imports 90-91)
    ImportStubEntry(compiled_register_match_descendants,  "compiled_register_match_descendants",  UInt32(90), (Int32, Int32),          Nothing),
    ImportStubEntry(compiled_register_bit_descendants,    "compiled_register_bit_descendants",    UInt32(91), (Int32, Int32),          Nothing),
    # Theme state query stub (import 92)
    ImportStubEntry(compiled_get_is_dark_mode,            "compiled_get_is_dark_mode",            UInt32(92), (),                      Int32),
    # DismissableLayer stubs (imports 93-94)
    ImportStubEntry(compiled_push_dismiss_layer,          "compiled_push_dismiss_layer",          UInt32(93), (Int32, Int32),          Nothing),
    ImportStubEntry(compiled_pop_dismiss_layer,           "compiled_pop_dismiss_layer",           UInt32(94), (),                      Nothing),
    # Elements count query stub (import 95)
    ImportStubEntry(compiled_get_elements_count,          "compiled_get_elements_count",          UInt32(95), (),                      Int32),
    # DOM update stubs (imports 0, 15-16) — for direct element manipulation from handlers
    ImportStubEntry(compiled_update_text,                 "compiled_update_text",                 UInt32(0),  (Int32, Float64),        Nothing),
    ImportStubEntry(compiled_show_element,                "compiled_show_element",                UInt32(15), (Int32,),                Nothing),
    ImportStubEntry(compiled_hide_element,                "compiled_hide_element",                UInt32(16), (Int32,),                Nothing),
    # Pointer capture/drag stubs (imports 28, 30, 44-47)
    ImportStubEntry(compiled_capture_pointer,             "compiled_capture_pointer",             UInt32(44), (Int32,),                Nothing),
    ImportStubEntry(compiled_release_pointer,             "compiled_release_pointer",             UInt32(45), (Int32,),                Nothing),
    ImportStubEntry(compiled_get_bounding_rect_x,         "compiled_get_bounding_rect_x",         UInt32(28), (Int32,),                Float64),
    ImportStubEntry(compiled_get_bounding_rect_w,         "compiled_get_bounding_rect_w",         UInt32(30), (Int32,),                Float64),
    ImportStubEntry(compiled_get_drag_delta_x,            "compiled_get_drag_delta_x",            UInt32(46), (),                      Float64),
    ImportStubEntry(compiled_get_drag_delta_y,            "compiled_get_drag_delta_y",            UInt32(47), (),                      Float64),
    # Style percent/numeric stubs (imports 96-97)
    ImportStubEntry(compiled_set_style_percent,           "compiled_set_style_percent",           UInt32(96), (Int32, Int32, Float64), Nothing),
    ImportStubEntry(compiled_set_style_numeric,           "compiled_set_style_numeric",           UInt32(97), (Int32, Int32, Float64), Nothing),
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

"""
    hydrate_data_state_binding(el::Int32, signal_global_idx::Int32, mode::Int32) -> Nothing

Register a BindBool data-state binding. Mode: 0=closed/open, 1=off/on, 2=unchecked/checked.
"""
function hydrate_data_state_binding(el::Int32, signal_global_idx::Int32, mode::Int32)::Nothing
    compiled_register_data_state_binding(el, signal_global_idx, mode)
    return nothing
end

"""
    hydrate_aria_binding(el::Int32, signal_global_idx::Int32, attr_code::Int32) -> Nothing

Register a BindBool aria binding. attr_code: 0=pressed, 1=checked, 2=expanded, 3=selected.
"""
function hydrate_aria_binding(el::Int32, signal_global_idx::Int32, attr_code::Int32)::Nothing
    compiled_register_aria_binding(el, signal_global_idx, attr_code)
    return nothing
end

"""
    hydrate_modal_binding(el::Int32, signal_global_idx::Int32, mode::Int32) -> Nothing

Register a BindModal binding. Mode: 0=dialog, 1=sheet, 2=drawer.
"""
function hydrate_modal_binding(el::Int32, signal_global_idx::Int32, mode::Int32)::Nothing
    compiled_register_modal_binding(el, signal_global_idx, mode)
    return nothing
end

"""
    hydrate_show_descendants_binding(el::Int32, signal_global_idx::Int32) -> Nothing

Register a show_descendants binding. Toggles display + data-state on all descendants
with [data-state] when the signal value changes. Replaces BindModal for visual toggle.
"""
function hydrate_show_descendants_binding(el::Int32, signal_global_idx::Int32)::Nothing
    compiled_show_descendants(el, signal_global_idx)
    return nothing
end

"""
    hydrate_match_binding(el::Int32, signal_global_idx::Int32, match_value::Int32) -> Nothing

Register a match binding — show element when signal value equals match_value, hide otherwise.
Used for per-child patterns like Tabs (show panel when active == index).
"""
function hydrate_match_binding(el::Int32, signal_global_idx::Int32, match_value::Int32)::Nothing
    compiled_register_match_binding(el, signal_global_idx, match_value)
    return nothing
end

"""
    hydrate_match_data_state_binding(el, signal_idx, match_value, mode) -> Nothing

Register a match-based data-state binding. Updates element's data-state attribute when
signal equals match_value. Mode: 0=closed/open, 1=off/on, 2=unchecked/checked, 3=inactive/active.
Used for per-child patterns (Accordion items, Tab triggers/content).
"""
function hydrate_match_data_state_binding(el::Int32, signal_global_idx::Int32, match_value::Int32, mode::Int32)::Nothing
    compiled_register_match_data_state_binding(el, signal_global_idx, match_value, mode)
    return nothing
end

"""
    hydrate_match_aria_binding(el, signal_idx, match_value, attr_code) -> Nothing

Register a match-based aria binding. Updates aria attribute when signal equals match_value.
attr_code: 0=pressed, 1=checked, 2=expanded, 3=selected.
"""
function hydrate_match_aria_binding(el::Int32, signal_global_idx::Int32, match_value::Int32, attr_code::Int32)::Nothing
    compiled_register_match_aria_binding(el, signal_global_idx, match_value, attr_code)
    return nothing
end

"""
    hydrate_bit_data_state_binding(el, signal_idx, bit_index, mode) -> Nothing

Register a bit-based data-state binding. Updates data-state based on (signal >> bit) & 1.
Used for multi-select patterns (Accordion multiple mode, ToggleGroup multiple mode).
"""
function hydrate_bit_data_state_binding(el::Int32, signal_global_idx::Int32, bit_index::Int32, mode::Int32)::Nothing
    compiled_register_bit_data_state_binding(el, signal_global_idx, bit_index, mode)
    return nothing
end

"""
    hydrate_bit_aria_binding(el, signal_idx, bit_index, attr_code) -> Nothing

Register a bit-based aria binding. Updates aria attribute based on (signal >> bit) & 1.
"""
function hydrate_bit_aria_binding(el::Int32, signal_global_idx::Int32, bit_index::Int32, attr_code::Int32)::Nothing
    compiled_register_bit_aria_binding(el, signal_global_idx, bit_index, attr_code)
    return nothing
end

"""
    hydrate_children_slot(position::WasmGlobal{Int32, 0}) -> Nothing

Skip over a <therapy-children> element during cursor walk. Children content is opaque
to the parent island — already server-rendered in DOM, handled by child islands.
Advances cursor to the therapy-children element, then immediately closes (no descent).
"""
function hydrate_children_slot(position::WasmGlobal{Int32, 0})::Nothing
    el = hydrate_element_open(position)
    hydrate_element_close(position, el)
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
    HelperFunctionEntry(hydrate_data_state_binding,   "hydrate_data_state_binding",  (Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_aria_binding,          "hydrate_aria_binding",        (Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_modal_binding,         "hydrate_modal_binding",       (Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_show_descendants_binding, "hydrate_show_descendants_binding", (Int32, Int32)),
    HelperFunctionEntry(hydrate_match_binding,         "hydrate_match_binding",       (Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_match_data_state_binding, "hydrate_match_data_state_binding", (Int32, Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_match_aria_binding,       "hydrate_match_aria_binding",       (Int32, Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_bit_data_state_binding,   "hydrate_bit_data_state_binding",   (Int32, Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_bit_aria_binding,         "hydrate_bit_aria_binding",         (Int32, Int32, Int32, Int32)),
    HelperFunctionEntry(hydrate_children_slot,            "hydrate_children_slot",            (WasmGlobal{Int32, 0},)),
]

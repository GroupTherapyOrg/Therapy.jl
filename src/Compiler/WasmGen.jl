# WasmGen.jl - Generate WebAssembly from component analysis
#
# Uses WasmTarget.jl to compile the reactive logic to Wasm
# Now with direct IR compilation via compile_closure_body!

using WasmTarget
using WasmTarget: WasmModule, add_import!, add_function!, add_export!,
                  add_global!, add_global_export!, to_bytes,
                  compile_closure_body, TypeRegistry,
                  I32, I64, F32, F64, ExternRef, Opcode, NumType

"""
Result of Wasm generation.
"""
struct WasmOutput
    bytes::Vector{UInt8}
    exports::Vector{String}
    signal_globals::Dict{UInt64, Int}  # signal_id -> global_index
end

"""
    generate_wasm(analysis::ComponentAnalysis) -> WasmOutput

Generate WebAssembly module from component analysis.

The generated module includes:
- Globals for each signal (state)
- Getter/setter functions for each signal
- Handler functions for each event handler
- Imports for DOM manipulation
"""
function generate_wasm(analysis::ComponentAnalysis)
    mod = WasmModule()
    exports = String[]
    signal_globals = Dict{UInt64, Int}()

    # =========================================================================
    # IMPORTS - DOM manipulation functions provided by JS runtime
    # All numeric values are passed as f64 for simplicity (JS numbers are f64)
    # =========================================================================

    # Import index 0: update_text(hk: i32, value: f64) - update text content
    add_import!(mod, "dom", "update_text",
                [I32, F64], WasmTarget.NumType[])

    # Import index 1: set_visible(hk: i32, visible: f64) - show/hide element (0=hidden, 1=visible)
    add_import!(mod, "dom", "set_visible",
                [I32, F64], WasmTarget.NumType[])

    # Import index 2: set_dark_mode(enabled: f64) - toggle dark mode (0=light, 1=dark)
    add_import!(mod, "dom", "set_dark_mode",
                [F64], WasmTarget.NumType[])

    # Import index 3: send_channel(channel_id: i32, cell_id: i32) - send channel message
    # Channel IDs: 0=execute, 1=delete_cell, 2=add_cell
    # This allows islands to send messages to Therapy.jl channels
    add_import!(mod, "channel", "send",
                [I32, I32], WasmTarget.NumType[])

    # Import index 4: get_editor_code(cell_hk: i32) -> f64 - placeholder for getting editor code
    # Returns 0 for now - actual implementation requires string handling
    # TODO: Implement proper string return via externref
    add_import!(mod, "dom", "get_editor_code",
                [I32], [F64])

    # =========================================================================
    # NEW DOM BRIDGE IMPORTS (T30) — indices 5–52
    # These enable Wasm islands to manipulate classes, attributes, styles,
    # focus, scroll, geometry, events, timers, storage, and clipboard.
    # JS bridge stubs are in Hydration.jl. Import order is FROZEN.
    # =========================================================================

    # Category 1: Class manipulation (indices 5-7)
    add_import!(mod, "dom", "add_class", [I32, I32], NumType[])          # 5
    add_import!(mod, "dom", "remove_class", [I32, I32], NumType[])       # 6
    add_import!(mod, "dom", "toggle_class", [I32, I32], NumType[])       # 7

    # Category 2: Attribute operations (indices 8-9)
    add_import!(mod, "dom", "set_attribute", [I32, I32, I32], NumType[]) # 8
    add_import!(mod, "dom", "remove_attribute", [I32, I32], NumType[])   # 9

    # Category 3: Style operations (index 10)
    add_import!(mod, "dom", "set_style", [I32, I32, I32], NumType[])     # 10

    # Category 4: DOM state fast path (indices 11-12)
    add_import!(mod, "dom", "set_data_state", [I32, I32], NumType[])     # 11
    add_import!(mod, "dom", "set_data_motion", [I32, I32], NumType[])    # 12

    # Category 5: Text/content (index 13)
    add_import!(mod, "dom", "set_text_content", [I32, I32], NumType[])   # 13

    # Category 6: Property access (index 14)
    add_import!(mod, "dom", "set_hidden", [I32, I32], NumType[])         # 14

    # Category 7: Display quick access (indices 15-16)
    add_import!(mod, "dom", "show_element", [I32], NumType[])            # 15
    add_import!(mod, "dom", "hide_element", [I32], NumType[])            # 16

    # Category 8: Focus management (indices 17-24)
    add_import!(mod, "dom", "focus_element", [I32], NumType[])           # 17
    add_import!(mod, "dom", "focus_element_prevent_scroll", [I32], NumType[]) # 18
    add_import!(mod, "dom", "blur_element", [I32], NumType[])            # 19
    add_import!(mod, "dom", "get_active_element", NumType[], [I32])      # 20
    add_import!(mod, "dom", "focus_first_tabbable", [I32], NumType[])    # 21
    add_import!(mod, "dom", "focus_last_tabbable", [I32], NumType[])     # 22
    add_import!(mod, "dom", "install_focus_guards", NumType[], NumType[]) # 23
    add_import!(mod, "dom", "uninstall_focus_guards", NumType[], NumType[]) # 24

    # Category 9: Scroll management (indices 25-27)
    add_import!(mod, "dom", "lock_scroll", NumType[], NumType[])         # 25
    add_import!(mod, "dom", "unlock_scroll", NumType[], NumType[])       # 26
    add_import!(mod, "dom", "scroll_into_view", [I32], NumType[])        # 27

    # Category 10: Geometry (indices 28-33)
    add_import!(mod, "dom", "get_bounding_rect_x", [I32], [F64])        # 28
    add_import!(mod, "dom", "get_bounding_rect_y", [I32], [F64])        # 29
    add_import!(mod, "dom", "get_bounding_rect_w", [I32], [F64])        # 30
    add_import!(mod, "dom", "get_bounding_rect_h", [I32], [F64])        # 31
    add_import!(mod, "dom", "get_viewport_width", NumType[], [F64])      # 32
    add_import!(mod, "dom", "get_viewport_height", NumType[], [F64])     # 33

    # Category 11: Event property getters (indices 34-40)
    add_import!(mod, "dom", "get_key_code", NumType[], [I32])            # 34
    add_import!(mod, "dom", "get_modifiers", NumType[], [I32])           # 35
    add_import!(mod, "dom", "get_pointer_x", NumType[], [F64])           # 36
    add_import!(mod, "dom", "get_pointer_y", NumType[], [F64])           # 37
    add_import!(mod, "dom", "get_pointer_id", NumType[], [I32])          # 38
    add_import!(mod, "dom", "get_target_value_f64", NumType[], [F64])    # 39
    add_import!(mod, "dom", "get_target_checked", NumType[], [I32])      # 40

    # Category 12: Storage / clipboard (indices 41-43)
    add_import!(mod, "dom", "storage_get_i32", [I32], [I32])             # 41
    add_import!(mod, "dom", "storage_set_i32", [I32, I32], NumType[])    # 42
    add_import!(mod, "dom", "copy_to_clipboard", [I32], NumType[])       # 43

    # Category 13: Pointer capture / drag (indices 44-47)
    add_import!(mod, "dom", "capture_pointer", [I32], NumType[])         # 44
    add_import!(mod, "dom", "release_pointer", [I32], NumType[])         # 45
    add_import!(mod, "dom", "get_drag_delta_x", NumType[], [F64])        # 46
    add_import!(mod, "dom", "get_drag_delta_y", NumType[], [F64])        # 47

    # Category 14: Timers (indices 48-51)
    add_import!(mod, "dom", "set_timeout", [I32, I32], [I32])            # 48
    add_import!(mod, "dom", "clear_timeout", [I32], NumType[])           # 49
    add_import!(mod, "dom", "request_animation_frame", [I32], [I32])     # 50
    add_import!(mod, "dom", "cancel_animation_frame", [I32], NumType[])  # 51

    # Category 15: Event control (index 52)
    add_import!(mod, "dom", "prevent_default", NumType[], NumType[])     # 52

    # Category 16: Boolean state helpers (indices 53-54)
    # These enable BindBool attribute bindings for @island components.
    # set_data_state_bool(el, mode, state): mode 0=closed/open, 1=off/on, 2=unchecked/checked
    add_import!(mod, "dom", "set_data_state_bool", [I32, I32, F64], NumType[])  # 53
    # set_aria_bool(el, attr_code, state): attr 0=pressed, 1=checked, 2=expanded, 3=selected
    add_import!(mod, "dom", "set_aria_bool", [I32, I32, F64], NumType[])        # 54

    # Category 17: Modal behavior (index 55)
    # modal_state(el, mode, state): manages scroll lock, focus trap, dismiss
    # mode: 0=dialog, 1=alert_dialog, 2=drawer, 3=popover, 4=tooltip (hover+floating), 5=hover_card (hover+floating+dismiss)
    add_import!(mod, "dom", "modal_state", [I32, I32, F64], NumType[])          # 55

    # =========================================================================
    # T31 HYDRATION CURSOR IMPORTS — indices 56-66
    # These enable Leptos-style full-body island compilation.
    # Cursor walks SSR-rendered DOM; bindings connect signals to DOM updates.
    # Import order is FROZEN after implementation.
    # =========================================================================

    # Category 18: Cursor navigation (indices 56-61)
    add_import!(mod, "dom", "cursor_child", NumType[], NumType[])               # 56
    add_import!(mod, "dom", "cursor_sibling", NumType[], NumType[])             # 57
    add_import!(mod, "dom", "cursor_parent", NumType[], NumType[])              # 58
    add_import!(mod, "dom", "cursor_current", NumType[], [I32])                 # 59
    add_import!(mod, "dom", "cursor_set", [I32], NumType[])                     # 60
    add_import!(mod, "dom", "cursor_skip_children", NumType[], NumType[])       # 61

    # Category 19: Event attachment (index 62)
    add_import!(mod, "dom", "add_event_listener", [I32, I32, I32], NumType[])   # 62

    # Category 20: Signal→DOM binding registration (indices 63-66)
    add_import!(mod, "dom", "register_text_binding", [I32, I32], NumType[])     # 63
    add_import!(mod, "dom", "register_visibility_binding", [I32, I32], NumType[]) # 64
    add_import!(mod, "dom", "register_attribute_binding", [I32, I32, I32], NumType[]) # 65
    add_import!(mod, "dom", "trigger_bindings", [I32, I32], NumType[])          # 66

    # Category 21: Props deserialization (indices 67-70)
    add_import!(mod, "dom", "get_prop_count", NumType[], [I32])                # 67
    add_import!(mod, "dom", "get_prop_i32", [I32], [I32])                      # 68
    add_import!(mod, "dom", "get_prop_f64", [I32], [F64])                      # 69
    add_import!(mod, "dom", "get_prop_string_id", [I32], [I32])                # 70

    # Category 22: BindBool/BindModal binding registration (indices 71-73)
    add_import!(mod, "dom", "register_data_state_binding", [I32, I32, I32], NumType[]) # 71
    add_import!(mod, "dom", "register_aria_binding", [I32, I32, I32], NumType[])       # 72
    add_import!(mod, "dom", "register_modal_binding", [I32, I32, I32], NumType[])      # 73

    # Category 23: Per-child pattern support (indices 74-75)
    add_import!(mod, "dom", "get_event_data_index", NumType[], [I32])                  # 74
    add_import!(mod, "dom", "register_match_binding", [I32, I32, I32], NumType[])      # 75

    # Category 24: Per-child match/bit state bindings (indices 76-79)
    add_import!(mod, "dom", "register_match_data_state_binding", [I32, I32, I32, I32], NumType[]) # 76
    add_import!(mod, "dom", "register_match_aria_binding", [I32, I32, I32, I32], NumType[])       # 77
    add_import!(mod, "dom", "register_bit_data_state_binding", [I32, I32, I32, I32], NumType[])   # 78
    add_import!(mod, "dom", "register_bit_aria_binding", [I32, I32, I32, I32], NumType[])         # 79

    # Category 25: Escape dismiss (Phase 6) — Thaw-style modal escape handler stack
    add_import!(mod, "dom", "push_escape_handler", [I32], NumType[])                            # 80
    add_import!(mod, "dom", "pop_escape_handler", NumType[], NumType[])                         # 81

    # Category 26: Click-outside dismiss (Phase 6) — Thaw-style click-outside detection
    add_import!(mod, "dom", "add_click_outside_listener", [I32, I32], NumType[])                # 82
    add_import!(mod, "dom", "remove_click_outside_listener", [I32], NumType[])                  # 83

    # Category 27: Active element save/restore (Phase 6) — focus management for modals
    add_import!(mod, "dom", "store_active_element", NumType[], NumType[])                       # 84
    add_import!(mod, "dom", "restore_active_element", NumType[], NumType[])                     # 85

    # Category 28: ShowDescendants binding (Phase 7) — toggle display + data-state on descendants
    add_import!(mod, "dom", "show_descendants", [I32, I32], NumType[])                          # 86

    # Category 29: Event delegation role detection (Phase 7) — read data-role from event target
    add_import!(mod, "dom", "get_event_closest_role", NumType[], [I32])                         # 87

    # Category 30: Parent island navigation (Phase 7) — find parent island root element
    add_import!(mod, "dom", "get_parent_island_root", NumType[], [I32])                         # 88

    # Category 31: Focus trap cycling (Phase 7) — cycle Tab focus within event.currentTarget
    add_import!(mod, "dom", "cycle_focus_in_current_target", [I32], NumType[])                  # 89

    # Category 32: Auto-register bindings on [data-index] descendants (T32)
    add_import!(mod, "dom", "register_match_descendants", [I32, I32], NumType[])                # 90
    add_import!(mod, "dom", "register_bit_descendants", [I32, I32], NumType[])                  # 91

    # Import 92: Theme state query — read current dark mode state for signal initialization
    add_import!(mod, "dom", "get_is_dark_mode", NumType[], [I32])                               # 92

    # Category 33: DismissableLayer — Radix-style dismiss layer stack (imports 93-94)
    add_import!(mod, "dom", "push_dismiss_layer", [I32, I32], NumType[])                        # 93
    add_import!(mod, "dom", "pop_dismiss_layer", NumType[], NumType[])                          # 94

    # =========================================================================
    # GLOBALS - One for each signal
    # Type conversion to f64 for DOM calls is handled automatically by WasmTarget
    # =========================================================================

    for signal in analysis.signals
        initial = signal.initial_value

        # Determine Wasm type and create global
        # Match the actual Julia type for correct handler compilation
        global_idx = if signal.type == Int32 || signal.type == UInt32
            add_global!(mod, I32, true, Int32(initial))
        elseif signal.type == Int64 || signal.type == UInt64 || signal.type == Int
            add_global!(mod, I64, true, Int64(initial))
        elseif signal.type == Float32
            add_global!(mod, F32, true, Float32(initial))
        elseif signal.type == Float64
            add_global!(mod, F64, true, Float64(initial))
        elseif signal.type == Bool
            add_global!(mod, I32, true, Int32(initial ? 1 : 0))
        else
            # Default to i64 for other types
            add_global!(mod, I64, true, Int64(0))
        end

        signal_globals[signal.id] = global_idx
        add_global_export!(mod, "signal_$(signal.id)", global_idx)
    end

    # =========================================================================
    # SIGNAL GETTERS/SETTERS
    # =========================================================================

    no_params = WasmTarget.NumType[]
    no_results = WasmTarget.NumType[]
    no_locals = WasmTarget.NumType[]

    for signal in analysis.signals
        global_idx = signal_globals[signal.id]

        # Determine the Wasm type for this signal
        wasm_type = if signal.type == Int32 || signal.type == UInt32 || signal.type == Bool
            I32
        elseif signal.type == Int64 || signal.type == UInt64 || signal.type == Int
            I64
        elseif signal.type == Float32
            F32
        elseif signal.type == Float64
            F64
        else
            I64  # Default to i64 for unknown integer types
        end

        # get_signal_N() -> wasm_type
        get_code = UInt8[
            Opcode.GLOBAL_GET, UInt8(global_idx),
            Opcode.END
        ]
        get_idx = add_function!(mod, no_params, [wasm_type], no_locals, get_code)
        add_export!(mod, "get_signal_$(signal.id)", 0x00, get_idx)
        push!(exports, "get_signal_$(signal.id)")

        # set_signal_N(value: wasm_type)
        set_code = UInt8[
            Opcode.LOCAL_GET, 0x00,
            Opcode.GLOBAL_SET, UInt8(global_idx),
            Opcode.END
        ]
        set_idx = add_function!(mod, [wasm_type], no_results, no_locals, set_code)
        add_export!(mod, "set_signal_$(signal.id)", 0x00, set_idx)
        push!(exports, "set_signal_$(signal.id)")
    end

    # =========================================================================
    # EVENT HANDLERS - Direct IR compilation with fallback to tracing
    # =========================================================================

    # Create type registry for direct compilation
    type_registry = TypeRegistry()

    # Build DOM bindings map for all signals (used by direct IR compilation)
    # Maps global_idx -> [(import_idx, const_args), ...]
    dom_bindings = build_dom_bindings(analysis, signal_globals)

    for handler in analysis.handlers
        # Direct IR compilation - no fallback, errors are visible
        if handler.handler_ir !== nothing
            handler_code, handler_locals = compile_handler_direct(
                handler, analysis, signal_globals, dom_bindings, mod, type_registry
            )
            handler_idx = add_function!(mod, no_params, no_results, handler_locals, handler_code)
            add_export!(mod, "handler_$(handler.id)", 0x00, handler_idx)
            push!(exports, "handler_$(handler.id)")
        else
            error("Handler $(handler.id) has no IR - cannot compile. Direct IR compilation is required.")
        end
    end

    # =========================================================================
    # INPUT BINDING HANDLERS - Take a value parameter and set signal directly
    # =========================================================================

    for input_binding in analysis.input_bindings
        if !haskey(signal_globals, input_binding.signal_id)
            continue
        end

        global_idx = signal_globals[input_binding.signal_id]

        # Find all bindings that display this signal (to update DOM)
        bindings_for_signal = filter(b -> b.signal_id == input_binding.signal_id, analysis.bindings)

        handler_code = UInt8[]

        # Get signal type for conversion
        signal = findfirst(s -> s.id == input_binding.signal_id, analysis.signals)
        signal_type = signal !== nothing ? analysis.signals[signal].type : Int64

        # Set the signal from the parameter: signal = param
        # Input comes as f64 from JS, convert to signal's native type
        append!(handler_code, [Opcode.LOCAL_GET, 0x00])  # Get the input value parameter (f64)
        # Convert f64 to signal type
        if signal_type == Int64 || signal_type == UInt64 || signal_type == Int
            push!(handler_code, 0xB0)  # i64.trunc_f64_s
        elseif signal_type == Int32 || signal_type == UInt32
            push!(handler_code, 0xAA)  # i32.trunc_f64_s
        elseif signal_type == Float32
            push!(handler_code, 0xB6)  # f32.demote_f64
        end
        # If Float64, no conversion needed
        append!(handler_code, [Opcode.GLOBAL_SET, UInt8(global_idx)])

        # Update DOM for all bindings (except the input itself which already has the value)
        for binding in bindings_for_signal
            if binding.target_hk != input_binding.target_hk  # Don't update the input itself
                # Push hydration key (i32)
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_unsigned(binding.target_hk))
                # Push signal value
                append!(handler_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
                # Convert to f64 based on signal type
                if signal_type == Int64 || signal_type == UInt64 || signal_type == Int
                    push!(handler_code, 0xB9)  # f64.convert_i64_s
                elseif signal_type == Int32 || signal_type == UInt32
                    push!(handler_code, 0xB7)  # f64.convert_i32_s
                elseif signal_type == Float32
                    push!(handler_code, 0xBB)  # f64.promote_f32
                end
                # If Float64, no conversion needed
                append!(handler_code, [Opcode.CALL, 0x00])  # call update_text
            end
        end

        append!(handler_code, [Opcode.END])

        # Input handlers take one f64 parameter (the new value from JS)
        # JS passes numbers as f64, so we need to convert for the signal
        handler_idx = add_function!(mod, [F64], no_results, no_locals, handler_code)
        add_export!(mod, "input_handler_$(input_binding.handler_id)", 0x00, handler_idx)
        push!(exports, "input_handler_$(input_binding.handler_id)")
    end

    # =========================================================================
    # INIT FUNCTION - Called after hydration to sync initial state
    # =========================================================================

    init_code = UInt8[]
    for signal in analysis.signals
        if signal.type <: Number
            global_idx = signal_globals[signal.id]
            bindings_for_signal = filter(b -> b.signal_id == signal.id, analysis.bindings)

            for binding in bindings_for_signal
                # Push hydration key (i32)
                append!(init_code, [Opcode.I32_CONST])
                append!(init_code, encode_leb128_unsigned(binding.target_hk))
                # Push signal value and convert to f64
                append!(init_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
                # Add f64 conversion based on signal type
                if signal.type == Int64 || signal.type == UInt64 || signal.type == Int
                    push!(init_code, 0xB9)  # f64.convert_i64_s
                elseif signal.type == Int32 || signal.type == UInt32
                    push!(init_code, 0xB7)  # f64.convert_i32_s
                elseif signal.type == Float32
                    push!(init_code, 0xBB)  # f64.promote_f32
                end
                # If Float64, no conversion needed
                append!(init_code, [Opcode.CALL, 0x00])  # call update_text
            end
        end
    end
    append!(init_code, [Opcode.END])

    if !isempty(init_code)
        init_idx = add_function!(mod, no_params, no_results, no_locals, init_code)
        add_export!(mod, "init", 0x00, init_idx)
        push!(exports, "init")
    end

    return WasmOutput(to_bytes(mod), exports, signal_globals)
end

"""
Encode unsigned LEB128 integer.
"""
function encode_leb128_unsigned(value::Int)::Vector{UInt8}
    result = UInt8[]
    while true
        byte = UInt8(value & 0x7f)
        value >>= 7
        if value != 0
            byte |= 0x80
        end
        push!(result, byte)
        if value == 0
            break
        end
    end
    return result
end

"""
Encode signed LEB128 integer.
"""
function encode_leb128_signed(value::Int)::Vector{UInt8}
    result = UInt8[]
    more = true
    while more
        byte = UInt8(value & 0x7f)
        value >>= 7
        # Check if we need more bytes
        if (value == 0 && (byte & 0x40) == 0) || (value == -1 && (byte & 0x40) != 0)
            more = false
        else
            byte |= 0x80
        end
        push!(result, byte)
    end
    return result
end

# ============================================================================
# Direct IR Compilation Support
# ============================================================================

"""
Build DOM bindings map for all signals.

Returns a Dict mapping global_idx -> [(import_idx, const_args), ...]
This tells the compiler what DOM updates to inject after signal writes.

All numeric values are automatically converted to f64 by WasmTarget.

Import indices:
- 0: update_text(hk, value: f64) - update text content
- 1: set_visible(hk, visible: f64) - show/hide element
- 2: set_dark_mode(enabled: f64) - toggle dark mode
- 53: set_data_state_bool(hk, mode, state: f64) - toggle data-state attribute
- 54: set_aria_bool(hk, attr_code, state: f64) - toggle aria-* attribute
- 55: modal_state(hk, mode, state: f64) - modal lifecycle (scroll lock, focus trap, dismiss)
"""
function build_dom_bindings(analysis::ComponentAnalysis, signal_globals::Dict{UInt64, Int})
    dom_bindings = Dict{UInt32, Vector{Tuple{UInt32, Vector{Int32}}}}()

    for (signal_id, global_idx) in signal_globals
        bindings_list = Tuple{UInt32, Vector{Int32}}[]

        # Text bindings: update_text(hk, value) - import idx 0
        for binding in filter(b -> b.signal_id == signal_id && b.attribute === nothing, analysis.bindings)
            push!(bindings_list, (UInt32(0), Int32[binding.target_hk]))
        end

        # Show bindings: set_visible(hk, visible) - import idx 1
        for show in filter(s -> s.signal_id == signal_id, analysis.show_nodes)
            push!(bindings_list, (UInt32(1), Int32[show.target_hk]))
        end

        # Theme bindings: set_dark_mode(enabled) - import idx 2
        for _theme in filter(t -> t.signal_id == signal_id, analysis.theme_bindings)
            push!(bindings_list, (UInt32(2), Int32[]))
        end

        # Bool attribute bindings (BindBool) — import idx 53/54
        for binding in filter(b -> b.signal_id == signal_id, analysis.bool_bindings)
            attr_name = replace(string(binding.attribute), "_" => "-")

            if attr_name == "data-state"
                # set_data_state_bool(el, mode, state) — import 53
                # mode: 0=closed/open, 1=off/on, 2=unchecked/checked
                mode = if binding.off_value == "off" && binding.on_value == "on"
                    Int32(1)
                elseif binding.off_value == "unchecked" && binding.on_value == "checked"
                    Int32(2)
                else
                    Int32(0)  # default: closed/open
                end
                push!(bindings_list, (UInt32(53), Int32[binding.target_hk, mode]))
            elseif startswith(attr_name, "aria-")
                # set_aria_bool(el, attr_code, state) — import 54
                # attr_code: 0=pressed, 1=checked, 2=expanded, 3=selected
                attr_code = if attr_name == "aria-pressed"
                    Int32(0)
                elseif attr_name == "aria-checked"
                    Int32(1)
                elseif attr_name == "aria-expanded"
                    Int32(2)
                elseif attr_name == "aria-selected"
                    Int32(3)
                else
                    Int32(0)
                end
                push!(bindings_list, (UInt32(54), Int32[binding.target_hk, attr_code]))
            end
        end

        # Modal bindings: modal_state(target_hk, mode, state) - import idx 55
        for binding in filter(b -> b.signal_id == signal_id, analysis.modal_bindings)
            push!(bindings_list, (UInt32(55), Int32[binding.target_hk, binding.mode]))
        end

        if !isempty(bindings_list)
            dom_bindings[UInt32(global_idx)] = bindings_list
        end
    end

    return dom_bindings
end

"""
Compile a handler using direct IR compilation (WasmTarget's compile_closure_body).

Returns (bytecode, locals) tuple. Errors are not caught - they propagate for visibility.
"""
function compile_handler_direct(
    handler::AnalyzedHandler,
    analysis::ComponentAnalysis,
    signal_globals::Dict{UInt64, Int},
    dom_bindings::Dict{UInt32, Vector{Tuple{UInt32, Vector{Int32}}}},
    mod::WasmModule,
    type_registry::TypeRegistry
)
    ir = handler.handler_ir

    # Build captured_signal_fields from the closure
    # Maps field_name -> (is_getter, global_idx)
    captured_signal_fields = Dict{Symbol, Tuple{Bool, UInt32}}()
    closure_type = typeof(ir.closure)
    field_names = fieldnames(closure_type)

    # Map getters: field_idx -> signal_id -> global_idx
    for (field_idx, signal_id) in ir.captured_getters
        if haskey(signal_globals, signal_id)
            field_name = field_names[field_idx]
            global_idx = UInt32(signal_globals[signal_id])
            captured_signal_fields[field_name] = (true, global_idx)  # is_getter=true
        end
    end

    # Map setters: field_idx -> signal_id -> global_idx
    for (field_idx, signal_id) in ir.captured_setters
        if haskey(signal_globals, signal_id)
            field_name = field_names[field_idx]
            global_idx = UInt32(signal_globals[signal_id])
            captured_signal_fields[field_name] = (false, global_idx)  # is_getter=false
        end
    end

    # Compile the closure body - no try/catch, errors propagate
    # Use void_return=true since event handlers don't return values
    body, locals = compile_closure_body(
        ir.closure,
        captured_signal_fields,
        mod,
        type_registry;
        dom_bindings = dom_bindings,
        void_return = true
    )

    return (body, locals)
end

"""
Compile a handler using tracing-based compilation (fallback).

Returns bytecode for the handler function.
"""
function compile_handler_traced(
    handler::AnalyzedHandler,
    analysis::ComponentAnalysis,
    signal_globals::Dict{UInt64, Int}
)
    handler_code = UInt8[]

    # Track which signals are modified so we can update their DOM bindings
    modified_signals = Set{UInt64}()

    # Generate code for each traced operation
    for op in handler.operations
        if !haskey(signal_globals, op.signal_id)
            continue  # Signal not found, skip
        end

        global_idx = signal_globals[op.signal_id]
        push!(modified_signals, op.signal_id)

        # Generate Wasm code based on operation type
        if op.operation == OP_INCREMENT
            append!(handler_code, [
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.I32_CONST, 0x01,
                Opcode.I32_ADD,
                Opcode.GLOBAL_SET, UInt8(global_idx),
            ])
        elseif op.operation == OP_DECREMENT
            append!(handler_code, [
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.I32_CONST, 0x01,
                Opcode.I32_SUB,
                Opcode.GLOBAL_SET, UInt8(global_idx),
            ])
        elseif op.operation == OP_ADD
            append!(handler_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
            append!(handler_code, [Opcode.I32_CONST])
            append!(handler_code, encode_leb128_signed(Int(op.operand)))
            append!(handler_code, [Opcode.I32_ADD, Opcode.GLOBAL_SET, UInt8(global_idx)])
        elseif op.operation == OP_SUB
            append!(handler_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
            append!(handler_code, [Opcode.I32_CONST])
            append!(handler_code, encode_leb128_signed(Int(op.operand)))
            append!(handler_code, [Opcode.I32_SUB, Opcode.GLOBAL_SET, UInt8(global_idx)])
        elseif op.operation == OP_MUL
            append!(handler_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
            append!(handler_code, [Opcode.I32_CONST])
            append!(handler_code, encode_leb128_signed(Int(op.operand)))
            append!(handler_code, [Opcode.I32_MUL, Opcode.GLOBAL_SET, UInt8(global_idx)])
        elseif op.operation == OP_SET
            append!(handler_code, [Opcode.I32_CONST])
            append!(handler_code, encode_leb128_signed(Int(op.operand)))
            append!(handler_code, [Opcode.GLOBAL_SET, UInt8(global_idx)])
        elseif op.operation == OP_NEGATE
            append!(handler_code, [
                Opcode.I32_CONST, 0x00,
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.I32_SUB,
                Opcode.GLOBAL_SET, UInt8(global_idx),
            ])
        elseif op.operation == OP_TOGGLE
            append!(handler_code, [
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.I32_EQZ,
                Opcode.GLOBAL_SET, UInt8(global_idx),
            ])
        end
    end

    # Update DOM for all modified signals
    for signal_id in modified_signals
        global_idx = signal_globals[signal_id]
        bindings_for_signal = filter(b -> b.signal_id == signal_id, analysis.bindings)

        for binding in bindings_for_signal
            append!(handler_code, [Opcode.I32_CONST])
            append!(handler_code, encode_leb128_unsigned(binding.target_hk))
            append!(handler_code, [
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.CALL, 0x00,  # call update_text_i32 (import idx 0)
            ])
        end

        # Update Show visibility
        shows_for_signal = filter(s -> s.signal_id == signal_id, analysis.show_nodes)
        for show in shows_for_signal
            append!(handler_code, [Opcode.I32_CONST])
            append!(handler_code, encode_leb128_unsigned(show.target_hk))
            append!(handler_code, [
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.I32_CONST, 0x00,
                Opcode.I32_NE,
                Opcode.CALL, 0x03,  # call set_visible (import idx 3)
            ])
        end

        # Update theme
        theme_for_signal = filter(t -> t.signal_id == signal_id, analysis.theme_bindings)
        for _theme in theme_for_signal
            append!(handler_code, [
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.I32_CONST, 0x00,
                Opcode.I32_NE,
                Opcode.CALL, 0x04,  # call set_dark_mode (import idx 4)
            ])
        end
    end

    append!(handler_code, [Opcode.END])
    return handler_code
end

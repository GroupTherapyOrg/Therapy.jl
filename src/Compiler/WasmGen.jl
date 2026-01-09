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

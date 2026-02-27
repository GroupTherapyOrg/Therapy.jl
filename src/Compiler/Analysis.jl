# Analysis.jl - Analyze components to extract reactive structure
#
# This module runs a component and tracks:
# - Signals created (state)
# - Event handlers defined
# - DOM structure with signal bindings

# Helper to check if something is a signal getter (Function or SignalGetter struct)
is_signal_getter(x) = x isa Function || x isa SignalGetter
# Helper to check if something is a signal setter (Function or SignalSetter struct)
is_signal_setter(x) = x isa Function || x isa SignalSetter
# Helper to check if something is callable (for event handlers)
is_handler(x) = x isa Function

"""
Represents a signal discovered during component analysis.
"""
struct AnalyzedSignal
    id::UInt64
    name::Symbol
    initial_value::Any
    type::Type
end

"""
Represents extracted IR from an event handler closure.
Used for direct compilation instead of tracing.
"""
struct HandlerIR
    closure::Function                      # The original closure
    ir::Core.CodeInfo                      # Typed IR from code_typed
    return_type::Type                      # Return type from code_typed
    captured_getters::Dict{Int, UInt64}    # field_idx -> signal_id for getters
    captured_setters::Dict{Int, UInt64}    # field_idx -> signal_id for setters
end

"""
Represents an event handler discovered during component analysis.
"""
struct AnalyzedHandler
    id::Int
    event::Symbol           # :on_click, :on_input, etc.
    target_hk::Int          # Hydration key of the element
    handler::Function       # The actual handler function
    operations::Vector{TracedOperation}  # What operations the handler performs (legacy tracing)
    handler_ir::Union{HandlerIR, Nothing}  # Extracted IR for direct compilation
end

"""
Represents a DOM binding where a signal value is displayed.
"""
struct AnalyzedBinding
    signal_id::UInt64
    target_hk::Int          # Hydration key of the element to update
    attribute::Union{Symbol, Nothing}  # nothing for text content, :class, :value, etc.
end

"""
Represents a two-way input binding.
The input's value is bound to a signal, and changes update the signal.
"""
struct AnalyzedInputBinding
    signal_id::UInt64       # The signal bound to this input
    target_hk::Int          # Hydration key of the input element
    handler_id::Int         # ID of the generated handler
    input_type::Symbol      # :text, :number, :checkbox, etc.
end

"""
Represents a Show conditional rendering node.
"""
struct AnalyzedShow
    signal_id::UInt64       # The signal that controls visibility
    target_hk::Int          # Hydration key of the Show wrapper
    initial_visible::Bool   # Initial visibility state
end

"""
Represents a theme binding where a signal controls dark/light mode.
When the signal is 1, dark mode is enabled; when 0, light mode.
"""
struct AnalyzedThemeBinding
    signal_id::UInt64       # The signal that controls the theme
end

"""
Represents a boolean signal-to-attribute binding (BindBool).
When the signal changes, the attribute is updated to off_value or on_value.
"""
struct AnalyzedBoolBinding
    signal_id::UInt64       # The signal that controls the attribute
    target_hk::Int          # Hydration key of the element
    attribute::Symbol       # :data_state, :aria_pressed, :aria_checked, etc.
    off_value::String       # Value when signal is 0/false
    on_value::String        # Value when signal is non-zero/true
end

"""
Represents a modal behavior binding (BindModal).
When the signal changes, modal lifecycle is managed: scroll lock, focus trap, dismiss.
"""
struct AnalyzedModalBinding
    signal_id::UInt64       # The signal that controls modal open/close
    target_hk::Int          # Hydration key of the element (island root)
    mode::Int32             # 0=dialog (Escape+outside), 1=alert_dialog (no dismiss)
end

"""
Result of analyzing a component.
"""
struct ComponentAnalysis
    signals::Vector{AnalyzedSignal}
    handlers::Vector{AnalyzedHandler}
    bindings::Vector{AnalyzedBinding}
    input_bindings::Vector{AnalyzedInputBinding}
    show_nodes::Vector{AnalyzedShow}
    theme_bindings::Vector{AnalyzedThemeBinding}  # Theme (dark mode) bindings
    bool_bindings::Vector{AnalyzedBoolBinding}    # Boolean attribute bindings (BindBool)
    modal_bindings::Vector{AnalyzedModalBinding}  # Modal behavior bindings (BindModal)
    vnode::Any
    html::String
    # Maps for direct compilation
    getter_map::Dict{Any, UInt64}   # signal getter -> signal_id
    setter_map::Dict{Any, UInt64}   # signal setter -> signal_id
end

"""
    analyze_component(component_fn::Function) -> ComponentAnalysis

Analyze a component to extract its reactive structure.

This runs the component once to discover:
- What signals it creates
- What event handlers it defines
- How signals bind to the DOM
"""
function analyze_component(component_fn::Function)
    # Enable signal tracking mode
    enable_signal_analysis!()

    local vnode
    local raw_signals
    local getter_map

    try
        # Run the component to get its VNode structure
        vnode = component_fn()

        # Get the signals that were created
        raw_signals, getter_map = disable_signal_analysis!()
    catch e
        disable_signal_analysis!()
        rethrow(e)
    end

    # Convert raw signals to AnalyzedSignal
    signals = AnalyzedSignal[]
    for s in raw_signals
        push!(signals, AnalyzedSignal(
            s.id,
            Symbol("signal_", s.id),
            s.initial,
            s.type
        ))
    end

    # Build setter map for input binding detection
    setter_map = Dict{Any, UInt64}()
    for s in raw_signals
        setter_map[s.setter] = s.id
    end

    # Walk the VNode tree to find event handlers and signal bindings
    raw_handlers = Tuple{Int, Symbol, Int, Function}[]  # (id, event, hk, handler)
    bindings = AnalyzedBinding[]
    input_bindings = AnalyzedInputBinding[]
    show_nodes = AnalyzedShow[]
    theme_bindings = AnalyzedThemeBinding[]
    bool_bindings = AnalyzedBoolBinding[]
    modal_bindings = AnalyzedModalBinding[]
    hk_counter = Ref(0)
    handler_counter = Ref(0)

    analyze_vnode!(vnode, raw_handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)

    # Process each handler: extract IR for direct compilation AND trace for fallback
    handlers = AnalyzedHandler[]
    for (h_id, h_event, h_hk, h_fn) in raw_handlers
        # Try to extract handler IR for direct compilation
        handler_ir = extract_handler_ir(h_fn, getter_map, setter_map)

        # Also trace for backward compatibility (can be removed once direct compilation is stable)
        ops = trace_handler(h_fn, raw_signals)

        push!(handlers, AnalyzedHandler(h_id, h_event, h_hk, h_fn, ops, handler_ir))
    end

    # Generate HTML with hydration keys
    html = render_to_string(vnode)

    return ComponentAnalysis(signals, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, vnode, html, getter_map, setter_map)
end

"""
Recursively analyze a VNode tree.
"""
function analyze_vnode!(node::VNode, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
    hk_counter[] += 1
    hk = hk_counter[]

    # Track if this is an input element with a value binding
    is_input = node.tag == :input
    value_signal_id = nothing
    input_type = :text

    # Check props for event handlers and signal bindings
    for (key, value) in node.props
        key_str = string(key)

        # Get input type if present
        if key == :type && value isa String
            input_type = Symbol(value)
        end

        if startswith(key_str, "on_")
            # Event handler - store as tuple for later tracing
            if value isa Function
                # Check if this is a direct setter (for input binding)
                setter_signal_id = get(setter_map, value, nothing)
                if is_input && key == :on_input && setter_signal_id !== nothing
                    # This is a two-way input binding with direct setter
                    value_signal_id = setter_signal_id
                    handler_counter[] += 1
                    push!(input_bindings, AnalyzedInputBinding(
                        setter_signal_id,
                        hk,
                        handler_counter[],
                        input_type
                    ))
                else
                    # Regular event handler
                    handler_counter[] += 1
                    push!(handlers, (handler_counter[], key, hk, value))
                end
            end
        elseif value isa BindBool
            # Boolean signal-to-attribute binding
            signal_id = get(getter_map, value.getter, nothing)
            if signal_id !== nothing
                push!(bool_bindings, AnalyzedBoolBinding(signal_id, hk, key, value.off_value, value.on_value))
            end
        elseif value isa BindModal
            # Modal behavior binding (scroll lock, focus trap, dismiss)
            signal_id = get(getter_map, value.getter, nothing)
            if signal_id !== nothing
                push!(modal_bindings, AnalyzedModalBinding(signal_id, hk, value.mode))
            end
        elseif key == :dark_mode && is_signal_getter(value)
            # Theme binding - signal controls dark/light mode
            signal_id = get(getter_map, value, nothing)
            if signal_id !== nothing
                # Only add if not already present
                if !any(tb -> tb.signal_id == signal_id, theme_bindings)
                    push!(theme_bindings, AnalyzedThemeBinding(signal_id))
                end
            end
        elseif is_signal_getter(value)
            # Check if it's a signal getter (use local getter_map, not global)
            signal_id = get(getter_map, value, nothing)
            if signal_id !== nothing
                push!(bindings, AnalyzedBinding(signal_id, hk, key))
                # Track value binding for input elements
                if is_input && key == :value
                    value_signal_id = signal_id
            end
            end
        end
    end

    # Check children for signal bindings and nested nodes
    for child in node.children
        if child isa VNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
        elseif child isa ShowNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
        elseif child isa Fragment
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
        elseif is_signal_getter(child)
            # Check if it's a signal getter (use local getter_map, not global)
            signal_id = get(getter_map, child, nothing)
            if signal_id !== nothing
                # Signal bound to text content - bind to this element's hk
                push!(bindings, AnalyzedBinding(signal_id, hk, nothing))
            end
        elseif child isa ComponentInstance
            rendered = render_component(child)
            if rendered isa VNode
                analyze_vnode!(rendered, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
            end
        end
    end
end

function analyze_vnode!(node::ShowNode, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
    # Show wrapper gets its own hydration key
    hk_counter[] += 1
    hk = hk_counter[]

    # Check if the condition is a signal getter
    signal_id = get(getter_map, node.condition, nothing)
    if signal_id !== nothing
        push!(show_nodes, AnalyzedShow(signal_id, hk, node.initial_visible))
    end

    # Analyze the content inside the Show
    if node.content !== nothing
        if node.content isa VNode
            analyze_vnode!(node.content, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
        elseif node.content isa Fragment
            analyze_vnode!(node.content, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
        end
    end
end

function analyze_vnode!(node::Fragment, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
    for child in node.children
        if child isa VNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
        elseif child isa ShowNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
        end
    end
end

function analyze_vnode!(node, handlers, bindings, input_bindings, show_nodes, theme_bindings, bool_bindings, modal_bindings, getter_map, setter_map, hk_counter, handler_counter)
    # Primitive values, strings, etc. - nothing to analyze
end

"""
Trace a handler to discover what signal operations it performs.

This runs the handler multiple times with different starting values
to disambiguate operations (e.g., +1 vs ×2 when starting from 1).
"""
function trace_handler(handler::Function, raw_signals)::Vector{TracedOperation}
    # Use multiple test values to disambiguate operations
    # Include 0 and 1 for toggle detection, plus larger values for arithmetic
    test_values = [0, 1, 10]

    results_per_signal = Dict{UInt64, Vector{Tuple{Any, Any}}}()  # signal_id -> [(old, new), ...]

    for test_val in test_values
        # Set all signals to test value
        for s in raw_signals
            if s.type <: Integer
                s.setter(test_val)
            end
        end

        # Enable tracing and run the handler
        enable_handler_tracing!()
        try
            handler()
        catch e
            # Handler might fail - that's OK
        end
        traced = disable_handler_tracing!()

        # Record old/new pairs for analysis
        for op in traced
            if !haskey(results_per_signal, op.signal_id)
                results_per_signal[op.signal_id] = Tuple{Any, Any}[]
            end
            # Reconstruct old value from test_val and the operation
            old_val = test_val
            new_val = get_signal_value_by_id(raw_signals, op.signal_id)
            push!(results_per_signal[op.signal_id], (old_val, new_val))
        end
    end

    # Analyze results to determine actual operations
    ops = TracedOperation[]
    for (signal_id, pairs) in results_per_signal
        if length(pairs) >= 3
            # We have 3 samples (0, 1, 10) - check for toggle pattern
            op = disambiguate_operation_3(pairs)
            push!(ops, TracedOperation(signal_id, op.operation, op.operand))
        elseif length(pairs) >= 2
            (old1, new1) = pairs[1]
            (old2, new2) = pairs[2]
            op = disambiguate_operation(old1, new1, old2, new2)
            push!(ops, TracedOperation(signal_id, op.operation, op.operand))
        elseif length(pairs) == 1
            (old_val, new_val) = pairs[1]
            op = detect_operation(old_val, new_val)
            push!(ops, TracedOperation(signal_id, op.operation, op.operand))
        end
    end

    # Restore original signal values
    for s in raw_signals
        s.setter(s.initial)
    end

    return ops
end

"""
Get a signal's current value by its ID.
"""
function get_signal_value_by_id(raw_signals, signal_id::UInt64)
    for s in raw_signals
        if s.id == signal_id
            return s.getter()
        end
    end
    return nothing
end

"""
Disambiguate operation using two test samples.
"""
function disambiguate_operation(old1, new1, old2, new2)
    diff1 = new1 - old1
    diff2 = new2 - old2

    # Check for constant SET (both results are the same regardless of input)
    if new1 == new2
        return (operation=OP_SET, operand=new1)
    end

    # Check for consistent additive offset (ADD/SUB/INCREMENT/DECREMENT)
    if diff1 == diff2
        if diff1 == 1
            return (operation=OP_INCREMENT, operand=nothing)
        elseif diff1 == -1
            return (operation=OP_DECREMENT, operand=nothing)
        elseif diff1 > 0
            return (operation=OP_ADD, operand=diff1)
        else
            return (operation=OP_SUB, operand=-diff1)
        end
    end

    # Check for multiplication (ratio is consistent)
    if old1 != 0 && old2 != 0
        ratio1 = new1 / old1
        ratio2 = new2 / old2
        if ratio1 == ratio2 && ratio1 == floor(ratio1)
            return (operation=OP_MUL, operand=Int(ratio1))
        end
    end

    # Check for negation
    if new1 == -old1 && new2 == -old2
        return (operation=OP_NEGATE, operand=nothing)
    end

    # Fallback to SET with first new value
    return (operation=OP_SET, operand=new1)
end

"""
Disambiguate operation using three test samples (0, 1, 10).
This enables detection of toggle patterns.
"""
function disambiguate_operation_3(pairs::Vector{Tuple{Any, Any}})
    # Expected pairs from test values [0, 1, 10]:
    # pairs[1] = (0, result_when_0)
    # pairs[2] = (1, result_when_1)
    # pairs[3] = (10, result_when_10)

    (old0, new0) = pairs[1]  # When input is 0
    (old1, new1) = pairs[2]  # When input is 1
    (old10, new10) = pairs[3]  # When input is 10

    # Check for toggle pattern: 0→1 and nonzero→0
    if old0 == 0 && new0 == 1 && new1 == 0 && new10 == 0
        return (operation=OP_TOGGLE, operand=nothing)
    end

    # Check for constant SET (all results the same)
    if new0 == new1 == new10
        return (operation=OP_SET, operand=new0)
    end

    # Check for consistent additive offset
    diff1 = new1 - old1
    diff10 = new10 - old10
    if diff1 == diff10
        if diff1 == 1
            return (operation=OP_INCREMENT, operand=nothing)
        elseif diff1 == -1
            return (operation=OP_DECREMENT, operand=nothing)
        elseif diff1 > 0
            return (operation=OP_ADD, operand=diff1)
        else
            return (operation=OP_SUB, operand=-diff1)
        end
    end

    # Check for multiplication (using non-zero values)
    if old1 != 0 && old10 != 0
        ratio1 = new1 / old1
        ratio10 = new10 / old10
        if ratio1 == ratio10 && ratio1 == floor(ratio1)
            return (operation=OP_MUL, operand=Int(ratio1))
        end
    end

    # Check for negation
    if new1 == -old1 && new10 == -old10
        return (operation=OP_NEGATE, operand=nothing)
    end

    # Fallback to 2-sample disambiguation
    return disambiguate_operation(old1, new1, old10, new10)
end

# ============================================================================
# Direct Compilation: Closure IR Extraction
# ============================================================================

"""
    extract_handler_ir(handler::Function, getter_map, setter_map) -> Union{HandlerIR, Nothing}

Extract typed IR from an event handler closure for direct compilation.

Returns HandlerIR with:
- The closure's typed IR
- Mappings from captured fields to signal IDs

Returns nothing if IR extraction fails (e.g., not a closure).
"""
function extract_handler_ir(handler::Function, getter_map::Dict{Any, UInt64}, setter_map::Dict{Any, UInt64})::Union{HandlerIR, Nothing}
    try
        # Get the typed IR for the closure (called with no arguments)
        typed_results = Base.code_typed(handler, ())
        if isempty(typed_results)
            return nothing
        end

        ir, return_type = typed_results[1]

        # Get the closure type to examine captured fields
        closure_type = typeof(handler)

        # Map captured signal functions to their field indices
        captured_getters = Dict{Int, UInt64}()
        captured_setters = Dict{Int, UInt64}()

        # Iterate through the closure's fields (captured variables)
        for (field_idx, field_name) in enumerate(fieldnames(closure_type))
            # Get the captured value
            captured_value = getfield(handler, field_name)

            # Check if it's a signal getter
            if haskey(getter_map, captured_value)
                captured_getters[field_idx] = getter_map[captured_value]
            end

            # Check if it's a signal setter
            if haskey(setter_map, captured_value)
                captured_setters[field_idx] = setter_map[captured_value]
            end
        end

        return HandlerIR(handler, ir, return_type, captured_getters, captured_setters)
    catch e
        # IR extraction failed - this is OK, we'll fall back to tracing
        @debug "IR extraction failed for handler" exception=e
        return nothing
    end
end

"""
    get_signal_bindings_map(bindings::Vector{AnalyzedBinding}) -> Dict{UInt64, Vector{Int}}

Build a map from signal_id to list of hydration keys where that signal is displayed.
Used for auto-injecting DOM updates after signal changes.
"""
function get_signal_bindings_map(bindings::Vector{AnalyzedBinding})::Dict{UInt64, Vector{Int}}
    result = Dict{UInt64, Vector{Int}}()
    for b in bindings
        if !haskey(result, b.signal_id)
            result[b.signal_id] = Int[]
        end
        push!(result[b.signal_id], b.target_hk)
    end
    return result
end

# ============================================================================
# Semantic Operation Extraction from IR
# ============================================================================

"""
Operations that can be expressed semantically for Wasm compilation.
This extends TracedOperation with IR-based detection.
"""
@enum SemanticOpType begin
    SEM_READ        # Read signal value
    SEM_WRITE       # Write signal value
    SEM_ADD         # Addition
    SEM_SUB         # Subtraction
    SEM_MUL         # Multiplication
    SEM_CONST       # Constant value
    SEM_COMPARE     # Comparison (for conditionals)
    SEM_BRANCH      # Conditional branch
end

"""
Represents a single semantic operation in the handler.
"""
struct SemanticOp
    op_type::SemanticOpType
    signal_id::Union{UInt64, Nothing}  # For SEM_READ/SEM_WRITE
    operand::Any                        # Constant value, comparison operator, etc.
    result_ssa::Union{Int, Nothing}     # SSA that holds result (if any)
    input_ssa::Vector{Int}              # SSA inputs this op depends on
end

"""
    extract_semantic_ops(handler_ir::HandlerIR) -> Vector{SemanticOp}

Extract semantic operations from handler IR by pattern matching.

This analyzes the IR to find:
1. Signal reads (getter invocations) -> SEM_READ
2. Arithmetic operations -> SEM_ADD, SEM_SUB, SEM_MUL
3. Signal writes (setfield! on signal.value) -> SEM_WRITE

Returns a sequence of semantic operations that can be compiled to Wasm.
"""
function extract_semantic_ops(handler_ir::HandlerIR)::Vector{SemanticOp}
    ops = SemanticOp[]
    ir = handler_ir.ir
    code = ir.code

    # Track which SSAs are signal getters/setters (from closure getfield)
    getter_ssas = Dict{Int, UInt64}()  # ssa_id -> signal_id
    setter_ssas = Dict{Int, UInt64}()  # ssa_id -> signal_id

    # Track which SSAs are Signal objects (from getfield(setter, :signal))
    signal_obj_ssas = Dict{Int, UInt64}()  # ssa_id -> signal_id

    # First pass: identify signal-related SSAs
    for (i, stmt) in enumerate(code)
        if stmt isa Expr && stmt.head === :call
            func = stmt.args[1]
            if func isa GlobalRef && func.mod === Core && func.name === :getfield
                # Core.getfield(target, field)
                target = stmt.args[2]
                field_ref = stmt.args[3]
                field_name = field_ref isa QuoteNode ? field_ref.value : field_ref

                # Check if this is getfield(_1, :signal_field) - getting captured closure field
                if target isa Core.SlotNumber && target.id == 1 && field_name isa Symbol
                    # Map field name to field index
                    closure_type = typeof(handler_ir.closure)
                    field_names = fieldnames(closure_type)
                    field_idx = findfirst(==(field_name), field_names)

                    if field_idx !== nothing
                        if haskey(handler_ir.captured_getters, field_idx)
                            getter_ssas[i] = handler_ir.captured_getters[field_idx]
                        end
                        if haskey(handler_ir.captured_setters, field_idx)
                            setter_ssas[i] = handler_ir.captured_setters[field_idx]
                        end
                    end
                end

                # Check if this is getfield(setter_ssa, :signal) - getting Signal from setter
                if target isa Core.SSAValue && field_name === :signal
                    if haskey(setter_ssas, target.id)
                        signal_obj_ssas[i] = setter_ssas[target.id]
                    end
                end
            end
        end
    end

    # Track which SSAs contain computed values we care about
    value_ssas = Dict{Int, Tuple{Symbol, Vector{Int}, Any}}()  # ssa -> (op, inputs, extra)

    # Second pass: extract semantic operations
    for (i, stmt) in enumerate(code)
        # Handle invoke (function calls)
        if stmt isa Expr && stmt.head === :invoke
            # invoke format: (MethodInstance, func_ref, args...)
            func_ref = stmt.args[2]
            args = stmt.args[3:end]

            # Check if this is calling a signal getter (no args)
            if func_ref isa Core.SSAValue && haskey(getter_ssas, func_ref.id) && isempty(args)
                signal_id = getter_ssas[func_ref.id]
                push!(ops, SemanticOp(SEM_READ, signal_id, nothing, i, Int[]))
                value_ssas[i] = (:signal_read, Int[], signal_id)
            end
        end

        # Handle arithmetic calls
        if stmt isa Expr && stmt.head === :call
            func = stmt.args[1]
            args = stmt.args[2:end]

            # Base.add_int, Base.sub_int, etc.
            if func isa GlobalRef && func.mod === Base
                if func.name === :add_int && length(args) == 2
                    input_ssas = [a.id for a in args if a isa Core.SSAValue]
                    const_val = nothing
                    for a in args
                        if a isa Integer
                            const_val = a
                        end
                    end
                    if const_val !== nothing
                        push!(ops, SemanticOp(SEM_ADD, nothing, const_val, i, input_ssas))
                    end
                    value_ssas[i] = (:add, input_ssas, const_val)

                elseif func.name === :sub_int && length(args) == 2
                    input_ssas = [a.id for a in args if a isa Core.SSAValue]
                    const_val = nothing
                    for a in args
                        if a isa Integer
                            const_val = a
                        end
                    end
                    if const_val !== nothing
                        push!(ops, SemanticOp(SEM_SUB, nothing, const_val, i, input_ssas))
                    end
                    value_ssas[i] = (:sub, input_ssas, const_val)

                elseif func.name === :mul_int && length(args) == 2
                    input_ssas = [a.id for a in args if a isa Core.SSAValue]
                    const_val = nothing
                    for a in args
                        if a isa Integer
                            const_val = a
                        end
                    end
                    if const_val !== nothing
                        push!(ops, SemanticOp(SEM_MUL, nothing, const_val, i, input_ssas))
                    end
                    value_ssas[i] = (:mul, input_ssas, const_val)
                end

                # setfield!(signal_obj, :value, new_value) - signal write
                if func.name === :setfield! && length(args) >= 3
                    target = args[1]
                    field_ref = args[2]
                    new_value = args[3]

                    field_name = field_ref isa QuoteNode ? field_ref.value : field_ref

                    if target isa Core.SSAValue && field_name === :value
                        if haskey(signal_obj_ssas, target.id)
                            signal_id = signal_obj_ssas[target.id]
                            input_ssas = new_value isa Core.SSAValue ? [new_value.id] : Int[]
                            push!(ops, SemanticOp(SEM_WRITE, signal_id, nothing, nothing, input_ssas))
                        end
                    end
                end
            end
        end
    end

    return ops
end

"""
    semantic_ops_to_traced(ops::Vector{SemanticOp}) -> Vector{TracedOperation}

Convert semantic operations to traced operations for compatibility with WasmGen.
This allows using the semantic extraction with the existing bytecode generation.
"""
function semantic_ops_to_traced(ops::Vector{SemanticOp})::Vector{TracedOperation}
    result = TracedOperation[]

    # Track signal reads for computing deltas
    signal_reads = Dict{UInt64, Int}()  # signal_id -> ssa that holds the read value

    for op in ops
        if op.op_type == SEM_READ && op.signal_id !== nothing
            signal_reads[op.signal_id] = op.result_ssa !== nothing ? op.result_ssa : 0
        end

        if op.op_type == SEM_WRITE && op.signal_id !== nothing
            # Find the computation that produces the write value
            # Look at the semantic ops to determine the operation

            # Simple case: check if there's an ADD or SUB that writes to this signal
            for prior_op in ops
                if prior_op.op_type == SEM_ADD && !isempty(prior_op.input_ssa)
                    # Check if input is from a signal read
                    for input_ssa in prior_op.input_ssa
                        if haskey(signal_reads, op.signal_id) && signal_reads[op.signal_id] == input_ssa
                            if prior_op.operand == 1
                                push!(result, TracedOperation(op.signal_id, OP_INCREMENT, nothing))
                            else
                                push!(result, TracedOperation(op.signal_id, OP_ADD, prior_op.operand))
                            end
                            @goto found_op
                        end
                    end
                end

                if prior_op.op_type == SEM_SUB && !isempty(prior_op.input_ssa)
                    for input_ssa in prior_op.input_ssa
                        if haskey(signal_reads, op.signal_id) && signal_reads[op.signal_id] == input_ssa
                            if prior_op.operand == 1
                                push!(result, TracedOperation(op.signal_id, OP_DECREMENT, nothing))
                            else
                                push!(result, TracedOperation(op.signal_id, OP_SUB, prior_op.operand))
                            end
                            @goto found_op
                        end
                    end
                end
            end

            # Fallback: unknown operation
            push!(result, TracedOperation(op.signal_id, OP_UNKNOWN, nothing))
            @label found_op
        end
    end

    return result
end

# Compile.jl - Main compiler API for Therapy.jl
#
# JST backend: compiles @island components to inline JavaScript.
# Uses analyze_component() to discover signals/handlers/bindings,
# then generates a self-contained JS IIFE for each island.

include("Floating.jl")
include("Analysis.jl")

# ─── JST Compilation Output ───

"""
Result of compiling an island to JavaScript.
"""
struct IslandJSOutput
    js::String              # Compiled JavaScript (inline IIFE)
    component_name::String  # Island component name
    n_signals::Int          # Number of signals discovered
    n_handlers::Int         # Number of event handlers
end

# ─── compile_component (legacy — removed) ───

function compile_component(component_fn::Function; kwargs...)
    error("compile_component() removed. Use compile_island(:Name) instead.")
end

function compile_and_serve(component_fn::Function; kwargs...)
    error("compile_and_serve() removed.")
end

# ─── Island Compilation ───

"""
    compile_island(name::Symbol) -> IslandJSOutput

Compile a registered @island component to inline JavaScript.

Uses analyze_component() to discover signals, handlers, and DOM bindings,
then generates a self-contained IIFE that hydrates the island.
"""
function compile_island(name::Symbol)::IslandJSOutput
    island_def = get(ISLAND_REGISTRY, name, nothing)
    island_def === nothing && error("No island :$name registered")

    # Run the island function in analysis mode
    analysis = analyze_component(island_def.render_fn)

    # Generate JS IIFE
    js = _generate_island_js(string(name), analysis)

    return IslandJSOutput(js, string(name), length(analysis.signals), length(analysis.handlers))
end

"""
    compile_island(name::Symbol, body::Expr) -> IslandJSOutput

Compile an island from an explicit body expression (for testing).
Evaluates the body as a zero-arg function, then compiles.
"""
function compile_island(name::Symbol, body::Expr)::IslandJSOutput
    # Wrap body in a function and eval
    fn = Core.eval(Main, Expr(:function, Expr(:call, gensym()), body))
    analysis = analyze_component(fn)
    js = _generate_island_js(string(name), analysis)
    return IslandJSOutput(js, string(name), length(analysis.signals), length(analysis.handlers))
end

# ─── JS Generation ───

"""
Generate the complete IIFE for an island.

Output format:
```javascript
(function() {
  const island = document.querySelector('[data-component="Name"]');
  if (!island || island.dataset.hydrated) return;
  island.dataset.hydrated = "true";
  let signal_0 = 0;
  const hk_2 = island.querySelector('[data-hk="2"]');
  hk_2.addEventListener("click", () => {
    signal_0 = (signal_0 + 1) | 0;
    hk_3.textContent = String(signal_0);
  });
})();
```
"""
function _generate_island_js(component_name::String, analysis::ComponentAnalysis)::String
    parts = String[]

    push!(parts, "(function() {")

    # Find island element and guard against double hydration
    cn = lowercase(component_name)
    push!(parts, "  const island = document.querySelector('[data-component=\"$cn\"]');")
    push!(parts, "  if (!island || island.dataset.hydrated) return;")
    push!(parts, "  island.dataset.hydrated = \"true\";")

    # Declare signal variables
    # Build signal_id -> index mapping
    sig_idx = Dict{UInt64, Int}()
    for (i, sig) in enumerate(analysis.signals)
        idx = i - 1
        sig_idx[sig.id] = idx
        initial = _js_initial_value(sig.initial_value)
        push!(parts, "  let signal_$idx = $initial;")
    end

    # Build binding map: signal_id -> list of (hk, attribute)
    binding_map = Dict{UInt64, Vector{Tuple{Int, Union{Symbol, Nothing}}}}()
    for b in analysis.bindings
        if !haskey(binding_map, b.signal_id)
            binding_map[b.signal_id] = Tuple{Int, Union{Symbol, Nothing}}[]
        end
        push!(binding_map[b.signal_id], (b.target_hk, b.attribute))
    end

    # Collect all hk values that need DOM references
    needed_hks = Set{Int}()
    for h in analysis.handlers
        push!(needed_hks, h.target_hk)
    end
    for b in analysis.bindings
        push!(needed_hks, b.target_hk)
    end
    for s in analysis.show_nodes
        push!(needed_hks, s.target_hk)
    end
    for ib in analysis.input_bindings
        push!(needed_hks, ib.target_hk)
    end

    # Declare DOM element references
    for hk in sort(collect(needed_hks))
        push!(parts, "  const hk_$hk = island.querySelector('[data-hk=\"$hk\"]');")
    end

    # Generate event handlers
    for h in analysis.handlers
        dom_event = event_name_to_dom(h.event)
        push!(parts, "  hk_$(h.target_hk).addEventListener(\"$dom_event\", function() {")

        # Generate operation code from traced operations
        for op in h.operations
            idx = get(sig_idx, op.signal_id, nothing)
            idx === nothing && continue

            # Signal mutation
            op_js = _operation_to_js(idx, op)
            if op_js !== nothing
                push!(parts, "    $op_js")
            end

            # DOM updates for this signal's bindings
            if haskey(binding_map, op.signal_id)
                for (bhk, attr) in binding_map[op.signal_id]
                    update_js = _binding_update_js(idx, bhk, attr)
                    push!(parts, "    $update_js")
                end
            end

            # Show/hide updates for this signal
            for sn in analysis.show_nodes
                if sn.signal_id == op.signal_id
                    push!(parts, "    hk_$(sn.target_hk).style.display = signal_$idx ? \"\" : \"none\";")
                end
            end
        end

        push!(parts, "  });")
    end

    # Generate input bindings (two-way)
    for ib in analysis.input_bindings
        idx = get(sig_idx, ib.signal_id, nothing)
        idx === nothing && continue

        if ib.input_type == :number
            push!(parts, "  hk_$(ib.target_hk).addEventListener(\"input\", function(e) {")
            push!(parts, "    signal_$idx = Number(e.target.value) || 0;")
        elseif ib.input_type == :checkbox
            push!(parts, "  hk_$(ib.target_hk).addEventListener(\"change\", function(e) {")
            push!(parts, "    signal_$idx = e.target.checked ? 1 : 0;")
        else
            push!(parts, "  hk_$(ib.target_hk).addEventListener(\"input\", function(e) {")
            push!(parts, "    signal_$idx = e.target.value;")
        end

        # Update bindings
        if haskey(binding_map, ib.signal_id)
            for (bhk, attr) in binding_map[ib.signal_id]
                update_js = _binding_update_js(idx, bhk, attr)
                push!(parts, "    $update_js")
            end
        end

        push!(parts, "  });")
    end

    push!(parts, "})();")

    return join(parts, "\n")
end

"""Convert Julia initial value to JS literal."""
function _js_initial_value(val)::String
    if val isa Bool
        return val ? "true" : "false"
    elseif val isa Integer
        return string(val)
    elseif val isa AbstractFloat
        return string(val)
    elseif val isa AbstractString
        return "\"$(escape_string(val))\""
    elseif val === nothing
        return "null"
    else
        return string(val)
    end
end

"""Convert a TracedOperation to a JS assignment statement."""
function _operation_to_js(sig_idx::Int, op::TracedOperation)::Union{String, Nothing}
    s = "signal_$sig_idx"
    if op.operation == OP_INCREMENT
        return "$s = ($s + 1) | 0;"
    elseif op.operation == OP_DECREMENT
        return "$s = ($s - 1) | 0;"
    elseif op.operation == OP_ADD
        return "$s = ($s + $(op.operand)) | 0;"
    elseif op.operation == OP_SUB
        return "$s = ($s - $(op.operand)) | 0;"
    elseif op.operation == OP_MUL
        return "$s = ($s * $(op.operand)) | 0;"
    elseif op.operation == OP_NEGATE
        return "$s = (-$s) | 0;"
    elseif op.operation == OP_SET
        return "$s = $(_js_initial_value(op.operand));"
    elseif op.operation == OP_TOGGLE
        return "$s = $s ? 0 : 1;"
    else
        return "/* unknown operation on $s */"
    end
end

"""Generate a JS DOM update for a signal binding."""
function _binding_update_js(sig_idx::Int, hk::Int, attr::Union{Symbol, Nothing})::String
    s = "signal_$sig_idx"
    if attr === nothing
        # Text content binding
        return "hk_$hk.textContent = String($s);"
    elseif attr == :value
        return "hk_$hk.value = String($s);"
    elseif attr == :class
        return "hk_$hk.className = String($s);"
    else
        return "hk_$hk.setAttribute(\"$(string(attr))\", String($s));"
    end
end

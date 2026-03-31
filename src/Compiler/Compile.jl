# Compile.jl - Main compiler API for Therapy.jl
#
# WasmTarget backend: compiles @island components to WASM + thin JS loader.
# Uses analyze_component() to discover signals/handlers/bindings,
# then compiles handler closures via WasmTarget and generates a JS loader
# that instantiates the WASM module and wires events/effects.

import WasmTarget
const WT = WasmTarget

include("Floating.jl")
include("Analysis.jl")
include("SignalRuntime.jl")
include("ReactiveRuntime.jl")
include("ForRuntime.jl")
include("WasmRuntime.jl")

# ─── Compilation Output ───

"""
Result of compiling an island. Contains JS that embeds inline WASM bytes.
The JS field is a self-contained loader script (replaces the old JST IIFE).
"""
struct IslandJSOutput
    js::String              # JS loader script (embeds WASM bytes inline)
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

Compile a registered @island component to WASM + JS loader.

Uses analyze_component() to discover signals, handlers, and DOM bindings,
then compiles handler/effect/memo closures to WASM via WasmTarget and
generates a JS loader that instantiates the module and wires hydration.
"""
function compile_island(name::Symbol)::IslandJSOutput
    island_def = get(ISLAND_REGISTRY, name, nothing)
    island_def === nothing && error("No island :$name registered")

    # Run the island function in analysis mode
    analysis = analyze_component(island_def.render_fn)

    # Generate WASM module + JS loader
    js = _generate_island_wasm(string(name), analysis; prop_names=island_def.prop_names)

    return IslandJSOutput(js, string(name), length(analysis.signals), length(analysis.handlers))
end

"""
    compile_island(name::Symbol, body::Expr) -> IslandJSOutput

Compile an island from an explicit body expression (for testing).
"""
function compile_island(name::Symbol, body::Expr)::IslandJSOutput
    fn = Core.eval(Main, Expr(:function, Expr(:call, gensym()), body))
    analysis = analyze_component(fn)
    js = _generate_island_wasm(string(name), analysis)
    return IslandJSOutput(js, string(name), length(analysis.signals), length(analysis.handlers))
end

# ─── WASM Island Generation ───

"""
Generate the complete WASM module + JS loader for an island.

Architecture:
  - WASM module: signal globals + handler/effect/memo exports
  - JS loader: instantiates WASM, creates __t.signal mirrors, wires events/effects
  - __t reactive runtime handles dependency tracking (unchanged)
"""
function _generate_island_wasm(component_name::String, analysis::ComponentAnalysis;
                                prop_names::Vector{Symbol}=Symbol[])::String
    cn = lowercase(component_name)

    # Build signal_id -> index mapping
    sig_idx = Dict{UInt64, Int}()
    for (i, sig) in enumerate(analysis.signals)
        sig_idx[sig.id] = i - 1
    end

    # ─── Build shared WASM module ───
    mod = WT.WasmModule()
    type_registry = WT.TypeRegistry()

    # Add Math.pow import (required by WasmTarget for float power operations)
    # Must come before any compile_closure_body calls since imports affect function indices.
    # The JS import object (__tw.io) always provides Math.pow.
    WT.add_import!(mod, "Math", "pow", WT.NumType[WT.F64, WT.F64], WT.NumType[WT.F64])

    # Add signal globals (one mutable i64 per signal — Julia Int is Int64)
    for (i, sig) in enumerate(analysis.signals)
        init_val = sig.initial_value isa Integer ? Int64(sig.initial_value) : Int64(0)
        actual_idx = WT.add_global!(mod, WT.I64, true, init_val)
        WT.add_global_export!(mod, "signal_$(i-1)", actual_idx)
    end

    # ─── Compile handler closures to WASM ───
    handler_results = Dict{Int, Any}()
    for h in analysis.handlers
        result = _compile_handler_wasm(h.handler, h.id, analysis, sig_idx, mod, type_registry)
        if result !== nothing
            handler_results[h.id] = result
        end
    end

    # ─── Compile effect closures to WASM (stub — returns nothing for now) ───
    effect_results = Dict{Int, Any}()
    for eff in analysis.effects
        result = _compile_effect_wasm(eff.fn, eff.id, analysis, sig_idx, mod, type_registry)
        if result !== nothing
            effect_results[eff.id] = result
        end
    end

    # ─── Compile mount closures to WASM ───
    mount_results = Dict{Int, Any}()
    for mt in analysis.mount_effects
        result = _compile_mount_wasm(mt.fn, mt.id, analysis, sig_idx, mod, type_registry)
        if result !== nothing
            mount_results[mt.id] = result
        end
    end

    # ─── Compile memo closures to WASM ───
    memo_results = Dict{Int, Any}()
    for m in analysis.memos
        result = _compile_memo_wasm(m.fn, m.idx, analysis, sig_idx, mod, type_registry)
        if result !== nothing
            memo_results[m.idx] = result
        end
    end

    # ─── Serialize WASM to bytes ───
    wasm_bytes = WT.to_bytes(mod)

    # ─── Generate JS loader ───
    parts = String[]
    push!(parts, "(function() {")

    # therapyFor runtime (for For() nodes)
    if !isempty(analysis.for_nodes)
        for line in split(therapy_for_runtime_js(), "\n")
            push!(parts, "  $line")
        end
    end

    # Hydration function
    push!(parts, "  window.TherapyHydrate = window.TherapyHydrate || {};")
    push!(parts, "  function hydrate_$cn() {")
    push!(parts, "    document.querySelectorAll('[data-component=\"$cn\"]:not([data-hydrated])').forEach(function(island) {")
    push!(parts, "      island.dataset.hydrated = \"true\";")

    # Props
    has_prop_signals = !isempty(prop_names) && !isempty(analysis.signals) && length(analysis.signals) >= length(prop_names)
    if !isempty(prop_names)
        push!(parts, "      var props = JSON.parse(island.dataset.props || '{}');")
    end

    # ─── Inline WASM bytes as Uint8Array ───
    bytes_str = join(string.(wasm_bytes), ",")
    push!(parts, "      var _wb = new Uint8Array([$bytes_str]);")

    # ─── Import object for WASM module ───
    push!(parts, "      var _io = __tw.io(island);")

    # ─── js() imports: provide JS implementations for WASM imports ───
    js_imports = String[]
    for h in analysis.handlers
        result = get(handler_results, h.id, nothing)
        result === nothing && continue
        if hasproperty(result, :js_strings) && !isempty(result.js_strings)
            combined = join(result.js_strings, ";")
            push!(js_imports, "js_h$(h.id):function(){$combined}")
        end
    end
    # Effects with js() that use invoke_imports would go here too
    if !isempty(js_imports)
        push!(parts, "      _io.js={$(join(js_imports, ","))};")
    end

    # ─── Instantiate WASM ───
    push!(parts, "      WebAssembly.instantiate(_wb, _io).then(function(result) {")
    push!(parts, "        var ex = result.instance.exports;")

    # ─── Create JS signal mirrors for __t tracking ───
    for (i, sig) in enumerate(analysis.signals)
        idx = i - 1
        default = _js_initial_value(sig.initial_value)
        init_expr = if has_prop_signals && i <= length(prop_names)
            pname = string(prop_names[i])
            "props.$pname !== undefined ? props.$pname : $default"
        else
            default
        end
        if sig.shared_name !== nothing
            push!(parts, "        var s$idx = __t.shared(\"$(sig.shared_name)\", $init_expr);")
        else
            push!(parts, "        var s$idx = __t.signal($init_expr);")
        end
        # Sync initial prop value to WASM global
        if has_prop_signals && i <= length(prop_names)
            pname = string(prop_names[i])
            push!(parts, "        if (props.$pname !== undefined) ex.signal_$idx.value = BigInt(props.$pname);")
        end
        # Dark mode init: sync browser dark state to signal after creation
        # This handles the top-level js("if(...)$1(1)", set_dark) pattern
        if sig.shared_name !== nothing && occursin("dark", string(sig.shared_name))
            push!(parts, "        if(document.documentElement.classList.contains('dark')){s$(idx)[1](1);ex.signal_$(idx).value=BigInt(1);}")
        end
    end

    # ─── DOM refs ───
    needed_hks = Set{Int}()
    for h in analysis.handlers; push!(needed_hks, h.target_hk); end
    for b in analysis.bindings; push!(needed_hks, b.target_hk); end
    for mb in analysis.memo_bindings; push!(needed_hks, mb.target_hk); end
    for s in analysis.show_nodes
        push!(needed_hks, s.target_hk)
        s.fallback_hk > 0 && push!(needed_hks, s.fallback_hk)
    end
    for ib in analysis.input_bindings; push!(needed_hks, ib.target_hk); end
    for f in analysis.for_nodes; push!(needed_hks, f.target_hk); end
    for hk in sort(collect(needed_hks))
        push!(parts, "        var hk_$hk = island.querySelector('[data-hk=\"$hk\"]');")
    end

    # ─── Reactive Memos ───
    for m in analysis.memos
        result = get(memo_results, m.idx, nothing)
        if result !== nothing
            # WASM memo: JS __t.memo reads signals for tracking, calls WASM for computation
            dep_reads = _signal_dep_reads(m.fn, analysis, sig_idx)
            push!(parts, "        var m$(m.idx) = __t.memo(function(){$(dep_reads)return ex.$(result.export_name)();});")
        end
    end

    # ─── DOM Binding Effects (pure JS — reads signal mirrors) ───
    for b in analysis.bindings
        idx = get(sig_idx, b.signal_id, nothing)
        idx === nothing && continue
        if b.attribute === nothing
            push!(parts, "        __t.effect(function(){hk_$(b.target_hk).textContent=String(s$(idx)[0]());});")
        elseif b.attribute == :value
            push!(parts, "        __t.effect(function(){hk_$(b.target_hk).value=String(s$(idx)[0]());});")
        elseif b.attribute == :class
            push!(parts, "        __t.effect(function(){hk_$(b.target_hk).className=String(s$(idx)[0]());});")
        else
            push!(parts, "        __t.effect(function(){hk_$(b.target_hk).setAttribute(\"$(string(b.attribute))\",String(s$(idx)[0]()));});")
        end
    end

    # ─── Memo Binding Effects ───
    for mb in analysis.memo_bindings
        if mb.attribute === nothing
            push!(parts, "        __t.effect(function(){hk_$(mb.target_hk).textContent=String(m$(mb.memo_idx)());});")
        elseif mb.attribute == :value
            push!(parts, "        __t.effect(function(){hk_$(mb.target_hk).value=String(m$(mb.memo_idx)());});")
        else
            push!(parts, "        __t.effect(function(){hk_$(mb.target_hk).setAttribute(\"$(string(mb.attribute))\",String(m$(mb.memo_idx)()));});")
        end
    end

    # ─── Show() Effects ───
    for sn in analysis.show_nodes
        idx = get(sig_idx, sn.signal_id, nothing)
        idx === nothing && continue
        shk = sn.target_hk
        has_fallback = sn.fallback_hk > 0

        push!(parts, "        var _show_$(shk)_html = hk_$(shk).innerHTML;")
        push!(parts, "        hk_$(shk).innerHTML = '';")
        push!(parts, "        hk_$(shk).style.display = '';")

        if has_fallback
            fbhk = sn.fallback_hk
            push!(parts, "        var _show_$(shk)_fb = hk_$(fbhk).innerHTML;")
            push!(parts, "        hk_$(fbhk).innerHTML = '';")
            push!(parts, "        hk_$(fbhk).style.display = '';")
        end

        # Rewire function for handlers inside Show content
        inner_handlers = [(h, get(handler_results, h.id, nothing)) for h in analysis.handlers
                          if h.target_hk >= sn.content_hk_start && h.target_hk <= sn.content_hk_end]

        push!(parts, "        function _show_$(shk)_rewire() {")
        for (h, wasm_result) in inner_handlers
            hk_h = h.target_hk
            dom_event = event_name_to_dom(h.event)
            push!(parts, "          hk_$(hk_h) = hk_$(shk).querySelector('[data-hk=\"$(hk_h)\"]');")
            if wasm_result !== nothing
                modified = wasm_result.modified_signals
                presync_code = _handler_presync_js(analysis, sig_idx)
                sync_code = _handler_sync_js(modified, sig_idx, analysis)
                push!(parts, "          if (hk_$(hk_h)) hk_$(hk_h).addEventListener(\"$(dom_event)\", function(){__t.batch(function(){$(presync_code)ex.$(wasm_result.export_name)();$(sync_code)});});")
            end
        end
        push!(parts, "        }")

        push!(parts, "        var _show_$(shk)_vis;")
        push!(parts, "        __t.effect(function(){")
        push!(parts, "          var _s = !!s$(idx)[0]();")
        push!(parts, "          if (_s === _show_$(shk)_vis) return;")
        push!(parts, "          _show_$(shk)_vis = _s;")
        if has_fallback
            fbhk = sn.fallback_hk
            push!(parts, "          if (_s) { hk_$(shk).innerHTML = _show_$(shk)_html; _show_$(shk)_rewire(); hk_$(fbhk).innerHTML = ''; }")
            push!(parts, "          else { hk_$(shk).innerHTML = ''; hk_$(fbhk).innerHTML = _show_$(shk)_fb; }")
        else
            push!(parts, "          if (_s) { hk_$(shk).innerHTML = _show_$(shk)_html; _show_$(shk)_rewire(); }")
            push!(parts, "          else { hk_$(shk).innerHTML = ''; }")
        end
        push!(parts, "        });")
    end

    # ─── For() render functions + reactive effects ───
    for f in analysis.for_nodes
        result = _compile_for_render(f.render_fn, f.id)
        push!(parts, result.render_js)
        push!(parts, "        var _for_$(f.id)_update = therapyFor(hk_$(f.target_hk), _for_$(f.id)_render);")

        if f.items_type == :memo
            push!(parts, "        __t.effect(function(){_for_$(f.id)_update(m$(f.memo_idx)());});")
        elseif f.items_type == :signal
            sidx = get(sig_idx, f.signal_id, nothing)
            sidx !== nothing && push!(parts, "        __t.effect(function(){_for_$(f.id)_update(s$(sidx)[0]());});")
        end

        # For item event delegation
        if !isempty(result.item_handlers)
            for (event_sym, handler_fn) in result.item_handlers
                compiled = _compile_for_item_handler(handler_fn, f.id, event_sym, analysis, sig_idx)
                compiled === nothing && continue
                push!(parts, "        var $(compiled.idx_var) = 0;")
                push!(parts, compiled.func_js)
                dom_event = event_name_to_dom(event_sym)
                tag = result.item_tag
                fn_name = "_for_$(f.id)_$(string(event_sym)[4:end])"
                push!(parts, "        hk_$(f.target_hk).addEventListener(\"$dom_event\", function(e) {")
                push!(parts, "          var el = e.target.closest('$(tag)');")
                push!(parts, "          if (!el) return;")
                push!(parts, "          __t.batch(function(){")
                push!(parts, "            $(compiled.idx_var) = Array.from(hk_$(f.target_hk).children).indexOf(el) + 1;")
                push!(parts, "            $(fn_name)();")
                push!(parts, "          });")
                push!(parts, "        });")
            end
        end
    end

    # ─── Compiled Effects ───
    for eff in analysis.effects
        result = get(effect_results, eff.id, nothing)
        result === nothing && continue
        dep_reads = _signal_dep_reads(eff.fn, analysis, sig_idx)
        if hasproperty(result, :js_only) && result.js_only
            # Pure JS effect (e.g., println → console.log)
            push!(parts, "        __t.effect(function(){$(dep_reads)$(result.js_code)});")
        else
            # WASM effect, possibly with appended JS
            js_suffix = hasproperty(result, :js_strings) && !isempty(result.js_strings) ? join(result.js_strings, ";") * ";" : ""
            push!(parts, "        __t.effect(function(){$(dep_reads)ex.$(result.export_name)();$(js_suffix)});")
        end
    end

    # ─── Mount Effects ───
    for mt in analysis.mount_effects
        result = get(mount_results, mt.id, nothing)
        result === nothing && continue
        push!(parts, "        __t.onMount(function(){ex.$(result.export_name)();});")
    end

    # ─── Event Handlers ───
    show_hk_ranges = [(sn.content_hk_start, sn.content_hk_end) for sn in analysis.show_nodes]
    for h in analysis.handlers
        in_show = any(r -> h.target_hk >= r[1] && h.target_hk <= r[2], show_hk_ranges)
        dom_event = event_name_to_dom(h.event)
        wasm_result = get(handler_results, h.id, nothing)

        if wasm_result !== nothing && !in_show
            modified = wasm_result.modified_signals
            presync_code = _handler_presync_js(analysis, sig_idx)
            sync_code = _handler_sync_js(modified, sig_idx, analysis)
            # js() calls are now WASM imports — called from inside the WASM handler
            push!(parts, "        hk_$(h.target_hk).addEventListener(\"$dom_event\", function(){__t.batch(function(){$(presync_code)ex.$(wasm_result.export_name)();$(sync_code)});});")
        elseif wasm_result === nothing && !in_show
            # Fallback: tracing approach for non-closure handlers
            push!(parts, "        hk_$(h.target_hk).addEventListener(\"$dom_event\", function(){__t.batch(function(){")
            for op in h.operations
                idx = get(sig_idx, op.signal_id, nothing)
                idx === nothing && continue
                op_js = _operation_to_js(idx, op)
                op_js !== nothing && push!(parts, "          $op_js")
            end
            push!(parts, "        });});")
        end
    end

    # ─── Input Bindings ───
    for ib in analysis.input_bindings
        idx = get(sig_idx, ib.signal_id, nothing)
        idx === nothing && continue

        if ib.input_type == :number || ib.input_type == :range
            push!(parts, "        hk_$(ib.target_hk).addEventListener(\"input\", function(e){__t.batch(function(){var v=Number(e.target.value)||0;s$(idx)[1](v);ex.signal_$(idx).value=BigInt(v);});});")
        elseif ib.input_type == :checkbox
            push!(parts, "        hk_$(ib.target_hk).addEventListener(\"change\", function(e){__t.batch(function(){var v=e.target.checked?1:0;s$(idx)[1](v);ex.signal_$(idx).value=BigInt(v);});});")
        else
            push!(parts, "        hk_$(ib.target_hk).addEventListener(\"input\", function(e){__t.batch(function(){s$(idx)[1](e.target.value);});});")
        end
    end

    push!(parts, "      });")  # end .then
    push!(parts, "    });")    # end forEach
    push!(parts, "  }")
    push!(parts, "  window.TherapyHydrate[\"$cn\"] = hydrate_$cn;")
    push!(parts, "  if (!window._therapyRouterHydrating) hydrate_$cn();")
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
    elseif val isa AbstractVector
        items = join([_js_initial_value(v) for v in val], ",")
        return "[$items]"
    elseif val isa AbstractDict
        pairs = join(["\"$(escape_string(string(k)))\":$(_js_initial_value(v))" for (k, v) in val], ",")
        return "{$pairs}"
    else
        return string(val)
    end
end

"""Convert a TracedOperation to a JS statement (reactive runtime: sN[1](val)).
Used as fallback for non-closure handlers."""
function _operation_to_js(sig_idx::Int, op::TracedOperation)::Union{String, Nothing}
    g = "s$(sig_idx)[0]()"
    s = "s$(sig_idx)[1]"
    if op.operation == OP_INCREMENT
        return "$s(($g + 1) | 0);"
    elseif op.operation == OP_DECREMENT
        return "$s(($g - 1) | 0);"
    elseif op.operation == OP_ADD
        return "$s(($g + $(op.operand)) | 0);"
    elseif op.operation == OP_SUB
        return "$s(($g - $(op.operand)) | 0);"
    elseif op.operation == OP_MUL
        return "$s(($g * $(op.operand)) | 0);"
    elseif op.operation == OP_NEGATE
        return "$s((-$g) | 0);"
    elseif op.operation == OP_SET
        return "$s($(_js_initial_value(op.operand)));"
    elseif op.operation == OP_TOGGLE
        return "$s($g ? 0 : 1);"
    else
        return "/* unknown operation */"
    end
end

# ─── Signal dependency reads (for __t.effect tracking) ───

"""
Generate JS code that reads signal mirrors to trigger __t dependency tracking.
WASM functions read WasmGlobals directly (zero-crossing), but __t needs to
know about the dependency. We read the JS mirror to establish the subscription.
"""
function _signal_dep_reads(fn::Function, analysis::ComponentAnalysis,
                            sig_idx::Dict{UInt64, Int})::String
    reads = String[]
    closure_type = typeof(fn)
    for fname in fieldnames(closure_type)
        captured = getfield(fn, fname)
        gid = get(analysis.getter_map, captured, nothing)
        if gid !== nothing
            idx = get(sig_idx, gid, nothing)
            idx !== nothing && push!(reads, "s$(idx)[0]();")
        end
        if captured isa MemoAnalysisGetter
            midx = get(analysis.memo_getter_map, captured, nothing)
            midx !== nothing && push!(reads, "m$(midx)();")
        end
    end
    return join(reads)
end

# ─── Handler sync JS (WASM global → JS signal mirror) ───

"""
Generate JS code to sync shared JS signals INTO WASM globals before a handler runs.
Ensures WASM reads the latest cross-instance value for shared signals.
"""
function _handler_presync_js(analysis::ComponentAnalysis, sig_idx::Dict{UInt64, Int})::String
    syncs = String[]
    for (i, sig) in enumerate(analysis.signals)
        sig.shared_name === nothing && continue
        idx = i - 1
        push!(syncs, "ex.signal_$(idx).value=BigInt(s$(idx)[0]());")
    end
    return join(syncs)
end

"""
Generate JS code to sync WASM globals back to JS signals after a handler runs.
Only syncs signals that the handler modifies (writes).
"""
function _handler_sync_js(modified_signals::Vector{UInt64},
                           sig_idx::Dict{UInt64, Int},
                           analysis::ComponentAnalysis)::String
    syncs = String[]
    for sig_id in modified_signals
        idx = get(sig_idx, sig_id, nothing)
        idx === nothing && continue
        push!(syncs, "s$(idx)[1](Number(ex.signal_$(idx).value));")
    end
    return join(syncs)
end

# ─── js() / println() Extraction ───

"""
    _extract_js_calls(closure, analysis, sig_idx) -> (skip_indices, js_strings)

Pre-scan a closure's typed IR for js() calls. Returns the SSA indices to skip
during WASM compilation and the extracted JS code strings with \$N args resolved.

This implements the Leptos pattern: WASM does computation, JS does browser APIs.
js() strings are compile-time constants. \$1, \$2 etc. are resolved to their
JS signal/memo expressions (e.g., Number(s0[0]()), Number(m0())).
"""
function _extract_js_calls(closure::Function,
                            analysis::ComponentAnalysis=ComponentAnalysis(),
                            sig_idx::Dict{UInt64, Int}=Dict{UInt64, Int}())::Tuple{Set{Int}, Vector{String}}
    skip_indices = Set{Int}()
    js_strings = String[]

    typed_results = Base.code_typed(closure, ())
    isempty(typed_results) && return (skip_indices, js_strings)
    code_info = typed_results[1][1]

    # Build SSA id → JS expression map for resolving $N args.
    # Walk IR: getfield(_1, :fname) → SSA X, then SignalGetter(SSA X) → SSA Y.
    # Map SSA Y → "Number(sN[0]())" or "Number(mN())".
    ssa_js = Dict{Int, String}()
    closure_type = typeof(closure)
    # First pass: map getfield SSAs to their field names
    # Pattern: Core.getfield(_1, :field_name) → head=:call, args=[Core.getfield, Argument(1), QuoteNode(:name)]
    ssa_field = Dict{Int, Symbol}()
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3
            if stmt.args[1] isa GlobalRef && stmt.args[1].name === :getfield && stmt.args[3] isa QuoteNode
                ssa_field[i] = stmt.args[3].value::Symbol
            end
        end
    end
    # Second pass: map getter/memo call SSAs to JS expressions via field name
    # Getter invoke pattern: args = [CodeInstance, SSAValue] (2 args, self is arg[2])
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 2
            src = stmt.args[2]  # The "self" arg (the captured getter/memo object)
            src_id = src isa Core.SSAValue ? src.id : nothing
            fname = src_id !== nothing ? get(ssa_field, src_id, nothing) : nothing
            fname === nothing && continue
            # Look up the captured value by field name
            if fname in fieldnames(closure_type)
                captured = getfield(closure, fname)
                # Signal getter → Number(sN[0]())
                gid = get(analysis.getter_map, captured, nothing)
                if gid !== nothing
                    idx = get(sig_idx, gid, nothing)
                    idx !== nothing && (ssa_js[i] = "Number(s$(idx)[0]())")
                end
                # Memo getter → Number(mN())
                if captured isa MemoAnalysisGetter
                    midx = get(analysis.memo_getter_map, captured, nothing)
                    midx !== nothing && (ssa_js[i] = "Number(m$(midx)())")
                end
            end
        end
    end

    # Now extract js() calls and resolve $N args
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :invoke
            ci_or_mi = stmt.args[1]
            mi = if ci_or_mi isa Core.CodeInstance
                ci_or_mi.def
            elseif ci_or_mi isa Core.MethodInstance
                ci_or_mi
            else
                nothing
            end
            if mi isa Core.MethodInstance && mi.def isa Method && mi.def.name === :js
                push!(skip_indices, i)
                if length(stmt.args) >= 3
                    str_arg = stmt.args[3]
                    js_str = if str_arg isa String
                        str_arg
                    elseif str_arg isa QuoteNode
                        string(str_arg.value)
                    else
                        string(str_arg)
                    end
                    # Resolve $N args: stmt.args[4], [5], ... are the $1, $2, ... values
                    for n in 1:(length(stmt.args) - 3)
                        arg = stmt.args[3 + n]
                        js_expr = if arg isa Core.SSAValue
                            get(ssa_js, arg.id, "undefined")
                        else
                            string(arg)
                        end
                        js_str = replace(js_str, "\$$n" => js_expr)
                    end
                    push!(js_strings, js_str)
                end
                # Also skip any SSA values that are args to js() (signal getter calls etc.)
                for arg in stmt.args[4:end]
                    if arg isa Core.SSAValue
                        push!(skip_indices, arg.id)
                    end
                end
            end
        end
    end

    return (skip_indices, js_strings)
end


"""
    _extract_signal_ops_js(handler, analysis, sig_idx) -> Vector{String}

Extract signal operations from a handler's IR and emit as JS.
Used for js_fallback handlers where the tracer can't handle js() no-ops.

Detects patterns like:
  set_dark(1 - is_dark())  →  s0[1](1 - s0[0]());  (with WASM global sync)
"""
function _extract_signal_ops_js(handler::Function, analysis::ComponentAnalysis,
                                 sig_idx::Dict{UInt64, Int})::Vector{String}
    ops = String[]
    typed_results = Base.code_typed(handler, ())
    isempty(typed_results) && return ops
    code_info = typed_results[1][1]
    closure_type = typeof(handler)

    # Map getfield SSAs to field names
    ssa_field = Dict{Int, Symbol}()
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3
            if stmt.args[1] isa GlobalRef && stmt.args[1].name === :getfield && stmt.args[3] isa QuoteNode
                ssa_field[i] = stmt.args[3].value::Symbol
            end
        end
    end

    # Map SSAs to getter JS expressions
    ssa_getter_js = Dict{Int, String}()
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 2
            src = stmt.args[2]
            src_id = src isa Core.SSAValue ? src.id : nothing
            fname = src_id !== nothing ? get(ssa_field, src_id, nothing) : nothing
            fname === nothing && continue
            if fname in fieldnames(closure_type)
                captured = getfield(handler, fname)
                gid = get(analysis.getter_map, captured, nothing)
                if gid !== nothing
                    idx = get(sig_idx, gid, nothing)
                    idx !== nothing && (ssa_getter_js[i] = "s$(idx)[0]()")
                end
            end
        end
    end

    # Find setter calls: SignalSetter{T}(value) invocations
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 3
            ci_or_mi = stmt.args[1]
            mi = if ci_or_mi isa Core.CodeInstance; ci_or_mi.def
            elseif ci_or_mi isa Core.MethodInstance; ci_or_mi
            else; nothing; end
            mi === nothing && continue
            mi isa Core.MethodInstance || continue
            mi.specTypes === nothing && continue
            params = mi.specTypes.parameters
            length(params) >= 1 || continue
            params[1] <: SignalSetter || continue

            # This is a setter call. Find which signal.
            setter_src = stmt.args[2]  # The setter object SSA
            setter_src_id = setter_src isa Core.SSAValue ? setter_src.id : nothing
            setter_fname = setter_src_id !== nothing ? get(ssa_field, setter_src_id, nothing) : nothing
            setter_fname === nothing && continue
            if setter_fname in fieldnames(closure_type)
                captured = getfield(handler, setter_fname)
                sid = get(analysis.setter_map, captured, nothing)
                sid === nothing && continue
                idx = get(sig_idx, sid, nothing)
                idx === nothing && continue

                # Resolve the value being set (stmt.args[3])
                val_arg = stmt.args[3]
                val_js = _resolve_value_js(val_arg, code_info, ssa_getter_js)
                push!(ops, "s$(idx)[1]($val_js);")
                push!(ops, "ex.signal_$(idx).value=BigInt(s$(idx)[0]());")
            end
        end
    end
    return ops
end

"""Resolve an IR value to a JS expression string."""
function _resolve_value_js(val, code_info, ssa_getter_js)::String
    if val isa Core.SSAValue
        # Check if it's a known getter
        js = get(ssa_getter_js, val.id, nothing)
        js !== nothing && return js

        # Check if it's an arithmetic op (sub_int, add_int, etc.)
        stmt = code_info.code[val.id]
        if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3
            fname = stmt.args[1]
            op_name = if fname isa GlobalRef; fname.name
            elseif fname isa Core.IntrinsicFunction; nameof(fname)
            else; nothing; end

            if op_name !== nothing
                a = _resolve_value_js(stmt.args[2], code_info, ssa_getter_js)
                b = _resolve_value_js(stmt.args[3], code_info, ssa_getter_js)
                if op_name === :sub_int
                    return "($a - $b)"
                elseif op_name === :add_int
                    return "($a + $b)"
                elseif op_name === :mul_int
                    return "($a * $b)"
                end
            end
        end
        return "undefined"
    elseif val isa Integer
        return string(val)
    elseif val isa AbstractString
        return "'$(val)'"
    else
        return string(val)
    end
end

# ─── WasmTarget Handler Compilation ───

"""
    _compile_handler_wasm(handler, handler_id, analysis, sig_idx, mod, type_registry)

Compile a handler closure to WASM via WasmTarget.compile_closure_body().
Maps signal getters/setters to WasmGlobal reads/writes.
Returns (export_name, modified_signals) or nothing on failure.
"""
function _compile_handler_wasm(handler::Function, handler_id::Int,
                                analysis::ComponentAnalysis,
                                sig_idx::Dict{UInt64, Int},
                                mod::WT.WasmModule,
                                type_registry::WT.TypeRegistry)
    closure_type = typeof(handler)
    fnames = fieldnames(closure_type)

    # Non-closure functions — skip, use tracing fallback
    if isempty(fnames)
        return nothing
    end

    # Build captured_signal_fields: field_name -> (is_getter, global_idx)
    captured_signal_fields = Dict{Symbol, Tuple{Bool, UInt32}}()
    modified_signals = UInt64[]

    for field_name in fnames
        captured_value = getfield(handler, field_name)

        # Signal getter → global.get
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                captured_signal_fields[field_name] = (true, UInt32(idx))
                continue
            end
        end

        # Signal setter → global.set
        setter_sig_id = get(analysis.setter_map, captured_value, nothing)
        if setter_sig_id !== nothing
            idx = get(sig_idx, setter_sig_id, nothing)
            if idx !== nothing
                captured_signal_fields[field_name] = (false, UInt32(idx))
                push!(modified_signals, setter_sig_id)
                continue
            end
        end

        # Non-signal capture: skip (WasmTarget handles via closure struct)
    end

    # Extract js() calls — wire as WASM imports (Leptos pattern).
    # Consecutive js() calls are combined into a single import for shared scope.
    skip_indices, js_strings = _extract_js_calls(handler, analysis, sig_idx)

    # Register combined js() import on the WASM module
    invoke_imports = Dict{Int, UInt32}()
    if !isempty(js_strings)
        combined_js = join(js_strings, ";")
        js_import_idx = WT.add_import!(mod, "js", "js_h$(handler_id)", WT.NumType[], WT.NumType[])
        # Map the FIRST js() SSA to the import call; skip the rest
        first_js_ssa = minimum(skip_indices)
        invoke_imports[first_js_ssa] = js_import_idx
        delete!(skip_indices, first_js_ssa)
    end

    try
        body, locals = WT.compile_closure_body(
            handler, captured_signal_fields, mod, type_registry;
            skip_stmts=skip_indices,
            invoke_imports=invoke_imports,
            void_return=true
        )

        export_name = "_h$(handler_id)"
        func_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[], locals, body)
        WT.add_export!(mod, export_name, 0, func_idx)

        return (export_name=export_name, modified_signals=modified_signals, js_strings=js_strings)
    catch e
        @debug "WASM handler compilation failed, falling back to tracing" handler_id exception=e
        return nothing
    end
end

# ─── WasmTarget Effect Compilation ───

"""
    _compile_effect_wasm(effect_fn, effect_id, analysis, sig_idx, mod, type_registry)

Compile an effect closure to WASM. Effects read signals and perform side effects.

Effects that are purely js() calls (no WASM-compilable computation) are emitted
as pure JS — there's no computation that benefits from WASM.
"""
function _compile_effect_wasm(effect_fn::Function, effect_id::Int,
                               analysis::ComponentAnalysis,
                               sig_idx::Dict{UInt64, Int},
                               mod::WT.WasmModule,
                               type_registry::WT.TypeRegistry)
    closure_type = typeof(effect_fn)
    fnames = fieldnames(closure_type)

    if isempty(fnames)
        return nothing
    end

    # Extract js() calls with $N arg resolution
    skip_indices, js_strings = _extract_js_calls(effect_fn, analysis, sig_idx)

    # If the effect is ONLY js() calls (no other computation), emit as pure JS
    if !isempty(js_strings)
        js_code = join(js_strings, ";") * ";"
        return (js_only=true, js_code=js_code)
    end

    captured_signal_fields = Dict{Symbol, Tuple{Bool, UInt32}}()

    for field_name in fnames
        captured_value = getfield(effect_fn, field_name)

        # Signal getter
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                captured_signal_fields[field_name] = (true, UInt32(idx))
                continue
            end
        end

        # Memo getter
        if captured_value isa MemoAnalysisGetter
            memo_idx = get(analysis.memo_getter_map, captured_value, nothing)
            if memo_idx !== nothing
                continue
            end
        end
    end

    try
        body, locals = WT.compile_closure_body(
            effect_fn, captured_signal_fields, mod, type_registry;
            skip_stmts=skip_indices,
            void_return=true
        )

        export_name = "_effect_$(effect_id)"
        func_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[], locals, body)
        WT.add_export!(mod, export_name, 0, func_idx)

        return (export_name=export_name, js_strings=js_strings)
    catch e
        @debug "WASM effect compilation failed" effect_id exception=e
        return nothing
    end
end

# ─── WasmTarget Mount Compilation ───

"""
    _compile_mount_wasm(mount_fn, mount_id, analysis, sig_idx, mod, type_registry)

Compile an on_mount callback to WASM. Mounts run once after hydration.
Returns (export_name,) or nothing on failure.
"""
function _compile_mount_wasm(mount_fn::Function, mount_id::Int,
                              analysis::ComponentAnalysis,
                              sig_idx::Dict{UInt64, Int},
                              mod::WT.WasmModule,
                              type_registry::WT.TypeRegistry)
    closure_type = typeof(mount_fn)
    fnames = fieldnames(closure_type)
    captured_signal_fields = Dict{Symbol, Tuple{Bool, UInt32}}()

    for field_name in fnames
        captured_value = getfield(mount_fn, field_name)

        # Signal getter
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                captured_signal_fields[field_name] = (true, UInt32(idx))
                continue
            end
        end

        # Signal setter
        setter_sig_id = get(analysis.setter_map, captured_value, nothing)
        if setter_sig_id !== nothing
            idx = get(sig_idx, setter_sig_id, nothing)
            if idx !== nothing
                captured_signal_fields[field_name] = (false, UInt32(idx))
                continue
            end
        end

        # Memo getter
        if captured_value isa MemoAnalysisGetter
            memo_idx = get(analysis.memo_getter_map, captured_value, nothing)
            if memo_idx !== nothing
                continue
            end
        end
    end

    try
        body, locals = WT.compile_closure_body(
            mount_fn, captured_signal_fields, mod, type_registry;
            void_return=true
        )

        export_name = "_mount_$(mount_id)"
        func_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[], locals, body)
        WT.add_export!(mod, export_name, 0, func_idx)

        return (export_name=export_name,)
    catch e
        @debug "WASM mount compilation failed" mount_id exception=e
        return nothing
    end
end

# ─── WasmTarget Memo Compilation ───

"""
    _compile_memo_wasm(memo_fn, memo_idx, analysis, sig_idx, mod, type_registry)

Compile a memo closure to WASM. Memos are cached computations that return a value.
Returns (export_name,) or nothing on failure.
"""
function _compile_memo_wasm(memo_fn::Function, memo_idx::Int,
                             analysis::ComponentAnalysis,
                             sig_idx::Dict{UInt64, Int},
                             mod::WT.WasmModule,
                             type_registry::WT.TypeRegistry)
    closure_type = typeof(memo_fn)
    fnames = fieldnames(closure_type)

    if isempty(fnames)
        return nothing
    end

    captured_signal_fields = Dict{Symbol, Tuple{Bool, UInt32}}()

    for field_name in fnames
        captured_value = getfield(memo_fn, field_name)

        # Signal getter
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                captured_signal_fields[field_name] = (true, UInt32(idx))
                continue
            end
        end
    end

    try
        # Memos RETURN a value (not void)
        body, locals = WT.compile_closure_body(
            memo_fn, captured_signal_fields, mod, type_registry;
            void_return=false
        )

        export_name = "_memo_$(memo_idx)"
        # Memo returns i64 (Julia Int is Int64, matching signal globals)
        func_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[WT.I64], locals, body)
        WT.add_export!(mod, export_name, 0, func_idx)

        return (export_name=export_name,)
    catch e
        @debug "WASM memo compilation failed" memo_idx exception=e
        return nothing
    end
end

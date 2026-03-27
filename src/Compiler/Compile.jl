# Compile.jl - Main compiler API for Therapy.jl
#
# JST backend: compiles @island components to inline JavaScript.
# Uses analyze_component() to discover signals/handlers/bindings,
# then compiles handler closures via JavaScriptTarget.compile() and
# generates a self-contained JS IIFE for each island.

import JavaScriptTarget
const JST = JavaScriptTarget

include("Floating.jl")
include("Analysis.jl")
include("SignalRuntime.jl")
include("ReactiveRuntime.jl")
include("ForRuntime.jl")

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

    # Generate JS IIFE with prop names for data-props deserialization
    js = _generate_island_js(string(name), analysis; prop_names=island_def.prop_names)

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
function _generate_island_js(component_name::String, analysis::ComponentAnalysis;
                              prop_names::Vector{Symbol}=Symbol[])::String
    cn = lowercase(component_name)

    # Build signal_id -> index mapping
    sig_idx = Dict{UInt64, Int}()
    for (i, sig) in enumerate(analysis.signals)
        sig_idx[sig.id] = i - 1
    end

    # ─── Pre-compile handler/effect/memo bodies via JST ───
    # These produce the JS function bodies; the reactive runtime handles propagation.

    handler_results = Dict{Int, Any}()
    jst_runtime_code = ""
    for h in analysis.handlers
        result = _compile_handler_jst(h.handler, h.id, analysis, sig_idx)
        if result !== nothing
            handler_results[h.id] = result
            if !isempty(result.runtime_js)
                jst_runtime_code = result.runtime_js
            end
        end
    end

    effect_results = Dict{Int, Any}()
    for eff in analysis.effects
        result = _compile_effect_jst(eff.fn, eff.id, analysis, sig_idx)
        if result !== nothing
            effect_results[eff.id] = result
            if !isempty(result.runtime_js) && isempty(jst_runtime_code)
                jst_runtime_code = result.runtime_js
            end
        end
    end

    mount_results = Dict{Int, Any}()
    for mt in analysis.mount_effects
        result = _compile_effect_jst(mt.fn, mt.id, analysis, sig_idx)
        if result !== nothing
            mount_results[mt.id] = result
            if !isempty(result.runtime_js) && isempty(jst_runtime_code)
                jst_runtime_code = result.runtime_js
            end
        end
    end

    memo_results = Dict{Int, Any}()
    for m in analysis.memos
        result = _compile_memo_jst(m.fn, m.idx, analysis, sig_idx)
        if result !== nothing
            memo_results[m.idx] = result
            if !isempty(result.runtime_js) && isempty(jst_runtime_code)
                jst_runtime_code = result.runtime_js
            end
        end
    end

    # ─── Build the IIFE ───
    parts = String[]
    push!(parts, "(function() {")

    # JST runtime helpers (jl_println, etc.)
    if !isempty(jst_runtime_code)
        for line in split(jst_runtime_code, "\n")
            push!(parts, "  $line")
        end
    end

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

    # ─── Reactive Signals: __t.signal() or __t.shared() ───
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
            # External (module-level) signal → shared across islands
            push!(parts, "      var s$idx = __t.shared(\"$(sig.shared_name)\", $init_expr);")
        else
            push!(parts, "      var s$idx = __t.signal($init_expr);")
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
        push!(parts, "      var hk_$hk = island.querySelector('[data-hk=\"$hk\"]');")
    end

    # ─── Reactive Memos: __t.memo() ───
    for m in analysis.memos
        result = get(memo_results, m.idx, nothing)
        if result !== nothing
            # Emit the memo body as a __t.memo() call
            push!(parts, "      var m$(m.idx) = __t.memo($(result.func_js));")
        end
    end

    # ─── DOM Binding Effects: auto-track signal reads ───
    for b in analysis.bindings
        idx = get(sig_idx, b.signal_id, nothing)
        idx === nothing && continue
        if b.attribute === nothing
            push!(parts, "      __t.effect(function(){hk_$(b.target_hk).textContent=String(s$(idx)[0]());});")
        elseif b.attribute == :value
            push!(parts, "      __t.effect(function(){hk_$(b.target_hk).value=String(s$(idx)[0]());});")
        elseif b.attribute == :class
            push!(parts, "      __t.effect(function(){hk_$(b.target_hk).className=String(s$(idx)[0]());});")
        else
            push!(parts, "      __t.effect(function(){hk_$(b.target_hk).setAttribute(\"$(string(b.attribute))\",String(s$(idx)[0]()));});")
        end
    end

    # ─── Memo Binding Effects ───
    for mb in analysis.memo_bindings
        if mb.attribute === nothing
            push!(parts, "      __t.effect(function(){hk_$(mb.target_hk).textContent=String(m$(mb.memo_idx)());});")
        elseif mb.attribute == :value
            push!(parts, "      __t.effect(function(){hk_$(mb.target_hk).value=String(m$(mb.memo_idx)());});")
        else
            push!(parts, "      __t.effect(function(){hk_$(mb.target_hk).setAttribute(\"$(string(mb.attribute))\",String(m$(mb.memo_idx)()));});")
        end
    end

    # ─── Show() Effects: DOM insertion/removal + fallback ───
    for sn in analysis.show_nodes
        idx = get(sig_idx, sn.signal_id, nothing)
        idx === nothing && continue
        shk = sn.target_hk
        has_fallback = sn.fallback_hk > 0

        # Capture content HTML, clear immediately (effect handles initial state)
        push!(parts, "      var _show_$(shk)_html = hk_$(shk).innerHTML;")
        push!(parts, "      hk_$(shk).innerHTML = '';")
        push!(parts, "      hk_$(shk).style.display = '';")

        # Capture fallback HTML if present
        if has_fallback
            fbhk = sn.fallback_hk
            push!(parts, "      var _show_$(shk)_fb = hk_$(fbhk).innerHTML;")
            push!(parts, "      hk_$(fbhk).innerHTML = '';")
            push!(parts, "      hk_$(fbhk).style.display = '';")
        end

        # Rewire function for handlers inside Show content
        inner_handlers = [(h, get(handler_results, h.id, nothing)) for h in analysis.handlers
                          if h.target_hk >= sn.content_hk_start && h.target_hk <= sn.content_hk_end]

        push!(parts, "      function _show_$(shk)_rewire() {")
        for (h, jst_result) in inner_handlers
            hk_h = h.target_hk
            dom_event = event_name_to_dom(h.event)
            push!(parts, "        hk_$(hk_h) = hk_$(shk).querySelector('[data-hk=\"$(hk_h)\"]');")
            if jst_result !== nothing
                push!(parts, "        if (hk_$(hk_h)) hk_$(hk_h).addEventListener(\"$(dom_event)\", function(){__t.batch(function(){_h$(h.id)();});});")
            end
        end
        push!(parts, "      }")

        # Show effect: auto-tracks condition signal, swaps content/fallback
        push!(parts, "      var _show_$(shk)_vis;")
        push!(parts, "      __t.effect(function(){")
        push!(parts, "        var _s = !!s$(idx)[0]();")
        push!(parts, "        if (_s === _show_$(shk)_vis) return;")
        push!(parts, "        _show_$(shk)_vis = _s;")
        if has_fallback
            fbhk = sn.fallback_hk
            push!(parts, "        if (_s) { hk_$(shk).innerHTML = _show_$(shk)_html; _show_$(shk)_rewire(); hk_$(fbhk).innerHTML = ''; }")
            push!(parts, "        else { hk_$(shk).innerHTML = ''; hk_$(fbhk).innerHTML = _show_$(shk)_fb; }")
        else
            push!(parts, "        if (_s) { hk_$(shk).innerHTML = _show_$(shk)_html; _show_$(shk)_rewire(); }")
            push!(parts, "        else { hk_$(shk).innerHTML = ''; }")
        end
        push!(parts, "      });")
    end

    # ─── For() render functions + reactive effects ───
    for f in analysis.for_nodes
        result = _compile_for_render(f.render_fn, f.id)
        push!(parts, result.render_js)
        push!(parts, "      var _for_$(f.id)_update = therapyFor(hk_$(f.target_hk), _for_$(f.id)_render);")

        # For update effect: auto-tracks the items signal/memo
        if f.items_type == :memo
            push!(parts, "      __t.effect(function(){_for_$(f.id)_update(m$(f.memo_idx)());});")
        elseif f.items_type == :signal
            sidx = get(sig_idx, f.signal_id, nothing)
            sidx !== nothing && push!(parts, "      __t.effect(function(){_for_$(f.id)_update(s$(sidx)[0]());});")
        end

        # For item event delegation (e.g., click on header Th)
        if !isempty(result.item_handlers)
            for (event_sym, handler_fn) in result.item_handlers
                compiled = _compile_for_item_handler(handler_fn, f.id, event_sym, analysis, sig_idx)
                compiled === nothing && continue
                push!(parts, "      var $(compiled.idx_var) = 0;")
                push!(parts, compiled.func_js)
                dom_event = event_name_to_dom(event_sym)
                tag = result.item_tag
                fn_name = "_for_$(f.id)_$(string(event_sym)[4:end])"
                push!(parts, "      hk_$(f.target_hk).addEventListener(\"$dom_event\", function(e) {")
                push!(parts, "        var el = e.target.closest('$(tag)');")
                push!(parts, "        if (!el) return;")
                push!(parts, "        __t.batch(function(){")
                push!(parts, "          $(compiled.idx_var) = Array.from(hk_$(f.target_hk).children).indexOf(el) + 1;")
                push!(parts, "          $(fn_name)();")
                push!(parts, "        });")
                push!(parts, "      });")
            end
        end
    end

    # ─── Compiled Effects: __t.effect() ───
    for eff in analysis.effects
        result = get(effect_results, eff.id, nothing)
        result === nothing && continue
        push!(parts, "      __t.effect($(result.func_js));")
    end

    # ─── Mount Effects: __t.onMount() — runs once after hydration ───
    for mt in analysis.mount_effects
        result = get(mount_results, mt.id, nothing)
        result === nothing && continue
        push!(parts, "      __t.onMount($(result.func_js));")
    end

    # ─── Event Handlers: just set signals, runtime propagates everything ───
    # Handlers inside Show content: emit function declaration but skip addEventListener
    # (Show's rewire function handles the wiring after DOM re-insertion).
    show_hk_ranges = [(sn.content_hk_start, sn.content_hk_end) for sn in analysis.show_nodes]
    for h in analysis.handlers
        in_show = any(r -> h.target_hk >= r[1] && h.target_hk <= r[2], show_hk_ranges)
        dom_event = event_name_to_dom(h.event)
        jst_result = get(handler_results, h.id, nothing)

        if jst_result !== nothing
            # Always emit function declaration (needed by Show rewire)
            push!(parts, jst_result.func_js)
            # Only wire addEventListener if NOT inside a Show
            if !in_show
                push!(parts, "      hk_$(h.target_hk).addEventListener(\"$dom_event\", function(){__t.batch(function(){_h$(h.id)();});});")
            end
        else
            # Fallback: tracing approach (legacy)
            push!(parts, "      hk_$(h.target_hk).addEventListener(\"$dom_event\", function(){__t.batch(function(){")
            for op in h.operations
                idx = get(sig_idx, op.signal_id, nothing)
                idx === nothing && continue
                op_js = _operation_to_js(idx, op)
                op_js !== nothing && push!(parts, "        $op_js")
            end
            push!(parts, "      });});")
        end
    end

    # ─── Input Bindings: set signal, runtime handles the rest ───
    for ib in analysis.input_bindings
        idx = get(sig_idx, ib.signal_id, nothing)
        idx === nothing && continue

        if ib.input_type == :number || ib.input_type == :range
            push!(parts, "      hk_$(ib.target_hk).addEventListener(\"input\", function(e){__t.batch(function(){s$(idx)[1](Number(e.target.value)||0);});});")
        elseif ib.input_type == :checkbox
            push!(parts, "      hk_$(ib.target_hk).addEventListener(\"change\", function(e){__t.batch(function(){s$(idx)[1](e.target.checked?1:0);});});")
        else
            push!(parts, "      hk_$(ib.target_hk).addEventListener(\"input\", function(e){__t.batch(function(){s$(idx)[1](e.target.value);});});")
        end
    end

    push!(parts, "    });")
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

"""Convert a TracedOperation to a JS statement (reactive runtime: sN[1](val))."""
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

# ─── IR Fallback: optimized → unoptimized for array code ───

"""
Get typed IR, falling back to optimize=false if optimized IR uses array internals.
This enables Julia array code (push!, Float64[], for loops) to compile to JS arrays.
"""
function _get_ir_with_fallback(f, arg_types)
    # Try optimized first
    code_info, return_type = JST.get_typed_ir(f, arg_types; optimize=true)

    # Check if IR uses array memory internals (memorynew, memoryrefnew, _growend!)
    needs_unoptimized = false
    for stmt in code_info.code
        if stmt isa Expr
            if stmt.head === :call && length(stmt.args) >= 1
                callee = stmt.args[1]
                # Check GlobalRef names
                if callee isa GlobalRef && callee.name in (:memorynew, :memoryrefnew, :memoryrefset!)
                    needs_unoptimized = true
                    break
                end
                # Check Core builtins (memorynew is a Core builtin, not a GlobalRef)
                callee_name = string(callee isa Core.Builtin ? nameof(typeof(callee)) : callee isa GlobalRef ? callee.name : "")
                if callee_name in ("memorynew", "memoryrefnew", "memoryrefset!")
                    needs_unoptimized = true
                    break
                end
            elseif stmt.head === :invoke && length(stmt.args) >= 1
                ci_or_mi = stmt.args[1]
                mi = ci_or_mi isa Core.CodeInstance ? ci_or_mi.def : ci_or_mi
                meth = mi.def
                if contains(string(meth.name), "_growend!")
                    needs_unoptimized = true
                    break
                end
            end
        end
    end

    if needs_unoptimized
        @debug "JST: falling back to optimize=false for array compilation"
        code_info, return_type = JST.get_typed_ir(f, arg_types; optimize=false)
    end

    return code_info, return_type
end

# ─── JST Handler Compilation ───

"""
    _compile_handler_jst(handler, handler_id, analysis, sig_idx)

Compile a handler closure to JavaScript via JavaScriptTarget.compile().

Maps signal getters/setters to JS variable reads/writes using callable_overrides.
Returns a NamedTuple (func_js, runtime_js, modified_signals) or nothing on failure.
"""
function _compile_handler_jst(handler::Function, handler_id::Int,
                               analysis::ComponentAnalysis,
                               sig_idx::Dict{UInt64, Int})
    closure_type = typeof(handler)
    fnames = fieldnames(closure_type)

    # Non-closure functions (no captured fields) — skip JST, use tracing fallback
    if isempty(fnames)
        return nothing
    end

    # Build captured_vars and callable_overrides from closure fields
    captured_vars = Dict{Symbol, String}()
    callable_overrides = Dict{DataType, Function}()
    modified_signals = UInt64[]

    for field_name in fnames
        captured_value = getfield(handler, field_name)

        # Check if signal getter
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                captured_vars[field_name] = "s$idx[0]"
                getter_type = typeof(captured_value)
                if !haskey(callable_overrides, getter_type)
                    callable_overrides[getter_type] = (recv_js, _args_js) -> "$(recv_js)()"
                end
                continue
            end
        end

        # Check if signal setter
        setter_sig_id = get(analysis.setter_map, captured_value, nothing)
        if setter_sig_id !== nothing
            idx = get(sig_idx, setter_sig_id, nothing)
            if idx !== nothing
                captured_vars[field_name] = "s$idx[1]"
                push!(modified_signals, setter_sig_id)
                setter_type = typeof(captured_value)
                if !haskey(callable_overrides, setter_type)
                    callable_overrides[setter_type] = (recv_js, args_js) -> "$(recv_js)($(args_js[1]))"
                end
                continue
            end
        end

        # Non-signal capture: emit as JS literal
        captured_vars[field_name] = _js_initial_value(captured_value)
    end

    # Compile via JST using lower-level API for separate runtime/function access
    try
        code_info, return_type = _get_ir_with_fallback(handler, ())
        ctx = JST.JSCompilationContext(code_info, (), return_type, "_h$handler_id")
        merge!(ctx.captured_vars, captured_vars)
        merge!(ctx.callable_overrides, callable_overrides)

        func_js = JST.compile_function(ctx)
        runtime_js = JST.get_runtime_code(ctx.required_runtime)

        # Indent the function body for placement inside forEach
        indented_lines = String[]
        for line in split(strip(func_js), "\n")
            push!(indented_lines, "      $line")
        end
        indented_func = join(indented_lines, "\n")

        return (func_js=indented_func, runtime_js=runtime_js, modified_signals=modified_signals)
    catch e
        @debug "JST handler compilation failed, falling back to tracing" handler_id exception=e
        return nothing
    end
end

# ─── JST Effect Compilation ───

"""
    _compile_effect_jst(effect_fn, effect_id, analysis, sig_idx)

Compile an effect closure to JavaScript via JavaScriptTarget.compile().
Maps signal getters to JS variable reads and memo getters to memo variable reads.
Returns (func_js, runtime_js) or nothing on failure.
"""
function _compile_effect_jst(effect_fn::Function, effect_id::Int,
                              analysis::ComponentAnalysis,
                              sig_idx::Dict{UInt64, Int})
    closure_type = typeof(effect_fn)
    fnames = fieldnames(closure_type)

    if isempty(fnames)
        return nothing
    end

    captured_vars = Dict{Symbol, String}()
    callable_overrides = Dict{DataType, Function}()

    for field_name in fnames
        captured_value = getfield(effect_fn, field_name)

        # Signal getter
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                captured_vars[field_name] = "s$idx[0]"
                getter_type = typeof(captured_value)
                if !haskey(callable_overrides, getter_type)
                    callable_overrides[getter_type] = (recv_js, _args_js) -> "$(recv_js)()"
                end
                continue
            end
        end

        # Memo getter (MemoAnalysisGetter)
        if captured_value isa MemoAnalysisGetter
            memo_idx = get(analysis.memo_getter_map, captured_value, nothing)
            if memo_idx !== nothing
                captured_vars[field_name] = "m$memo_idx"
                memo_type = typeof(captured_value)
                if !haskey(callable_overrides, memo_type)
                    callable_overrides[memo_type] = (recv_js, _args_js) -> "$(recv_js)()"
                end
                continue
            end
        end

        # Non-signal, non-memo capture
        captured_vars[field_name] = _js_initial_value(captured_value)
    end

    try
        code_info, return_type = _get_ir_with_fallback(effect_fn, ())
        ctx = JST.JSCompilationContext(code_info, (), return_type, "_effect_$effect_id")
        merge!(ctx.captured_vars, captured_vars)
        merge!(ctx.callable_overrides, callable_overrides)

        func_js = JST.compile_function(ctx)
        runtime_js = JST.get_runtime_code(ctx.required_runtime)

        indented_lines = String[]
        for line in split(strip(func_js), "\n")
            push!(indented_lines, "      $line")
        end

        return (func_js=join(indented_lines, "\n"), runtime_js=runtime_js)
    catch e
        @debug "JST effect compilation failed" effect_id exception=e
        return nothing
    end
end

# ─── JST Memo Compilation ───

"""
    _compile_memo_jst(memo_fn, memo_idx, analysis, sig_idx)

Compile a memo closure to JavaScript via JavaScriptTarget.compile().
The compiled function returns the recomputed value.
Returns (func_js, runtime_js) or nothing on failure.
"""
function _compile_memo_jst(memo_fn::Function, memo_idx::Int,
                            analysis::ComponentAnalysis,
                            sig_idx::Dict{UInt64, Int})
    closure_type = typeof(memo_fn)
    fnames = fieldnames(closure_type)

    if isempty(fnames)
        return nothing
    end

    captured_vars = Dict{Symbol, String}()
    callable_overrides = Dict{DataType, Function}()

    for field_name in fnames
        captured_value = getfield(memo_fn, field_name)

        # Signal getter
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                captured_vars[field_name] = "s$idx[0]"
                getter_type = typeof(captured_value)
                if !haskey(callable_overrides, getter_type)
                    callable_overrides[getter_type] = (recv_js, _args_js) -> "$(recv_js)()"
                end
                continue
            end
        end

        # Non-signal capture
        captured_vars[field_name] = _js_initial_value(captured_value)
    end

    try
        code_info, return_type = _get_ir_with_fallback(memo_fn, ())
        ctx = JST.JSCompilationContext(code_info, (), return_type, "_memo_$(memo_idx)_recompute")
        merge!(ctx.captured_vars, captured_vars)
        merge!(ctx.callable_overrides, callable_overrides)

        func_js = JST.compile_function(ctx)
        runtime_js = JST.get_runtime_code(ctx.required_runtime)

        indented_lines = String[]
        for line in split(strip(func_js), "\n")
            push!(indented_lines, "      $line")
        end

        return (func_js=join(indented_lines, "\n"), runtime_js=runtime_js)
    catch e
        @debug "JST memo compilation failed" memo_idx exception=e
        return nothing
    end
end

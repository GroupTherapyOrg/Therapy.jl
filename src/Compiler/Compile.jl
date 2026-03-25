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

    # Build signal_id -> index mapping (needed for handler compilation)
    sig_idx = Dict{UInt64, Int}()
    for (i, sig) in enumerate(analysis.signals)
        sig_idx[sig.id] = i - 1
    end

    # Build binding map: signal_id -> list of (hk, attribute)
    binding_map = Dict{UInt64, Vector{Tuple{Int, Union{Symbol, Nothing}}}}()
    for b in analysis.bindings
        if !haskey(binding_map, b.signal_id)
            binding_map[b.signal_id] = Tuple{Int, Union{Symbol, Nothing}}[]
        end
        push!(binding_map[b.signal_id], (b.target_hk, b.attribute))
    end

    # Build memo binding map: memo_idx -> list of (hk, attribute)
    memo_binding_map = Dict{Int, Vector{Tuple{Int, Union{Symbol, Nothing}}}}()
    for mb in analysis.memo_bindings
        if !haskey(memo_binding_map, mb.memo_idx)
            memo_binding_map[mb.memo_idx] = Tuple{Int, Union{Symbol, Nothing}}[]
        end
        push!(memo_binding_map[mb.memo_idx], (mb.target_hk, mb.attribute))
    end

    # Pre-compile all handlers via JST (so we know runtime helpers needed)
    handler_results = Dict{Int, Any}()  # handler_id -> compilation result or nothing
    jst_runtime_code = ""
    for h in analysis.handlers
        result = _compile_handler_jst(h.handler, h.id, analysis, sig_idx)
        if result !== nothing
            handler_results[h.id] = result
            if !isempty(result.runtime_js)
                jst_runtime_code = result.runtime_js  # All handlers share the same runtime
            end
        end
    end

    # Pre-compile effects via JST
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

    # Pre-compile memos via JST
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

    # Build the IIFE
    parts = String[]

    push!(parts, "(function() {")

    # JST runtime helpers at IIFE scope (stateless, shared across all island instances)
    if !isempty(jst_runtime_code)
        for line in split(jst_runtime_code, "\n")
            push!(parts, "  $line")
        end
    end

    # therapyFor runtime (if any dynamic For nodes)
    if !isempty(analysis.for_nodes)
        for line in split(therapy_for_runtime_js(), "\n")
            push!(parts, "  $line")
        end
    end

    # Register hydration function with TherapyHydrate for SPA re-hydration
    push!(parts, "  window.TherapyHydrate = window.TherapyHydrate || {};")
    push!(parts, "  function hydrate_$cn() {")
    push!(parts, "    document.querySelectorAll('[data-component=\"$cn\"]:not([data-hydrated])').forEach(function(island) {")
    push!(parts, "      island.dataset.hydrated = \"true\";")

    # Read props from data-props attribute (set by SSR)
    # Only map props → signals when there are at least as many signals as props
    # (i.e., each prop corresponds to a signal). When the island has more props
    # than signals, the props don't map 1-to-1 — emit them as a separate object.
    has_prop_signals = !isempty(prop_names) && !isempty(analysis.signals) && length(analysis.signals) >= length(prop_names)
    if !isempty(prop_names)
        push!(parts, "      var props = JSON.parse(island.dataset.props || '{}');")
    end

    # Declare signal variables
    for (i, sig) in enumerate(analysis.signals)
        idx = i - 1
        default = _js_initial_value(sig.initial_value)
        if has_prop_signals && i <= length(prop_names)
            pname = string(prop_names[i])
            push!(parts, "      let signal_$idx = props.$pname !== undefined ? props.$pname : $default;")
        else
            push!(parts, "      let signal_$idx = $default;")
        end
    end

    # Declare memo variables (initial values from analysis)
    for m in analysis.memos
        push!(parts, "      let memo_$(m.idx) = $(_js_initial_value(m.initial_value));")
    end

    # Collect all hk values that need DOM references
    needed_hks = Set{Int}()
    for h in analysis.handlers
        push!(needed_hks, h.target_hk)
    end
    for b in analysis.bindings
        push!(needed_hks, b.target_hk)
    end
    for mb in analysis.memo_bindings
        push!(needed_hks, mb.target_hk)
    end
    for s in analysis.show_nodes
        push!(needed_hks, s.target_hk)
    end
    for ib in analysis.input_bindings
        push!(needed_hks, ib.target_hk)
    end
    for f in analysis.for_nodes
        push!(needed_hks, f.target_hk)
    end

    # Declare DOM element references (scoped to island)
    for hk in sort(collect(needed_hks))
        push!(parts, "      var hk_$hk = island.querySelector('[data-hk=\"$hk\"]');")
    end

    # Emit compiled effect functions
    for eff in analysis.effects
        result = get(effect_results, eff.id, nothing)
        if result !== nothing
            push!(parts, result.func_js)
        end
    end

    # Emit compiled memo recomputation functions
    for m in analysis.memos
        result = get(memo_results, m.idx, nothing)
        if result !== nothing
            push!(parts, result.func_js)
        end
    end

    # Emit For() render functions, updaters, and item event delegation
    for_render_results = Dict{Int, ForRenderResult}()
    for_handler_results = Dict{Int, Vector{Any}}()  # for_id -> [(event, compiled_result), ...]

    for f in analysis.for_nodes
        # Compile render function from VNode template via marker analysis
        result = _compile_for_render(f.render_fn, f.id)
        for_render_results[f.id] = result
        push!(parts, result.render_js)

        # Create updater: therapyFor(container, renderItem) returns update(items) function
        push!(parts, "      var _for_$(f.id)_update = therapyFor(hk_$(f.target_hk), _for_$(f.id)_render);")

        # Compile item event handlers (e.g., on_click on header Th elements)
        if !isempty(result.item_handlers)
            compiled_handlers = Any[]
            for (event_sym, handler_fn) in result.item_handlers
                compiled = _compile_for_item_handler(handler_fn, f.id, event_sym, analysis, sig_idx)
                if compiled !== nothing
                    push!(compiled_handlers, (event_sym, compiled))

                    # Declare shared idx variable
                    push!(parts, "      var $(compiled.idx_var) = 0;")

                    # Emit compiled handler function
                    push!(parts, compiled.func_js)

                    # Generate event delegation on the For container
                    dom_event = event_name_to_dom(event_sym)
                    tag = result.item_tag
                    fn_name = "_for_$(f.id)_$(string(event_sym)[4:end])"

                    push!(parts, "      hk_$(f.target_hk).addEventListener(\"$dom_event\", function(e) {")
                    push!(parts, "        var el = e.target.closest('$(tag)');")
                    push!(parts, "        if (!el) return;")
                    push!(parts, "        $(compiled.idx_var) = Array.from(hk_$(f.target_hk).children).indexOf(el) + 1;")
                    push!(parts, "        $(fn_name)();")

                    # DOM updates for signals modified by this handler
                    for mod_sig_id in compiled.modified_signals
                        idx = get(sig_idx, mod_sig_id, nothing)
                        idx === nothing && continue
                        if haskey(binding_map, mod_sig_id)
                            for (bhk, attr) in binding_map[mod_sig_id]
                                push!(parts, "        $(_binding_update_js(idx, bhk, attr))")
                            end
                        end
                    end

                    # Recompute memos that depend on modified signals
                    handler_memos_recomputed = Set{Int}()
                    for m in analysis.memos
                        if any(dep in Set(compiled.modified_signals) for dep in m.dependencies)
                            if haskey(memo_results, m.idx)
                                push!(parts, "        memo_$(m.idx) = _memo_$(m.idx)_recompute();")
                                push!(handler_memos_recomputed, m.idx)
                            end
                            if haskey(memo_binding_map, m.idx)
                                for (bhk, attr) in memo_binding_map[m.idx]
                                    push!(parts, "        $(_memo_binding_update_js(m.idx, bhk, attr))")
                                end
                            end
                        end
                    end

                    # Update For nodes that depend on recomputed memos
                    for f2 in analysis.for_nodes
                        should_update = (f2.items_type == :signal && f2.signal_id in Set(compiled.modified_signals)) ||
                                        (f2.items_type == :memo && f2.memo_idx in handler_memos_recomputed)
                        if should_update
                            if f2.items_type == :memo
                                push!(parts, "        _for_$(f2.id)_update(memo_$(f2.memo_idx));")
                            elseif f2.items_type == :signal
                                sidx = get(sig_idx, f2.signal_id, nothing)
                                sidx !== nothing && push!(parts, "        _for_$(f2.id)_update(signal_$(sidx));")
                            end
                        end
                    end

                    # Run effects
                    for eff in analysis.effects
                        should_run = any(dep in Set(compiled.modified_signals) for dep in eff.signal_deps) ||
                                     any(mi in handler_memos_recomputed for mi in eff.memo_deps)
                        if should_run && haskey(effect_results, eff.id)
                            push!(parts, "        _effect_$(eff.id)();")
                        end
                    end

                    push!(parts, "      });")
                end
            end
            for_handler_results[f.id] = compiled_handlers
        end
    end

    # ─── Show() runtime: SolidJS-style DOM insertion/removal ───
    # For each Show node, capture content HTML and generate update/rewire functions.
    # When signal changes: content is removed (innerHTML='') or re-inserted + handlers re-wired.
    for sn in analysis.show_nodes
        idx = get(sig_idx, sn.signal_id, nothing)
        idx === nothing && continue
        shk = sn.target_hk

        # Capture initial content HTML, then prepare for DOM insertion/removal.
        # Set _vis to opposite of actual state so the first _update() call always triggers.
        # Remove SSR style="display:none" since we use innerHTML swap, not CSS.
        push!(parts, "      var _show_$(shk)_html = hk_$(shk).innerHTML;")
        push!(parts, "      var _show_$(shk)_vis = $(sn.initial_visible ? "false" : "true");")
        push!(parts, "      hk_$(shk).style.display = '';")

        # Find handlers whose target_hk is inside this Show's content range
        inner_handlers = [(h, get(handler_results, h.id, nothing)) for h in analysis.handlers
                          if h.target_hk >= sn.content_hk_start && h.target_hk <= sn.content_hk_end]

        # Generate rewire function (re-attaches event listeners after DOM insertion)
        push!(parts, "      function _show_$(shk)_rewire() {")
        for (h, jst_result) in inner_handlers
            hk_h = h.target_hk
            dom_event = event_name_to_dom(h.event)
            push!(parts, "        hk_$(hk_h) = hk_$(shk).querySelector('[data-hk=\"$(hk_h)\"]');")
            push!(parts, "        if (hk_$(hk_h)) hk_$(hk_h).addEventListener(\"$(dom_event)\", function() {")
            if jst_result !== nothing
                push!(parts, "          _h$(h.id)();")
                # Signal DOM updates
                for mod_sig_id in jst_result.modified_signals
                    midx = get(sig_idx, mod_sig_id, nothing)
                    midx === nothing && continue
                    if haskey(binding_map, mod_sig_id)
                        for (bhk, attr) in binding_map[mod_sig_id]
                            push!(parts, "          $(_binding_update_js(midx, bhk, attr))")
                        end
                    end
                end
                # Show updates for all Show nodes affected by this handler
                for sn2 in analysis.show_nodes
                    if sn2.signal_id in Set(jst_result.modified_signals)
                        push!(parts, "          _show_$(sn2.target_hk)_update();")
                    end
                end
                # Memo recompute + For update
                memos_rc = Set{Int}()
                for m in analysis.memos
                    if any(dep in Set(jst_result.modified_signals) for dep in m.dependencies)
                        if haskey(memo_results, m.idx)
                            push!(parts, "          memo_$(m.idx) = _memo_$(m.idx)_recompute();")
                            push!(memos_rc, m.idx)
                        end
                    end
                end
                for f in analysis.for_nodes
                    should_update = (f.items_type == :signal && f.signal_id in Set(jst_result.modified_signals)) ||
                                    (f.items_type == :memo && f.memo_idx in memos_rc)
                    if should_update
                        if f.items_type == :memo
                            push!(parts, "          _for_$(f.id)_update(memo_$(f.memo_idx));")
                        elseif f.items_type == :signal
                            sidx = get(sig_idx, f.signal_id, nothing)
                            sidx !== nothing && push!(parts, "          _for_$(f.id)_update(signal_$(sidx));")
                        end
                    end
                end
                # Effects
                for eff in analysis.effects
                    should_run = any(dep in Set(jst_result.modified_signals) for dep in eff.signal_deps) ||
                                 any(mi in memos_rc for mi in eff.memo_deps)
                    if should_run && haskey(effect_results, eff.id)
                        push!(parts, "          _effect_$(eff.id)();")
                    end
                end
            end
            push!(parts, "        });")
        end
        # Update bindings inside Show (textContent etc.)
        for b in analysis.bindings
            if b.target_hk >= sn.content_hk_start && b.target_hk <= sn.content_hk_end
                bidx = get(sig_idx, b.signal_id, nothing)
                bidx === nothing && continue
                push!(parts, "        var _el = hk_$(shk).querySelector('[data-hk=\"$(b.target_hk)\"]');")
                push!(parts, "        if (_el) _el.textContent = String(signal_$(bidx));")
            end
        end
        push!(parts, "      }")

        # Generate update function (swaps content in/out)
        push!(parts, "      function _show_$(shk)_update() {")
        push!(parts, "        var _s = !!signal_$(idx);")
        push!(parts, "        if (_s === _show_$(shk)_vis) return;")
        push!(parts, "        _show_$(shk)_vis = _s;")
        push!(parts, "        if (_s) {")
        push!(parts, "          hk_$(shk).innerHTML = _show_$(shk)_html;")
        if !isempty(inner_handlers) || any(b -> b.target_hk >= sn.content_hk_start && b.target_hk <= sn.content_hk_end, analysis.bindings)
            push!(parts, "          _show_$(shk)_rewire();")
        end
        push!(parts, "        } else {")
        push!(parts, "          hk_$(shk).innerHTML = '';")
        push!(parts, "        }")
        push!(parts, "      }")

        # If initially hidden, clear innerHTML on hydration
        if !sn.initial_visible
            push!(parts, "      _show_$(shk)_update();")
        end
    end

    # Emit compiled handler functions and event wiring
    for h in analysis.handlers
        dom_event = event_name_to_dom(h.event)
        jst_result = get(handler_results, h.id, nothing)

        if jst_result !== nothing
            # Emit JST-compiled handler function (inside forEach to access signal vars)
            push!(parts, jst_result.func_js)

            # Wire addEventListener: call compiled handler, then update DOM
            push!(parts, "      hk_$(h.target_hk).addEventListener(\"$dom_event\", function() {")
            push!(parts, "        _h$(h.id)();")

            # DOM updates for all signals this handler modifies
            for mod_sig_id in jst_result.modified_signals
                idx = get(sig_idx, mod_sig_id, nothing)
                idx === nothing && continue
                if haskey(binding_map, mod_sig_id)
                    for (bhk, attr) in binding_map[mod_sig_id]
                        push!(parts, "        $(_binding_update_js(idx, bhk, attr))")
                    end
                end
                for sn in analysis.show_nodes
                    if sn.signal_id == mod_sig_id
                        push!(parts, "        _show_$(sn.target_hk)_update();")
                    end
                end
            end

            # Recompute memos that depend on modified signals
            memos_recomputed = Set{Int}()
            for m in analysis.memos
                if any(dep in Set(jst_result.modified_signals) for dep in m.dependencies)
                    if haskey(memo_results, m.idx)
                        push!(parts, "        memo_$(m.idx) = _memo_$(m.idx)_recompute();")
                        push!(memos_recomputed, m.idx)
                    end
                    if haskey(memo_binding_map, m.idx)
                        for (bhk, attr) in memo_binding_map[m.idx]
                            push!(parts, "        $(_memo_binding_update_js(m.idx, bhk, attr))")
                        end
                    end
                end
            end

            # Run effects that depend on modified signals or recomputed memos
            for eff in analysis.effects
                should_run = any(dep in Set(jst_result.modified_signals) for dep in eff.signal_deps) ||
                             any(mi in memos_recomputed for mi in eff.memo_deps)
                if should_run && haskey(effect_results, eff.id)
                    push!(parts, "        _effect_$(eff.id)();")
                end
            end

            # Update For nodes that depend on modified signals or recomputed memos
            for f in analysis.for_nodes
                should_update = (f.items_type == :signal && f.signal_id in Set(jst_result.modified_signals)) ||
                                (f.items_type == :memo && f.memo_idx in memos_recomputed)
                if should_update
                    if f.items_type == :memo
                        push!(parts, "        _for_$(f.id)_update(memo_$(f.memo_idx));")
                    elseif f.items_type == :signal
                        sidx = get(sig_idx, f.signal_id, nothing)
                        sidx !== nothing && push!(parts, "        _for_$(f.id)_update(signal_$(sidx));")
                    end
                end
            end

            push!(parts, "      });")
        else
            # Fallback: old tracing approach
            push!(parts, "      hk_$(h.target_hk).addEventListener(\"$dom_event\", function() {")
            modified_sig_ids = Set{UInt64}()
            for op in h.operations
                idx = get(sig_idx, op.signal_id, nothing)
                idx === nothing && continue
                push!(modified_sig_ids, op.signal_id)
                op_js = _operation_to_js(idx, op)
                if op_js !== nothing
                    push!(parts, "        $op_js")
                end
                if haskey(binding_map, op.signal_id)
                    for (bhk, attr) in binding_map[op.signal_id]
                        push!(parts, "        $(_binding_update_js(idx, bhk, attr))")
                    end
                end
                for sn in analysis.show_nodes
                    if sn.signal_id == op.signal_id
                        push!(parts, "        _show_$(sn.target_hk)_update();")
                    end
                end
            end

            # Recompute memos and run effects (fallback path)
            memos_recomputed_fb = Set{Int}()
            for m in analysis.memos
                if any(dep in modified_sig_ids for dep in m.dependencies)
                    if haskey(memo_results, m.idx)
                        push!(parts, "        memo_$(m.idx) = _memo_$(m.idx)_recompute();")
                        push!(memos_recomputed_fb, m.idx)
                    end
                    if haskey(memo_binding_map, m.idx)
                        for (bhk, attr) in memo_binding_map[m.idx]
                            push!(parts, "        $(_memo_binding_update_js(m.idx, bhk, attr))")
                        end
                    end
                end
            end
            for eff in analysis.effects
                should_run = any(dep in modified_sig_ids for dep in eff.signal_deps) ||
                             any(mi in memos_recomputed_fb for mi in eff.memo_deps)
                if should_run && haskey(effect_results, eff.id)
                    push!(parts, "        _effect_$(eff.id)();")
                end
            end

            # Update For nodes (fallback path)
            for f in analysis.for_nodes
                should_update = (f.items_type == :signal && f.signal_id in modified_sig_ids) ||
                                (f.items_type == :memo && f.memo_idx in memos_recomputed_fb)
                if should_update
                    if f.items_type == :memo
                        push!(parts, "        _for_$(f.id)_update(memo_$(f.memo_idx));")
                    elseif f.items_type == :signal
                        sidx = get(sig_idx, f.signal_id, nothing)
                        sidx !== nothing && push!(parts, "        _for_$(f.id)_update(signal_$(sidx));")
                    end
                end
            end

            push!(parts, "      });")
        end
    end

    # Generate input bindings (two-way)
    for ib in analysis.input_bindings
        idx = get(sig_idx, ib.signal_id, nothing)
        idx === nothing && continue

        if ib.input_type == :number || ib.input_type == :range
            push!(parts, "      hk_$(ib.target_hk).addEventListener(\"input\", function(e) {")
            push!(parts, "        signal_$idx = Number(e.target.value) || 0;")
        elseif ib.input_type == :checkbox
            push!(parts, "      hk_$(ib.target_hk).addEventListener(\"change\", function(e) {")
            push!(parts, "        signal_$idx = e.target.checked ? 1 : 0;")
        else
            push!(parts, "      hk_$(ib.target_hk).addEventListener(\"input\", function(e) {")
            push!(parts, "        signal_$idx = e.target.value;")
        end

        # Update signal bindings
        if haskey(binding_map, ib.signal_id)
            for (bhk, attr) in binding_map[ib.signal_id]
                update_js = _binding_update_js(idx, bhk, attr)
                push!(parts, "        $update_js")
            end
        end

        # Recompute memos that depend on this signal
        ib_memos_recomputed = Set{Int}()
        for m in analysis.memos
            if ib.signal_id in m.dependencies
                if haskey(memo_results, m.idx)
                    push!(parts, "        memo_$(m.idx) = _memo_$(m.idx)_recompute();")
                    push!(ib_memos_recomputed, m.idx)
                end
                if haskey(memo_binding_map, m.idx)
                    for (bhk, attr) in memo_binding_map[m.idx]
                        push!(parts, "        $(_memo_binding_update_js(m.idx, bhk, attr))")
                    end
                end
            end
        end

        # Run effects that depend on this signal or recomputed memos
        for eff in analysis.effects
            should_run = ib.signal_id in eff.signal_deps ||
                         any(mi in ib_memos_recomputed for mi in eff.memo_deps)
            if should_run && haskey(effect_results, eff.id)
                push!(parts, "        _effect_$(eff.id)();")
            end
        end

        # Update For nodes that depend on this signal or recomputed memos
        for f in analysis.for_nodes
            should_update = (f.items_type == :signal && f.signal_id == ib.signal_id) ||
                            (f.items_type == :memo && f.memo_idx in ib_memos_recomputed)
            if should_update
                if f.items_type == :memo
                    push!(parts, "        _for_$(f.id)_update(memo_$(f.memo_idx));")
                elseif f.items_type == :signal
                    sidx = get(sig_idx, f.signal_id, nothing)
                    sidx !== nothing && push!(parts, "        _for_$(f.id)_update(signal_$(sidx));")
                end
            end
        end

        push!(parts, "      });")
    end

    # Run effects on initial load (SolidJS: effects run immediately)
    for eff in analysis.effects
        if haskey(effect_results, eff.id)
            push!(parts, "      _effect_$(eff.id)();")
        end
    end

    push!(parts, "    });")
    push!(parts, "  }")
    # Register for SPA re-hydration
    push!(parts, "  window.TherapyHydrate[\"$cn\"] = hydrate_$cn;")
    # Auto-execute on initial load (skip during router-driven hydration)
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
        return "hk_$hk.textContent = String($s);"
    elseif attr == :value
        return "hk_$hk.value = String($s);"
    elseif attr == :class
        return "hk_$hk.className = String($s);"
    else
        return "hk_$hk.setAttribute(\"$(string(attr))\", String($s));"
    end
end

"""Generate a JS DOM update for a memo binding."""
function _memo_binding_update_js(memo_idx::Int, hk::Int, attr::Union{Symbol, Nothing})::String
    m = "memo_$memo_idx"
    if attr === nothing
        return "hk_$hk.textContent = String($m);"
    elseif attr == :value
        return "hk_$hk.value = String($m);"
    elseif attr == :class
        return "hk_$hk.className = String($m);"
    else
        return "hk_$hk.setAttribute(\"$(string(attr))\", String($m));"
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
                sig_var = "signal_$idx"
                captured_vars[field_name] = sig_var
                getter_type = typeof(captured_value)
                if !haskey(callable_overrides, getter_type)
                    # Use recv_js (compiled from captured_vars) — supports multiple
                    # getters of the same type (e.g., two SignalGetter{Int} signals)
                    callable_overrides[getter_type] = (recv_js, _args_js) -> recv_js
                end
                continue
            end
        end

        # Check if signal setter
        setter_sig_id = get(analysis.setter_map, captured_value, nothing)
        if setter_sig_id !== nothing
            idx = get(sig_idx, setter_sig_id, nothing)
            if idx !== nothing
                sig_var = "signal_$idx"
                captured_vars[field_name] = sig_var
                push!(modified_signals, setter_sig_id)
                setter_type = typeof(captured_value)
                if !haskey(callable_overrides, setter_type)
                    # Use recv_js (from captured_vars) — supports multiple
                    # setters of the same type (e.g., two SignalSetter{Int})
                    callable_overrides[setter_type] = (recv_js, args_js) -> "($(recv_js) = $(args_js[1]))"
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
                sig_var = "signal_$idx"
                captured_vars[field_name] = sig_var
                getter_type = typeof(captured_value)
                if !haskey(callable_overrides, getter_type)
                    callable_overrides[getter_type] = (recv_js, _args_js) -> recv_js
                end
                continue
            end
        end

        # Memo getter (MemoAnalysisGetter)
        if captured_value isa MemoAnalysisGetter
            memo_idx = get(analysis.memo_getter_map, captured_value, nothing)
            if memo_idx !== nothing
                memo_var = "memo_$memo_idx"
                captured_vars[field_name] = memo_var
                memo_type = typeof(captured_value)
                if !haskey(callable_overrides, memo_type)
                    callable_overrides[memo_type] = (recv_js, _args_js) -> recv_js
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
                sig_var = "signal_$idx"
                captured_vars[field_name] = sig_var
                getter_type = typeof(captured_value)
                if !haskey(callable_overrides, getter_type)
                    callable_overrides[getter_type] = (recv_js, _args_js) -> recv_js
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

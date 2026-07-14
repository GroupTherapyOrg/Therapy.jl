# Compile.jl - Main compiler API for Therapy.jl
#
# WasmTarget backend: compiles @island components to WASM + thin JS loader.
# Uses analyze_component() to discover signals/handlers/bindings,
# then compiles handler closures via WasmTarget and generates a JS loader
# that instantiates the WASM module and wires events/effects.

import WasmTarget
const WT = WasmTarget

include("CanvasProvider.jl")
include("Floating.jl")
include("Analysis.jl")
include("SignalRuntime.jl")
include("ForRuntime.jl")
include("DOMBridge.jl")
include("WasmReactiveRuntime.jl")
include("WasmRuntime.jl")

# ─── Compilation Output ───

"""
Result of compiling an island. Contains JS that embeds inline WASM bytes.
The JS field is a self-contained loader script.
"""
struct IslandJSOutput
    js::String              # JS loader script (embeds WASM bytes inline)
    component_name::String  # Island component name
    n_signals::Int          # Number of signals discovered
    n_handlers::Int         # Number of event handlers
    wasm_size::Int          # WASM binary size in bytes (before embedding in JS)
end

# ─── Island Compilation ───

"""
    compile_island(name::Symbol) -> IslandJSOutput

Compile a registered @island component to WASM + JS loader.

Uses analyze_component() to discover signals, handlers, and DOM bindings,
then compiles handler/effect/memo closures to WASM via WasmTarget and
generates a JS loader that instantiates the module and wires hydration.
"""
function compile_island(name::Symbol; optimize_wasm::Bool=true)::IslandJSOutput
    island_def = get(ISLAND_REGISTRY, name, nothing)
    island_def === nothing && error("No island :$name registered")

    # Analyze the component's declared defaults. Runtime instances provide their
    # own typed props during hydration; compilation must never depend on whichever
    # instance happened to render last.
    analysis = analyze_component(island_def.render_fn)

    # WasmTarget is the validation and code-generation authority. Keep every
    # compiler diagnostic visible and propagate every failure to the caller.
    js, wasm_size = _generate_island_wasm(
        string(name), analysis;
        prop_names=island_def.prop_names,
        prop_types=island_def.prop_types,
        optimize_wasm=optimize_wasm,
    )

    return IslandJSOutput(js, string(name), length(analysis.signals), length(analysis.handlers), wasm_size)
end

# ─── WASM Island Generation ───

"""
Generate the complete WASM module + JS loader for an island.

Architecture:
  - WASM module: signal globals + handler/effect/memo exports
  - JS loader: instantiates WASM, sets up DOM refs, wires events via delegation
  - WASM reactive runtime handles dependency tracking + effect scheduling
"""
function _generate_island_wasm(component_name::String, analysis::ComponentAnalysis;
                                prop_names::Vector{Symbol}=Symbol[],
                                prop_types::Vector{Type}=Type[],
                                optimize_wasm::Bool=false)
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
    # Imports are declared before the one closed-world root plan freezes function indices.
    # The JS import object (__tw.io) always provides Math.pow.
    WT.add_import!(mod, "Math", "pow", WT.NumType[WT.F64, WT.F64], WT.NumType[WT.F64])

    # Add DOM bridge imports (externref-based, Leptos web-sys pattern)
    dom_imports = add_dom_imports!(mod)

    # Add For() update imports (one per For node, Leptos Keyed pattern)
    # Each import receives the container externref; JS handles DOM reconciliation.
    # Uses deferred proxy pattern (like shared signals) — actual impl set after instantiation.
    for_update_imports = Dict{Int, UInt32}()
    for f in analysis.for_nodes
        import_idx = WT.add_import!(mod, "for_fns", "for_$(f.id)_update",
            WT.WasmValType[WT.ExternRef], WT.WasmValType[])
        for_update_imports[f.id] = import_idx
    end

    # Add string text binding deferred imports (same pattern as For() updates).
    # Each string signal→text binding needs a JS bridge to convert WasmGC ref to string.
    str_text_imports = Dict{Int, UInt32}()  # target_hk → import_idx
    str_value_imports = Dict{Int, UInt32}() # target_hk → import_idx
    for b in analysis.bindings
        # Find signal index
        _bi = findfirst(s -> s.id == b.signal_id, analysis.signals)
        _bi === nothing && continue
        sig = analysis.signals[_bi]
        if _signal_wasm_kind(sig) == :string_ref
            if b.attribute === nothing
                import_idx = WT.add_import!(mod, "str_fns", "stb_$(b.target_hk)",
                    WT.WasmValType[WT.ExternRef, WT.ExternRef], WT.WasmValType[])
                str_text_imports[b.target_hk] = import_idx
            elseif b.attribute == :value
                import_idx = WT.add_import!(mod, "str_fns", "svb_$(b.target_hk)",
                    WT.WasmValType[WT.ExternRef, WT.ExternRef], WT.WasmValType[])
                str_value_imports[b.target_hk] = import_idx
            end
        end
    end

    # Add signal globals (local) or imports (shared)
    # Local signals → WASM globals (fast, zero-crossing)
    # Shared signals → WASM imports (for cross-island sync)
    shared_signal_imports = Dict{Int, UInt32}()  # sig_idx → get_import_idx
    string_signal_indices = Set{Int}()  # track which signal indices are string-typed
    bool_signal_indices = Set{Int}()    # track which signal indices are Bool (i32)
    float_signal_indices = Set{Int}()   # track which signal indices are Float64 (f64)
    vec_signal_indices = Set{Int}()     # track which signal indices are Vector (ref)
    signal_global_indices = Dict{Int,UInt32}()
    vector_signal_initializers = Any[]
    for (i, sig) in enumerate(analysis.signals)
        idx = i - 1
        wasm_kind = _signal_wasm_kind(sig)
        if sig.shared_name !== nothing
            # Shared signal: register getter import — JS is the single source of truth.
            # Writes use the WASM global + postsync to JS (no set import needed).
            get_idx = WT.add_import!(mod, "signals", "get_s$(idx)", WT.NumType[], WT.NumType[WT.I64])
            shared_signal_imports[idx] = get_idx
            # Still add a global (for compatibility with memo/effect code that reads globals)
            # but it won't be the source of truth
            init_val = sig.initial_value isa Integer ? Int64(sig.initial_value) : Int64(0)
            actual_idx = WT.add_global!(mod, WT.I64, true, init_val)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
        elseif wasm_kind == :string_ref
            # String signal: mutable global holds WT's canonical classed String.
            push!(string_signal_indices, idx)
            init_str = sig.initial_value isa AbstractString ? String(sig.initial_value) : ""
            actual_idx = WT.add_string_global!(mod, type_registry, init_str)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
        elseif wasm_kind == :vec_ref
            # Vector signal: WASM global holds a WasmGC struct ref (Vector{T})
            push!(vec_signal_indices, idx)
            vec_val = sig.initial_value isa AbstractVector ? sig.initial_value : String[]
            vec_type = typeof(vec_val)
            vec_info = WT.register_vector_type!(mod, type_registry, vec_type)
            actual_idx = WT.add_uninitialized_ref_global!(mod, vec_info.wasm_type_idx)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
            init_fn = let initial_value=vec_val
                () -> initial_value
            end
            push!(vector_signal_initializers,
                (name="_signal_init_$(idx)", fn=init_fn, global_idx=actual_idx))
        elseif wasm_kind == :i32
            # Bool signal: WASM I32 global (0 or 1)
            push!(bool_signal_indices, idx)
            init_val = Int32(sig.initial_value isa Bool ? (sig.initial_value ? 1 : 0) : 0)
            actual_idx = WT.add_global!(mod, WT.I32, true, init_val)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
        elseif wasm_kind == :f64
            # Float signal: WASM F64 global
            push!(float_signal_indices, idx)
            init_val = Float64(sig.initial_value isa Number ? sig.initial_value : 0.0)
            actual_idx = WT.add_global!(mod, WT.F64, true, init_val)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
        else
            # Local signal: WASM global is the source of truth (i64)
            init_val = sig.initial_value isa Integer ? Int64(sig.initial_value) : Int64(0)
            actual_idx = WT.add_global!(mod, WT.I64, true, init_val)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
        end
        signal_global_indices[idx] = UInt32(actual_idx)
    end

    # ─── Add externref globals for hydration-keyed DOM elements ───
    # Collect all hk IDs needed by handlers, bindings, show nodes, for nodes, input bindings
    needed_hks_vec = Int[]
    for h in analysis.handlers; push!(needed_hks_vec, h.target_hk); end
    for b in analysis.bindings; push!(needed_hks_vec, b.target_hk); end
    for mb in analysis.memo_bindings; push!(needed_hks_vec, mb.target_hk); end
    for s in analysis.show_nodes
        push!(needed_hks_vec, s.target_hk)
        s.fallback_hk > 0 && push!(needed_hks_vec, s.fallback_hk)
    end
    for ib in analysis.input_bindings; push!(needed_hks_vec, ib.target_hk); end
    for f in analysis.for_nodes; push!(needed_hks_vec, f.target_hk); end
    unique!(sort!(needed_hks_vec))
    hk_globals = add_hk_globals!(mod, needed_hks_vec)

    # ─── Pre-scan effects for js() imports (must come before any add_function! calls) ───
    # Effect js() calls need WASM imports. All imports must be registered before any
    # local functions to keep function indices correct.
    effect_js_imports = Dict{Int,Dict{Int,UInt32}}() # effect_id → IR site → import
    effect_js_meta = Dict{Int,Vector{Any}}()
    for eff in analysis.effects
        _, _, _, plans = _extract_js_calls(eff.fn, analysis, sig_idx; use_params=true)
        if !isempty(plans)
            imports = Dict{Int,UInt32}()
            meta = Any[]
            for (call_no, plan) in enumerate(plans)
            param_types = WT.WasmValType[]
                for (kind, idx, wasm_kind) in plan.arg_refs
                if kind === :signal
                    if wasm_kind === :i32
                        push!(param_types, WT.I32)
                    elseif wasm_kind === :f64
                        push!(param_types, WT.F64)
                    elseif wasm_kind in (:string_ref, :vec_ref)
                        push!(param_types, WT.ExternRef)
                    else
                        push!(param_types, WT.I64)
                    end
                elseif kind === :memo
                    push!(param_types, WT.I64)
                end
            end
                import_name = "eff_$(eff.id)_$(call_no)"
                import_idx = WT.add_import!(mod, "eff_js", import_name,
                param_types, WT.WasmValType[])
                imports[plan.site] = import_idx
                params_str = join(["_p$i" for i in 0:(length(plan.arg_refs)-1)], ",")
                push!(meta, (name=import_name, site=plan.site,
                    js_code=plan.js_code * ";", params_str=params_str,
                    argument_indices=plan.argument_indices))
            end
            effect_js_imports[eff.id] = imports
            effect_js_meta[eff.id] = meta
        end
    end

    # ─── Canvas2D imports (generic provider protocol — WASMMAKIE E-002) ───
    # Register the ACTIVE canvas provider's draw calls as WASM imports: no-op
    # stubs in Julia that become real Canvas2D calls in the browser. Any
    # package exposing import_specs()/js_glue() (e.g. WasmMakie) registers
    # via Therapy.register_canvas_provider! (E-005: providers are explicit —
    # the legacy WasmPlot autoload is retired).
    canvas_import_stubs = Any[]
    let provider = active_canvas_provider()
        if provider !== nothing
            n_imports = 0
            for spec in provider.import_specs()
                func_ref, import_name, arg_types, return_type = _normalize_canvas_spec(spec)
                wasm_params = WT.NumType[]
                for T in arg_types
                    push!(wasm_params, T === Float64 ? WT.F64 : WT.I64)
                end
                wasm_ret = return_type === Float64 ? WT.NumType[WT.F64] : WT.NumType[WT.I64]
                wasm_idx = WT.add_import!(mod, "canvas2d", import_name, wasm_params, wasm_ret)
                # The closed-world compiler owns its function registry. Give it
                # the Julia-stub ↔ predeclared-import mapping explicitly so the
                # stub is excluded from collection and every call resolves to
                # the existing Canvas2D import index.
                push!(canvas_import_stubs,
                    (func_ref, import_name, Tuple(arg_types), UInt32(wasm_idx), return_type))
                n_imports += 1
            end
            @debug "Canvas2D: registered $(n_imports) imports from provider $(provider.name)"
        end
    end

    # ─── Add reactive runtime globals ───
    # Count effects that will be in the funcref table:
    # - DOM text bindings, attribute bindings, memo bindings
    # - Explicit create_effect() calls
    # - Show() condition effects
    num_dom_effects = length(analysis.bindings) + length(analysis.memo_bindings)
    num_explicit_effects = length(analysis.effects)
    num_show_effects = length(analysis.show_nodes)
    total_effects = num_dom_effects + num_explicit_effects + num_show_effects
    rt_globals = add_reactive_globals!(mod, length(analysis.signals), total_effects)

    # ─── Declare handler closure roots for one closed-world compilation ───
    handler_results = Dict{Int, Any}()
    closure_roots = Any[]
    root_bindings = Dict{String,WT.RootBindings}()
    for init in vector_signal_initializers
        constants = Dict{Symbol,Any}(field => getfield(init.fn, field)
            for field in fieldnames(typeof(init.fn)))
        push!(closure_roots, (init.fn, (), init.name))
        root_bindings[init.name] = WT.RootBindings(
            captured_constants=constants, elide_closure_context=true)
    end
    for h in analysis.handlers
        result = _plan_handler_root(h.handler, h.id, analysis, sig_idx,
            signal_global_indices, mod, shared_signal_imports)
        push!(closure_roots, (h.handler, (), result.export_name))
        root_bindings[result.export_name] = result.bindings
        handler_results[h.id] = result
    end

    # ─── Compile memo closures to WASM (before effects — effects may call memos) ───
    memo_results = Dict{Int, Any}()
    for m in analysis.memos
        result = _plan_memo_root(m.fn, m.idx, analysis, sig_idx,
            signal_global_indices, memo_results)
        push!(closure_roots, (m.fn, (), result.export_name))
        root_bindings[result.export_name] = result.bindings
        memo_results[m.idx] = result
    end
    any(r -> r.returns_vec_str, values(memo_results)) && push!(closure_roots,
        ((v::Vector{String},) -> Int64(length(v)), (Vector{String},), "_bv_str_len"),
        ((v::Vector{String}, i::Int64) -> v[i], (Vector{String}, Int64), "_bv_str_get"),
        ((s::String,) -> Int64(ncodeunits(s)), (String,), "_str_len"),
        ((s::String, i::Int64) -> Int64(codeunit(s, i)), (String, Int64), "_str_byte"))
    any(r -> r.returns_vec_i64, values(memo_results)) && push!(closure_roots,
        ((v::Vector{Int64},) -> Int64(length(v)), (Vector{Int64},), "_bv_i64_len"),
        ((v::Vector{Int64}, i::Int64) -> v[i], (Vector{Int64}, Int64), "_bv_i64_get"))
    any(r -> r.returns_vec_f64, values(memo_results)) && push!(closure_roots,
        ((v::Vector{Float64},) -> Int64(length(v)), (Vector{Float64},), "_bv_f64_len"),
        ((v::Vector{Float64}, i::Int64) -> v[i], (Vector{Float64}, Int64), "_bv_f64_get"))

    # ─── Compile effect closures to WASM ───
    effect_results = Dict{Int, Any}()
    for eff in analysis.effects
        result = if haskey(effect_js_imports, eff.id) && haskey(effect_js_meta, eff.id)
            planned = _plan_js_effect_root(eff.fn, eff.id, analysis, sig_idx,
                signal_global_indices, rt_globals, mod, memo_results,
                effect_js_imports[eff.id], effect_js_meta[eff.id])
            push!(closure_roots, (eff.fn, (), planned.export_name))
            root_bindings[planned.export_name] = planned.bindings
            planned
        else
            planned = _plan_effect_root(eff.fn, eff.id, analysis, sig_idx,
                signal_global_indices, rt_globals, mod, memo_results)
            push!(closure_roots, (eff.fn, (), planned.export_name))
            root_bindings[planned.export_name] = planned.bindings
            planned
        end
        effect_results[eff.id] = result
    end

    # ─── Compile mount closures to WASM ───
    mount_results = Dict{Int, Any}()
    for mt in analysis.mount_effects
        result = _plan_mount_root(mt.fn, mt.id, analysis, sig_idx,
            signal_global_indices)
        if hasproperty(result, :bindings)
            push!(closure_roots, (mt.fn, (), result.export_name))
            root_bindings[result.export_name] = result.bindings
        end
        mount_results[mt.id] = result
    end

    # ─── Compile Show() closure conditions to WASM ───
    show_condition_exports = Dict{Int, String}()  # target_hk → export_name
    for sn in analysis.show_nodes
        if sn.condition_fn !== nothing && sn.condition_fn isa Function
            planned = _plan_show_root(sn.condition_fn, sn.target_hk, analysis,
                sig_idx, signal_global_indices, memo_results)
            push!(closure_roots, (sn.condition_fn, (), planned.export_name))
            root_bindings[planned.export_name] = planned.bindings
            show_condition_exports[sn.target_hk] = planned.export_name
        end
    end

    # ─── Compile string signal bridge functions (JS string ↔ WasmGC string) ───
    # JS→WASM: _u8_new, _u8_set!, _str_from_bytes (used by __tw.toWasm)
    # WASM→JS: _str_len, _str_byte (used by __tw.fromWasm)
    has_str_bridges = false
    if !isempty(string_signal_indices)
        push!(closure_roots,
            ((n::Int64) -> Vector{UInt8}(undef, n), (Int64,), "_u8_new"),
            ((v::Vector{UInt8}, i::Int64, b::Int64) -> (v[i] = UInt8(b); Int64(0)),
                (Vector{UInt8}, Int64, Int64), "_u8_set!"),
            ((v::Vector{UInt8},) -> String(copy(v)), (Vector{UInt8},), "_str_from_bytes"),
            ((s::String,) -> Int64(ncodeunits(s)), (String,), "_str_len"),
            ((s::String, i::Int64) -> Int64(codeunit(s, i)),
                (String, Int64), "_str_byte"))
        has_str_bridges = true
    end

    # ─── Compile DOM binding effects as WASM functions ───
    # Each text/attribute binding becomes a WASM effect in the funcref table.
    # Each binding compiles to a WASM effect function in the funcref table.
    wasm_effect_funcs = UInt32[]  # function indices for funcref table
    wasm_effect_binding_hks = Set{Int}()  # track which bindings are WASM-managed

    for b in analysis.bindings
        idx = get(sig_idx, b.signal_id, nothing)
        idx === nothing && continue
        hk_gidx = get(hk_globals, b.target_hk, nothing)
        hk_gidx === nothing && continue

        # Determine signal kind
        sig = analysis.signals[idx + 1]
        kind = _signal_wasm_kind(sig)

        # Compile numeric signal bindings to WASM
        # Text, value, and class bindings for numeric signals
        # String/vector signals stay in JS until WasmGC string bridge is ready
        if kind in (:i64, :i32, :f64) && (b.attribute === nothing || b.attribute == :value || b.attribute == :class)
            # Find the signal global index (it was the Nth signal → global at idx offset)
            # Signal globals are exported as "signal_N" — find the global index
            sig_global_idx = nothing
            for exp in mod.exports
                if exp.name == "signal_$(idx)" && exp.kind == 0x03  # global export
                    sig_global_idx = exp.idx
                    break
                end
            end
            sig_global_idx === nothing && continue

            subs_global = rt_globals.signal_subs_base + UInt32(idx)

            effect_body = if b.attribute == :value
                compile_value_binding_effect(
                    sig_global_idx, subs_global, hk_gidx, kind, dom_imports, rt_globals)
            elseif b.attribute == :class
                compile_class_binding_effect(
                    sig_global_idx, subs_global, hk_gidx, kind, dom_imports, rt_globals)
            else
                compile_text_binding_effect(
                    sig_global_idx, subs_global, hk_gidx, kind, dom_imports, rt_globals)
            end

            effect_fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
                WT.WasmValType[], effect_body)
            push!(wasm_effect_funcs, effect_fidx)
            push!(wasm_effect_binding_hks, b.target_hk)
        elseif kind == :string_ref && (b.attribute === nothing || b.attribute == :value)
            # String signal → text/value binding via a typed deferred JS proxy.
            str_import = b.attribute === nothing ?
                get(str_text_imports, b.target_hk, nothing) :
                get(str_value_imports, b.target_hk, nothing)
            str_import === nothing && continue

            sig_global_idx = nothing
            for exp in mod.exports
                if exp.name == "signal_$(idx)" && exp.kind == 0x03
                    sig_global_idx = exp.idx
                    break
                end
            end
            sig_global_idx === nothing && continue

            subs_global = rt_globals.signal_subs_base + UInt32(idx)
            effect_body = compile_string_text_binding_effect(
                sig_global_idx, subs_global, hk_gidx, str_import, rt_globals)
            effect_fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
                WT.WasmValType[], effect_body)
            push!(wasm_effect_funcs, effect_fidx)
            push!(wasm_effect_binding_hks, b.target_hk)
        end
    end

    # Root-dependent memo/Show adapters are linked after WT reserves root indices.
    show_frag_globals = Dict{Int, UInt32}()
    show_fb_frag_globals = Dict{Int, UInt32}()
    show_prev_globals = Dict{Int, UInt32}()
    wasm_show_hks = Set{Int}()
    # ─── Compile For() effects as WASM functions ───
    # Each For node gets a WASM effect that tracks signal deps and calls a JS import
    # for DOM reconciliation. Leptos equivalent: RenderEffect on Keyed list.
    for_compiled = Dict{Int, NamedTuple}()  # for_id → compilation info
    for f in analysis.for_nodes
        hk_gidx = get(hk_globals, f.target_hk, nothing)
        hk_gidx === nothing && continue

        for_import = get(for_update_imports, f.id, nothing)
        for_import === nothing && continue

        # Find signal deps for tracking (same pattern as Show effects)
        dep_subs = UInt32[]
        if f.items_type == :memo
            # Walk the memo function's closure to find signal deps
            memo_match = findfirst(m -> m.idx == f.memo_idx, analysis.memos)
            if memo_match !== nothing
                dep_sig_ids = _discover_closure_signal_deps(analysis.memos[memo_match].fn, analysis)
                for sig_id in dep_sig_ids
                    idx = get(sig_idx, sig_id, nothing)
                    if idx !== nothing
                        push!(dep_subs, rt_globals.signal_subs_base + UInt32(idx))
                    end
                end
            end
        elseif f.items_type == :signal
            idx = get(sig_idx, f.signal_id, nothing)
            if idx !== nothing
                push!(dep_subs, rt_globals.signal_subs_base + UInt32(idx))
            end
        end
        effect_body = compile_for_effect(dep_subs, hk_gidx, for_import, rt_globals)
        effect_fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
            WT.WasmValType[], effect_body)
        push!(wasm_effect_funcs, effect_fidx)

        # Compile render template for JS glue
        render_result = _compile_for_render(f.render_fn, f.id)

        # Determine memo result type for bridge function selection
        memo_result = f.items_type == :memo ? get(memo_results, f.memo_idx, nothing) : nothing

        for_compiled[f.id] = (
            for_node = f,
            render_js = render_result.render_js,
            memo_idx = f.memo_idx,
            memo_result = memo_result,
        )
    end

    flush_func_idx = Ref{Union{Nothing,UInt32}}(nothing)
    handler_wrapper_exports = Dict{Int,String}()

    function link_framework_roots!(linked_mod, root_indices, linked_types)
        for init in vector_signal_initializers
            root_idx = get(root_indices, init.name, nothing)
            root_idx === nothing && error("missing vector signal initializer $(init.name)")
            WT.add_root_global_initializer!(linked_mod, linked_types,
                init.global_idx, root_idx)
        end
        for mb in analysis.memo_bindings
            hk = get(hk_globals, mb.target_hk, nothing)
            mr = get(memo_results, mb.memo_idx, nothing)
            (hk === nothing || mr === nothing) && continue
            memo_idx = get(root_indices, mr.export_name, nothing)
            memo_idx === nothing && error("missing memo root $(mr.export_name)")
            pos = findfirst(m -> m.idx == mb.memo_idx, analysis.memos)
            pos === nothing && error("memo binding references unknown memo $(mb.memo_idx)")
            memo = analysis.memos[pos]
            deps = UInt32[rt_globals.signal_subs_base + UInt32(sig_idx[id])
                for id in memo.dependencies if haskey(sig_idx, id)]
            isempty(deps) && !isempty(analysis.signals) && append!(deps,
                (rt_globals.signal_subs_base + UInt32(i)
                    for i in 0:(length(analysis.signals) - 1)))
            typed = Base.code_typed(memo.fn, ())
            isempty(typed) && error("memo $(mb.memo_idx) has no typed return")
            ret = typed[1][2]
            ret isa Type || error("memo $(mb.memo_idx) has non-type inferred return $ret")
            kind = ret === Bool ? :i32 : ret <: AbstractFloat ? :f64 : :i64
            body = compile_memo_text_binding_effect(memo_idx, deps, hk, kind,
                dom_imports, rt_globals)
            push!(wasm_effect_funcs, WT.add_function!(linked_mod,
                WT.WasmValType[], WT.WasmValType[], WT.WasmValType[], body))
        end

        for sn in analysis.show_nodes
            shk = sn.target_hk
            hk = get(hk_globals, shk, nothing)
            hk === nothing && continue
            condition = if sn.condition_fn !== nothing
                name = get(show_condition_exports, shk, nothing)
                name === nothing ? nothing : get(root_indices, name, nothing)
            else
                idx = get(sig_idx, sn.signal_id, nothing)
                idx === nothing ? nothing : begin
                    body = UInt8[0x23]
                    append!(body, WT.encode_leb128_unsigned(signal_global_indices[idx]))
                    signal_kind = _signal_wasm_kind(analysis.signals[idx + 1])
                    signal_kind === :i64 && push!(body, 0xa7)
                    signal_kind === :f64 && push!(body, 0xaa)
                    push!(body, WT.Opcode.END)
                    WT.add_function!(linked_mod, WT.WasmValType[],
                        WT.WasmValType[WT.I32], WT.WasmValType[], body)
                end
            end
            condition === nothing && error("Show at hk=$shk has no condition root")
            frag = WT.add_global!(linked_mod, WT.ExternRef, true, nothing)
            WT.add_global_export!(linked_mod, "_show_$(shk)_frag", frag)
            show_frag_globals[shk] = frag
            prev = WT.add_global!(linked_mod, WT.I32, true, Int32(-1))
            show_prev_globals[shk] = prev
            fb_hk = sn.fallback_hk > 0 ? get(hk_globals, sn.fallback_hk, nothing) : nothing
            fb_frag = nothing
            if fb_hk !== nothing
                fb_frag = WT.add_global!(linked_mod, WT.ExternRef, true, nothing)
                WT.add_global_export!(linked_mod, "_show_$(shk)_fb_frag", fb_frag)
                show_fb_frag_globals[shk] = fb_frag
            end
            dep_ids = sn.condition_fn !== nothing ?
                _discover_closure_signal_deps(sn.condition_fn, analysis) :
                (sn.signal_id == UInt64(0) ? UInt64[] : UInt64[sn.signal_id])
            deps = UInt32[rt_globals.signal_subs_base + UInt32(sig_idx[id])
                for id in dep_ids if haskey(sig_idx, id)]
            isempty(deps) && !isempty(analysis.signals) && append!(deps,
                (rt_globals.signal_subs_base + UInt32(i)
                    for i in 0:(length(analysis.signals) - 1)))
            body = compile_show_effect(condition, prev, deps, hk, frag,
                dom_imports, rt_globals; fb_hk_global=fb_hk,
                fb_frag_global=fb_frag)
            push!(wasm_effect_funcs, WT.add_function!(linked_mod,
                WT.WasmValType[], WT.WasmValType[], WT.WasmValType[WT.I32], body))
            push!(wasm_show_hks, shk)
        end

        for result in values(effect_results)
            idx = get(root_indices, result.export_name, nothing)
            idx === nothing && error("missing effect root $(result.export_name)")
            push!(wasm_effect_funcs, idx)
        end

        if !isempty(wasm_effect_funcs)
            n = length(wasm_effect_funcs)
            table = WT.add_table!(linked_mod, WT.FuncRef, UInt32(n), UInt32(n))
            WT.add_elem_segment!(linked_mod, table, UInt32(0), wasm_effect_funcs)
            void_type = WT.add_type!(linked_mod,
                WT.FuncType(WT.WasmValType[], WT.WasmValType[]))
            flush_func_idx[] = emit_rt_flush_function!(linked_mod, rt_globals,
                n, length(analysis.signals), table, void_type)
        end

        flush_func_idx[] === nothing && return nothing
        for h in analysis.handlers
            result = get(handler_results, h.id, nothing)
            result === nothing && continue
            handler_idx = get(root_indices, result.export_name, nothing)
            handler_idx === nothing && error("missing handler root $(result.export_name)")
            body = UInt8[]
            append!(body, emit_rt_batch_start_bytecode(rt_globals))
            push!(body, 0x10)
            append!(body, WT.encode_leb128_unsigned(handler_idx))
            for signal_id in result.modified_signals
                idx = get(sig_idx, signal_id, nothing)
                (idx === nothing || idx in string_signal_indices ||
                    idx in vec_signal_indices) && continue
                subs = rt_globals.signal_subs_base + UInt32(idx)
                push!(body, 0x23); append!(body, WT.encode_leb128_unsigned(rt_globals.batch_depth))
                push!(body, 0x41, 0x00, 0x4a, 0x04, 0x40)
                push!(body, 0x23); append!(body, WT.encode_leb128_unsigned(rt_globals.pending_effects))
                push!(body, 0x23); append!(body, WT.encode_leb128_unsigned(subs))
                push!(body, 0x84, 0x24)
                append!(body, WT.encode_leb128_unsigned(rt_globals.pending_effects))
                push!(body, WT.Opcode.END)
            end
            append!(body, emit_rt_batch_end_bytecode(rt_globals, flush_func_idx[]))
            push!(body, WT.Opcode.END)
            name = "_hw$(h.id)"
            wrapper = WT.add_function!(linked_mod, WT.WasmValType[],
                WT.WasmValType[], WT.WasmValType[], body)
            WT.add_export!(linked_mod, name, 0, wrapper)
            handler_wrapper_exports[h.id] = name
        end
        return nothing
    end
    # ─── Serialize WASM to bytes ───
    unique_roots = Any[]
    seen_root_names = Set{String}()
    for root in closure_roots
        name = String(root[3])
        name in seen_root_names && continue
        push!(seen_root_names, name)
        push!(unique_roots, root)
        get!(root_bindings, name) do
            WT.RootBindings(elide_closure_context=true)
        end
    end
    wasm_bytes = WT.compile_multi(unique_roots;
        existing_module=mod,
        import_stubs=canvas_import_stubs,
        root_bindings=root_bindings,
        link_roots=link_framework_roots!,
        optimize=optimize_wasm,
        validate=true,
    )

    # ─── Generate JS loader ───
    parts = String[]
    push!(parts, "(function() {")

    # Hydration function
    push!(parts, "  window.TherapyHydrate = window.TherapyHydrate || {};")
    push!(parts, "  function hydrate_$cn() {")
    push!(parts, "    document.querySelectorAll('[data-component=\"$cn\"]:not([data-hydrated])').forEach(function(island) {")
    # Note: `island.dataset.hydrated = "true"` used to fire HERE,
    # before `WebAssembly.instantiate(...)`. That meant a WASM module
    # that failed to compile (invalid heap type, unknown import,
    # validator reject) still flipped the flag — a downstream
    # observer had no way to tell whether hydration actually
    # succeeded. Sessions.jl's notebook-init.js fallback uses the
    # flag to decorate un-hydrated islands with a red "WASM
    # compile failed" band; if the flag is set before
    # instantiation we'd silently paper over every failure.
    #
    # Moved the flag down into the `.then(function(result){…})`
    # callback so it fires only after `WebAssembly.instantiate`
    # resolves successfully. The `.catch(function(e){…})` stays
    # unchanged — errors still log, `data-hydrated` stays unset,
    # downstream fallbacks can reliably detect the failure.

    # Props — parse for memo factory / bridge access (NOT for signal init).
    # Prop-to-signal mapping only applies when ALL props are integer signals
    # (e.g., Counter(initial=0)). When any prop is a non-signal type
    # (Vector{String}, etc.), disable the mapping entirely.
    length(prop_names) == length(prop_types) || error(
        "island $component_name has inconsistent prop metadata")
    has_prop_signals = !isempty(prop_names) &&
        length(analysis.signals) >= length(prop_names) &&
        all(i -> analysis.signals[i].type === prop_types[i], eachindex(prop_names))
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
    if !isempty(js_imports)
        push!(parts, "      _io.js={$(join(js_imports, ","))};")
    end

    # ─── Effect js() imports: deferred pattern (need access to `ex` for string signals) ───
    eff_js_imports = String[]
    eff_js_deferred = String[]  # deferred implementations set after instantiation
    for eff in analysis.effects
        result = get(effect_results, eff.id, nothing)
        result === nothing && continue
        if hasproperty(result, :effect_js_calls)
            for call in result.effect_js_calls
                ps = call.params_str
                body = call.js_code
                key = call.name
                if isempty(ps)
                    push!(eff_js_imports, "$(key):function(){$body}")
                else
                    push!(eff_js_imports,
                        "$(key):function($(ps)){if(_eff['$(key)'])_eff['$(key)']($(ps));}")
                    push!(eff_js_deferred,
                        "        _eff['$(key)']=function($(ps)){$body};")
                end
            end
        end
    end
    if !isempty(eff_js_imports)
        push!(parts, "      var _eff={};")
        push!(parts, "      _io.eff_js={$(join(eff_js_imports, ","))};")
    end

    # ─── Shared signal imports: resolve lazily since sN vars are created inside .then() ───
    # Use a holder object that the import functions close over. Set the actual
    # getter functions after signal creation inside .then().
    has_shared_signals = any(sig.shared_name !== nothing for sig in analysis.signals)
    if has_shared_signals
        push!(parts, "      var _ss={};")
        sig_import_stubs = String[]
        for (i, sig) in enumerate(analysis.signals)
            sig.shared_name === nothing && continue
            idx = i - 1
            push!(sig_import_stubs, "get_s$(idx):function(){return _ss.get_s$(idx)()}")
        end
        push!(parts, "      _io.signals={$(join(sig_import_stubs, ","))};")
    end

    # ─── For() deferred imports: resolve lazily (same pattern as shared signals) ───
    # The for_update imports need access to `ex` (WASM exports), which isn't available
    # until after instantiation. Use a proxy object that forwards calls.
    if !isempty(for_compiled)
        push!(parts, "      var _ff={};")
        for_stubs = String[]
        for (fid, _) in sort(collect(for_compiled))
            push!(for_stubs, "for_$(fid)_update:function(c){if(_ff[$(fid)])_ff[$(fid)](c);}")
        end
        push!(parts, "      _io.for_fns={$(join(for_stubs, ","))};")
    end

    # ─── String DOM binding deferred imports (same pattern as For()) ───
    if !isempty(str_text_imports) || !isempty(str_value_imports)
        push!(parts, "      var _stb={};")
        stb_stubs = String[]
        for (hk, _) in sort(collect(str_text_imports))
            push!(stb_stubs, "stb_$(hk):function(n,r){if(_stb[$(hk)])_stb[$(hk)](n,r);}")
        end
        for (hk, _) in sort(collect(str_value_imports))
            push!(stb_stubs, "svb_$(hk):function(n,r){if(_stb[$(hk)])_stb[$(hk)](n,r);}")
        end
        push!(parts, "      _io.str_fns={$(join(stb_stubs, ","))};")
    end

    # ─── Instantiate WASM ───
    # builtins: WasmTarget emits `wasm:js-string` builtin imports whenever a
    # module PRODUCES strings (axis-tick labels in WasmMakie figures, etc).
    # Those are an engine-provided builtin module, not a JS import-object entry,
    # so we opt in here and stub the `io` write bridge in __tw.io (WasmRuntime).
    push!(parts, "      WebAssembly.instantiate(_wb, _io, {builtins:['js-string']}).then(function(result) {")
    push!(parts, "        var ex = result.instance.exports;")
    # Expose exports on the island element so external code can poke
    # signals (the documented HMR snapshot pattern in WebSocketClient.jl
    # also relies on this — read-only previously, now also written).
    push!(parts, "        island._wasmExports = ex;")
    # Mark the island hydrated ONLY after successful WASM
    # instantiation. The `.catch` handler below logs the error but
    # leaves `data-hydrated` unset — downstream fallbacks (e.g.
    # Sessions.jl's notebook-init.js WALL detector) use the flag's
    # absence to paint the failed cell's chrome with an error band.
    push!(parts, "        island.dataset.hydrated = \"true\";")

    # ─── String bridge: now uses shared __tw.toWasm(ex, str) / __tw.fromWasm(ex, ref) ───
    # No per-island _jsToWasm function needed — defined once in WasmRuntime.jl

    # ─── Sync props to WASM signal globals ───
    for (i, sig) in enumerate(analysis.signals)
        idx = i - 1
        is_string_sig = idx in string_signal_indices
        is_bool_sig = idx in bool_signal_indices
        is_float_sig = idx in float_signal_indices
        # Sync initial prop value to WASM global (only for non-string numeric props)
        if !is_string_sig && has_prop_signals && i <= length(prop_names)
            pname = string(prop_names[i])
            if is_bool_sig
                push!(parts, "        if (props.$pname !== undefined && typeof props.$pname === 'number') ex.signal_$idx.value = props.$pname ? 1 : 0;")
            elseif is_float_sig
                push!(parts, "        if (props.$pname !== undefined && typeof props.$pname === 'number') ex.signal_$idx.value = props.$pname;")
            else
                push!(parts, "        if (props.$pname !== undefined && typeof props.$pname === 'number') ex.signal_$idx.value = BigInt(props.$pname);")
            end
        end
        # Dark mode init: sync browser dark state to WASM signal global
        if sig.shared_name !== nothing && occursin("dark", string(sig.shared_name))
            push!(parts, "        if(document.documentElement.classList.contains('dark'))ex.signal_$(idx).value=BigInt(1);")
        end
    end

    # ─── Populate shared signal getters + register cross-island subscribers ───
    # Each shared signal participates in two-way live sync via window.__therapy
    # (the pub/sub registry from SignalRuntime.jl). Reads delegate to the local
    # WASM global; writes from any island broadcast via __therapy.set, and the
    # registered callback below mirrors the new value into THIS island's WASM
    # global + triggers the reactive runtime to re-flush dependent effects.
    if has_shared_signals
        for (i, sig) in enumerate(analysis.signals)
            sig.shared_name === nothing && continue
            idx = i - 1
            push!(parts, "        _ss.get_s$(idx)=function(){return ex.signal_$(idx).value;};")
            # Convert incoming JS value to the WASM global's expected representation
            is_string_sig = idx in string_signal_indices
            is_bool_sig = idx in bool_signal_indices
            is_float_sig = idx in float_signal_indices
            conv = if is_string_sig
                "(v===null||v===undefined)?0:__tw.toWasm(ex,String(v))"
            elseif is_bool_sig
                "v?1:0"
            elseif is_float_sig
                "(Number(v)||0)"
            else
                "BigInt(Number(v)||0)"
            end
            flush_call = flush_func_idx[] !== nothing ?
                "if(ex._rt_subs_$(idx))ex._rt_flush(ex._rt_subs_$(idx).value);" : ""
            push!(parts,
                "        window.__therapy.reg(" *
                "\"$(sig.shared_name)\"," *
                "ex.signal_$(idx).value," *
                "function(v){ex.signal_$(idx).value=$(conv);$(flush_call)_io.present();});")
        end
    end

    # ─── DOM refs (JS variables + WASM externref globals) ───
    # JS variables: used by current JS effects (will be removed in P1)
    # WASM externref globals: used by WASM effects (added in P1)
    for hk in needed_hks_vec
        push!(parts, "        var hk_$hk = island.querySelector('[data-hk=\"$hk\"]');")
        push!(parts, "        ex.hk_$(hk).value = hk_$hk;")
    end

    # ─── Wire string text binding proxies (now that ex is available) ───
    for (hk, _) in sort(collect(str_text_imports))
        push!(parts, "        _stb[$(hk)]=function(n,r){if(n)n.textContent=r?__tw.fromWasm(ex,r):'';};")
    end
    for (hk, _) in sort(collect(str_value_imports))
        push!(parts, "        _stb[$(hk)]=function(n,r){if(n)n.value=r?__tw.fromWasm(ex,r):'';};")
    end

    # ─── Wire effect js() deferred implementations (now that ex is available) ───
    for line in eff_js_deferred
        push!(parts, line)
    end

    # ─── Reactive Memos ───
    # Memo factory closures still need initialization in JS (creates WASM closure struct).
    # The memo computation itself runs in WASM via the reactive runtime.
    for m in analysis.memos
        result = get(memo_results, m.idx, nothing)
        if result !== nothing
            if hasproperty(result, :needs_closure_arg) && result.needs_closure_arg && result.factory_export !== nothing
                push!(parts, "        var _mc$(m.idx) = ex.$(result.factory_export)();")
            end
        end
    end

    # ─── DOM Binding Effects ───
    # Every analyzed binding must have entered the WASM effect table above.
    # Unsupported representation/attribute pairs reject compilation rather than
    # hydrating a partially reactive DOM tree.
    for b in analysis.bindings
        idx = get(sig_idx, b.signal_id, nothing)
        idx === nothing && continue
        if !(b.target_hk in wasm_effect_binding_hks)
            error("unsupported DOM binding at hk=$(b.target_hk): signal $(idx), attribute $(b.attribute)")
        end
    end

    # ─── $$ event delegation tracking (used by both Show and handler sections) ───
    show_hk_ranges = [(sn.content_hk_start, sn.content_hk_end) for sn in analysis.show_nodes]
    delegated_events = Set{String}()

    # ─── Show() Effects (Leptos-style node-level DOM) ───
    for sn in analysis.show_nodes
        idx = get(sig_idx, sn.signal_id, nothing)
        if idx === nothing && sn.condition_fn === nothing
            continue
        end
        shk = sn.target_hk
        has_fallback = sn.fallback_hk > 0
        is_wasm_show = shk in wasm_show_hks

        # Save child nodes as a DocumentFragment (preserves event listeners)
        push!(parts, "        var _show_$(shk)_frag = document.createDocumentFragment();")
        push!(parts, "        while(hk_$(shk).firstChild) _show_$(shk)_frag.appendChild(hk_$(shk).firstChild);")
        push!(parts, "        hk_$(shk).style.display = '';")

        if has_fallback
            fbhk = sn.fallback_hk
            push!(parts, "        var _show_$(shk)_fb_frag = document.createDocumentFragment();")
            push!(parts, "        while(hk_$(fbhk).firstChild) _show_$(shk)_fb_frag.appendChild(hk_$(fbhk).firstChild);")
            push!(parts, "        hk_$(fbhk).style.display = '';")
        end

        # Wire inner handlers on fragment nodes via $$ property delegation
        # When Show content is visible (in DOM), island delegation catches events.
        # When hidden (in fragment), events don't fire anyway.
        inner_handlers = [(h, get(handler_results, h.id, nothing)) for h in analysis.handlers
                          if h.target_hk >= sn.content_hk_start && h.target_hk <= sn.content_hk_end]
        for (h, wasm_result) in inner_handlers
            if wasm_result !== nothing && hasproperty(wasm_result, :needs_closure_arg) && wasm_result.needs_closure_arg && wasm_result.factory_export !== nothing
                push!(parts, "        var _hc$(h.id) = ex.$(wasm_result.factory_export)();")
            end
        end
        for (h, wasm_result) in inner_handlers
            if wasm_result !== nothing
                hk_h = h.target_hk
                dom_event = event_name_to_dom(h.event)
                wrapper_name = get(handler_wrapper_exports, h.id, nothing)
                has_closure = hasproperty(wasm_result, :needs_closure_arg) && wasm_result.needs_closure_arg && wasm_result.factory_export !== nothing
                call_fn = wrapper_name !== nothing ? wrapper_name : wasm_result.export_name
                call_js = has_closure ? "ex.$(call_fn)(_hc$(h.id))" : "ex.$(call_fn)()"
                # Store handler as $$ property (Leptos pattern) — delegation picks it up
                push!(parts, "        var _ih_$(hk_h) = _show_$(shk)_frag.querySelector('[data-hk=\"$(hk_h)\"]');")
                push!(parts, "        if (_ih_$(hk_h)) _ih_$(hk_h).\$\$$(dom_event) = function(e){$(call_js);_io.present();};")
                # Register event type for delegation (may already be registered by non-Show handler)
                push!(delegated_events, dom_event)
            end
        end

        # All Shows are WASM-managed — no JS fallback
        push!(parts, "        ex._show_$(shk)_frag.value = _show_$(shk)_frag;")
        if has_fallback
            push!(parts, "        ex._show_$(shk)_fb_frag.value = _show_$(shk)_fb_frag;")
        end
    end

    # ─── For() nodes — Leptos-style keyed reconciliation ───
    # For each compiled For node: generate render function + reconciliation in JS glue.
    # WASM effect tracks deps and calls the deferred for_update import.
    # JS reconciler calls the memo, reads items via bridge functions, rebuilds innerHTML.
    if !isempty(for_compiled)
        # HTML escape helper (used by auto-generated render functions)
        push!(parts, "        function _escH(v){return String(v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;');}")
    end
    for (fid, fc) in sort(collect(for_compiled))
        f = fc.for_node
        mr = fc.memo_result

        # Emit the auto-generated render function
        push!(parts, fc.render_js)

        # Determine memo call expression and bridge functions
        if f.items_type == :memo && mr !== nothing
            memo_call = if hasproperty(mr, :needs_closure_arg) && mr.needs_closure_arg && mr.factory_export !== nothing
                "ex.$(mr.export_name)(_mc$(f.memo_idx))"
            else
                "ex.$(mr.export_name)()"
            end

            if hasproperty(mr, :returns_vec_str) && mr.returns_vec_str
                # Vector{String} memo: read items as strings
                push!(parts, "        _ff[$(fid)]=function(c){var items=$(memo_call);var len=Number(ex._bv_str_len(items));var html='';for(var i=0;i<len;i++){var ir=ex._bv_str_get(items,BigInt(i+1));var is_=__tw.fromWasm(ex,ir);html+=_for_$(fid)_render(is_,i+1);}c.innerHTML=html;};")
            elseif hasproperty(mr, :returns_vec_i64) && mr.returns_vec_i64
                # Vector{Int64} memo: read items as integers
                push!(parts, "        _ff[$(fid)]=function(c){var items=$(memo_call);var len=Number(ex._bv_i64_len(items));var html='';for(var i=0;i<len;i++){var idx=Number(ex._bv_i64_get(items,BigInt(i+1)));html+=_for_$(fid)_render(idx,i+1);}c.innerHTML=html;};")
            elseif hasproperty(mr, :returns_vec_f64) && mr.returns_vec_f64
                # Vector{Float64} memo: read items as floats
                push!(parts, "        _ff[$(fid)]=function(c){var items=$(memo_call);var len=Number(ex._bv_f64_len(items));var html='';for(var i=0;i<len;i++){var val=ex._bv_f64_get(items,BigInt(i+1));html+=_for_$(fid)_render(val,i+1);}c.innerHTML=html;};")
            else
                @warn "For() node $(fid): memo does not return Vector{String}, Vector{Int64}, or Vector{Float64} — cannot reconcile" memo_idx=f.memo_idx
            end
        elseif f.items_type == :signal
            # Signal-sourced For: read from signal global directly
            idx = get(sig_idx, f.signal_id, nothing)
            if idx !== nothing && idx in vec_signal_indices
                # Vector signal — TODO: determine element type
                @warn "For() with vector signal source not yet supported" for_id=fid signal_idx=idx
            else
                @warn "For() with non-vector signal source — cannot reconcile" for_id=fid
            end
        else
            @warn "For() node $(fid): static items — no reconciliation needed" for_id=fid
        end
    end

    # ─── Compiled Effects ───
    # Effects with export_name are in the funcref table — they run via _rt_flush.
    # No queueMicrotask needed; initial run is handled by _rt_flush(all_bits).
    # Effects with js_strings (mixed WASM+JS) still need queueMicrotask for the JS part.
    for eff in analysis.effects
        result = get(effect_results, eff.id, nothing)
        result === nothing && continue
        if hasproperty(result, :effect_js_calls)
            # Reactive JS effect — in funcref table, runs via _rt_flush. No emission needed.
        elseif hasproperty(result, :js_strings) && !isempty(result.js_strings)
            # WASM effect with appended js() strings: run JS after WASM effect
            js_suffix = join(result.js_strings, ";") * ";"
            push!(parts, "        queueMicrotask(function(){ex.$(result.export_name)();$(js_suffix)});")
        end
    end

    # ─── Mount Effects ───
    for mt in analysis.mount_effects
        result = get(mount_results, mt.id, nothing)
        result === nothing && continue
        if hasproperty(result, :js_code) && !isempty(result.js_code)
            # Pure JS mount effect — emit directly
            push!(parts, "        queueMicrotask(function(){$(result.js_code);_io.present();});")
        elseif hasproperty(result, :export_name)
            push!(parts, "        queueMicrotask(function(){ex.$(result.export_name)();_io.present();});")
        end
    end

    # ─── Event Handlers (Leptos $$ property delegation) ───
    # Leptos pattern: store handler as $$event property on element,
    # one global listener per event type walks DOM checking properties.
    # Faster than data-hk string matching — property check vs getAttribute.

    for h in analysis.handlers
        in_show = any(r -> h.target_hk >= r[1] && h.target_hk <= r[2], show_hk_ranges)
        in_show && continue  # Show handlers wired in Show() section

        dom_event = event_name_to_dom(h.event)
        wasm_result = get(handler_results, h.id, nothing)

        if wasm_result !== nothing
            has_closure = hasproperty(wasm_result, :needs_closure_arg) && wasm_result.needs_closure_arg && wasm_result.factory_export !== nothing
            wrapper_name = get(handler_wrapper_exports, h.id, nothing)

            # Initialize closure struct if needed
            if has_closure
                push!(parts, "        var _hc$(h.id) = ex.$(wasm_result.factory_export)();")
            end

            # Build the WASM call expression
            call_js = if has_closure
                wrapper_name !== nothing ? "ex.$(wrapper_name)(_hc$(h.id))" : "ex.$(wasm_result.export_name)(_hc$(h.id))"
            else
                wrapper_name !== nothing ? "ex.$(wrapper_name)()" : "ex.$(wasm_result.export_name)()"
            end

            # Store handler as $$ property on the target element (Leptos pattern)
            push!(parts, "        hk_$(h.target_hk).\$\$$(dom_event) = function(e){$(call_js);_io.present();};")
            push!(delegated_events, dom_event)
        else
            error("missing canonical Wasm root for handler $(h.id) ($(h.event) on hk=$(h.target_hk))")
        end
    end

    # Emit one delegation listener per event type on island root
    # Walks DOM from event.target upward, checks for $$ property
    for dom_event in sort(collect(delegated_events))
        push!(parts, "        island.addEventListener(\"$dom_event\", function(e){var el=e.target;while(el&&el!==island){if(el.\$\$$dom_event){el.\$\$$(dom_event)(e);return;}el=el.parentNode;}});")
    end

    # ─── Input Bindings ───
    for ib in analysis.input_bindings
        idx = get(sig_idx, ib.signal_id, nothing)
        idx === nothing && continue
        is_string_sig = idx in string_signal_indices
        is_bool_sig = idx in bool_signal_indices
        is_float_sig = idx in float_signal_indices

        # Input binding: write to WASM global + notify reactive runtime
        # WASM reactive runtime handles effect scheduling
        subs_global_idx = rt_globals.signal_subs_base + UInt32(idx)
        all_bits = flush_func_idx[] !== nothing ? "ex._rt_flush(ex._rt_subs_$(idx).value);" : ""
        # No JS signal sync needed — signals live in WASM globals only.
        # If the bound signal is shared, broadcast the new value to other
        # islands via __therapy.set so their .reg callbacks fire.
        sig_obj = analysis.signals[idx + 1]
        broadcast = sig_obj.shared_name !== nothing ?
            "window.__therapy.set(\"$(sig_obj.shared_name)\",v);" : ""
        all_bits *= broadcast * "_io.present();"

        if ib.input_type == :number || ib.input_type == :range
            if is_float_sig
                push!(parts, "        hk_$(ib.target_hk).addEventListener(\"input\", function(e){var v=Number(e.target.value)||0;ex.signal_$(idx).value=v;$(all_bits)});")
            elseif is_bool_sig
                push!(parts, "        hk_$(ib.target_hk).addEventListener(\"input\", function(e){var v=Number(e.target.value)||0;ex.signal_$(idx).value=v?1:0;$(all_bits)});")
            else
                push!(parts, "        hk_$(ib.target_hk).addEventListener(\"input\", function(e){var v=Number(e.target.value)||0;ex.signal_$(idx).value=BigInt(v);$(all_bits)});")
            end
        elseif ib.input_type == :checkbox
            if is_bool_sig
                push!(parts, "        hk_$(ib.target_hk).addEventListener(\"change\", function(e){var v=e.target.checked?1:0;ex.signal_$(idx).value=v;$(all_bits)});")
            elseif is_float_sig
                push!(parts, "        hk_$(ib.target_hk).addEventListener(\"change\", function(e){var v=e.target.checked?1:0;ex.signal_$(idx).value=v;$(all_bits)});")
            else
                push!(parts, "        hk_$(ib.target_hk).addEventListener(\"change\", function(e){var v=e.target.checked?1:0;ex.signal_$(idx).value=BigInt(v);$(all_bits)});")
            end
        elseif is_string_sig
            push!(parts, "        hk_$(ib.target_hk).addEventListener(\"input\", function(e){var v=e.target.value;ex.signal_$(idx).value=__tw.toWasm(ex,v);$(all_bits)});")
        else
            push!(parts, "        hk_$(ib.target_hk).addEventListener(\"input\", function(e){var v=e.target.value;ex.signal_$(idx).value=v;$(all_bits)});")
        end
    end

    # ─── Initial effect flush (run WASM effects once to display initial values) ───
    if !isempty(wasm_effect_funcs)
        # Call _rt_flush with all effect bits set to run every WASM effect once
        all_bits = Int64((1 << length(wasm_effect_funcs)) - 1)
        push!(parts, "        ex._rt_flush(BigInt($(all_bits)));")
    end
    push!(parts, "        _io.present();")

    push!(parts, "      }).catch(function(e){console.error('[therapy] WASM instantiation failed for $cn:',e);});")  # end .then + .catch
    push!(parts, "    });")    # end forEach
    push!(parts, "  }")
    push!(parts, "  window.TherapyHydrate[\"$cn\"] = hydrate_$cn;")
    # Leptos pattern: defer hydration with requestIdleCallback so initial HTML
    # renders without blocking. Falls back to setTimeout for Safari < 17.4.
    push!(parts, "  if (!window._therapyRouterHydrating) (window.requestIdleCallback||setTimeout)(hydrate_$cn);")
    push!(parts, "})();")

    return (join(parts, "\n"), length(wasm_bytes))
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

"""Classify a signal's WASM storage based on its Julia type."""
function _signal_wasm_kind(sig::AnalyzedSignal)::Symbol
    if sig.type !== nothing && sig.type <: AbstractString
        return :string_ref
    elseif sig.type !== nothing && sig.type === Bool
        return :i32
    elseif sig.type !== nothing && sig.type <: AbstractFloat
        return :f64
    elseif sig.type !== nothing && sig.type <: AbstractVector
        return :vec_ref
    else
        return :i64
    end
end

"""Build captured_signal_fields mapping for a Show condition closure.
Same pattern as handlers/memos — maps captured signal getters to WASM global indices."""
function captured_signal_fields_for_show(condition_fn::Function, analysis::ComponentAnalysis,
                                          sig_idx::Dict{UInt64, Int})
    fields = Dict{Symbol, Tuple{Bool, UInt32}}()
    closure_type = typeof(condition_fn)
    for fname in fieldnames(closure_type)
        captured = getfield(condition_fn, fname)
        gid = get(analysis.getter_map, captured, nothing)
        if gid !== nothing
            idx = get(sig_idx, gid, nothing)
            if idx !== nothing
                fields[fname] = (true, UInt32(idx))
            end
        end
    end
    return fields
end

# LEPTOS-1002: Deleted _operation_to_js(). Handler tracing fallback removed.

# LEPTOS-1003: Deleted _signal_dep_reads(), _walk_closure_deps!(),
# _handler_presync_js(), _handler_sync_js(). All JS signal mirror infrastructure removed.
# Signals live in WASM globals only — no JS mirrors, no sync.

"""
Walk a closure's captured fields to discover which signals it depends on.
Returns a Set of signal IDs found in the closure's captured fields.
Used for WASM reactive runtime subscription bitmask setup.
"""
function _discover_closure_signal_deps(fn, analysis::ComponentAnalysis)::Set{UInt64}
    deps = Set{UInt64}()
    visited = Set{UInt64}()
    _walk_signal_deps!(fn, analysis, deps, visited)
    return deps
end

function _walk_signal_deps!(fn, analysis::ComponentAnalysis, deps::Set{UInt64}, visited::Set{UInt64})
    oid = objectid(fn)
    oid in visited && return
    push!(visited, oid)

    closure_type = typeof(fn)
    for fname in fieldnames(closure_type)
        captured = getfield(fn, fname)
        gid = get(analysis.getter_map, captured, nothing)
        if gid !== nothing
            push!(deps, gid)
            continue
        end
        if captured isa Function
            _walk_signal_deps!(captured, analysis, deps, visited)
        end
    end
end

# ─── js() / println() Extraction ───

"""
    _extract_js_calls(closure, analysis, sig_idx; use_params=false) ->
        (skip_indices, js_strings, arg_refs, call_plans)

Pre-scan a closure's typed IR for js() calls. Returns the SSA indices to skip
during WASM compilation and the extracted JS code strings with \$N args resolved.

This implements the Leptos pattern: WASM does computation, JS does browser APIs.
js() strings are compile-time constants. When use_params=true, \$N args resolve
to import parameter names (_p0, _p1) for WASM import calls. When false, they
resolve to host-side signal access for lifecycle JS deliberately outside the
Julia-to-Wasm compilation boundary.

Returns `arg_refs`, the aggregate `(kind, idx, wasm_kind)` references, and
`call_plans`, the per-call import argument projections used by canonical roots.
"""
function _extract_js_calls(closure::Function,
                            analysis::ComponentAnalysis=ComponentAnalysis(),
                            sig_idx::Dict{UInt64, Int}=Dict{UInt64, Int}();
                            use_params::Bool=false)
    skip_indices = Set{Int}()
    js_strings = String[]
    arg_refs = Tuple{Symbol, Int, Symbol}[]  # (kind, idx, wasm_kind) for effect params
    call_plans = Any[]
    ssa_ref = Dict{Int, Tuple{Symbol, Int, Symbol}}()  # SSA id → structured ref

    typed_results = Base.code_typed(closure, ())
    isempty(typed_results) && return (skip_indices, js_strings, arg_refs, call_plans)
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
                # Signal getter → Number(sN[0]()) for numeric, sN[0]() for strings
                gid = get(analysis.getter_map, captured, nothing)
                if gid !== nothing
                    idx = get(sig_idx, gid, nothing)
                    if idx !== nothing
                        sig = analysis.signals[idx + 1]  # 0-indexed → 1-indexed
                        wasm_kind = _signal_wasm_kind(sig)
                        ssa_ref[i] = (:signal, idx, wasm_kind)
                        if sig.type !== nothing && sig.type <: AbstractString
                            ssa_js[i] = "s$(idx)[0]()"
                        else
                            ssa_js[i] = "Number(s$(idx)[0]())"
                        end
                    end
                end
                # Memo getter → Number(mN())
                if captured isa MemoAnalysisGetter
                    midx = get(analysis.memo_getter_map, captured, nothing)
                    if midx !== nothing
                        ssa_ref[i] = (:memo, midx, :i64)
                        ssa_js[i] = "Number(m$(midx)())"
                    end
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
                local_refs = Tuple{Symbol,Int,Symbol}[]
                selected_args = Int[]
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
                            ref = get(ssa_ref, arg.id, nothing)
                            if use_params && ref !== nothing
                                pidx = length(arg_refs)
                                push!(arg_refs, ref)
                                push!(local_refs, ref)
                                push!(selected_args, n + 1) # bound-invoke args include the JS string at 1
                                ref[3] == :string_ref ? "__tw.fromWasm(ex,_p$(pidx))" : "Number(_p$(pidx))"
                            else
                                get(ssa_js, arg.id, "undefined")
                            end
                        else
                            string(arg)
                        end
                        js_str = replace(js_str, "\$$n" => js_expr)
                    end
                    push!(js_strings, js_str)
                    push!(call_plans, (site=i, js_code=js_str,
                        arg_refs=local_refs, argument_indices=selected_args))
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

    return (skip_indices, js_strings, arg_refs, call_plans)
end


# LEPTOS-1002: Deleted _extract_signal_ops_js() and _resolve_value_js().
# Handler compilation is WASM-only — no JS fallback for signal ops.

# ─── WasmTarget Handler Compilation ───

function _plan_captured_fields(fn::Function, analysis::ComponentAnalysis,
        sig_idx::Dict{UInt64,Int}, signal_globals::Dict{Int,UInt32})
    globals = Dict{Symbol,Tuple{Bool,UInt32}}()
    constants = Dict{Symbol,Any}()
    getter_indices = Dict{Symbol,Int}()
    modified = UInt64[]
    bound_leaves = Tuple{Any,Tuple}[]
    for field in fieldnames(typeof(fn))
        value = getfield(fn, field)
        signal_id = get(analysis.getter_map, value, nothing)
        is_getter = true
        if signal_id === nothing
            signal_id = get(analysis.setter_map, value, nothing)
            is_getter = false
        end
        if signal_id === nothing
            constants[field] = value
            continue
        end
        idx = get(sig_idx, signal_id, nothing)
        idx === nothing && error("closure field `$field` references an unknown signal")
        global_idx = get(signal_globals, idx, nothing)
        global_idx === nothing && error("signal $idx has no declared Wasm global")
        globals[field] = (is_getter, global_idx)
        if is_getter
            getter_indices[field] = idx
            push!(bound_leaves, (value, ()))
        else
            push!(modified, signal_id)
            value_type = typeof(value)
            isempty(value_type.parameters) &&
                error("signal setter `$field` has no declared value type")
            push!(bound_leaves, (value, (value_type.parameters[1],)))
        end
    end
    return (globals=globals, constants=constants,
        getter_indices=getter_indices, modified=modified,
        bound_leaves=bound_leaves)
end

function _memo_root_links(fn::Function, analysis::ComponentAnalysis, memo_results)
    typed = Base.code_typed(fn, ())
    isempty(typed) && error("closure has no typed IR")
    code = typed[1][1]
    field_for_ssa = Dict{Int,Symbol}()
    for (i, stmt) in enumerate(code.code)
        if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3 &&
           stmt.args[1] isa GlobalRef && stmt.args[1].name === :getfield &&
           stmt.args[3] isa QuoteNode
            field_for_ssa[i] = stmt.args[3].value
        end
    end
    skip = Set{Int}()
    roots = Dict{Int,String}()
    bound_leaves = Tuple{Any,Tuple}[]
    for (i, stmt) in enumerate(code.code)
        stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 2 || continue
        source = stmt.args[2]
        source isa Core.SSAValue || continue
        field = get(field_for_ssa, source.id, nothing)
        field === nothing && continue
        value = getfield(fn, field)
        value isa MemoAnalysisGetter || continue
        memo_idx = get(analysis.memo_getter_map, value, nothing)
        memo_idx === nothing && error("memo getter field `$field` is not owned by this island")
        result = get(memo_results, memo_idx, nothing)
        result === nothing && error("memo $memo_idx is not a declared compilation root")
        push!(skip, source.id)
        roots[i] = result.export_name
        push!(bound_leaves, (value, ()))
    end
    return skip, roots, bound_leaves
end

function _plan_memo_root(fn::Function, memo_idx::Int, analysis::ComponentAnalysis,
        sig_idx::Dict{UInt64,Int}, signal_globals::Dict{Int,UInt32}, memo_results)
    captures = _plan_captured_fields(fn, analysis, sig_idx, signal_globals)
    skip, invoke_roots, memo_leaves = _memo_root_links(fn, analysis, memo_results)
    typed = Base.code_typed(fn, ())
    isempty(typed) && error("memo $memo_idx has no typed IR")
    return_type = typed[1][2]
    bindings = WT.RootBindings(captured_globals=captures.globals,
        captured_constants=captures.constants, skip_stmts=skip,
        invoke_roots=invoke_roots,
        bound_leaves=vcat(captures.bound_leaves, memo_leaves),
        elide_closure_context=true)
    return (export_name="_memo_$(memo_idx)", bindings=bindings,
        needs_closure_arg=false, factory_export=nothing,
        returns_vec_str=return_type === Vector{String},
        returns_vec_i64=return_type === Vector{Int64},
        returns_vec_f64=return_type === Vector{Float64})
end

function _plan_effect_root(fn::Function, effect_id::Int, analysis::ComponentAnalysis,
        sig_idx::Dict{UInt64,Int}, signal_globals::Dict{Int,UInt32},
        rt_globals::ReactiveRuntimeGlobals, mod::WT.WasmModule, memo_results)
    captures = _plan_captured_fields(fn, analysis, sig_idx, signal_globals)
    skip, invoke_roots, memo_leaves = _memo_root_links(fn, analysis, memo_results)
    tracking = UInt8[]
    for idx in values(captures.getter_indices)
        append!(tracking, emit_tracking_bytecode(
            rt_globals.signal_subs_base + UInt32(idx), rt_globals))
    end
    entry_calls = UInt32[]
    if !isempty(tracking)
        push!(tracking, WT.Opcode.END)
        tracking_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
            WT.WasmValType[], tracking)
        push!(entry_calls, tracking_idx)
    end
    bindings = WT.RootBindings(captured_globals=captures.globals,
        captured_constants=captures.constants, skip_stmts=skip,
        invoke_roots=invoke_roots, entry_calls=entry_calls,
        bound_leaves=vcat(captures.bound_leaves, memo_leaves),
        elide_closure_context=true, void_return=true)
    return (export_name="_effect_$(effect_id)", bindings=bindings,
        js_strings=String[])
end

function _plan_js_effect_root(fn::Function, effect_id::Int,
        analysis::ComponentAnalysis, sig_idx::Dict{UInt64,Int},
        signal_globals::Dict{Int,UInt32}, rt_globals::ReactiveRuntimeGlobals,
        mod::WT.WasmModule, memo_results, invoke_imports::Dict{Int,UInt32}, meta)
    captures = _plan_captured_fields(fn, analysis, sig_idx, signal_globals)
    skip, invoke_roots, memo_leaves = _memo_root_links(fn, analysis, memo_results)
    extracted_skip, _, _, _ = _extract_js_calls(fn, analysis, sig_idx; use_params=true)
    union!(skip, extracted_skip)
    invoke_arguments = Dict{Int,Vector{Int}}()
    for call in meta
        delete!(skip, call.site)
        invoke_arguments[call.site] = call.argument_indices
    end
    tracking = UInt8[]
    for idx in values(captures.getter_indices)
        append!(tracking, emit_tracking_bytecode(
            rt_globals.signal_subs_base + UInt32(idx), rt_globals))
    end
    entry_calls = UInt32[]
    if !isempty(tracking)
        push!(tracking, WT.Opcode.END)
        push!(entry_calls, WT.add_function!(mod, WT.WasmValType[],
            WT.WasmValType[], WT.WasmValType[], tracking))
    end
    bindings = WT.RootBindings(captured_globals=captures.globals,
        captured_constants=captures.constants, skip_stmts=skip,
        invoke_imports=invoke_imports, invoke_roots=invoke_roots,
        invoke_arguments=invoke_arguments, entry_calls=entry_calls,
        bound_leaves=vcat(captures.bound_leaves, memo_leaves),
        elide_closure_context=true, void_return=true)
    return (export_name="_effect_$(effect_id)", bindings=bindings,
        effect_js_calls=meta)
end

function _plan_mount_root(fn::Function, mount_id::Int, analysis::ComponentAnalysis,
        sig_idx::Dict{UInt64,Int}, signal_globals::Dict{Int,UInt32})
    _, js_strings, _, _ = _extract_js_calls(fn, analysis, sig_idx)
    !isempty(js_strings) && return (js_code=join(js_strings, ";") * ";",)
    captures = _plan_captured_fields(fn, analysis, sig_idx, signal_globals)
    bindings = WT.RootBindings(captured_globals=captures.globals,
        captured_constants=captures.constants,
        bound_leaves=captures.bound_leaves,
        elide_closure_context=true, void_return=true)
    return (export_name="_mount_$(mount_id)", bindings=bindings)
end

function _plan_show_root(fn::Function, target_hk::Int, analysis::ComponentAnalysis,
        sig_idx::Dict{UInt64,Int}, signal_globals::Dict{Int,UInt32}, memo_results)
    captures = _plan_captured_fields(fn, analysis, sig_idx, signal_globals)
    skip, invoke_roots, memo_leaves = _memo_root_links(fn, analysis, memo_results)
    bindings = WT.RootBindings(captured_globals=captures.globals,
        captured_constants=captures.constants, skip_stmts=skip,
        invoke_roots=invoke_roots,
        bound_leaves=vcat(captures.bound_leaves, memo_leaves),
        elide_closure_context=true)
    return (export_name="_show_cond_$(target_hk)", bindings=bindings)
end

"""Declare one handler as a root in Therapy's single closed-world WT plan."""
function _plan_handler_root(handler::Function, handler_id::Int,
        analysis::ComponentAnalysis, sig_idx::Dict{UInt64,Int},
        signal_globals::Dict{Int,UInt32}, mod::WT.WasmModule,
        shared_signal_imports::Dict{Int,UInt32}=Dict{Int,UInt32}())
    captured = Dict{Symbol,Tuple{Bool,UInt32}}()
    captured_constants = Dict{Symbol,Any}()
    modified = UInt64[]
    shared_fields = Dict{Symbol,Int}()
    bound_leaves = Tuple{Any,Tuple}[]

    for field in fieldnames(typeof(handler))
        value = getfield(handler, field)
        signal_id = get(analysis.getter_map, value, nothing)
        is_getter = true
        if signal_id === nothing
            signal_id = get(analysis.setter_map, value, nothing)
            is_getter = false
        end
        if signal_id === nothing
            captured_constants[field] = value
            continue
        end
        idx = get(sig_idx, signal_id, nothing)
        idx === nothing && error("handler $handler_id references an unknown signal")
        global_idx = get(signal_globals, idx, nothing)
        global_idx === nothing && error("handler $handler_id signal has no declared global")
        captured[field] = (is_getter, global_idx)
        if is_getter
            push!(bound_leaves, (value, ()))
        else
            push!(modified, signal_id)
            value_type = typeof(value)
            isempty(value_type.parameters) &&
                error("handler setter `$field` has no declared value type")
            push!(bound_leaves, (value, (value_type.parameters[1],)))
        end
        is_getter && haskey(shared_signal_imports, idx) && (shared_fields[field] = idx)
    end

    skip_stmts, js_strings, _, _ = _extract_js_calls(handler, analysis, sig_idx)
    invoke_imports = Dict{Int,UInt32}()
    invoke_arguments = Dict{Int,Vector{Int}}()
    if !isempty(js_strings)
        import_idx = WT.add_import!(mod, "js", "js_h$(handler_id)",
            WT.WasmValType[], WT.WasmValType[])
        first_js = minimum(skip_stmts)
        invoke_imports[first_js] = import_idx
        invoke_arguments[first_js] = Int[]
        delete!(skip_stmts, first_js)
    end

    if !isempty(shared_fields)
        typed = Base.code_typed(handler, ())
        isempty(typed) && error("handler $handler_id has no typed IR")
        code = typed[1][1]
        fields = Dict{Int,Symbol}()
        for (i, stmt) in enumerate(code.code)
            if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3 &&
               stmt.args[1] isa GlobalRef && stmt.args[1].name === :getfield &&
               stmt.args[3] isa QuoteNode
                fields[i] = stmt.args[3].value
            end
        end
        for (i, stmt) in enumerate(code.code)
            stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 2 || continue
            source = stmt.args[2]
            source isa Core.SSAValue || continue
            field = get(fields, source.id, nothing)
            field !== nothing && haskey(shared_fields, field) || continue
            invoke_imports[i] = shared_signal_imports[shared_fields[field]]
        end
    end

    export_name = "_h$(handler_id)"
    bindings = WT.RootBindings(
        captured_globals=captured,
        captured_constants=captured_constants,
        skip_stmts=skip_stmts,
        invoke_imports=invoke_imports,
        invoke_arguments=invoke_arguments,
        bound_leaves=bound_leaves,
        elide_closure_context=true,
        void_return=true,
    )
    return (export_name=export_name, modified_signals=modified,
        js_strings=js_strings, needs_closure_arg=false,
        factory_export=nothing, bindings=bindings)
end

# ─── WasmTarget Effect Compilation ───

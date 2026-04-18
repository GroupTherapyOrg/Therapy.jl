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
include("ForRuntime.jl")
include("DOMBridge.jl")
include("WasmReactiveRuntime.jl")
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
    wasm_size::Int          # WASM binary size in bytes (before embedding in JS)
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
function compile_island(name::Symbol; optimize_wasm::Bool=false)::IslandJSOutput
    island_def = get(ISLAND_REGISTRY, name, nothing)
    island_def === nothing && error("No island :$name registered")

    # Use cached props from SSR (populated when IslandDef is called with real data).
    # This ensures analyze_component runs with actual prop values, so closures
    # capture real data (e.g., items_data=["Julia",...]) instead of empty defaults.
    cached_props = get(ISLAND_PROPS_CACHE, name, Dict{Symbol, Any}())
    analysis = analyze_component(island_def.render_fn; cached_props...)

    # Generate WASM module + JS loader.
    # Suppress WasmTarget stack validator warnings — they're non-fatal type-tracking
    # mismatches in the internal validator. The WASM itself validates with wasm-tools.
    # Suppress WasmTarget stack validator warnings during compilation.
    # They're non-fatal type-tracking mismatches — the WASM validates with wasm-tools.
    prev_logger = Base.CoreLogging.current_logger_for_env(Base.CoreLogging.Warn, :WasmTarget, nothing)
    js, wasm_size = try
        Base.disable_logging(Base.CoreLogging.Info)
        Base.disable_logging(Base.CoreLogging.Warn)
        _generate_island_wasm(string(name), analysis; prop_names=island_def.prop_names, optimize_wasm=optimize_wasm)
    finally
        Base.disable_logging(Base.CoreLogging.Debug)  # reset to default threshold
    end

    return IslandJSOutput(js, string(name), length(analysis.signals), length(analysis.handlers), wasm_size)
end

"""
    compile_island(name::Symbol, body::Expr) -> IslandJSOutput

Compile an island from an explicit body expression (for testing).
"""
function compile_island(name::Symbol, body::Expr)::IslandJSOutput
    fn = Core.eval(Main, Expr(:function, Expr(:call, gensym()), body))
    analysis = analyze_component(fn)
    js, wasm_size = _generate_island_wasm(string(name), analysis)
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

    # Initialize WasmGC type hierarchy (DataType, Union, etc.)
    # Required for compile_closure_body with optimize=false (unoptimized IR references DataType).
    WT.create_jl_type_hierarchy!(mod, type_registry)

    # Add Math.pow import (required by WasmTarget for float power operations)
    # Must come before any compile_closure_body calls since imports affect function indices.
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
    for b in analysis.bindings
        b.attribute !== nothing && continue  # only text content bindings
        # Find signal index
        _bi = findfirst(s -> s.id == b.signal_id, analysis.signals)
        _bi === nothing && continue
        sig = analysis.signals[_bi]
        if _signal_wasm_kind(sig) == :string_ref
            import_idx = WT.add_import!(mod, "str_fns", "stb_$(b.target_hk)",
                WT.WasmValType[WT.ExternRef, WT.ExternRef], WT.WasmValType[])
            str_text_imports[b.target_hk] = import_idx
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
            # String signal: WASM global holds a WasmGC ref (i8 array)
            push!(string_signal_indices, idx)
            str_type_idx = WT.get_string_array_type!(mod, type_registry)
            init_str = sig.initial_value isa AbstractString ? String(sig.initial_value) : ""
            init_bytes = WT.compile_const_value(init_str, mod, type_registry)
            actual_idx = WT.add_global_ref!(mod, str_type_idx, true, init_bytes)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
        elseif wasm_kind == :vec_ref
            # Vector signal: WASM global holds a WasmGC struct ref (Vector{T})
            push!(vec_signal_indices, idx)
            vec_val = sig.initial_value isa AbstractVector ? sig.initial_value : String[]
            vec_type = typeof(vec_val)
            vec_info = WT.register_vector_type!(mod, type_registry, vec_type)
            init_bytes = WT.compile_const_value(vec_val, mod, type_registry)
            actual_idx = WT.add_global_ref!(mod, vec_info.wasm_type_idx, true, init_bytes)
            WT.add_global_export!(mod, "signal_$(idx)", actual_idx)
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
    effect_js_imports = Dict{Int, UInt32}()  # effect_id → import_idx
    effect_js_meta = Dict{Int, NamedTuple{(:arg_refs, :js_code, :params_str), Tuple{Vector{Tuple{Symbol, Int, Symbol}}, String, String}}}()
    for eff in analysis.effects
        _, js_strings, arg_refs = _extract_js_calls(eff.fn, analysis, sig_idx; use_params=true)
        if !isempty(js_strings)
            js_code = join(js_strings, ";") * ";"
            # Build WASM import parameter types
            param_types = WT.WasmValType[]
            for (kind, idx, wasm_kind) in arg_refs
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
            import_idx = WT.add_import!(mod, "eff_js", "eff_$(eff.id)",
                param_types, WT.WasmValType[])
            effect_js_imports[eff.id] = import_idx
            params_str = join(["_p$i" for i in 0:(length(arg_refs)-1)], ",")
            effect_js_meta[eff.id] = (arg_refs=arg_refs, js_code=js_code, params_str=params_str)
        end
    end

    # ─── Canvas2D imports (WasmPlot.jl plotting backend) ───
    # Register Canvas2D draw calls as WASM imports. These are no-op stubs in Julia
    # that become real Canvas2D calls when the WASM module runs in the browser.
    # Uses func_registry so WasmTarget maps Julia function refs → import indices.
    #
    # UUID sourced from WasmPlot.jl's Project.toml — the previous
    # placeholder `a1b2c3d4-…` never matched a real package so
    # `Base.require` always threw; the `catch` silently dropped
    # canvas imports, and every WasmPlot-driven effect compiled into
    # an empty WASM module (render!(fig) calls resolved to nothing,
    # hence every extracted bar-chart / heatmap /lines! plot was a
    # blank canvas in the browser).
    canvas_func_registry = WT.FunctionRegistry()
    try
        _wasmplot = Base.require(Base.PkgId(Base.UUID("c1c0b9ed-8be2-478a-b5eb-22e4f5885b7b"), "WasmPlot"))
        canvas_stubs = getfield(_wasmplot, :CANVAS2D_STUBS)
        for (func_ref, import_name, arg_types, return_type) in canvas_stubs
            # Map Julia types to WASM types
            wasm_params = WT.NumType[]
            for T in arg_types
                push!(wasm_params, T === Float64 ? WT.F64 : WT.I64)
            end
            wasm_ret = return_type === Float64 ? WT.NumType[WT.F64] : WT.NumType[WT.I64]
            wasm_idx = WT.add_import!(mod, "canvas2d", import_name, wasm_params, wasm_ret)
            WT.register_function!(canvas_func_registry, import_name, func_ref, arg_types, UInt32(wasm_idx), return_type)
        end
        @debug "Canvas2D: registered $(length(canvas_stubs)) imports"
    catch e
        @debug "WasmPlot not available — Canvas2D imports skipped" exception=e
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

    # ─── Compile handler closures to WASM ───
    handler_results = Dict{Int, Any}()
    for h in analysis.handlers
        result = _compile_handler_wasm(h.handler, h.id, analysis, sig_idx, mod, type_registry, shared_signal_imports)
        if result !== nothing
            handler_results[h.id] = result
        end
    end

    # ─── Compile memo closures to WASM (before effects — effects may call memos) ───
    memo_results = Dict{Int, Any}()
    for m in analysis.memos
        result = _compile_memo_wasm(m.fn, m.idx, analysis, sig_idx, mod, type_registry)
        if result !== nothing
            memo_results[m.idx] = result
        end
    end

    # ─── Compile effect closures to WASM ───
    effect_results = Dict{Int, Any}()
    for eff in analysis.effects
        fr_to_use = isempty(canvas_func_registry.functions) ? nothing : canvas_func_registry
        result = _compile_effect_wasm(eff.fn, eff.id, analysis, sig_idx, mod, type_registry,
                                       rt_globals, effect_js_imports, effect_js_meta;
                                       func_registry=fr_to_use)
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

    # ─── Compile Show() closure conditions to WASM ───
    show_condition_exports = Dict{Int, String}()  # target_hk → export_name
    for sn in analysis.show_nodes
        if sn.condition_fn !== nothing && sn.condition_fn isa Function
            try
                show_export = "_show_cond_$(sn.target_hk)"
                csf = captured_signal_fields_for_show(sn.condition_fn, analysis, sig_idx)

                # Build invoke_imports for memo deps: map MemoAnalysisGetter invoke SSAs
                # to the memo's WASM function index (from memo_results)
                show_invoke_imports = Dict{Int, UInt32}()
                if !isempty(sn.memo_deps)
                    typed_results = Base.code_typed(sn.condition_fn, ())
                    if !isempty(typed_results)
                        code_info = typed_results[1][1]
                        for (i, stmt) in enumerate(code_info.code)
                            if stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 2
                                ci_or_mi = stmt.args[1]
                                mi = if ci_or_mi isa Core.CodeInstance
                                    ci_or_mi.def
                                elseif ci_or_mi isa Core.MethodInstance
                                    ci_or_mi
                                else
                                    nothing
                                end
                                if mi isa Core.MethodInstance && mi.specTypes !== nothing
                                    spec_params = mi.specTypes.parameters
                                    if length(spec_params) >= 1 && spec_params[1] <: MemoAnalysisGetter
                                        # This is a MemoAnalysisGetter() call — find which memo
                                        src = stmt.args[2]
                                        if src isa Core.SSAValue
                                            # Walk back to find which MemoAnalysisGetter this is
                                            src_stmt = code_info.code[src.id]
                                            if src_stmt isa Expr && src_stmt.head === :call &&
                                               length(src_stmt.args) >= 3 &&
                                               src_stmt.args[1] isa GlobalRef &&
                                               src_stmt.args[1].name === :getfield &&
                                               src_stmt.args[3] isa QuoteNode
                                                fname = src_stmt.args[3].value::Symbol
                                                captured = getfield(sn.condition_fn, fname)
                                                if captured isa MemoAnalysisGetter
                                                    midx = get(analysis.memo_getter_map, captured, nothing)
                                                    if midx !== nothing
                                                        mr = get(memo_results, midx, nothing)
                                                        if mr !== nothing
                                                            # Find the WASM function index from module exports
                                                            memo_fidx = _find_export_func_idx(mod, mr.export_name)
                                                            if memo_fidx !== nothing
                                                                show_invoke_imports[i] = memo_fidx
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                body, locals = WT.compile_closure_body(
                    sn.condition_fn, csf, mod, type_registry;
                    void_return=false,
                    invoke_imports=show_invoke_imports)
                fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[WT.I32], locals, body)
                WT.add_export!(mod, show_export, 0, fidx)
                show_condition_exports[sn.target_hk] = show_export
            catch e
                @debug "Show condition WASM compilation failed for hk=$(sn.target_hk)" exception=e
            end
        end
    end

    # ─── Compile string signal bridge functions (JS string ↔ WasmGC string) ───
    # JS→WASM: _u8_new, _u8_set!, _str_from_bytes (used by __tw.toWasm)
    # WASM→JS: _str_len, _str_byte (used by __tw.fromWasm)
    has_str_bridges = false
    if !isempty(string_signal_indices)
        try
            WT.compile_function_into!((n::Int64) -> Vector{UInt8}(undef, n),
                (Int64,), mod, type_registry; export_name="_u8_new")
            WT.compile_function_into!((v::Vector{UInt8}, i::Int64, b::Int64) -> (v[i] = UInt8(b); Int64(0)),
                (Vector{UInt8}, Int64, Int64), mod, type_registry; export_name="_u8_set!")
            WT.compile_function_into!((v::Vector{UInt8},) -> String(copy(v)),
                (Vector{UInt8},), mod, type_registry; export_name="_str_from_bytes")
            # Reverse direction: WASM→JS string reading (skip if already compiled by memo bridge)
            _has_str_len = any(e -> e.name == "_str_len" && e.kind == 0x00, mod.exports)
            if !_has_str_len
                WT.compile_function_into!((s::String,) -> Int64(ncodeunits(s)),
                    (String,), mod, type_registry; export_name="_str_len")
                WT.compile_function_into!((s::String, i::Int64) -> Int64(codeunit(s, i)),
                    (String, Int64), mod, type_registry; export_name="_str_byte")
            end
            has_str_bridges = true
        catch e
            @debug "String signal bridge compilation failed" exception=e
        end
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

            try
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
            catch e
                @debug "DOM binding effect WASM compilation failed for hk=$(b.target_hk)" exception=e
            end
        elseif kind == :string_ref && b.attribute === nothing
            # String signal → text content binding via deferred JS proxy
            str_import = get(str_text_imports, b.target_hk, nothing)
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
            try
                effect_body = compile_string_text_binding_effect(
                    sig_global_idx, subs_global, hk_gidx, str_import, rt_globals)
                effect_fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
                    WT.WasmValType[], effect_body)
                push!(wasm_effect_funcs, effect_fidx)
                push!(wasm_effect_binding_hks, b.target_hk)
            catch e
                @debug "String DOM binding effect failed for hk=$(b.target_hk)" exception=e
            end
        end
    end

    # ─── Compile Memo Binding Effects as WASM functions ───
    # Each memo→DOM text binding becomes a WASM effect: track deps, call memo, set text.
    # Leptos equivalent: RenderEffect on a derived signal with Rndr::set_text()
    for mb in analysis.memo_bindings
        hk_gidx = get(hk_globals, mb.target_hk, nothing)
        hk_gidx === nothing && continue

        mr = get(memo_results, mb.memo_idx, nothing)
        mr === nothing && continue

        memo_fidx = _find_export_func_idx(mod, mr.export_name)
        memo_fidx === nothing && continue

        # Find signal deps for tracking (from the memo's analyzed dependencies)
        memo_match = findfirst(m -> m.idx == mb.memo_idx, analysis.memos)
        memo_match === nothing && continue
        memo = analysis.memos[memo_match]

        dep_subs = UInt32[]
        for sig_id in memo.dependencies
            idx = get(sig_idx, sig_id, nothing)
            if idx !== nothing
                push!(dep_subs, rt_globals.signal_subs_base + UInt32(idx))
            end
        end
        # Over-subscribe if no deps found
        if isempty(dep_subs) && !isempty(analysis.signals)
            for i in 0:(length(analysis.signals) - 1)
                push!(dep_subs, rt_globals.signal_subs_base + UInt32(i))
            end
        end

        # Determine memo result type for to_string conversion
        memo_result_kind = :i64
        try
            typed_results = Base.code_typed(memo.fn, ())
            if !isempty(typed_results)
                ret_type = typed_results[1][2]
                if ret_type === Bool
                    memo_result_kind = :i32
                elseif ret_type <: AbstractFloat
                    memo_result_kind = :f64
                end
            end
        catch; end

        # Check if memo needs closure arg (non-signal captures)
        needs_closure = hasproperty(mr, :needs_closure_arg) && mr.needs_closure_arg
        memo_closure_global = nothing
        if needs_closure && mr.factory_export !== nothing
            # Add a global to store the memo closure struct ref
            try
                closure_type = typeof(memo.fn)
                closure_wasm_type = WT.get_concrete_wasm_type(closure_type, mod, type_registry)
                mc_gidx = WT.add_global_ref!(mod, WT.get_type_idx(closure_wasm_type), true, nothing)
                WT.add_global_export!(mod, "_mc_$(mb.memo_idx)", mc_gidx)
                memo_closure_global = mc_gidx
            catch e
                @debug "Memo closure global failed for memo $(mb.memo_idx)" exception=e
            end
        end

        try
            effect_body = compile_memo_text_binding_effect(
                memo_fidx, dep_subs, hk_gidx, memo_result_kind,
                dom_imports, rt_globals;
                memo_closure_global=memo_closure_global)

            effect_fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
                WT.WasmValType[], effect_body)
            push!(wasm_effect_funcs, effect_fidx)
        catch e
            @debug "Memo binding effect WASM compilation failed for hk=$(mb.target_hk)" exception=e
        end
    end

    # ─── Compile Show() effects as WASM functions ───
    show_frag_globals = Dict{Int, UInt32}()     # shk → frag externref global
    show_fb_frag_globals = Dict{Int, UInt32}()  # shk → fb_frag externref global
    show_prev_globals = Dict{Int, UInt32}()     # shk → prev_vis i32 global
    wasm_show_hks = Set{Int}()                  # Show hks managed by WASM

    for sn in analysis.show_nodes
        shk = sn.target_hk
        hk_gidx = get(hk_globals, shk, nothing)
        hk_gidx === nothing && continue

        # Find or create condition function
        show_wasm_fn = get(show_condition_exports, shk, nothing)
        cond_fidx = if show_wasm_fn !== nothing
            _find_export_func_idx(mod, show_wasm_fn)
        else
            # Bare signal Show (Show(v) where v is a signal getter) — no closure condition.
            # Create a simple WASM function that reads the signal global and returns i32.
            sig_idx_val = get(sig_idx, sn.signal_id, nothing)
            if sig_idx_val !== nothing
                sig_global = nothing
                for exp in mod.exports
                    if exp.name == "signal_$(sig_idx_val)" && exp.kind == 0x03
                        sig_global = exp.idx
                        break
                    end
                end
                if sig_global !== nothing
                    # Emit: global.get $signal_N → i32.wrap_i64 → return
                    bare_body = UInt8[]
                    push!(bare_body, 0x23)  # global.get
                    append!(bare_body, WT.encode_leb128_unsigned(sig_global))
                    kind = _signal_wasm_kind(analysis.signals[sig_idx_val + 1])
                    if kind == :i64
                        push!(bare_body, 0xa7)  # i32.wrap_i64
                    elseif kind == :f64
                        push!(bare_body, 0xaa)  # i32.trunc_f64_s
                    end
                    # kind == :i32 → already i32, no conversion needed
                    push!(bare_body, 0x0b)  # end
                    bare_export = "_show_bare_$(shk)"
                    fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[WT.I32],
                        WT.WasmValType[], bare_body)
                    WT.add_export!(mod, bare_export, 0, fidx)
                    show_condition_exports[shk] = bare_export
                    fidx
                else
                    nothing
                end
            else
                nothing
            end
        end
        cond_fidx === nothing && error("Show at hk=$shk: could not compile condition to WASM")

        # Add externref globals for fragment and prev_vis
        frag_gidx = WT.add_global!(mod, WT.ExternRef, true, nothing)
        WT.add_global_export!(mod, "_show_$(shk)_frag", frag_gidx)
        show_frag_globals[shk] = frag_gidx

        prev_gidx = WT.add_global!(mod, WT.I32, true, Int32(-1))  # -1 = uninitialized
        show_prev_globals[shk] = prev_gidx

        has_fallback = sn.fallback_hk > 0
        fb_hk_gidx = nothing
        fb_frag_gidx = nothing
        if has_fallback
            fb_hk_gidx = get(hk_globals, sn.fallback_hk, nothing)
            if fb_hk_gidx !== nothing
                fb_frag_gidx = WT.add_global!(mod, WT.ExternRef, true, nothing)
                WT.add_global_export!(mod, "_show_$(shk)_fb_frag", fb_frag_gidx)
                show_fb_frag_globals[shk] = fb_frag_gidx
            end
        end

        # Find dep signal subscriber globals for tracking
        dep_subs = UInt32[]
        if sn.condition_fn !== nothing
            # Walk closure fields to discover signal dependencies
            dep_sig_ids = _discover_closure_signal_deps(sn.condition_fn, analysis)
            for sig_id in dep_sig_ids
                idx = get(sig_idx, sig_id, nothing)
                if idx !== nothing
                    push!(dep_subs, rt_globals.signal_subs_base + UInt32(idx))
                end
            end
        elseif sn.signal_id != UInt64(0)
            idx = get(sig_idx, sn.signal_id, nothing)
            if idx !== nothing
                push!(dep_subs, rt_globals.signal_subs_base + UInt32(idx))
            end
        end
        # If no deps found, track all signals (over-subscribe)
        if isempty(dep_subs) && !isempty(analysis.signals)
            for i in 0:(length(analysis.signals) - 1)
                push!(dep_subs, rt_globals.signal_subs_base + UInt32(i))
            end
        end

        try
            effect_body = compile_show_effect(cond_fidx, prev_gidx, dep_subs,
                hk_gidx, frag_gidx, dom_imports, rt_globals;
                fb_hk_global=fb_hk_gidx, fb_frag_global=fb_frag_gidx)

            # Show effect has 1 local: current_vis (i32)
            effect_fidx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
                WT.WasmValType[WT.I32], effect_body)
            push!(wasm_effect_funcs, effect_fidx)
            push!(wasm_show_hks, shk)
        catch e
            @debug "Show WASM effect compilation failed for hk=$(shk)" exception=e
        end
    end

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
        # Over-subscribe if no deps found
        if isempty(dep_subs) && !isempty(analysis.signals)
            for i in 0:(length(analysis.signals) - 1)
                push!(dep_subs, rt_globals.signal_subs_base + UInt32(i))
            end
        end

        try
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
        catch e
            @warn "For WASM effect compilation failed for id=$(f.id)" exception=e
        end
    end

    # ─── Add explicit effects (create_effect with js()) to funcref table ───
    for eff in analysis.effects
        result = get(effect_results, eff.id, nothing)
        result === nothing && continue
        if hasproperty(result, :export_name)
            fidx = _find_export_func_idx(mod, result.export_name)
            fidx !== nothing && push!(wasm_effect_funcs, fidx)
        end
    end

    # ─── Build funcref table + flush function ───
    flush_func_idx = nothing
    if !isempty(wasm_effect_funcs)
        # Create funcref table for effects
        n_effects = length(wasm_effect_funcs)
        effect_table_idx = WT.add_table!(mod, WT.FuncRef, UInt32(n_effects), UInt32(n_effects))

        # Populate table with effect functions via element segment
        WT.add_elem_segment!(mod, effect_table_idx, UInt32(0), wasm_effect_funcs)

        # Add () -> void function type for call_indirect (deduplicates via add_type!)
        void_void_tidx = WT.add_type!(mod, WT.FuncType(WT.WasmValType[], WT.WasmValType[]))

        flush_func_idx = emit_rt_flush_function!(mod, rt_globals,
            n_effects, length(analysis.signals),
            effect_table_idx, void_void_tidx)
    end

    # ─── Create handler wrappers (batch + handler + notify + batch_end) ───
    # Each handler gets a wrapper that manages the full reactive cycle in WASM.
    # The JS just calls the wrapper — WASM reactive runtime handles batching.
    handler_wrapper_exports = Dict{Int, String}()  # handler_id → wrapper export name
    if flush_func_idx !== nothing
        for h in analysis.handlers
            wasm_result = get(handler_results, h.id, nothing)
            wasm_result === nothing && continue

            # Find the handler's WASM function index
            handler_fidx = _find_export_func_idx(mod, wasm_result.export_name)
            handler_fidx === nothing && continue

            wrapper_body = UInt8[]

            # batch_start: batch_depth += 1
            append!(wrapper_body, emit_rt_batch_start_bytecode(rt_globals))

            # Call the handler
            has_closure = hasproperty(wasm_result, :needs_closure_arg) && wasm_result.needs_closure_arg
            if has_closure
                # Handler takes closure struct as param 0 → wrapper also takes it
                push!(wrapper_body, 0x20, 0x00)  # local.get 0 (closure arg)
            end
            push!(wrapper_body, 0x10)  # call
            append!(wrapper_body, WT.encode_leb128_unsigned(handler_fidx))

            # Notify for each modified signal
            for sig_id in wasm_result.modified_signals
                idx = get(sig_idx, sig_id, nothing)
                idx === nothing && continue
                # Skip string/vector signals for now (they use ref globals)
                idx in string_signal_indices && continue
                idx in vec_signal_indices && continue

                subs_global = rt_globals.signal_subs_base + UInt32(idx)

                # if batch_depth > 0: pending |= subs
                push!(wrapper_body, 0x23)
                append!(wrapper_body, WT.encode_leb128_unsigned(rt_globals.batch_depth))
                push!(wrapper_body, 0x41, 0x00)
                push!(wrapper_body, 0x4a)  # i32.gt_s
                push!(wrapper_body, 0x04, 0x40)  # if
                # pending |= subs
                push!(wrapper_body, 0x23)
                append!(wrapper_body, WT.encode_leb128_unsigned(rt_globals.pending_effects))
                push!(wrapper_body, 0x23)
                append!(wrapper_body, WT.encode_leb128_unsigned(subs_global))
                push!(wrapper_body, 0x84)  # i64.or
                push!(wrapper_body, 0x24)
                append!(wrapper_body, WT.encode_leb128_unsigned(rt_globals.pending_effects))
                push!(wrapper_body, 0x0b)  # end if
                # (else branch: immediate flush handled by batch_end)
            end

            # batch_end (with flush if depth reaches 0)
            append!(wrapper_body, emit_rt_batch_end_bytecode(rt_globals, flush_func_idx))

            # Also sync back to JS signal mirrors for Show/For (transitional)
            # This will be removed in P3 when Show/For move to WASM

            push!(wrapper_body, 0x0b)  # end function

            # Add wrapper function
            wrapper_params = if has_closure
                closure_wasm_type = WT.get_concrete_wasm_type(typeof(h.handler), mod, type_registry)
                WT.WasmValType[closure_wasm_type]
            else
                WT.WasmValType[]
            end

            wrapper_name = "_hw$(h.id)"
            wrapper_fidx = WT.add_function!(mod, wrapper_params, WT.WasmValType[],
                WT.WasmValType[], wrapper_body)
            WT.add_export!(mod, wrapper_name, 0, wrapper_fidx)
            handler_wrapper_exports[h.id] = wrapper_name
        end
    end

    # ─── Serialize WASM to bytes ───
    wasm_bytes = WT.to_bytes(mod)
    if optimize_wasm
        wasm_bytes = WT.optimize(wasm_bytes; level=:size)
    end

    # ─── Generate JS loader ───
    parts = String[]
    push!(parts, "(function() {")

    # Hydration function
    push!(parts, "  window.TherapyHydrate = window.TherapyHydrate || {};")
    push!(parts, "  function hydrate_$cn() {")
    push!(parts, "    document.querySelectorAll('[data-component=\"$cn\"]:not([data-hydrated])').forEach(function(island) {")
    push!(parts, "      island.dataset.hydrated = \"true\";")

    # Props — parse for memo factory / bridge access (NOT for signal init).
    # Prop-to-signal mapping only applies when ALL props are integer signals
    # (e.g., Counter(initial=0)). When any prop is a non-signal type
    # (Vector{String}, etc.), disable the mapping entirely.
    _cached = get(ISLAND_PROPS_CACHE, Symbol(component_name), Dict{Symbol,Any}())
    # Check if all props are integer-typed: first try cached SSR values, then fall back
    # to checking signal initial values (covers compile_island without prior SSR).
    all_props_are_int = if !isempty(prop_names) && !isempty(_cached)
        all(pn -> get(_cached, pn, nothing) isa Integer, prop_names)
    elseif !isempty(prop_names) && length(analysis.signals) >= length(prop_names)
        all(i -> analysis.signals[i].initial_value isa Integer, 1:length(prop_names))
    else
        false
    end
    has_prop_signals = all_props_are_int && !isempty(analysis.signals) && length(analysis.signals) >= length(prop_names)
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
        if hasproperty(result, :effect_js_body)
            ps = result.effect_js_params
            body = result.effect_js_body
            if isempty(ps)
                # No params — direct implementation
                push!(eff_js_imports, "eff_$(eff.id):function(){$body}")
            else
                # Deferred: proxy forwards to impl set after instantiation
                push!(eff_js_imports, "eff_$(eff.id):function($(ps)){if(_eff[$(eff.id)])_eff[$(eff.id)]($(ps));}")
                push!(eff_js_deferred, "        _eff[$(eff.id)]=function($(ps)){$body};")
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

    # ─── String text binding deferred imports (same pattern as For()) ───
    if !isempty(str_text_imports)
        push!(parts, "      var _stb={};")
        stb_stubs = String[]
        for (hk, _) in sort(collect(str_text_imports))
            push!(stb_stubs, "stb_$(hk):function(n,r){if(_stb[$(hk)])_stb[$(hk)](n,r);}")
        end
        push!(parts, "      _io.str_fns={$(join(stb_stubs, ","))};")
    end

    # ─── Instantiate WASM ───
    push!(parts, "      WebAssembly.instantiate(_wb, _io).then(function(result) {")
    push!(parts, "        var ex = result.instance.exports;")
    # Expose exports on the island element so external code can poke
    # signals (the documented HMR snapshot pattern in WebSocketClient.jl
    # also relies on this — read-only previously, now also written).
    push!(parts, "        island._wasmExports = ex;")

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
            flush_call = flush_func_idx !== nothing ?
                "if(ex._rt_subs_$(idx))ex._rt_flush(ex._rt_subs_$(idx).value);" : ""
            push!(parts,
                "        window.__therapy.reg(" *
                "\"$(sig.shared_name)\"," *
                "ex.signal_$(idx).value," *
                "function(v){ex.signal_$(idx).value=$(conv);$(flush_call)});")
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
    # Numeric signal bindings are WASM effects (compiled above via funcref table).
    # Non-numeric bindings (string/vector) that aren't WASM-managed get a warning.
    for b in analysis.bindings
        idx = get(sig_idx, b.signal_id, nothing)
        idx === nothing && continue
        if !(b.target_hk in wasm_effect_binding_hks)
            @warn "DOM binding at hk=$(b.target_hk) not WASM-managed (signal type not yet supported)" signal_idx=idx attribute=b.attribute
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
                push!(parts, "        if (_ih_$(hk_h)) _ih_$(hk_h).\$\$$(dom_event) = function(e){$(call_js);};")
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
        if hasproperty(result, :effect_js_body)
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
            push!(parts, "        queueMicrotask(function(){$(result.js_code)});")
        elseif hasproperty(result, :export_name)
            push!(parts, "        queueMicrotask(function(){ex.$(result.export_name)();});")
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
            push!(parts, "        hk_$(h.target_hk).\$\$$(dom_event) = function(e){$(call_js);};")
            push!(delegated_events, dom_event)
        else
            @warn "WASM handler compilation failed for handler $(h.id) ($(h.event) on hk=$(h.target_hk)). No JS fallback — handler will be non-functional."
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
        all_bits = flush_func_idx !== nothing ? "ex._rt_flush(ex._rt_subs_$(idx).value);" : ""
        # No JS signal sync needed — signals live in WASM globals only.
        # If the bound signal is shared, broadcast the new value to other
        # islands via __therapy.set so their .reg callbacks fire.
        sig_obj = analysis.signals[idx + 1]
        broadcast = sig_obj.shared_name !== nothing ?
            "window.__therapy.set(\"$(sig_obj.shared_name)\",v);" : ""
        all_bits *= broadcast

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

"""
    _find_export_func_idx(mod, export_name) -> Union{UInt32, Nothing}

Look up a function's absolute WASM index from the module's exports list.
Returns nothing if the export is not found.
"""
function _find_export_func_idx(mod::WT.WasmModule, export_name::String)::Union{UInt32, Nothing}
    for exp in mod.exports
        if exp.name == export_name && exp.kind == 0x00  # kind 0 = function
            return exp.idx
        end
    end
    return nothing
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
    _extract_js_calls(closure, analysis, sig_idx; use_params=false) -> (skip_indices, js_strings, arg_refs)

Pre-scan a closure's typed IR for js() calls. Returns the SSA indices to skip
during WASM compilation and the extracted JS code strings with \$N args resolved.

This implements the Leptos pattern: WASM does computation, JS does browser APIs.
js() strings are compile-time constants. When use_params=true, \$N args resolve
to import parameter names (_p0, _p1) for WASM import calls. When false, resolves
to legacy s0[0]() expressions (handler backward compat).

Returns arg_refs: Vector of (kind, idx, wasm_kind) for each \$N arg when use_params=true.
"""
function _extract_js_calls(closure::Function,
                            analysis::ComponentAnalysis=ComponentAnalysis(),
                            sig_idx::Dict{UInt64, Int}=Dict{UInt64, Int}();
                            use_params::Bool=false)
    skip_indices = Set{Int}()
    js_strings = String[]
    arg_refs = Tuple{Symbol, Int, Symbol}[]  # (kind, idx, wasm_kind) for effect params
    ssa_ref = Dict{Int, Tuple{Symbol, Int, Symbol}}()  # SSA id → structured ref

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

    return (skip_indices, js_strings, arg_refs)
end


# LEPTOS-1002: Deleted _extract_signal_ops_js() and _resolve_value_js().
# Handler compilation is WASM-only — no JS fallback for signal ops.

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
                                type_registry::WT.TypeRegistry,
                                shared_signal_imports::Dict{Int, UInt32}=Dict{Int, UInt32}())
    closure_type = typeof(handler)
    fnames = fieldnames(closure_type)

    # Non-closure functions — skip, use tracing fallback
    if isempty(fnames)
        return nothing
    end

    # Build captured_signal_fields: field_name -> (is_getter, global_idx)
    # For LOCAL signals only — shared signals use imports instead.
    captured_signal_fields = Dict{Symbol, Tuple{Bool, UInt32}}()
    modified_signals = UInt64[]
    # Track which fields are shared signal getters (will use invoke_imports)
    shared_getter_fields = Dict{Symbol, Int}()  # field_name → sig_idx

    has_non_signal_captures = false

    for field_name in fnames
        captured_value = getfield(handler, field_name)

        # Signal getter
        getter_sig_id = get(analysis.getter_map, captured_value, nothing)
        if getter_sig_id !== nothing
            idx = get(sig_idx, getter_sig_id, nothing)
            if idx !== nothing
                # Always register in captured_signal_fields so WasmTarget
                # recognizes the getfield as a signal (prevents struct construction).
                # For shared signals, invoke_imports will override the global.get
                # with an import call (checked first in compile_invoke).
                captured_signal_fields[field_name] = (true, UInt32(idx))
                if haskey(shared_signal_imports, idx)
                    shared_getter_fields[field_name] = idx
                end
                continue
            end
        end

        # Signal setter
        setter_sig_id = get(analysis.setter_map, captured_value, nothing)
        if setter_sig_id !== nothing
            idx = get(sig_idx, setter_sig_id, nothing)
            if idx !== nothing
                push!(modified_signals, setter_sig_id)
                # Setters always use WASM globals (postsync writes back to JS)
                captured_signal_fields[field_name] = (false, UInt32(idx))
                continue
            end
        end

        # Non-signal captured field (e.g., Vector{String} props, Int constants)
        # compile_closure_body will pass the closure struct as param 0
        has_non_signal_captures = true
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

    # Map shared signal getter SSAs to import calls (single source of truth in JS).
    # Scan IR: find the invoke of SignalGetter on shared fields → map to get import.
    if !isempty(shared_getter_fields)
        typed_results = Base.code_typed(handler, ())
        if !isempty(typed_results)
            code_info = typed_results[1][1]
            # Map getfield SSAs to field names
            ssa_to_field = Dict{Int, Symbol}()
            for (i, stmt) in enumerate(code_info.code)
                if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3
                    if stmt.args[1] isa GlobalRef && stmt.args[1].name === :getfield && stmt.args[3] isa QuoteNode
                        ssa_to_field[i] = stmt.args[3].value::Symbol
                    end
                end
            end
            # Find getter/setter invoke SSAs and map to imports
            for (i, stmt) in enumerate(code_info.code)
                if stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 2
                    src = stmt.args[2]
                    src_id = src isa Core.SSAValue ? src.id : nothing
                    fname = src_id !== nothing ? get(ssa_to_field, src_id, nothing) : nothing
                    fname === nothing && continue
                    # Shared getter: call $get_shared_N (returns i64)
                    if haskey(shared_getter_fields, fname)
                        sidx = shared_getter_fields[fname]
                        get_import = shared_signal_imports[sidx]
                        invoke_imports[i] = get_import
                    end
                end
            end
        end
    end

    try
        body, locals = WT.compile_closure_body(
            handler, captured_signal_fields, mod, type_registry;
            skip_stmts=skip_indices,
            invoke_imports=invoke_imports,
            void_return=true
        )

        export_name = "_h$(handler_id)"

        # If the closure captures non-signal data (e.g., Vector{String} props),
        # the WASM function takes the closure struct as its first parameter.
        # Same pattern as memo closures — closure object IS param 0.
        param_types = if has_non_signal_captures
            closure_wasm_type = WT.get_concrete_wasm_type(closure_type, mod, type_registry)
            WT.WasmValType[closure_wasm_type]
        else
            WT.WasmValType[]
        end

        func_idx = WT.add_function!(mod, param_types, WT.WasmValType[], locals, body)
        WT.add_export!(mod, export_name, 0, func_idx)

        # If the handler needs its closure struct, build a factory function
        # that constructs it with constant field values embedded in WASM.
        # Same pattern as _compile_memo_wasm's factory.
        factory_export = nothing
        if has_non_signal_captures
            try
                factory_name = "_h$(handler_id)_init"
                closure_wasm_type = WT.get_concrete_wasm_type(closure_type, mod, type_registry)
                struct_info = type_registry.structs[closure_type]

                # Build struct.new bytecode with constant field values
                factory_body = UInt8[]

                # Field 0: typeId (i32) — always 0
                push!(factory_body, 0x41)
                append!(factory_body, WT.encode_leb128_signed(Int32(0)))

                # Fields 1..N: captured values from the closure instance
                for (fi, fname) in enumerate(fieldnames(closure_type))
                    fval = getfield(handler, fname)
                    if haskey(captured_signal_fields, fname)
                        # Signal field: null placeholder (accessed via global.get at runtime)
                        push!(factory_body, 0xd0)  # ref.null
                        push!(factory_body, 0x6b)  # structref
                    else
                        # Data field: embed as constant via compile_const_value
                        append!(factory_body, WT.compile_const_value(fval, mod, type_registry))
                    end
                end

                # struct.new $closure_type
                push!(factory_body, 0xfb)  # GC prefix
                push!(factory_body, 0x00)  # struct.new
                append!(factory_body, WT.encode_leb128_unsigned(struct_info.wasm_type_idx))

                # end
                push!(factory_body, 0x0b)

                factory_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[closure_wasm_type],
                    UInt8[], factory_body)
                WT.add_export!(mod, factory_name, 0, factory_idx)
                factory_export = factory_name
            catch e
                @debug "Handler closure factory compilation failed" handler_id exception=e
            end
        end

        return (export_name=export_name, modified_signals=modified_signals,
                js_strings=js_strings, needs_closure_arg=has_non_signal_captures,
                factory_export=factory_export)
    catch e
        @debug "WASM handler compilation failed, falling back to tracing" handler_id exception=e
        return nothing
    end
end

# ─── WasmTarget Effect Compilation ───

"""
    _compile_effect_wasm(effect_fn, effect_id, analysis, sig_idx, mod, type_registry,
                          rt_globals, effect_js_imports, effect_js_meta)

Compile an effect closure to WASM. Effects read signals and perform side effects.

Pure-JS effects (only js() calls) are compiled as WASM functions that:
1. Emit tracking bytecode for signal dependencies (reactive re-run)
2. Read signal globals / call memo functions
3. Call a JS import with signal values as arguments (Leptos pattern)

Import indices are pre-computed (effect_js_imports) to avoid adding imports after functions.
"""
function _compile_effect_wasm(effect_fn::Function, effect_id::Int,
                               analysis::ComponentAnalysis,
                               sig_idx::Dict{UInt64, Int},
                               mod::WT.WasmModule,
                               type_registry::WT.TypeRegistry,
                               rt_globals::ReactiveRuntimeGlobals,
                               effect_js_imports::Dict{Int, UInt32},
                               effect_js_meta::Dict;
                               func_registry::Union{WT.FunctionRegistry, Nothing}=nothing)
    closure_type = typeof(effect_fn)
    fnames = fieldnames(closure_type)

    if isempty(fnames)
        return nothing
    end

    # Check if this effect has a pre-computed JS import (pure-JS effect with js() calls)
    import_idx = get(effect_js_imports, effect_id, nothing)
    meta = get(effect_js_meta, effect_id, nothing)

    if import_idx !== nothing && meta !== nothing
        arg_refs = meta.arg_refs

        try
            # Build WASM function body: tracking + reads + import call
            body = UInt8[]

            for (kind, idx, wasm_kind) in arg_refs
                if kind === :signal
                    # Emit tracking bytecode → registers this effect as subscriber
                    subs_global = rt_globals.signal_subs_base + UInt32(idx)
                    append!(body, emit_tracking_bytecode(subs_global, rt_globals))

                    # Read signal global value
                    sig_global_idx = nothing
                    for exp in mod.exports
                        if exp.name == "signal_$(idx)" && exp.kind == 0x03
                            sig_global_idx = exp.idx
                            break
                        end
                    end
                    if sig_global_idx === nothing
                        @debug "Effect $(effect_id): signal_$(idx) global not found"
                        return nothing
                    end
                    push!(body, 0x23)  # global.get
                    append!(body, WT.encode_leb128_unsigned(sig_global_idx))

                    # String/vec signals are GC refs — convert to externref for JS import
                    if wasm_kind in (:string_ref, :vec_ref)
                        push!(body, 0xfb, 0x1b)  # extern.convert_any → externref
                    end

                elseif kind === :memo
                    # Call memo function to get current computed value
                    memo_fidx = _find_export_func_idx(mod, "_memo_$(idx)")
                    if memo_fidx === nothing
                        @debug "Effect $(effect_id): _memo_$(idx) not found"
                        return nothing
                    end
                    push!(body, 0x10)  # call
                    append!(body, WT.encode_leb128_unsigned(memo_fidx))
                end
            end

            # Call the JS import with all values on the stack
            push!(body, 0x10)  # call
            append!(body, WT.encode_leb128_unsigned(import_idx))
            push!(body, 0x0b)  # end

            export_name = "_effect_$(effect_id)"
            func_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[],
                WT.WasmValType[], body)
            WT.add_export!(mod, export_name, 0, func_idx)

            return (export_name=export_name, effect_js_body=meta.js_code, effect_js_params=meta.params_str)
        catch e
            @debug "WASM effect compilation failed" effect_id exception=e
            return nothing
        end
    end

    # Non-js path: compile effect body to WASM (e.g., pure computation effects)
    skip_indices, js_strings_fallback = _extract_js_calls(effect_fn, analysis, sig_idx)

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
            func_registry=func_registry,
            skip_stmts=skip_indices,
            void_return=true
        )

        # Prepend reactive tracking bytecode for each captured signal.
        # The compiled body reads signals via global.get but doesn't register
        # subscriptions. Without this, the reactive system won't re-run the
        # effect when signals change (it only runs once at hydration).
        tracking_preamble = UInt8[]
        for (fname, (is_getter, sig_idx_val)) in captured_signal_fields
            if is_getter
                subs_global = rt_globals.signal_subs_base + sig_idx_val
                append!(tracking_preamble, emit_tracking_bytecode(subs_global, rt_globals))
            end
        end
        if !isempty(tracking_preamble)
            # Remove trailing 0x0b (end) from body, prepend tracking, re-add end
            if !isempty(body) && body[end] == 0x0b
                pop!(body)
            end
            body = vcat(tracking_preamble, body)
            push!(body, 0x0b)
        end

        export_name = "_effect_$(effect_id)"
        func_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[], locals, body)
        WT.add_export!(mod, export_name, 0, func_idx)

        return (export_name=export_name, js_strings=js_strings_fallback)
    catch e
        @warn "Effect $effect_id compilation failed" exception=(e, catch_backtrace())
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

    # Extract js() calls — same pattern as effects
    skip_indices, js_strings = _extract_js_calls(mount_fn, analysis, sig_idx)

    # If mount is ONLY js() calls, emit JS directly (no WASM wrapper needed).
    if !isempty(js_strings)
        js_code = join(js_strings, ";") * ";"
        return (js_code=js_code,)
    end

    try
        body, locals = WT.compile_closure_body(
            mount_fn, captured_signal_fields, mod, type_registry;
            skip_stmts=skip_indices,
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
    has_non_signal_captures = false

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

        # Non-signal captured field (e.g., items_data::Vector{String})
        # compile_closure_body will pass the closure struct as param 0
        has_non_signal_captures = true
    end

    try
        # Memos RETURN a value (not void)
        body, locals = WT.compile_closure_body(
            memo_fn, captured_signal_fields, mod, type_registry;
            void_return=false
        )

        export_name = "_memo_$(memo_idx)"

        # Get the concrete WASM return type from the TypeRegistry.
        # Must be called AFTER compile_closure_body (which registers types).
        typed_results = Base.code_typed(memo_fn, ())
        wasm_ret_type = if !isempty(typed_results)
            inferred_ret = typed_results[1][2]
            try
                WT.get_concrete_wasm_type(inferred_ret, mod, type_registry)
            catch
                WT.I64
            end
        else
            WT.I64
        end

        # If the closure captures non-signal data (e.g., Vector{String} props),
        # the WASM function takes the closure struct as its first parameter.
        # This follows the Leptos/dart2wasm pattern: closure object IS param 0.
        param_types = if has_non_signal_captures
            closure_wasm_type = WT.get_concrete_wasm_type(closure_type, mod, type_registry)
            WT.WasmValType[closure_wasm_type]
        else
            WT.WasmValType[]
        end

        func_idx = WT.add_function!(mod, param_types, WT.WasmValType[wasm_ret_type], locals, body)
        WT.add_export!(mod, export_name, 0, func_idx)

        # If the memo needs its closure struct, build a factory function
        # that constructs it with constant field values embedded in WASM.
        # Props data is available at compile time because analyze_component
        # runs with actual SSR prop values (via ISLAND_PROPS_CACHE).
        factory_export = nothing
        if has_non_signal_captures
            try
                factory_name = "_memo_$(memo_idx)_init"
                closure_wasm_type = WT.get_concrete_wasm_type(closure_type, mod, type_registry)
                struct_info = type_registry.structs[closure_type]

                # Build struct.new bytecode with constant field values
                factory_body = UInt8[]

                # Field 0: typeId (i32) — always 0
                push!(factory_body, 0x41)
                append!(factory_body, WT.encode_leb128_signed(Int32(0)))

                # Fields 1..N: captured values from the closure instance
                for (fi, fname) in enumerate(fieldnames(closure_type))
                    fval = getfield(memo_fn, fname)
                    if haskey(captured_signal_fields, fname)
                        # Signal field: null placeholder (accessed via global.get at runtime)
                        push!(factory_body, 0xd0)  # ref.null
                        push!(factory_body, 0x6b)  # structref
                    else
                        # Data field: embed as constant via compile_const_value
                        append!(factory_body, WT.compile_const_value(fval, mod, type_registry))
                    end
                end

                # struct.new $closure_type
                push!(factory_body, 0xfb)  # GC prefix
                push!(factory_body, 0x00)  # struct.new
                append!(factory_body, WT.encode_leb128_unsigned(struct_info.wasm_type_idx))

                # end
                push!(factory_body, 0x0b)

                factory_idx = WT.add_function!(mod, WT.WasmValType[], WT.WasmValType[closure_wasm_type],
                    UInt8[], factory_body)
                WT.add_export!(mod, factory_name, 0, factory_idx)
                factory_export = factory_name
            catch e
                @debug "Closure factory compilation failed" memo_idx exception=e
            end
        end

        # If the memo returns Vector{String} or Vector{Int64}, compile read-side
        # bridge functions so JS can extract items from the WasmGC vector.
        returns_vec_str = false
        returns_vec_i64 = false
        returns_vec_f64 = false
        memo_return_type = !isempty(typed_results) ? typed_results[1][2] : nothing

        if memo_return_type === Vector{String}
            try
                # Output bridge: extract Vector{String} → JS
                WT.compile_function_into!(
                    (v::Vector{String},) -> Int64(length(v)),
                    (Vector{String},), mod, type_registry; export_name="_bv_str_len")
                WT.compile_function_into!(
                    (v::Vector{String}, i::Int64) -> v[i],
                    (Vector{String}, Int64), mod, type_registry; export_name="_bv_str_get")
                # Only add _str_len/_str_byte if not already in the module
                _has_str_len = any(e -> e.name == "_str_len" && e.kind == 0x00, mod.exports)
                if !_has_str_len
                    WT.compile_function_into!(
                        (s::String,) -> Int64(ncodeunits(s)),
                        (String,), mod, type_registry; export_name="_str_len")
                    WT.compile_function_into!(
                        (s::String, i::Int64) -> Int64(codeunit(s, i)),
                        (String, Int64), mod, type_registry; export_name="_str_byte")
                end

                returns_vec_str = true
            catch e
                @warn "Vector{String} bridge compilation failed" exception=(e, catch_backtrace())
            end
        elseif memo_return_type === Vector{Int64}
            try
                # Output bridge: extract Vector{Int64} → JS
                WT.compile_function_into!(
                    (v::Vector{Int64},) -> Int64(length(v)),
                    (Vector{Int64},), mod, type_registry; export_name="_bv_i64_len")
                WT.compile_function_into!(
                    (v::Vector{Int64}, i::Int64) -> v[i],
                    (Vector{Int64}, Int64), mod, type_registry; export_name="_bv_i64_get")

                returns_vec_i64 = true
            catch e
                @debug "Vector{Int64} bridge compilation failed" exception=e
            end
        elseif memo_return_type === Vector{Float64}
            try
                # Output bridge: extract Vector{Float64} → JS
                WT.compile_function_into!(
                    (v::Vector{Float64},) -> Int64(length(v)),
                    (Vector{Float64},), mod, type_registry; export_name="_bv_f64_len")
                WT.compile_function_into!(
                    (v::Vector{Float64}, i::Int64) -> v[i],
                    (Vector{Float64}, Int64), mod, type_registry; export_name="_bv_f64_get")

                returns_vec_f64 = true
            catch e
                @debug "Vector{Float64} bridge compilation failed" exception=e
            end
        end

        return (export_name=export_name, needs_closure_arg=has_non_signal_captures,
                factory_export=factory_export, returns_vec_str=returns_vec_str,
                returns_vec_i64=returns_vec_i64, returns_vec_f64=returns_vec_f64)
    catch e
        @debug "WASM memo compilation failed" memo_idx exception=e
        return nothing
    end
end

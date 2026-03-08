# Compile.jl - Main compiler API for Therapy.jl
#
# Provides the high-level API for compiling components to Wasm

include("StringTable.jl")
include("Floating.jl")
include("Analysis.jl")
include("WasmGen.jl")
include("Hydration.jl")
include("CompiledElements.jl")
include("CompiledSignals.jl")
include("IslandTransform.jl")

"""
Complete compilation result for a component.
"""
struct CompiledComponent
    analysis::ComponentAnalysis
    wasm::WasmOutput
    hydration::HydrationOutput
    html::String
    string_table::StringTable
end

"""
    compile_component(component_fn::Function; container_selector=nothing, component_name="component", wasm_path="./app.wasm") -> CompiledComponent

Compile a Therapy.jl component for client-side execution.

This is the main entry point for compiling components. It:
1. Analyzes the component to extract signals, handlers, and DOM structure
2. Generates WebAssembly for the reactive logic
3. Generates JavaScript for hydration
4. Returns everything needed to run the component

# Arguments
- `component_fn`: The component function to compile
- `container_selector`: Optional CSS selector to scope DOM queries (e.g., "#my-app").
  Use this when embedding the component in a page with other data-hk attributes.
- `component_name`: Name of the component (used for hydration registration)
- `wasm_path`: Path to the Wasm module for the hydration script

# Example
```julia
Counter = () -> begin
    count, set_count = create_signal(0)
    Div(
        P("Count: ", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

compiled = compile_component(Counter)

# Write Wasm
write("app.wasm", compiled.wasm.bytes)

# Get HTML for SSR
html = compiled.html

# Get hydration JS
js = compiled.hydration.js
```
"""
function compile_component(component_fn::Function; container_selector::Union{String,Nothing}=nothing, component_name::String="component", wasm_path::String="./app.wasm")
    # Step 1: Analyze the component
    println("Analyzing component...")
    analysis = analyze_component(component_fn)
    println("  Found $(length(analysis.signals)) signals")
    println("  Found $(length(analysis.handlers)) handlers")
    println("  Found $(length(analysis.bindings)) DOM bindings")

    # Step 2: Create string table (populated by future DOM bridge imports)
    string_table = StringTable()

    # Step 3: Generate Wasm
    println("Generating WebAssembly...")
    wasm = generate_wasm(analysis)
    println("  Generated $(length(wasm.bytes)) bytes")
    println("  Exports: $(join(wasm.exports, ", "))")

    # Step 4: Generate hydration JS (with string table and element registry)
    println("Generating hydration code...")
    hydration = generate_hydration_js(analysis; container_selector=container_selector, component_name=component_name, wasm_path=wasm_path, string_table=string_table)

    return CompiledComponent(analysis, wasm, hydration, analysis.html, string_table)
end

"""
    compile_and_serve(component_fn::Function; port=8080)

Compile a component and start a dev server.

This is the easiest way to test a Therapy.jl component with Wasm.
"""
function compile_and_serve(component_fn::Function; port::Int=8080, title::String="Therapy.jl App")
    compiled = compile_component(component_fn)

    # Create temp directory
    serve_dir = mktempdir()
    wasm_path = joinpath(serve_dir, "app.wasm")
    write(wasm_path, compiled.wasm.bytes)
    println("Wrote Wasm to: $wasm_path")

    println("\nStarting server on http://127.0.0.1:$port")
    println("Open browser DevTools to see Wasm calls!\n")

    serve(port, static_dir=serve_dir) do path
        if path == "/" || path == "/index.html"
            return """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>$(title)</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        max-width: 600px;
                        margin: 50px auto;
                        padding: 20px;
                    }
                    button {
                        font-size: 18px;
                        padding: 10px 20px;
                        margin: 5px;
                        cursor: pointer;
                    }
                </style>
            </head>
            <body>
                $(compiled.html)
                <script>
                $(compiled.hydration.js)
                </script>
            </body>
            </html>
            """
        end
        nothing
    end
end

# Re-export compile_multi from WasmTarget for direct Julia function compilation
using WasmTarget: compile_multi

# =========================================================================
# T31: Leptos-Style Full-Body Island Compilation Pipeline
# =========================================================================

"""
    IslandCompilationSpec

Specification for compiling an island body to Wasm.
Built by the AST transform (THERAPY-3111) and consumed by compile_island_body.
"""
struct IslandCompilationSpec
    component_name::String
    # Hydrate function: the main entry point compiled to Wasm
    hydrate_fn::Function
    hydrate_arg_types::Tuple
    # Handler functions: extracted from event closures in the island body
    handlers::Vector{NamedTuple{(:fn, :arg_types, :name), Tuple{Function, Tuple, String}}}
    # Signal allocation: tracks global indices for all signals
    signal_alloc::SignalAllocator
end

"""
    IslandWasmOutput

Result of compile_island_body — the compiled Wasm module plus metadata.
"""
struct IslandWasmOutput
    bytes::Vector{UInt8}
    exports::Vector{String}
    n_signals::Int
    n_handlers::Int
end

"""
    compile_island_body(spec::IslandCompilationSpec) -> IslandWasmOutput

Compile an island's hydrate function + handlers to a Wasm module.

This is the Leptos-style full-body compilation pipeline. It replaces the old
analyze→extract→compile-handlers approach for islands that use the new pipeline.

Pipeline:
1. Create WasmModule with ALL imports (0-75)
2. Add position global (index 0) + signal globals (indices 1+)
3. Pre-register import stubs in func_registry at their import indices
4. Compile helper functions + hydrate function + handler functions
5. Export hydrate and all handlers
6. Return Wasm bytes

The old compile_component() path is unchanged and still works for backward compatibility.
"""
function compile_island_body(spec::IslandCompilationSpec)::IslandWasmOutput
    # ─── Step 1: Create WasmModule with all imports ───
    mod = WasmModule()
    _add_all_imports!(mod)

    # ─── Step 2: Add globals ───
    # Global 0: cursor position (i32, mutable, initial=FIRST_CHILD)
    add_global!(mod, I32, true, Int32(POSITION_FIRST_CHILD))

    # Globals 1+: signal globals from allocator
    for sig in spec.signal_alloc.signals
        wasm_type = _signal_julia_to_wasm_type(sig.type)
        initial = signal_initial_value(sig.type, sig.initial)
        add_global!(mod, wasm_type, true, initial)
    end

    # Variable globals (non-signal shared variables — timer IDs etc.)
    for var in spec.signal_alloc.variables
        wasm_type = _signal_julia_to_wasm_type(var.type)
        add_global!(mod, wasm_type, true, var.type(var.initial))
    end

    # ─── Step 3: Build import stubs list for func_registry ───
    import_stubs = Any[]
    for stub in HYDRATION_IMPORT_STUBS
        push!(import_stubs, (stub.func, stub.name, stub.arg_types, stub.import_idx, stub.return_type))
    end
    for stub in PROPS_IMPORT_STUBS
        push!(import_stubs, (stub.func, stub.name, stub.arg_types, stub.import_idx, stub.return_type))
    end

    # ─── Step 4: Build function list ───
    functions = Any[]
    exports_list = String[]

    # Helper functions (compiled alongside island body)
    for helper in HYDRATION_HELPER_FUNCTIONS
        push!(functions, (helper.func, helper.arg_types, helper.name))
    end

    # Hydrate function (main entry point)
    push!(functions, (spec.hydrate_fn, spec.hydrate_arg_types, "hydrate"))
    push!(exports_list, "hydrate")

    # Handler functions
    for handler in spec.handlers
        push!(functions, (handler.fn, handler.arg_types, handler.name))
        push!(exports_list, handler.name)
    end

    # ─── Step 5: Compile via compile_module with existing module + import stubs ───
    compiled_mod = WasmTarget.compile_module(
        functions;
        existing_module=mod,
        import_stubs=import_stubs
    )

    # ─── Step 6: Generate bytes ───
    bytes = to_bytes(compiled_mod)

    return IslandWasmOutput(
        bytes,
        exports_list,
        signal_count(spec.signal_alloc),
        length(spec.handlers)
    )
end

"""
Add ALL Therapy.jl Wasm imports to a module (indices 0-75).
Replicates the import table from generate_wasm in WasmGen.jl.
"""
function _add_all_imports!(mod::WasmModule)
    # Imports 0-4: Original
    add_import!(mod, "dom", "update_text", [I32, F64], NumType[])           # 0
    add_import!(mod, "dom", "set_visible", [I32, F64], NumType[])           # 1
    add_import!(mod, "dom", "set_dark_mode", [F64], NumType[])              # 2
    add_import!(mod, "channel", "send", [I32, I32], NumType[])              # 3
    add_import!(mod, "dom", "get_editor_code", [I32], [F64])                # 4

    # Imports 5-52: T30 DOM bridge
    add_import!(mod, "dom", "add_class", [I32, I32], NumType[])             # 5
    add_import!(mod, "dom", "remove_class", [I32, I32], NumType[])          # 6
    add_import!(mod, "dom", "toggle_class", [I32, I32], NumType[])          # 7
    add_import!(mod, "dom", "set_attribute", [I32, I32, I32], NumType[])    # 8
    add_import!(mod, "dom", "remove_attribute", [I32, I32], NumType[])      # 9
    add_import!(mod, "dom", "set_style", [I32, I32, I32], NumType[])        # 10
    add_import!(mod, "dom", "set_data_state", [I32, I32], NumType[])        # 11
    add_import!(mod, "dom", "set_data_motion", [I32, I32], NumType[])       # 12
    add_import!(mod, "dom", "set_text_content", [I32, I32], NumType[])      # 13
    add_import!(mod, "dom", "set_hidden", [I32, I32], NumType[])            # 14
    add_import!(mod, "dom", "show_element", [I32], NumType[])               # 15
    add_import!(mod, "dom", "hide_element", [I32], NumType[])               # 16
    add_import!(mod, "dom", "focus_element", [I32], NumType[])              # 17
    add_import!(mod, "dom", "focus_element_prevent_scroll", [I32], NumType[])  # 18
    add_import!(mod, "dom", "blur_element", [I32], NumType[])               # 19
    add_import!(mod, "dom", "get_active_element", NumType[], [I32])         # 20
    add_import!(mod, "dom", "focus_first_tabbable", [I32], NumType[])       # 21
    add_import!(mod, "dom", "focus_last_tabbable", [I32], NumType[])        # 22
    add_import!(mod, "dom", "install_focus_guards", NumType[], NumType[])   # 23
    add_import!(mod, "dom", "uninstall_focus_guards", NumType[], NumType[]) # 24
    add_import!(mod, "dom", "lock_scroll", NumType[], NumType[])            # 25
    add_import!(mod, "dom", "unlock_scroll", NumType[], NumType[])          # 26
    add_import!(mod, "dom", "scroll_into_view", [I32], NumType[])           # 27
    add_import!(mod, "dom", "get_bounding_rect_x", [I32], [F64])           # 28
    add_import!(mod, "dom", "get_bounding_rect_y", [I32], [F64])           # 29
    add_import!(mod, "dom", "get_bounding_rect_w", [I32], [F64])           # 30
    add_import!(mod, "dom", "get_bounding_rect_h", [I32], [F64])           # 31
    add_import!(mod, "dom", "get_viewport_width", NumType[], [F64])         # 32
    add_import!(mod, "dom", "get_viewport_height", NumType[], [F64])        # 33
    add_import!(mod, "dom", "get_key_code", NumType[], [I32])               # 34
    add_import!(mod, "dom", "get_modifiers", NumType[], [I32])              # 35
    add_import!(mod, "dom", "get_pointer_x", NumType[], [F64])              # 36
    add_import!(mod, "dom", "get_pointer_y", NumType[], [F64])              # 37
    add_import!(mod, "dom", "get_pointer_id", NumType[], [I32])             # 38
    add_import!(mod, "dom", "get_target_value_f64", NumType[], [F64])       # 39
    add_import!(mod, "dom", "get_target_checked", NumType[], [I32])         # 40
    add_import!(mod, "dom", "storage_get_i32", [I32], [I32])                # 41
    add_import!(mod, "dom", "storage_set_i32", [I32, I32], NumType[])       # 42
    add_import!(mod, "dom", "copy_to_clipboard", [I32], NumType[])          # 43
    add_import!(mod, "dom", "capture_pointer", [I32], NumType[])            # 44
    add_import!(mod, "dom", "release_pointer", [I32], NumType[])            # 45
    add_import!(mod, "dom", "get_drag_delta_x", NumType[], [F64])           # 46
    add_import!(mod, "dom", "get_drag_delta_y", NumType[], [F64])           # 47
    add_import!(mod, "dom", "set_timeout", [I32, I32], [I32])               # 48
    add_import!(mod, "dom", "clear_timeout", [I32], NumType[])              # 49
    add_import!(mod, "dom", "request_animation_frame", [I32], [I32])        # 50
    add_import!(mod, "dom", "cancel_animation_frame", [I32], NumType[])     # 51
    add_import!(mod, "dom", "prevent_default", NumType[], NumType[])        # 52

    # Imports 53-55: Bool/modal helpers
    add_import!(mod, "dom", "set_data_state_bool", [I32, I32, F64], NumType[])  # 53
    add_import!(mod, "dom", "set_aria_bool", [I32, I32, F64], NumType[])        # 54
    add_import!(mod, "dom", "modal_state", [I32, I32, F64], NumType[])          # 55

    # Imports 56-61: T31 cursor navigation
    add_import!(mod, "dom", "cursor_child", NumType[], NumType[])               # 56
    add_import!(mod, "dom", "cursor_sibling", NumType[], NumType[])             # 57
    add_import!(mod, "dom", "cursor_parent", NumType[], NumType[])              # 58
    add_import!(mod, "dom", "cursor_current", NumType[], [I32])                 # 59
    add_import!(mod, "dom", "cursor_set", [I32], NumType[])                     # 60
    add_import!(mod, "dom", "cursor_skip_children", NumType[], NumType[])       # 61

    # Import 62: Event attachment
    add_import!(mod, "dom", "add_event_listener", [I32, I32, I32], NumType[])   # 62

    # Imports 63-66: Signal→DOM bindings
    add_import!(mod, "dom", "register_text_binding", [I32, I32], NumType[])     # 63
    add_import!(mod, "dom", "register_visibility_binding", [I32, I32], NumType[])  # 64
    add_import!(mod, "dom", "register_attribute_binding", [I32, I32, I32], NumType[])  # 65
    add_import!(mod, "dom", "trigger_bindings", [I32, I32], NumType[])          # 66

    # Imports 67-70: Props deserialization
    add_import!(mod, "dom", "get_prop_count", NumType[], [I32])                 # 67
    add_import!(mod, "dom", "get_prop_i32", [I32], [I32])                       # 68
    add_import!(mod, "dom", "get_prop_f64", [I32], [F64])                       # 69
    add_import!(mod, "dom", "get_prop_string_id", [I32], [I32])                 # 70

    # Imports 71-73: BindBool/BindModal binding registration
    add_import!(mod, "dom", "register_data_state_binding", [I32, I32, I32], NumType[]) # 71
    add_import!(mod, "dom", "register_aria_binding", [I32, I32, I32], NumType[])       # 72
    add_import!(mod, "dom", "register_modal_binding", [I32, I32, I32], NumType[])      # 73

    # Imports 74-75: Per-child pattern support
    add_import!(mod, "dom", "get_event_data_index", NumType[], [I32])                  # 74
    add_import!(mod, "dom", "register_match_binding", [I32, I32, I32], NumType[])      # 75

    # Imports 76-79: Per-child match/bit state bindings
    add_import!(mod, "dom", "register_match_data_state_binding", [I32, I32, I32, I32], NumType[]) # 76
    add_import!(mod, "dom", "register_match_aria_binding", [I32, I32, I32, I32], NumType[])       # 77
    add_import!(mod, "dom", "register_bit_data_state_binding", [I32, I32, I32, I32], NumType[])   # 78
    add_import!(mod, "dom", "register_bit_aria_binding", [I32, I32, I32, I32], NumType[])         # 79

    # Imports 80-81: Escape dismiss (Phase 6) — Thaw-style modal escape handler stack
    add_import!(mod, "dom", "push_escape_handler", [I32], NumType[])                            # 80
    add_import!(mod, "dom", "pop_escape_handler", NumType[], NumType[])                         # 81

    # Imports 82-83: Click-outside dismiss (Phase 6) — Thaw-style click-outside detection
    add_import!(mod, "dom", "add_click_outside_listener", [I32, I32], NumType[])                # 82
    add_import!(mod, "dom", "remove_click_outside_listener", [I32], NumType[])                  # 83

    # Imports 84-85: Active element save/restore (Phase 6) — focus management for modals
    add_import!(mod, "dom", "store_active_element", NumType[], NumType[])                       # 84
    add_import!(mod, "dom", "restore_active_element", NumType[], NumType[])                     # 85

    # Import 86: ShowDescendants binding (Phase 7) — toggle display + data-state on descendants
    add_import!(mod, "dom", "show_descendants", [I32, I32], NumType[])                          # 86

    # Import 87: Event delegation role detection (Phase 7) — read data-role from event target
    add_import!(mod, "dom", "get_event_closest_role", NumType[], [I32])                         # 87

    # Import 88: Parent island navigation (Phase 7) — find parent island root element
    add_import!(mod, "dom", "get_parent_island_root", NumType[], [I32])                         # 88

    # Import 89: Focus trap cycling (Phase 7) — cycle Tab focus within event.currentTarget
    add_import!(mod, "dom", "cycle_focus_in_current_target", [I32], NumType[])                  # 89

    # Imports 90-91: Auto-register bindings on [data-index] descendants (T32)
    add_import!(mod, "dom", "register_match_descendants", [I32, I32], NumType[])                # 90
    add_import!(mod, "dom", "register_bit_descendants", [I32, I32], NumType[])                  # 91

    # Import 92: Theme state query — read current dark mode state for signal initialization
    add_import!(mod, "dom", "get_is_dark_mode", NumType[], [I32])                               # 92

    # Imports 93-94: DismissableLayer — Radix-style dismiss layer stack
    add_import!(mod, "dom", "push_dismiss_layer", [I32, I32], NumType[])                        # 93
    add_import!(mod, "dom", "pop_dismiss_layer", NumType[], NumType[])                          # 94

    # Import 95: Elements count query — returns current state.elements.length
    add_import!(mod, "dom", "get_elements_count", NumType[], [I32])                             # 95

    # Import 96-97: Style percent/numeric — direct style manipulation for Slider/Resizable
    add_import!(mod, "dom", "set_style_percent", [I32, I32, F64], NumType[])                    # 96
    add_import!(mod, "dom", "set_style_numeric", [I32, I32, F64], NumType[])                    # 97
end

# ─── Island Compilation (THERAPY-3122/3132) ───

"""
    compile_island(name::Symbol) -> IslandWasmOutput

Compile a registered @island component using its stored body expression.
The body is stored in IslandDef.body by the @island macro at definition time.
"""
function compile_island(name::Symbol)::IslandWasmOutput
    island_def = get(ISLAND_REGISTRY, name, nothing)
    (island_def === nothing || island_def.body === nothing) &&
        error("No compilable body for island :$name — define with @island macro")
    spec = build_island_spec(string(name), island_def.body)
    return compile_island_body(spec)
end

"""
    compile_island(name::Symbol, body::Expr) -> IslandWasmOutput

Compile an island from an explicit body expression (for testing).
"""
function compile_island(name::Symbol, body::Expr)::IslandWasmOutput
    spec = build_island_spec(string(name), body)
    return compile_island_body(spec)
end

"""Map Julia signal type to WasmTarget NumType for globals."""
function _signal_julia_to_wasm_type(T::Type)
    if T === Int32 || T === UInt32 || T === Bool
        return I32
    elseif T === Int64 || T === UInt64 || T === Int
        return I64
    elseif T === Float32
        return F32
    elseif T === Float64
        return F64
    else
        return I32  # Default
    end
end

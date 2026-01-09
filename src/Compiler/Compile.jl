# Compile.jl - Main compiler API for Therapy.jl
#
# Provides the high-level API for compiling components to Wasm

include("Analysis.jl")
include("WasmGen.jl")
include("Hydration.jl")

"""
Complete compilation result for a component.
"""
struct CompiledComponent
    analysis::ComponentAnalysis
    wasm::WasmOutput
    hydration::HydrationOutput
    html::String
end

"""
    compile_component(component_fn::Function; container_selector=nothing) -> CompiledComponent

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
function compile_component(component_fn::Function; container_selector::Union{String,Nothing}=nothing)
    # Step 1: Analyze the component
    println("Analyzing component...")
    analysis = analyze_component(component_fn)
    println("  Found $(length(analysis.signals)) signals")
    println("  Found $(length(analysis.handlers)) handlers")
    println("  Found $(length(analysis.bindings)) DOM bindings")

    # Step 2: Generate Wasm
    println("Generating WebAssembly...")
    wasm = generate_wasm(analysis)
    println("  Generated $(length(wasm.bytes)) bytes")
    println("  Exports: $(join(wasm.exports, ", "))")

    # Step 3: Generate hydration JS
    println("Generating hydration code...")
    hydration = generate_hydration_js(analysis; container_selector=container_selector)

    return CompiledComponent(analysis, wasm, hydration, analysis.html)
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

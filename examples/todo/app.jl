# Todo App - Reactive Julia compiled to WebAssembly
#
# This demonstrates Therapy.jl's full reactive pipeline:
# 1. Define components with signals and handlers in pure Julia
# 2. Compile to WebAssembly via WasmTarget.jl
# 3. Hydrate server-rendered HTML with Wasm reactivity
#
# Run with: julia --project=../.. app.jl

using Therapy

# =============================================================================
# REACTIVE COUNTER COMPONENT
# =============================================================================

function ReactiveCounter()
    count, set_count = create_signal(0)

    Div(:class => "bg-white rounded-lg shadow p-6 mb-6",
        H2(:class => "text-lg font-semibold mb-4", "Reactive Counter"),
        P(:class => "text-gray-600 mb-4",
            "This counter is powered by Julia compiled to WebAssembly. ",
            "Click the buttons to see Julia functions execute in your browser!"
        ),
        Div(:class => "flex items-center justify-center gap-4",
            Button(
                :class => "px-6 py-3 bg-red-500 text-white text-xl font-bold rounded-lg hover:bg-red-600 transition",
                :on_click => () -> set_count(count() - 1),
                "-"
            ),
            Span(:class => "text-4xl font-bold w-24 text-center", count),
            Button(
                :class => "px-6 py-3 bg-green-500 text-white text-xl font-bold rounded-lg hover:bg-green-600 transition",
                :on_click => () -> set_count(count() + 1),
                "+"
            )
        ),
        Div(:class => "flex justify-center gap-4 mt-4",
            Button(
                :class => "px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 transition",
                :on_click => () -> set_count(count() * 2),
                "Double"
            ),
            Button(
                :class => "px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition",
                :on_click => () -> set_count(0),
                "Reset"
            )
        )
    )
end

# =============================================================================
# TOGGLE DEMO COMPONENT
# =============================================================================

function ToggleDemo()
    visible, set_visible = create_signal(1)  # 1 = visible, 0 = hidden

    Div(:class => "bg-white rounded-lg shadow p-6 mb-6",
        H2(:class => "text-lg font-semibold mb-4", "Show/Hide Toggle"),
        P(:class => "text-gray-600 mb-4",
            "Demonstrates conditional rendering with Wasm-controlled visibility."
        ),
        Div(:class => "flex items-center justify-center gap-4 mb-4",
            Button(
                :class => "px-4 py-2 bg-purple-500 text-white rounded hover:bg-purple-600 transition",
                :on_click => () -> set_visible(visible() == 0 ? 1 : 0),
                "Toggle Content"
            )
        ),
        Show(visible) do
            Div(:class => "p-4 bg-purple-100 rounded-lg text-center",
                P(:class => "text-purple-800 font-semibold",
                    "This content is controlled by a Julia signal compiled to Wasm!"
                )
            )
        end
    )
end

# =============================================================================
# INFO SECTION
# =============================================================================

function InfoSection()
    Div(:class => "bg-white rounded-lg shadow p-6",
        H2(:class => "text-lg font-semibold mb-4", "How It Works"),
        Ul(:class => "space-y-2 text-gray-600",
            Li(:class => "flex items-start gap-2",
                Span(:class => "text-green-500 font-bold", "1."),
                Span("Julia signals and handlers are analyzed at compile time")
            ),
            Li(:class => "flex items-start gap-2",
                Span(:class => "text-green-500 font-bold", "2."),
                Span("Handler operations are traced to detect patterns (increment, decrement, toggle)")
            ),
            Li(:class => "flex items-start gap-2",
                Span(:class => "text-green-500 font-bold", "3."),
                Span("WebAssembly is generated with globals for signals and functions for handlers")
            ),
            Li(:class => "flex items-start gap-2",
                Span(:class => "text-green-500 font-bold", "4."),
                Span("HTML is server-rendered with hydration keys (data-hk)")
            ),
            Li(:class => "flex items-start gap-2",
                Span(:class => "text-green-500 font-bold", "5."),
                Span("JavaScript hydration code connects DOM events to Wasm functions")
            ),
            Li(:class => "flex items-start gap-2",
                Span(:class => "text-green-500 font-bold", "6."),
                Span("Wasm updates globals and calls JS imports to update the DOM")
            )
        ),
        P(:class => "mt-4 text-sm text-gray-500",
            "Open DevTools Console to see the Wasm calls in action!"
        )
    )
end

# =============================================================================
# FULL PAGE COMPONENT
# =============================================================================

function App()
    Div(:class => "min-h-screen bg-gray-100",
        # Header
        Header(:class => "bg-white shadow mb-8",
            Div(:class => "max-w-4xl mx-auto px-4 py-6",
                H1(:class => "text-2xl font-bold text-gray-900", "Therapy.jl"),
                P(:class => "text-gray-600", "Reactive Julia compiled to WebAssembly")
            )
        ),
        # Main content
        MainEl(:class => "max-w-4xl mx-auto px-4 pb-8",
            ReactiveCounter(),
            ToggleDemo(),
            InfoSection()
        )
    )
end

# =============================================================================
# COMPILE AND SERVE
# =============================================================================

println("=" ^ 60)
println("  Therapy.jl - Reactive Todo App")
println("=" ^ 60)

# Compile the App component
println("\nCompiling App component to WebAssembly...")
compiled = compile_component(App)

println("\nComponent analysis:")
println("  Signals: $(length(compiled.analysis.signals))")
for s in compiled.analysis.signals
    println("    - signal_$(s.id): $(s.type) = $(s.initial_value)")
end

println("  Handlers: $(length(compiled.analysis.handlers))")
for h in compiled.analysis.handlers
    ops_str = join([string(op.operation) for op in h.operations], ", ")
    println("    - handler_$(h.id) @ hk=$(h.target_hk): [$ops_str]")
end

println("  Bindings: $(length(compiled.analysis.bindings))")
for b in compiled.analysis.bindings
    println("    - signal_$(b.signal_id) -> hk=$(b.target_hk)")
end

println("  Show nodes: $(length(compiled.analysis.show_nodes))")
for s in compiled.analysis.show_nodes
    println("    - signal_$(s.signal_id) -> hk=$(s.target_hk) (visible=$(s.initial_visible))")
end

println("\nWasm output:")
println("  Size: $(length(compiled.wasm.bytes)) bytes")
println("  Exports: $(join(compiled.wasm.exports, ", "))")

# Create temp directory and write Wasm file
serve_dir = mktempdir()
wasm_path = joinpath(serve_dir, "app.wasm")
write(wasm_path, compiled.wasm.bytes)
println("\nWrote Wasm to: $wasm_path")

println("\n" * "=" ^ 60)
println("  Starting server on http://127.0.0.1:8080")
println("  Open DevTools Console to see Wasm calls!")
println("=" ^ 60 * "\n")

# Start the server
serve(8080, static_dir=serve_dir) do path
    if path == "/" || path == "/index.html"
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Therapy.jl - Reactive Julia to Wasm</title>
            $(tailwind_cdn())
        </head>
        <body>
            $(compiled.html)
            <script>
            $(compiled.hydration.js)
            </script>
        </body>
        </html>
        """
    else
        nothing
    end
end

# Hydration.jl - Generate JavaScript hydration code
#
# Creates the minimal JS needed to connect Wasm to DOM

"""
Result of hydration code generation.
"""
struct HydrationOutput
    js::String
    event_bindings::Vector{Tuple{Int, Symbol, Int}}  # (hk, event, handler_id)
end

"""
    generate_hydration_js(analysis::ComponentAnalysis) -> HydrationOutput

Generate JavaScript code to hydrate the server-rendered HTML.

The generated code:
- Loads the Wasm module
- Connects event handlers to DOM elements
- Sets up DOM update callbacks for Wasm
"""
function generate_hydration_js(analysis::ComponentAnalysis)
    event_bindings = [(h.target_hk, h.event, h.id) for h in analysis.handlers]

    # Generate the handler connections
    handler_connections = String[]
    for handler in analysis.handlers
        event_name = replace(string(handler.event), "on_" => "")
        push!(handler_connections, """
            document.querySelector('[data-hk="$(handler.target_hk)"]')?.addEventListener('$(event_name)', () => {
                console.log('%c[Event] $(event_name) → handler_$(handler.id)()', 'color: #e94560');
                wasm.handler_$(handler.id)();
            });""")
    end

    # Generate input binding connections
    input_connections = String[]
    for input_binding in analysis.input_bindings
        input_type = input_binding.input_type
        # For number inputs, parse as integer; for text, we'd need string handling
        if input_type == :number
            push!(input_connections, """
            document.querySelector('[data-hk="$(input_binding.target_hk)"]')?.addEventListener('input', (e) => {
                const value = parseInt(e.target.value) || 0;
                console.log('%c[Input] value changed → input_handler_$(input_binding.handler_id)(' + value + ')', 'color: #ffa94d');
                wasm.input_handler_$(input_binding.handler_id)(value);
            });""")
        else
            # For text inputs with integer signals, try to parse
            push!(input_connections, """
            document.querySelector('[data-hk="$(input_binding.target_hk)"]')?.addEventListener('input', (e) => {
                const value = parseInt(e.target.value) || 0;
                console.log('%c[Input] value changed → input_handler_$(input_binding.handler_id)(' + value + ')', 'color: #ffa94d');
                wasm.input_handler_$(input_binding.handler_id)(value);
            });""")
        end
    end

    # Generate signal info for debugging
    signal_info = String[]
    for signal in analysis.signals
        push!(signal_info, "signal_$(signal.id): $(signal.initial_value) ($(signal.type))")
    end

    js = """
// Therapy.jl Hydration - Auto-generated
(async function() {
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');
    console.log('%c  Therapy.jl - Hydrating Component', 'color: #e94560; font-weight: bold');
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');

    // Signals discovered:
    // $(join(signal_info, "\n    // "))

    // Load WebAssembly module (relative path for GitHub Pages compatibility)
    console.log('%c[Hydration] Loading Wasm module...', 'color: #748ffc');
    const response = await fetch('./app.wasm');
    const bytes = await response.arrayBuffer();
    console.log('%c[Hydration] Module size: ' + bytes.byteLength + ' bytes', 'color: #748ffc');

    // DOM imports for Wasm
    const imports = {
        dom: {
            update_text_i32: (hk, value) => {
                const el = document.querySelector('[data-hk="' + hk + '"]');
                if (el) {
                    el.textContent = value;
                    console.log('%c[Wasm→DOM] update_text_i32(hk=' + hk + ', value=' + value + ')', 'color: #51cf66');
                }
            },
            update_text_f64: (hk, value) => {
                const el = document.querySelector('[data-hk="' + hk + '"]');
                if (el) {
                    el.textContent = value;
                    console.log('%c[Wasm→DOM] update_text_f64(hk=' + hk + ', value=' + value + ')', 'color: #51cf66');
                }
            },
            update_attr: (hk, attr, value) => {
                const el = document.querySelector('[data-hk="' + hk + '"]');
                if (el) {
                    el.setAttribute(attr, value);
                    console.log('%c[Wasm→DOM] update_attr(hk=' + hk + ')', 'color: #51cf66');
                }
            },
            set_visible: (hk, visible) => {
                const el = document.querySelector('[data-hk="' + hk + '"]');
                if (el) {
                    el.style.display = visible ? '' : 'none';
                    console.log('%c[Wasm→DOM] set_visible(hk=' + hk + ', visible=' + !!visible + ')', 'color: #be4bdb');
                }
            }
        }
    };

    const { instance } = await WebAssembly.instantiate(bytes, imports);
    const wasm = instance.exports;

    console.log('%c[Hydration] ✓ Wasm loaded!', 'color: #51cf66; font-weight: bold');
    console.log('%c[Hydration] Exports:', 'color: #ffd43b', Object.keys(wasm));

    // Connect event handlers
    $(join(handler_connections, "\n    "))

    // Connect input bindings
    $(join(input_connections, "\n    "))

    // Initialize (sync DOM with Wasm state)
    if (wasm.init) {
        wasm.init();
        console.log('%c[Hydration] ✓ Initialized', 'color: #51cf66');
    }

    console.log('%c[Hydration] 🚀 Component hydrated!', 'color: #51cf66; font-weight: bold');
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');

    // Expose for debugging
    window.TherapyWasm = wasm;
})();
"""

    return HydrationOutput(js, event_bindings)
end

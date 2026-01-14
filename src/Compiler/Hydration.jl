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
    generate_hydration_js(analysis::ComponentAnalysis; container_selector=nothing) -> HydrationOutput

Generate JavaScript code to hydrate the server-rendered HTML.

The generated code:
- Loads the Wasm module
- Connects event handlers to DOM elements
- Sets up DOM update callbacks for Wasm
- Initializes theme signals from current DOM state

If `container_selector` is provided, all DOM queries are scoped within that container.
This is important when embedding compiled components in pages with other data-hk attributes.
"""
function generate_hydration_js(analysis::ComponentAnalysis; container_selector::Union{String,Nothing}=nothing)
    event_bindings = [(h.target_hk, h.event, h.id) for h in analysis.handlers]

    # Query helper - scoped to container if provided
    query_base = isnothing(container_selector) ? "document" : "container"
    container_init = isnothing(container_selector) ? "" : """
    const container = document.querySelector('$(container_selector)');
    if (!container) {
        console.error('[Hydration] Container not found: $(container_selector)');
        return;
    }
    console.log('%c[Hydration] Scoped to container: $(container_selector)', 'color: #748ffc');
"""

    # Generate the handler connections
    handler_connections = String[]
    for handler in analysis.handlers
        event_name = replace(string(handler.event), "on_" => "")
        push!(handler_connections, """
    $(query_base).querySelector('[data-hk="$(handler.target_hk)"]')?.addEventListener('$(event_name)', () => {
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
            $(query_base).querySelector('[data-hk="$(input_binding.target_hk)"]')?.addEventListener('input', (e) => {
                const value = parseInt(e.target.value) || 0;
                console.log('%c[Input] value changed → input_handler_$(input_binding.handler_id)(' + value + ')', 'color: #ffa94d');
                wasm.input_handler_$(input_binding.handler_id)(value);
            });""")
        else
            # For text inputs with integer signals, try to parse
            push!(input_connections, """
            $(query_base).querySelector('[data-hk="$(input_binding.target_hk)"]')?.addEventListener('input', (e) => {
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

$(container_init)
    // Load WebAssembly module (relative path for GitHub Pages compatibility)
    console.log('%c[Hydration] Loading Wasm module...', 'color: #748ffc');
    const response = await fetch('./app.wasm');
    const bytes = await response.arrayBuffer();
    console.log('%c[Hydration] Module size: ' + bytes.byteLength + ' bytes', 'color: #748ffc');

    // Query helper for scoped DOM access
    const queryEl = (hk) => $(query_base).querySelector('[data-hk="' + hk + '"]');

    // DOM imports for Wasm
    // All numeric values are passed as f64 (JavaScript numbers)
    const imports = {
        dom: {
            update_text: (hk, value) => {
                const el = queryEl(hk);
                if (el) {
                    let displayValue;
                    const format = el.dataset.format;

                    // Check for special format attributes
                    if (format === 'xo') {
                        // Square format: 0→"", 1→"X", 2→"O"
                        displayValue = value === 0 ? '' : (value === 1 ? 'X' : 'O');
                    } else if (format === 'turn') {
                        // Turn format: 0→"X", 1→"O"
                        displayValue = value === 0 ? 'X' : 'O';
                    } else if (format === 'winner') {
                        // Winner format: 0→"", 1→"X wins!", 2→"O wins!"
                        displayValue = value === 0 ? '' : (value === 1 ? 'X wins! 🎉' : 'O wins! 🎉');
                        // Also update parent badge styling
                        const badge = el.parentElement;
                        if (badge && badge.dataset.format === 'winner-badge') {
                            if (value === 0) {
                                badge.className = 'hidden mb-4 px-6 py-3 rounded-lg text-lg font-bold text-center';
                            } else {
                                const colors = value === 1
                                    ? 'bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300'
                                    : 'bg-red-100 dark:bg-red-900/50 text-red-700 dark:text-red-300';
                                badge.className = 'mb-4 px-6 py-3 rounded-lg text-lg font-bold text-center animate-bounce ' + colors;
                            }
                            // Also toggle turn display visibility
                            const turnDisplay = $(query_base).querySelector('[data-format=\"turn-display\"]');
                            if (turnDisplay) turnDisplay.style.display = value === 0 ? '' : 'none';
                        }
                    } else {
                        // Default: show as integer if whole number
                        displayValue = Number.isInteger(value) ? Math.trunc(value) : value;
                    }

                    el.textContent = displayValue;
                    console.log('%c[Wasm→DOM] update_text(hk=' + hk + ', value=' + displayValue + ')', 'color: #51cf66');
                }
            },
            set_visible: (hk, visible) => {
                const el = queryEl(hk);
                if (el) {
                    el.style.display = visible ? '' : 'none';
                    console.log('%c[Wasm→DOM] set_visible(hk=' + hk + ', visible=' + !!visible + ')', 'color: #be4bdb');
                }
            },
            set_dark_mode: (enabled) => {
                const isDark = !!enabled;
                document.documentElement.classList.toggle('dark', isDark);
                try {
                    localStorage.setItem('therapy-theme', isDark ? 'dark' : 'light');
                } catch (e) {}
                console.log('%c[Wasm→DOM] set_dark_mode(enabled=' + isDark + ')', 'color: #9775fa');
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

    // Initialize theme signals from current DOM state
    // This ensures the Wasm signal matches the saved theme preference
    $(generate_theme_init(analysis))

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

"""
Generate JavaScript code to initialize theme signals from DOM state.
This ensures the Wasm signal matches the current theme (from localStorage or system preference).
"""
function generate_theme_init(analysis::ComponentAnalysis)
    if isempty(analysis.theme_bindings)
        return ""
    end

    # Generate initialization code for each theme binding
    inits = String[]
    for theme_binding in analysis.theme_bindings
        signal_id = theme_binding.signal_id
        push!(inits, """
    // Sync theme signal with saved preference or current DOM state
    // Check localStorage first (where we save it), then fall back to DOM class
    const savedTheme = (() => {
        try { return localStorage.getItem('therapy-theme'); } catch (e) { return null; }
    })();
    const shouldBeDark = savedTheme === 'dark' ||
        (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches);

    // Apply theme to DOM first (in case localStorage was set but class not yet applied)
    document.documentElement.classList.toggle('dark', shouldBeDark);

    // Then sync the Wasm signal (use regular number for Int32)
    if (wasm.set_signal_$(signal_id)) {
        wasm.set_signal_$(signal_id)(shouldBeDark ? 1 : 0);
        console.log('%c[Hydration] Theme signal synced: ' + (shouldBeDark ? 'dark' : 'light') + ' mode', 'color: #9775fa');
    }""")
    end

    return join(inits, "\n")
end

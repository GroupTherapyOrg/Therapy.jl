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
    generate_hydration_js(analysis::ComponentAnalysis; container_selector=nothing, component_name="component", wasm_path="./app.wasm") -> HydrationOutput

Generate JavaScript code to hydrate the server-rendered HTML.

The generated code:
- Loads the Wasm module
- Connects event handlers to DOM elements
- Sets up DOM update callbacks for Wasm
- Initializes theme signals from current DOM state
- Registers globally for re-hydration after client-side navigation

If `container_selector` is provided, all DOM queries are scoped within that container.
This is important when embedding compiled components in pages with other data-hk attributes.

The `component_name` is used to register the hydration function globally on
`window.TherapyHydrate[name]` for re-hydration after SPA navigation.

The `wasm_path` specifies the path to the Wasm module (default: "./app.wasm").
"""
function generate_hydration_js(analysis::ComponentAnalysis; container_selector::Union{String,Nothing}=nothing, component_name::String="component", wasm_path::String="./app.wasm")
    event_bindings = [(h.target_hk, h.event, h.id) for h in analysis.handlers]

    # Query helper - scoped to container if provided
    query_base = isnothing(container_selector) ? "document" : "container"
    container_init = isnothing(container_selector) ? "" : """
        const container = document.querySelector('$(container_selector)');
        if (!container) {
            console.error('[Hydration] Container not found: $(container_selector)');
            console.error('[Hydration] Available therapy-islands:', document.querySelectorAll('therapy-island').length);
            document.querySelectorAll('therapy-island').forEach(el => console.log('  Found island:', el.dataset.component));
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

    # Lowercase component name for registry key
    registry_key = lowercase(component_name)

    js = """
// Therapy.jl Hydration - $(component_name)
// Registered globally for re-hydration after client-side navigation
(function() {
    'use strict';

    // Initialize global hydration registry
    window.TherapyHydrate = window.TherapyHydrate || {};

    // Hydration function for this component
    async function hydrate_$(registry_key)() {
        console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');
        console.log('%c  Therapy.jl - Hydrating $(component_name)', 'color: #e94560; font-weight: bold');
        console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');

        try {
        // Signals discovered:
        // $(join(signal_info, "\n        // "))

$(container_init)
        // Load WebAssembly module
        console.log('%c[Hydration] Loading Wasm module from: $(wasm_path)', 'color: #748ffc');
        const response = await fetch('$(wasm_path)');
        if (!response.ok) {
            console.error('[Hydration] Failed to fetch Wasm:', response.status, response.statusText);
            return;
        }
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
                },
                get_editor_code: (cell_hk) => {
                    // Get code from CodeMirror editor
                    // Returns 0 as placeholder - proper string handling requires externref
                    const cell = queryEl(cell_hk) || document.querySelector('[data-cell-id]');
                    if (cell) {
                        const container = cell.querySelector('[data-codemirror]');
                        if (container && container._cmView) {
                            // Code available via container._cmView.state.doc.toString()
                            // but returning as f64 doesn't work for strings
                            console.log('%c[Wasm→DOM] get_editor_code(hk=' + cell_hk + ') - string handling not yet supported', 'color: #ff6b6b');
                        }
                    }
                    return 0;  // Placeholder - needs externref for strings
                }
            },
            channel: {
                send: (channel_id, cell_id) => {
                    // Channel IDs: 0=execute, 1=delete_cell, 2=add_cell
                    // This allows islands to send messages to Therapy.jl channels
                    const channels = ['execute', 'delete_cell', 'add_cell'];
                    const channelName = channels[channel_id] || 'unknown';

                    // Find the cell by hydration key or data-cell-id
                    const cell = queryEl(cell_id) || document.querySelector('[data-cell-id]');
                    const cellIdStr = cell ? cell.dataset.cellId : String(cell_id);
                    const notebookId = window.notebookId || '';

                    if (typeof TherapyWS !== 'undefined' && TherapyWS.isConnected()) {
                        // Build payload based on channel
                        let payload = { notebook_id: notebookId, cell_id: cellIdStr };

                        if (channel_id === 0) {  // execute
                            // Get code from CodeMirror
                            const container = cell ? cell.querySelector('[data-codemirror]') : null;
                            const code = container && container._cmView ?
                                container._cmView.state.doc.toString() : '';
                            payload.code = code;
                        }

                        TherapyWS.sendMessage(channelName, payload);
                        console.log('%c[Wasm→Channel] send(' + channelName + ', cell=' + cellIdStr + ')', 'color: #22b8cf');
                    } else {
                        console.warn('%c[Wasm→Channel] WebSocket not connected', 'color: #ff6b6b');
                    }
                }
            }
        };

        const { instance } = await WebAssembly.instantiate(bytes, imports);
        const wasm = instance.exports;

        console.log('%c[Hydration] ✓ Wasm loaded!', 'color: #51cf66; font-weight: bold');
        console.log('%c[Hydration] Exports:', 'color: #ffd43b', Object.keys(wasm));

        // Connect event handlers
        $(join(handler_connections, "\n        "))

        // Connect input bindings
        $(join(input_connections, "\n        "))

        // Initialize theme signals from current DOM state
        // This ensures the Wasm signal matches the saved theme preference
        $(generate_theme_init(analysis))

        // Initialize (sync DOM with Wasm state)
        if (wasm.init) {
            wasm.init();
            console.log('%c[Hydration] ✓ Initialized', 'color: #51cf66');
        }

        console.log('%c[Hydration] 🚀 $(component_name) hydrated!', 'color: #51cf66; font-weight: bold');
        console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');

        // Expose for debugging
        window.TherapyWasm = window.TherapyWasm || {};
        window.TherapyWasm['$(registry_key)'] = wasm;

        return wasm;
        } catch (error) {
            console.error('[Hydration] Error hydrating $(component_name):', error);
            throw error;
        }
    }

    // Register hydration function globally for re-hydration after navigation
    window.TherapyHydrate['$(registry_key)'] = hydrate_$(registry_key);

    // Auto-hydrate on initial page load (skip if router will handle it)
    // The router sets this flag before executing extracted scripts
    if (!window._therapyRouterHydrating) {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', hydrate_$(registry_key));
        } else {
            hydrate_$(registry_key)();
        }
    }
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

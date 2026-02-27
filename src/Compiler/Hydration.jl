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
    event_extraction_js(event_name::String) -> String

Return JavaScript code to extract event properties into module-level variables
before calling the Wasm handler. The Wasm handler reads these via getter imports.

Event type → extraction mapping:
- click/dblclick: _currentEvent only
- contextmenu: _currentEvent + pointer coordinates
- pointerdown/move/up/enter/leave: pointer coords + pointerId
- keydown/keyup: keyCode via KEY_MAP + modifiers bitfield
- input/change: target value + checked state
- focus/blur/focusin/focusout: _currentEvent only
- scroll/resize/animationend/transitionend: _currentEvent only (no properties)
"""
function event_extraction_js(event_name::String)::String
    if event_name in ("pointerdown", "pointermove", "pointerup", "pointerenter", "pointerleave", "pointerover", "pointerout")
        return "_currentEvent = e; _pointerX = e.clientX; _pointerY = e.clientY; _pointerId = e.pointerId;"
    elseif event_name in ("keydown", "keyup", "keypress")
        return "_currentEvent = e; _keyCode = KEY_MAP[e.key] || (e.key.length===1 ? e.key.charCodeAt(0) : 0); _modifiers = (e.shiftKey?1:0)|(e.ctrlKey?2:0)|(e.altKey?4:0)|(e.metaKey?8:0);"
    elseif event_name in ("input", "change")
        return "_currentEvent = e; _targetValueF64 = parseFloat(e.target.value) || 0; _targetChecked = e.target.checked ? 1 : 0;"
    elseif event_name == "contextmenu"
        return "_currentEvent = e; _pointerX = e.clientX; _pointerY = e.clientY;"
    else
        # click, dblclick, focus, blur, focusin, focusout, scroll, resize, etc.
        return "_currentEvent = e;"
    end
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
function generate_hydration_js(analysis::ComponentAnalysis; container_selector::Union{String,Nothing}=nothing, component_name::String="component", wasm_path::String="./app.wasm", string_table::Union{StringTable,Nothing}=nothing)
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

        // CRITICAL: Guard against duplicate hydration (fixes rapid-click WASM fetch bug)
        // Check BEFORE the async fetch starts, not after it completes
        if (container.dataset.hydrated === 'true' || container.dataset.hydrating === 'true') {
            console.log('%c[Hydration] Skipping $(container_selector) - already hydrated/hydrating', 'color: #ffa500');
            return;
        }
        // Mark as hydrating IMMEDIATELY to prevent concurrent calls
        container.dataset.hydrating = 'true';

        console.log('%c[Hydration] Scoped to container: $(container_selector)', 'color: #748ffc');
"""

    # Generate the handler connections (with event parameter extraction)
    handler_connections = String[]
    for handler in analysis.handlers
        event_name = replace(string(handler.event), "on_" => "")
        extraction = event_extraction_js(event_name)
        push!(handler_connections, """
    $(query_base).querySelector('[data-hk="$(handler.target_hk)"]')?.addEventListener('$(event_name)', (e) => {
    $(extraction)
    console.log('%c[Event] $(event_name) → handler_$(handler.id)()', 'color: #e94560');
    wasm.handler_$(handler.id)();
    _currentEvent = null;
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

    // Global tracking of in-flight hydrations (prevents duplicate WASM fetches under rapid clicks)
    // This is CRITICAL because content swaps remove DOM elements, invalidating data-hydrating attrs
    window._therapyHydrating = window._therapyHydrating || {};
    if (window._therapyHydrating['$(registry_key)']) {
        console.log('%c[Hydration] $(component_name) - hydration already in progress (global guard)', 'color: #ffa500');
        return;
    }

    // Hydration function for this component
    async function hydrate_$(registry_key)() {
        // CRITICAL: Global guard against duplicate hydration during rapid clicks
        // This must be checked BEFORE any async operations (fetch, etc.)
        // The IIFE-level guard only works for the first script load; this handles re-execution
        if (window._therapyHydrating['$(registry_key)']) {
            console.log('%c[Hydration] $(component_name) - hydration already in progress (function guard)', 'color: #ffa500');
            return;
        }
        // Mark as hydrating IMMEDIATELY before any async operations
        window._therapyHydrating['$(registry_key)'] = true;

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

        // String table for DOM bridge imports (class names, attributes, etc.)
        const strings = $(string_table !== nothing ? emit_string_table(string_table) : "[]");

        // Element registry — maps hydration key integers to DOM elements
        const elements = [];
        $(query_base).querySelectorAll('[data-hk]').forEach(el => {
            elements[parseInt(el.dataset.hk)] = el;
        });

        // Event parameter storage — JS stores event properties here before calling Wasm,
        // Wasm reads them via getter imports (get_key_code, get_pointer_x, etc.)
        let _currentEvent = null;
        let _keyCode = 0, _modifiers = 0;
        let _pointerX = 0.0, _pointerY = 0.0, _pointerId = 0;
        let _targetValueF64 = 0.0, _targetChecked = 0;
        let _dragStartX = 0.0, _dragStartY = 0.0;

        // Key code mapping: named keys → integer codes (matches standard keyCode values)
        // Single printable chars return their Unicode code point (e.g., 'a' → 97)
        const KEY_MAP = {
            'Backspace':8,'Tab':9,'Enter':13,'Escape':27,' ':32,
            'End':35,'Home':36,'ArrowLeft':37,'ArrowUp':38,
            'ArrowRight':39,'ArrowDown':40,'Delete':46
        };

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
                        var bp = document.documentElement.getAttribute('data-base-path') || '';
                        var themeKey = bp ? 'therapy-theme:' + bp : 'therapy-theme';
                        localStorage.setItem(themeKey, isDark ? 'dark' : 'light');
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
                },

                // Event property getter imports — Wasm calls these to read stored event data
                // Values are set by event listeners before calling the Wasm handler
                get_key_code: () => _keyCode,
                get_modifiers: () => _modifiers,
                get_pointer_x: () => _pointerX,
                get_pointer_y: () => _pointerY,
                get_pointer_id: () => _pointerId,
                get_target_value_f64: () => _targetValueF64,
                get_target_checked: () => _targetChecked,

                // Event control — call from Wasm handler to suppress default browser action
                prevent_default: () => { if (_currentEvent) _currentEvent.preventDefault(); }
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

        // Initialize (sync DOM with Wasm state)
        if (wasm.init) {
            wasm.init();
            console.log('%c[Hydration] ✓ Initialized', 'color: #51cf66');
        }

        // Initialize theme signals from current DOM state
        // MUST run AFTER wasm.init() to override default signal values (0=light)
        // with the actual saved/system preference
        $(generate_theme_init(analysis))

        console.log('%c[Hydration] 🚀 $(component_name) hydrated!', 'color: #51cf66; font-weight: bold');
        console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #e94560');

        // Mark the island as hydrated to prevent re-hydration on SPA navigation
        // This is especially important for Layout islands like ThemeToggle
        if (container) {
            container.dataset.hydrated = 'true';
            delete container.dataset.hydrating;  // Clear the in-progress flag
        }

        // Clear the global hydrating flag now that we're done
        delete window._therapyHydrating['$(registry_key)'];

        // Expose for debugging
        window.TherapyWasm = window.TherapyWasm || {};
        window.TherapyWasm['$(registry_key)'] = wasm;

        return wasm;
        } catch (error) {
            console.error('[Hydration] Error hydrating $(component_name):', error);
            // Clear hydrating flags on error so retry is possible
            if (typeof container !== 'undefined' && container) {
                delete container.dataset.hydrating;
            }
            delete window._therapyHydrating['$(registry_key)'];
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
        try {
            var bp = document.documentElement.getAttribute('data-base-path') || '';
            var themeKey = bp ? 'therapy-theme:' + bp : 'therapy-theme';
            return localStorage.getItem(themeKey);
        } catch (e) { return null; }
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

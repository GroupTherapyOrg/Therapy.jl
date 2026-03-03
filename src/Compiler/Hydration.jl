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

        // T31 Hydration cursor state — for Leptos-style full-body island compilation
        // Cursor walks server-rendered DOM during hydration; _cursorElements[] populated incrementally
        let _cursor = null;
        const _cursorElements = [];
        const _cursorBindings = [];
        const _CURSOR_EVENT_NAMES = ['click','input','change','keydown','keyup',
                                     'pointerdown','pointermove','pointerup',
                                     'focus','blur','submit','dblclick','contextmenu',
                                     'pointerenter','pointerleave'];

        // T31 Props deserialization state — parsed from data-props JSON attribute
        // Props are sorted alphabetically by name; Wasm accesses by index.
        let _propValues = [];  // Array of parsed prop values (alphabetical order)

        // Key code mapping: named keys → integer codes (matches standard keyCode values)
        // Single printable chars return their Unicode code point (e.g., 'a' → 97)
        const KEY_MAP = {
            'Backspace':8,'Tab':9,'Enter':13,'Escape':27,' ':32,
            'End':35,'Home':36,'ArrowLeft':37,'ArrowUp':38,
            'ArrowRight':39,'ArrowDown':40,'Delete':46
        };

        // Timer/callback infrastructure — Wasm calls set_timeout/request_animation_frame,
        // JS dispatches to Wasm callback exports (callback_0, callback_1, etc.)
        const _timers = {};
        let _timerCounter = 0;

        // Scroll lock reference counting (for nested modals)
        let _scrollLockCount = 0;

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
                prevent_default: () => { if (_currentEvent) _currentEvent.preventDefault(); },

                // Timer/callback imports — Wasm schedules deferred work via callback IDs
                // Callback functions are Wasm exports: callback_0(), callback_1(), etc.
                set_timeout: (cb, ms) => { const id = ++_timerCounter; _timers[id] = setTimeout(() => { delete _timers[id]; if (wasm['callback_'+cb]) wasm['callback_'+cb](); }, ms); return id; },
                clear_timeout: (id) => { clearTimeout(_timers[id]); delete _timers[id]; },
                request_animation_frame: (cb) => { const id = ++_timerCounter; _timers[id] = requestAnimationFrame(() => { delete _timers[id]; if (wasm['callback_'+cb]) wasm['callback_'+cb](); }); return id; },
                cancel_animation_frame: (id) => { cancelAnimationFrame(_timers[id]); delete _timers[id]; },

                // Scroll management imports
                lock_scroll: () => { if (++_scrollLockCount === 1) document.body.style.overflow = 'hidden'; },
                unlock_scroll: () => { if (--_scrollLockCount <= 0) { _scrollLockCount = 0; document.body.style.overflow = ''; } },
                scroll_into_view: (el) => elements[el]?.scrollIntoView({ block: 'nearest' }),

                // Class manipulation imports (use string table for class names)
                add_class: (el, s) => elements[el]?.classList.add(strings[s]),
                remove_class: (el, s) => elements[el]?.classList.remove(strings[s]),
                toggle_class: (el, s) => elements[el]?.classList.toggle(strings[s]),

                // Attribute/style imports (use string table for names and values)
                set_attribute: (el, n, v) => elements[el]?.setAttribute(strings[n], strings[v]),
                remove_attribute: (el, n) => elements[el]?.removeAttribute(strings[n]),
                set_style: (el, p, v) => {
                    const prop = strings[p], val = strings[v];
                    if (prop && prop[0]==='-') elements[el]?.style.setProperty(prop, val);
                    else if (elements[el]) elements[el].style[prop] = val;
                },

                // DOM state fast path (no string table needed)
                set_data_state: (el, open) => { if (elements[el]) elements[el].dataset.state = open ? 'open' : 'closed'; },
                set_data_motion: (el, m) => { if (elements[el]) elements[el].dataset.motion = ['from-start','to-end','from-end','to-start'][m]; },
                set_text_content: (el, s) => { if (elements[el]) elements[el].textContent = strings[s]; },
                set_hidden: (el, h) => { if (elements[el]) elements[el].hidden = !!h; },
                show_element: (el) => { if (elements[el]) elements[el].style.display = ''; },
                hide_element: (el) => { if (elements[el]) elements[el].style.display = 'none'; },

                // Focus management imports
                focus_element: (el) => elements[el]?.focus(),
                focus_element_prevent_scroll: (el) => elements[el]?.focus({ preventScroll: true }),
                blur_element: (el) => elements[el]?.blur(),
                get_active_element: () => elements.indexOf(document.activeElement),
                focus_first_tabbable: (el) => { const FOCUSABLE = 'a[href],button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex]:not([tabindex=\"-1\"])'; const f = elements[el]?.querySelector(FOCUSABLE); if (f) f.focus(); },
                focus_last_tabbable: (el) => { const FOCUSABLE = 'a[href],button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex]:not([tabindex=\"-1\"])'; const all = elements[el]?.querySelectorAll(FOCUSABLE); if (all?.length) all[all.length-1].focus(); },
                install_focus_guards: () => { if (!window._therapyFocusGuards) { const s = () => { const g = document.createElement('span'); g.tabIndex = 0; g.setAttribute('data-focus-guard',''); g.style.cssText = 'position:fixed;opacity:0;pointer-events:none'; return g; }; window._therapyFocusGuards = [s(), s()]; document.body.prepend(window._therapyFocusGuards[0]); document.body.append(window._therapyFocusGuards[1]); } },
                uninstall_focus_guards: () => { window._therapyFocusGuards?.forEach(g => g.remove()); window._therapyFocusGuards = null; },

                // Geometry imports
                get_bounding_rect_x: (el) => elements[el]?.getBoundingClientRect().x ?? 0,
                get_bounding_rect_y: (el) => elements[el]?.getBoundingClientRect().y ?? 0,
                get_bounding_rect_w: (el) => elements[el]?.getBoundingClientRect().width ?? 0,
                get_bounding_rect_h: (el) => elements[el]?.getBoundingClientRect().height ?? 0,
                get_viewport_width: () => window.innerWidth,
                get_viewport_height: () => window.innerHeight,

                // Storage/clipboard imports (use string table for keys/text)
                storage_get_i32: (k) => { try { return parseInt(localStorage.getItem(strings[k])||'0'); } catch(e) { return 0; } },
                storage_set_i32: (k, v) => { try { localStorage.setItem(strings[k], String(v)); } catch(e) {} },
                copy_to_clipboard: (s) => { try { navigator.clipboard.writeText(strings[s]); } catch(e) {} },

                // Pointer capture / drag imports
                capture_pointer: (el) => { _dragStartX = _pointerX; _dragStartY = _pointerY; elements[el]?.setPointerCapture(_pointerId); },
                release_pointer: (el) => elements[el]?.releasePointerCapture(_pointerId),
                get_drag_delta_x: () => _pointerX - _dragStartX,
                get_drag_delta_y: () => _pointerY - _dragStartY,

                // Boolean state helpers (BindBool support)
                // set_data_state_bool(el, mode, state): mode 0=closed/open, 1=off/on, 2=unchecked/checked
                set_data_state_bool: (el, mode, state) => {
                    const modes = [['closed', 'open'], ['off', 'on'], ['unchecked', 'checked']];
                    const [off, on] = modes[mode] || modes[0];
                    const element = elements[el];
                    if (element) {
                        element.dataset.state = state ? on : off;
                        // For switch mode, also update thumb child
                        if (mode === 2) {
                            const thumb = element.querySelector('span[data-state]');
                            if (thumb) thumb.dataset.state = state ? on : off;
                        }
                    }
                },
                // set_aria_bool(el, attr_code, state): attr 0=pressed, 1=checked, 2=expanded, 3=selected
                set_aria_bool: (el, attr, state) => {
                    const attrs = ['aria-pressed', 'aria-checked', 'aria-expanded', 'aria-selected'];
                    if (elements[el]) elements[el].setAttribute(attrs[attr], state ? 'true' : 'false');
                },

                // modal_state: no-op (BindModal JS bridge deleted — THERAPY-3139)
                // All interactive behavior is now compiled to inline Wasm
                modal_state: (el, mode, state) => {},
                // ─── T31 Hydration Cursor Imports (indices 56-61) ───
                // Cursor navigates server-rendered DOM during Leptos-style hydration
                cursor_child: () => {
                    if (!_cursor) { console.warn('[Hydration] cursor_child: null cursor'); return; }
                    _cursor = _cursor.firstElementChild;
                },
                cursor_sibling: () => {
                    if (!_cursor) { console.warn('[Hydration] cursor_sibling: null cursor'); return; }
                    _cursor = _cursor.nextElementSibling;
                },
                cursor_parent: () => {
                    if (!_cursor) { console.warn('[Hydration] cursor_parent: null cursor'); return; }
                    _cursor = _cursor.parentElement;
                },
                cursor_current: () => {
                    if (!_cursor) { console.warn('[Hydration] cursor_current: null cursor, returning -1'); return -1; }
                    const id = _cursorElements.length;
                    _cursorElements.push(_cursor);
                    return id;
                },
                cursor_set: (el_id) => {
                    if (el_id >= 0 && el_id < _cursorElements.length) {
                        _cursor = _cursorElements[el_id];
                    }
                },
                cursor_skip_children: () => {
                    if (!_cursor) return;
                    let child = _cursor.firstElementChild;
                    while (child) {
                        if (child.tagName && child.tagName.toLowerCase() === 'therapy-children') {
                            _cursor = child.nextElementSibling;
                            return;
                        }
                        child = child.nextElementSibling;
                    }
                },

                // ─── T31 Event Attachment Import (index 62) ───
                add_event_listener: (el_id, event_type, handler_idx) => {
                    const el = _cursorElements[el_id];
                    if (!el) return;
                    const eventName = _CURSOR_EVENT_NAMES[event_type];
                    if (!eventName) return;
                    el.addEventListener(eventName, (e) => {
                        _currentEvent = e;
                        if (e.key !== undefined) {
                            _keyCode = KEY_MAP[e.key] || (e.key.length === 1 ? e.key.charCodeAt(0) : 0);
                            _modifiers = (e.shiftKey?1:0)|(e.ctrlKey?2:0)|(e.altKey?4:0)|(e.metaKey?8:0);
                        }
                        if (e.clientX !== undefined) { _pointerX = e.clientX; _pointerY = e.clientY; }
                        if (e.pointerId !== undefined) { _pointerId = e.pointerId; }
                        if (e.target && e.target.value !== undefined) { _targetValueF64 = parseFloat(e.target.value) || 0; }
                        if (e.target && e.target.checked !== undefined) { _targetChecked = e.target.checked ? 1 : 0; }
                        if (wasm['handler_' + handler_idx]) {
                            wasm['handler_' + handler_idx]();
                        }
                        _currentEvent = null;
                    });
                },

                // ─── T31 Signal→DOM Binding Imports (indices 63-66) ───
                register_text_binding: (el_id, signal_idx) => {
                    _cursorBindings.push({ el_id, signal_idx, type: 'text' });
                },
                register_visibility_binding: (el_id, signal_idx) => {
                    _cursorBindings.push({ el_id, signal_idx, type: 'visibility' });
                },
                register_attribute_binding: (el_id, attr_id, signal_idx) => {
                    _cursorBindings.push({ el_id, attr_id, signal_idx, type: 'attribute' });
                },
                trigger_bindings: (signal_idx, value) => {
                    for (const b of _cursorBindings) {
                        if (b.signal_idx !== signal_idx) continue;
                        const el = _cursorElements[b.el_id];
                        if (!el) continue;
                        if (b.type === 'text') {
                            el.textContent = Number.isInteger(value) ? String(Math.trunc(value)) : String(value);
                        } else if (b.type === 'visibility') {
                            el.style.display = value ? '' : 'none';
                        } else if (b.type === 'attribute') {
                            el.setAttribute(strings[b.attr_id], String(value));
                        }
                    }
                },

                // ─── T31 Props Deserialization Imports (indices 67-70) ───
                get_prop_count: () => {
                    return _propValues.length;
                },
                get_prop_i32: (idx) => {
                    if (idx < 0 || idx >= _propValues.length) return 0;
                    const v = _propValues[idx];
                    if (typeof v === 'boolean') return v ? 1 : 0;
                    return Math.trunc(Number(v)) | 0;
                },
                get_prop_f64: (idx) => {
                    if (idx < 0 || idx >= _propValues.length) return 0.0;
                    return Number(_propValues[idx]) || 0.0;
                },
                get_prop_string_id: (idx) => {
                    if (idx < 0 || idx >= _propValues.length) return -1;
                    const v = String(_propValues[idx]);
                    // Add to string table and return ID
                    const id = strings.length;
                    strings.push(v);
                    return id;
                },
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

        // Modal trigger bindings removed — THERAPY-3139 (all behavior now inline Wasm)

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

# DELETED: MODAL_TRIGGER_MAP and generate_modal_trigger_js (THERAPY-3139)
# All modal trigger bindings are now inline @island event handlers compiled to Wasm.
# See Phase 7 (THERAPY-3140-3144) for the Thaw-style component rewrites.

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

# =========================================================================
# T31: Leptos-Style Hydration JS (THERAPY-3112)
# =========================================================================

"""
    generate_hydration_js_v2(; wasm_base_path="/wasm") -> String

Generate minimal hydration JavaScript for the Leptos-style full-body pipeline.

Output is a SINGLE self-contained IIFE that:
1. Declares cursor/binding/element state variables
2. Builds the Wasm import object (all 76 imports)
3. Implements recursive DOM traversal to discover <therapy-island> elements
4. Per-island: loads Wasm, parses props, inits cursor, calls hydrate()
5. Caches compiled Wasm modules by component name
6. Exposes window.__hydrateTherapyIsland() for SPA navigation

Coexists with old generate_hydration_js() — both can be on the same page.
"""
function generate_hydration_js_v2(; wasm_base_path::String="/wasm")::String
    return """
(function() {
  'use strict';

  // ─── Shared state (cursor + props only used during synchronous hydrate call) ───
  let _cursor = null;
  let _propValues = [];
  let _skipIslandWrapper = false;

  // ─── Event state ───
  let _currentEvent = null;
  let _keyCode = 0, _modifiers = 0;
  let _pointerX = 0.0, _pointerY = 0.0, _pointerId = 0;
  let _targetValueF64 = 0.0, _targetChecked = 0;

  // ─── Timer state ───
  const _timers = {};
  let _timerCounter = 0;

  // ─── Escape handler stack (Thaw-style nested modal dismiss) ───
  const _escapeStack = [];
  let _escapeListenerActive = false;

  // ─── Active element save/restore (modal focus management) ───
  let _savedActiveElement = null;

  // ─── Wasm module cache (component name → compiled module) ───
  const _moduleCache = {};

  // ─── KEY_MAP for keyboard events ───
  const KEY_MAP = {'Backspace':8,'Tab':9,'Enter':13,'Escape':27,' ':32,
    'End':35,'Home':36,'ArrowLeft':37,'ArrowUp':38,
    'ArrowRight':39,'ArrowDown':40,'Delete':46};

  // ─── EVENT_NAMES for add_event_listener ───
  const _EVENT_NAMES = ['click','input','change','keydown','keyup',
    'pointerdown','pointermove','pointerup','focus','blur',
    'submit','dblclick','contextmenu','pointerenter','pointerleave'];

  // ─── Build Wasm imports object ───
  function buildImports(instRef, state) {
    return { dom: {
      // Imports 0-4: Original
      update_text: (hk, v) => {},
      set_visible: (hk, v) => {},
      set_dark_mode: (v) => {
        const isDark = !!v;
        document.documentElement.classList.toggle('dark', isDark);
        try { localStorage.setItem('therapy-theme', isDark ? 'dark' : 'light'); } catch(e) {}
      },
      send: (ch, msg) => {},
      get_editor_code: (id) => 0.0,
      // Imports 5-7: Class manipulation
      add_class: (el, cls) => { const e = state.elements[el]; if (e) e.classList.add(state.strings[cls]); },
      remove_class: (el, cls) => { const e = state.elements[el]; if (e) e.classList.remove(state.strings[cls]); },
      toggle_class: (el, cls) => { const e = state.elements[el]; if (e) e.classList.toggle(state.strings[cls]); },
      // Imports 8-10: Attribute/style
      set_attribute: (el, attr, val) => { const e = state.elements[el]; if (e) e.setAttribute(state.strings[attr], state.strings[val]); },
      remove_attribute: (el, attr) => { const e = state.elements[el]; if (e) e.removeAttribute(state.strings[attr]); },
      set_style: (el, prop, val) => { const e = state.elements[el]; if (e) e.style.setProperty(state.strings[prop], state.strings[val]); },
      // Imports 11-16: DOM state + text + display
      set_data_state: (el, val) => { const e = state.elements[el]; if (e) e.dataset.state = state.strings[val]; },
      set_data_motion: (el, val) => { const e = state.elements[el]; if (e) e.dataset.motion = state.strings[val]; },
      set_text_content: (el, val) => { const e = state.elements[el]; if (e) e.textContent = state.strings[val]; },
      set_hidden: (el, val) => { const e = state.elements[el]; if (e) e.hidden = !!val; },
      show_element: (el) => { const e = state.elements[el]; if (e) e.style.display = ''; },
      hide_element: (el) => { const e = state.elements[el]; if (e) e.style.display = 'none'; },
      // Imports 17-19: Focus
      focus_element: (el) => { const e = state.elements[el]; if (e) e.focus(); },
      focus_element_prevent_scroll: (el) => { const e = state.elements[el]; if (e) e.focus({preventScroll: true}); },
      blur_element: (el) => { const e = state.elements[el]; if (e) e.blur(); },
      // Import 20: Active element
      get_active_element: () => { const ae = document.activeElement; if (!ae) return -1; const id = state.elements.indexOf(ae); return id >= 0 ? id : -1; },
      // Imports 21-24: Focus management
      focus_first_tabbable: (el) => {},
      focus_last_tabbable: (el) => {},
      install_focus_guards: () => {},
      uninstall_focus_guards: () => {},
      // Imports 25-27: Scroll
      lock_scroll: () => { document.body.style.overflow = 'hidden'; },
      unlock_scroll: () => { document.body.style.overflow = ''; },
      scroll_into_view: (el) => { const e = state.elements[el]; if (e) e.scrollIntoView({block: 'nearest'}); },
      // Imports 28-33: Geometry
      get_bounding_rect_x: (el) => { const e = state.elements[el]; return e ? e.getBoundingClientRect().x : 0; },
      get_bounding_rect_y: (el) => { const e = state.elements[el]; return e ? e.getBoundingClientRect().y : 0; },
      get_bounding_rect_w: (el) => { const e = state.elements[el]; return e ? e.getBoundingClientRect().width : 0; },
      get_bounding_rect_h: (el) => { const e = state.elements[el]; return e ? e.getBoundingClientRect().height : 0; },
      get_viewport_width: () => window.innerWidth,
      get_viewport_height: () => window.innerHeight,
      // Imports 34-40: Event getters
      get_key_code: () => _keyCode,
      get_modifiers: () => _modifiers,
      get_pointer_x: () => _pointerX,
      get_pointer_y: () => _pointerY,
      get_pointer_id: () => _pointerId,
      get_target_value_f64: () => _targetValueF64,
      get_target_checked: () => _targetChecked,
      // Imports 41-43: Storage/clipboard
      storage_get_i32: (key) => { try { return parseInt(localStorage.getItem(state.strings[key])) || 0; } catch(e) { return 0; } },
      storage_set_i32: (key, val) => { try { localStorage.setItem(state.strings[key], String(val)); } catch(e) {} },
      copy_to_clipboard: (id) => { navigator.clipboard?.writeText(state.strings[id]); },
      // Imports 44-47: Pointer/drag
      capture_pointer: (el) => { const e = state.elements[el]; if (e) e.setPointerCapture(_pointerId); },
      release_pointer: (el) => { const e = state.elements[el]; if (e) e.releasePointerCapture(_pointerId); },
      get_drag_delta_x: () => 0,
      get_drag_delta_y: () => 0,
      // Imports 48-52: Timers + prevent_default
      set_timeout: (handler, ms) => { const id = ++_timerCounter; _timers[id] = setTimeout(() => { delete _timers[id]; const w = instRef.exports; if (w['handler_' + handler]) w['handler_' + handler](); }, ms); return id; },
      clear_timeout: (id) => { clearTimeout(_timers[id]); delete _timers[id]; },
      request_animation_frame: (handler) => { const id = requestAnimationFrame(() => { const w = instRef.exports; if (w['handler_' + handler]) w['handler_' + handler](); }); return id; },
      cancel_animation_frame: (id) => { cancelAnimationFrame(id); },
      prevent_default: () => { if (_currentEvent) _currentEvent.preventDefault(); },
      // Imports 53-55: Bool/modal helpers
      set_data_state_bool: (el, mode, v) => {},
      set_aria_bool: (el, attr, v) => {},
      modal_state: (el, mode, v) => {},
      // ─── T31 Cursor imports (56-61) ───
      cursor_child: () => {
        if (!_cursor) { console.warn('[Hydration] cursor_child: null cursor'); return; }
        _cursor = _cursor.firstElementChild;
      },
      cursor_sibling: () => {
        if (!_cursor) { console.warn('[Hydration] cursor_sibling: null cursor'); return; }
        _cursor = _cursor.nextElementSibling;
      },
      cursor_parent: () => {
        if (!_cursor) { console.warn('[Hydration] cursor_parent: null cursor'); return; }
        _cursor = _cursor.parentElement;
      },
      cursor_current: () => {
        if (_skipIslandWrapper && _cursor && _cursor.tagName && _cursor.tagName.toLowerCase() === 'therapy-island') {
          _cursor = _cursor.firstElementChild;
        }
        _skipIslandWrapper = false;
        if (!_cursor) { console.warn('[Hydration] cursor_current: null cursor'); return -1; }
        const id = state.elements.length;
        state.elements.push(_cursor);
        return id;
      },
      cursor_set: (el_id) => {
        if (el_id >= 0 && el_id < state.elements.length) _cursor = state.elements[el_id];
      },
      cursor_skip_children: () => {
        if (!_cursor) return;
        let child = _cursor.firstElementChild;
        while (child) {
          if (child.tagName.toLowerCase() === 'therapy-children') {
            _cursor = child.nextElementSibling;
            return;
          }
          child = child.nextElementSibling;
        }
      },
      // ─── T31 Event attachment (62) ───
      add_event_listener: (el_id, event_type, handler_idx) => {
        const el = state.elements[el_id];
        if (!el) return;
        el.addEventListener(_EVENT_NAMES[event_type], (e) => {
          _currentEvent = e;
          if (e.key !== undefined) {
            _keyCode = KEY_MAP[e.key] ?? (e.key.length === 1 ? e.key.charCodeAt(0) : 0);
            _modifiers = (e.shiftKey?1:0)|(e.ctrlKey?2:0)|(e.altKey?4:0)|(e.metaKey?8:0);
          }
          if (e.clientX !== undefined) { _pointerX = e.clientX; _pointerY = e.clientY; }
          if (e.pointerId !== undefined) _pointerId = e.pointerId;
          if (e.target?.value !== undefined) _targetValueF64 = parseFloat(e.target.value) || 0;
          if (e.target?.checked !== undefined) _targetChecked = e.target.checked ? 1 : 0;
          const w = instRef.exports;
          if (w['handler_' + handler_idx]) w['handler_' + handler_idx]();
          _currentEvent = null;
        });
      },
      // ─── T31 Binding imports (63-66) ───
      register_text_binding: (el_id, signal_idx) => {
        state.bindings.push({ el_id, signal_idx, type: 'text' });
      },
      register_visibility_binding: (el_id, signal_idx) => {
        state.bindings.push({ el_id, signal_idx, type: 'visibility' });
      },
      register_attribute_binding: (el_id, attr_id, signal_idx) => {
        state.bindings.push({ el_id, attr_id, signal_idx, type: 'attribute' });
      },
      trigger_bindings: (signal_idx, value) => {
        const DATA_STATE_MODES = [['closed','open'], ['off','on'], ['unchecked','checked'], ['inactive','active']];
        const ARIA_ATTRS = ['aria-pressed', 'aria-checked', 'aria-expanded', 'aria-selected'];
        for (const b of state.bindings) {
          if (b.signal_idx !== signal_idx) continue;
          const el = state.elements[b.el_id];
          if (!el) continue;
          if (b.type === 'text') {
            el.textContent = String(value);
          } else if (b.type === 'visibility') {
            el.style.display = value ? '' : 'none';
          } else if (b.type === 'attribute') {
            el.setAttribute(state.strings[b.attr_id] || '', String(value));
          } else if (b.type === 'data_state') {
            const pair = DATA_STATE_MODES[b.mode] || DATA_STATE_MODES[0];
            el.dataset.state = value ? pair[1] : pair[0];
          } else if (b.type === 'aria') {
            const attr = ARIA_ATTRS[b.attr_code] || ARIA_ATTRS[0];
            el.setAttribute(attr, value ? 'true' : 'false');
          } else if (b.type === 'modal') {
            // Slim modal binding: show/hide + data-state + close button delegation only.
            // Behavior (scroll lock, focus, Escape, Tab trap) is inline Wasm in trigger handlers.
            const _OVL = '[data-dialog-overlay],[data-sheet-overlay],[data-drawer-overlay],[data-alert-dialog-overlay],[data-popover-content],[data-tooltip-content],[data-hover-card-content]';
            const _CTN = '[data-dialog-content],[data-sheet-content],[data-drawer-content],[data-alert-dialog-content]';
            const _CLS = '[data-dialog-close],[data-sheet-close],[data-drawer-close],[data-alert-dialog-action],[data-alert-dialog-cancel],[data-popover-close]';
            if (value) {
              const ov = el.querySelector(_OVL), ct = el.querySelector(_CTN);
              if (ov) { ov.style.display = ''; ov.dataset.state = 'open'; }
              if (ct) { ct.style.display = ''; ct.dataset.state = 'open'; requestAnimationFrame(() => ct.focus({ preventScroll: true })); }
              // Close button delegation (plain function components can't have Wasm handlers)
              if (!el._clsH) {
                el._clsH = (e) => { const btn = e.target.closest(_CLS); if (btn && el.contains(btn)) { const w = instRef.exports; if (w.handler_0) w.handler_0(); } };
                el.addEventListener('click', el._clsH);
              }
            } else {
              const ov = el.querySelector(_OVL), ct = el.querySelector(_CTN);
              if (ov) ov.dataset.state = 'closed';
              if (ct) ct.dataset.state = 'closed';
              // Animation-aware hide: wait for animationend or timeout
              const hide = () => { if (ov && ov.dataset.state === 'closed') ov.style.display = 'none'; if (ct && ct.dataset.state === 'closed') ct.style.display = 'none'; };
              if (ct) ct.addEventListener('animationend', hide, { once: true });
              setTimeout(hide, 300);
              if (el._clsH) { el.removeEventListener('click', el._clsH); el._clsH = null; }
            }
          } else if (b.type === 'match') {
            el.style.display = (value === b.match_value) ? '' : 'none';
          } else if (b.type === 'match_data_state') {
            const pair = DATA_STATE_MODES[b.mode] || DATA_STATE_MODES[0];
            el.dataset.state = (value === b.match_value) ? pair[1] : pair[0];
          } else if (b.type === 'match_aria') {
            const attr = ARIA_ATTRS[b.attr_code] || ARIA_ATTRS[0];
            el.setAttribute(attr, (value === b.match_value) ? 'true' : 'false');
          } else if (b.type === 'bit_data_state') {
            const pair = DATA_STATE_MODES[b.mode] || DATA_STATE_MODES[0];
            el.dataset.state = ((value >> b.bit_index) & 1) ? pair[1] : pair[0];
          } else if (b.type === 'bit_aria') {
            const attr = ARIA_ATTRS[b.attr_code] || ARIA_ATTRS[0];
            el.setAttribute(attr, ((value >> b.bit_index) & 1) ? 'true' : 'false');
          } else if (b.type === 'show_descendants') {
            // Phase 7: show/hide descendants with [data-state] + update aria-expanded on triggers
            const root = state.elements[b.el_id] || el;
            root.querySelectorAll('[data-state]').forEach(d => {
              if (value) {
                d.dataset.state = 'open';
                if (d.style.display === 'none') { d.style.display = ''; d._sd = 1; }
              } else {
                d.dataset.state = 'closed';
                if (d._sd) {
                  const h = () => { if (d.dataset.state === 'closed') d.style.display = 'none'; };
                  d.addEventListener('animationend', h, { once: true });
                  setTimeout(h, 300);
                }
              }
            });
            // Focus dialog content on open
            if (value) {
              const ct = root.querySelector('[role="dialog"],[role="alertdialog"]');
              if (ct) requestAnimationFrame(() => ct.focus({ preventScroll: true }));
            }
            // Update aria-expanded on triggers
            const trig = root.querySelector('[aria-expanded]');
            if (trig) trig.setAttribute('aria-expanded', value ? 'true' : 'false');
          }
        }
      },
      // ─── T31 Props imports (67-70) ───
      get_prop_count: () => _propValues.length,
      get_prop_i32: (idx) => {
        if (idx < 0 || idx >= _propValues.length) return 0;
        return Math.trunc(Number(_propValues[idx])) || 0;
      },
      get_prop_f64: (idx) => {
        if (idx < 0 || idx >= _propValues.length) return 0.0;
        return Number(_propValues[idx]) || 0.0;
      },
      get_prop_string_id: (idx) => {
        if (idx < 0 || idx >= _propValues.length) return -1;
        const s = String(_propValues[idx]);
        const id = state.strings.length;
        state.strings.push(s);
        return id;
      },
      // ─── T31 BindBool/BindModal binding registration (71-73) ───
      register_data_state_binding: (el_id, signal_idx, mode) => {
        state.bindings.push({ el_id, signal_idx, mode, type: 'data_state' });
      },
      register_aria_binding: (el_id, signal_idx, attr_code) => {
        state.bindings.push({ el_id, signal_idx, attr_code, type: 'aria' });
      },
      register_modal_binding: (el_id, signal_idx, mode) => {
        state.bindings.push({ el_id, signal_idx, mode, type: 'modal' });
      },
      // ─── T31 Per-child pattern support (74-75) ───
      get_event_data_index: () => {
        if (!_currentEvent || !_currentEvent.target) return -1;
        const el = _currentEvent.target.closest('[data-index]');
        if (!el) return -1;
        const idx = parseInt(el.dataset.index, 10);
        return isNaN(idx) ? -1 : idx;
      },
      register_match_binding: (el_id, signal_idx, match_value) => {
        state.bindings.push({ el_id, signal_idx, match_value, type: 'match' });
      },
      // ─── T31 Per-child match/bit state bindings (76-79) ───
      register_match_data_state_binding: (el_id, signal_idx, match_value, mode) => {
        state.bindings.push({ el_id, signal_idx, match_value, mode, type: 'match_data_state' });
      },
      register_match_aria_binding: (el_id, signal_idx, match_value, attr_code) => {
        state.bindings.push({ el_id, signal_idx, match_value, attr_code, type: 'match_aria' });
      },
      register_bit_data_state_binding: (el_id, signal_idx, bit_index, mode) => {
        state.bindings.push({ el_id, signal_idx, bit_index, mode, type: 'bit_data_state' });
      },
      register_bit_aria_binding: (el_id, signal_idx, bit_index, attr_code) => {
        state.bindings.push({ el_id, signal_idx, bit_index, attr_code, type: 'bit_aria' });
      },
      // ─── T31 Phase 6: Escape dismiss handler stack (80-81) ───
      push_escape_handler: (handler_idx) => {
        _escapeStack.push({ handler_idx, inst: instRef });
        if (!_escapeListenerActive) {
          _escapeListenerActive = true;
          document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && _escapeStack.length > 0) {
              const top = _escapeStack[_escapeStack.length - 1];
              const w = top.inst.exports;
              _currentEvent = e;
              _keyCode = 27;
              _modifiers = (e.shiftKey?1:0)|(e.ctrlKey?2:0)|(e.altKey?4:0)|(e.metaKey?8:0);
              if (w['handler_' + top.handler_idx]) w['handler_' + top.handler_idx]();
              _currentEvent = null;
            }
          });
        }
      },
      pop_escape_handler: () => {
        _escapeStack.pop();
      },
      // ─── T31 Phase 6: Click-outside dismiss (82-83) ───
      add_click_outside_listener: (el_id, handler_idx) => {
        const el = state.elements[el_id];
        if (!el) return;
        const handler = (e) => {
          if (el && !el.contains(e.target)) {
            const w = instRef.exports;
            _currentEvent = e;
            if (w['handler_' + handler_idx]) w['handler_' + handler_idx]();
            _currentEvent = null;
          }
        };
        el._outsideClickHandler = handler;
        document.addEventListener('pointerdown', handler, true);
      },
      remove_click_outside_listener: (el_id) => {
        const el = state.elements[el_id];
        if (el && el._outsideClickHandler) {
          document.removeEventListener('pointerdown', el._outsideClickHandler, true);
          delete el._outsideClickHandler;
        }
      },
      // ─── T31 Phase 6: Active element save/restore (84-85) ───
      store_active_element: () => {
        _savedActiveElement = document.activeElement;
      },
      restore_active_element: () => {
        if (_savedActiveElement) { _savedActiveElement.focus(); _savedActiveElement = null; }
      },
      // ─── T31 Phase 7: ShowDescendants + event delegation (86-88) ───
      show_descendants: (el_id, signal_idx) => {
        state.bindings.push({ el_id, signal_idx, type: 'show_descendants' });
      },
      get_event_closest_role: () => {
        if (!_currentEvent || !_currentEvent.target) return 0;
        const t = _currentEvent.target.closest ? _currentEvent.target.closest('[data-role]') : null;
        return t ? (parseInt(t.dataset.role) || 0) : 0;
      },
      get_parent_island_root: () => {
        // Walk up from current island element to find parent therapy-island
        const cur = _currentIslandElement;
        if (!cur) return -1;
        const parent = cur.parentElement ? cur.parentElement.closest('therapy-island') : null;
        if (!parent) return -1;
        // Return the first registered element (root) of the parent island — store in _parentRoots
        return parent._rootElId !== undefined ? parent._rootElId : -1;
      },
      // ─── T31 Phase 7: Focus trap cycling (89) ───
      cycle_focus_in_current_target: (direction) => {
        // Cycle Tab focus within the event's currentTarget element
        // direction: 0 = forward (Tab), 1 = backward (Shift+Tab)
        if (!_currentEvent || !_currentEvent.currentTarget) return;
        const el = _currentEvent.currentTarget;
        const sel = 'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex=\\"-1\\"])';
        const focusable = Array.from(el.querySelectorAll(sel));
        if (focusable.length === 0) return;
        const idx = focusable.indexOf(document.activeElement);
        let next;
        if (direction) { // backward (Shift+Tab)
          next = idx <= 0 ? focusable.length - 1 : idx - 1;
        } else { // forward (Tab)
          next = idx >= focusable.length - 1 ? 0 : idx + 1;
        }
        focusable[next].focus();
      },
      // ─── T32: Auto-register bindings on [data-index] descendants (90-91) ───
      register_match_descendants: (signal_idx, mode) => {
        const root = state.island || _cursor;
        if (!root) return;
        root.querySelectorAll('[data-index]').forEach(el => {
          const idx = parseInt(el.dataset.index, 10);
          if (isNaN(idx)) return;
          const el_id = state.elements.length;
          state.elements.push(el);
          state.bindings.push({ el_id, signal_idx, match_value: idx, type: 'match_data_state', mode });
          if (el.hasAttribute('aria-selected'))
            state.bindings.push({ el_id, signal_idx, match_value: idx, type: 'match_aria', attr_code: 3 });
          if (el.hasAttribute('aria-expanded'))
            state.bindings.push({ el_id, signal_idx, match_value: idx, type: 'match_aria', attr_code: 2 });
          if (el.hasAttribute('aria-checked'))
            state.bindings.push({ el_id, signal_idx, match_value: idx, type: 'match_aria', attr_code: 1 });
          if (el.hasAttribute('aria-pressed'))
            state.bindings.push({ el_id, signal_idx, match_value: idx, type: 'match_aria', attr_code: 0 });
        });
      },
      register_bit_descendants: (signal_idx, mode) => {
        const root = state.island || _cursor;
        if (!root) return;
        root.querySelectorAll('[data-index]').forEach(el => {
          const idx = parseInt(el.dataset.index, 10);
          if (isNaN(idx)) return;
          const el_id = state.elements.length;
          state.elements.push(el);
          state.bindings.push({ el_id, signal_idx, bit_index: idx, type: 'bit_data_state', mode });
          if (el.hasAttribute('aria-expanded'))
            state.bindings.push({ el_id, signal_idx, bit_index: idx, type: 'bit_aria', attr_code: 2 });
          if (el.hasAttribute('aria-pressed'))
            state.bindings.push({ el_id, signal_idx, bit_index: idx, type: 'bit_aria', attr_code: 0 });
        });
      },
    }, channel: { send: (ch, msg) => {} } };
  }

  // ─── Hydrate a single island element ───
  async function hydrateIsland(el) {
    const name = el.dataset.component;
    if (!name) return;
    const wasmPath = el.dataset.wasm || '$(wasm_base_path)/' + name + '.wasm';

    // Load or reuse cached Wasm module
    if (!_moduleCache[name]) {
      const resp = await fetch(wasmPath);
      if (!resp.ok) { console.warn('[Hydration] Failed to load', wasmPath); return; }
      const bytes = await resp.arrayBuffer();
      _moduleCache[name] = await WebAssembly.compile(bytes);
    }

    // Per-island state (each island gets its own arrays so parent bindings survive child hydration)
    const state = { elements: [], bindings: [], strings: [] };

    // Parse string table into per-island state
    if (el.dataset.strings) {
      try { JSON.parse(el.dataset.strings).forEach(s => state.strings.push(s)); } catch(e) {}
    }

    // Parse props (alphabetical key order)
    const props = JSON.parse(el.dataset.props || '{}');
    const propKeys = Object.keys(props).sort();
    _propValues = propKeys.map(k => props[k]);

    // Instantiate with circular reference for handler callbacks
    let instance = null;
    const imports = buildImports({ get exports() { return instance.exports; } }, state);
    instance = await WebAssembly.instantiate(_moduleCache[name], imports);

    // Set cursor for DOM walk. The _skipIslandWrapper flag tells cursor_current()
    // to descend past the therapy-island wrapper on its first call, so the Wasm
    // hydrate function registers bindings on the component root (e.g. <button>)
    // rather than the therapy-island wrapper element.
    _skipIslandWrapper = true;
    _cursor = el;

    // Call hydrate with prop values as arguments
    instance.exports.hydrate(..._propValues.map(v => typeof v === 'boolean' ? (v ? 1 : 0) : Number(v) || 0));

    el.dataset.hydrated = 'true';
  }

  // ─── Recursive DOM traversal (like Leptos island_script.js) ───
  async function hydrateIslands(node) {
    for (const child of Array.from(node.children)) {
      const tag = child.tagName.toLowerCase();
      if (tag === 'therapy-island') {
        if (!child.dataset.hydrated) {
          await hydrateIsland(child);
        }
        // Recurse INTO island for nested islands
        await hydrateIslands(child);
      } else if (tag === 'therapy-children') {
        await hydrateIslands(child);
      } else {
        await hydrateIslands(child);
      }
    }
  }

  // ─── Entry point ───
  hydrateIslands(document.body);

  // ─── Expose for SPA navigation ───
  window.__hydrateTherapyIsland = hydrateIsland;
  window.__hydrateTherapyIslands = hydrateIslands;
})();
"""
end

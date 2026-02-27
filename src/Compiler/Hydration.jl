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

                // modal_state(el, mode, state): modal lifecycle management
                // mode: 0=dialog, 1=alert_dialog, 2=drawer, 3=popover, 4=tooltip, 5=hover_card, 6=dropdown_menu, 7=context_menu, 8=menubar, 9=nav_menu, 10=select, 11=command, 12=command_dialog, 13=slider, 14=calendar, 15=datepicker, 16=datatable, 17=form, 18=codeblock, 19=treeview, 20=carousel, 21=resizable, 22=toast, 23=theme_switcher
                // Modes 0-3: scroll lock, focus trap, etc. Modes 4-5: hover-based floating with timers. Modes 6-8: floating menu with keyboard nav. Mode 9: hover-timed nav panels. Mode 10: floating select. Mode 11: command filtering/nav. Mode 12: command dialog. Mode 13: slider drag+keyboard. Mode 14: calendar grid+nav. Mode 15: datepicker popover. Mode 16: datatable sort/filter/paginate. Mode 17: form validation. Mode 18: codeblock copy+highlight. Mode 19: treeview expand/collapse+keyboard nav. Mode 20: carousel scroll/nav. Mode 21: resizable drag panels. Mode 22: toast notification system. Mode 23: theme switcher dropdown.
                modal_state: (el, mode, state) => {
                    const island = elements[el];
                    if (!island) return;

                    // Mode 4 (tooltip) and Mode 5 (hover_card) — hover-based floating components
                    if (mode === 4 || mode === 5) {
                        const isTT = mode === 4;
                        const ct = island.querySelector(isTT ? '[data-tooltip-content]' : '[data-hover-card-content]');
                        if (!ct) return;
                        const tw = island.querySelector(isTT ? '[data-tooltip-trigger-wrapper]' : '[data-hover-card-trigger-wrapper]');
                        const trig = tw ? (tw.firstElementChild || tw) : null;

                        // Read positioning params from content data attributes
                        const pfx = isTT ? 'data-tooltip' : 'data-hover-card';
                        const side = ct.getAttribute(pfx + '-side') || (isTT ? 'top' : 'bottom');
                        const sideOff = parseInt(ct.getAttribute(pfx + '-side-offset') || '4', 10);
                        const align = ct.getAttribute(pfx + '-align') || 'center';
                        const pad = 4;

                        // Read delay
                        const prov = isTT ? island.closest('[data-tooltip-provider]') : null;
                        const openDelay = isTT
                            ? parseInt((prov || island).getAttribute('data-tooltip-delay') || '700', 10)
                            : parseInt(island.getAttribute('data-hover-card-open-delay') || '700', 10);
                        const closeDelay = isTT ? 0 : parseInt(island.getAttribute('data-hover-card-close-delay') || '300', 10);

                        function floatPos() {
                            if (!trig || !ct) return;
                            const r = trig.getBoundingClientRect();
                            const f = ct.getBoundingClientRect();
                            const vw = window.innerWidth, vh = window.innerHeight;
                            function ap(rs, rz, fz) { return align === 'start' ? rs : align === 'end' ? rs + rz - fz : rs + (rz - fz) / 2; }
                            let t, l, as = side;
                            if (side === 'bottom') { t = r.bottom + sideOff; l = ap(r.left, r.width, f.width); }
                            else if (side === 'top') { t = r.top - f.height - sideOff; l = ap(r.left, r.width, f.width); }
                            else if (side === 'right') { l = r.right + sideOff; t = ap(r.top, r.height, f.height); }
                            else { l = r.left - f.width - sideOff; t = ap(r.top, r.height, f.height); }
                            if (as === 'bottom' && t + f.height > vh - pad) { const n = r.top - f.height - sideOff; if (n >= pad) { t = n; as = 'top'; } }
                            else if (as === 'top' && t < pad) { const n = r.bottom + sideOff; if (n + f.height <= vh - pad) { t = n; as = 'bottom'; } }
                            else if (as === 'right' && l + f.width > vw - pad) { const n = r.left - f.width - sideOff; if (n >= pad) { l = n; as = 'left'; } }
                            else if (as === 'left' && l < pad) { const n = r.right + sideOff; if (n + f.width <= vw - pad) { l = n; as = 'right'; } }
                            l = Math.max(pad, Math.min(l, vw - f.width - pad));
                            t = Math.max(pad, Math.min(t, vh - f.height - pad));
                            ct.style.position = 'fixed'; ct.style.top = t + 'px'; ct.style.left = l + 'px';
                            ct.setAttribute('data-side', as); ct.setAttribute('data-align', align);
                        }

                        function doClose() {
                            if (!island._hoverOpen) return;
                            island._hoverOpen = false;
                            if (island._hoverOT) { clearTimeout(island._hoverOT); island._hoverOT = null; }
                            if (island._hoverCT) { clearTimeout(island._hoverCT); island._hoverCT = null; }
                            ct.setAttribute('data-state', 'closed');
                            if (tw) tw.setAttribute('data-state', 'closed');
                            if (island._fScroll) { window.removeEventListener('scroll', island._fScroll, true); island._fScroll = null; }
                            if (island._fResize) { window.removeEventListener('resize', island._fResize); island._fResize = null; }
                            if (island._hCE) { ct.removeEventListener('pointerenter', island._hCE); island._hCE = null; }
                            if (island._hCL) { ct.removeEventListener('pointerleave', island._hCL); island._hCL = null; }
                            if (island._hEsc) { document.removeEventListener('keydown', island._hEsc); island._hEsc = null; }
                            if (island._hOut) { document.removeEventListener('pointerdown', island._hOut); island._hOut = null; }
                            if (island._hDown && trig) { trig.removeEventListener('pointerdown', island._hDown); island._hDown = null; }
                            const h = () => { ct.style.display = 'none'; ct.style.position = ''; ct.style.top = ''; ct.style.left = ''; };
                            ct.addEventListener('animationend', h, { once: true });
                            setTimeout(h, isTT ? 200 : 250);
                        }

                        if (state) {
                            // OPEN REQUEST
                            if (island._hoverCT) { clearTimeout(island._hoverCT); island._hoverCT = null; }
                            if (island._hoverOpen) return;

                            island._hoverOT = setTimeout(() => {
                                island._hoverOpen = true;
                                island._hoverOT = null;
                                ct.style.visibility = 'hidden'; ct.style.display = '';
                                requestAnimationFrame(() => {
                                    floatPos();
                                    ct.style.visibility = '';
                                    ct.setAttribute('data-state', isTT ? 'instant-open' : 'open');
                                    if (tw) tw.setAttribute('data-state', 'open');
                                });
                                island._fScroll = () => floatPos();
                                island._fResize = () => floatPos();
                                window.addEventListener('scroll', island._fScroll, true);
                                window.addEventListener('resize', island._fResize);
                                // Content hover: cancel close / restart close
                                island._hCE = () => { if (island._hoverCT) { clearTimeout(island._hoverCT); island._hoverCT = null; } };
                                island._hCL = () => { if (isTT) doClose(); else { island._hoverCT = setTimeout(doClose, closeDelay); } };
                                ct.addEventListener('pointerenter', island._hCE);
                                ct.addEventListener('pointerleave', island._hCL);
                                // Escape dismiss
                                island._hEsc = (e) => { if (e.key === 'Escape') doClose(); };
                                document.addEventListener('keydown', island._hEsc);
                                // Tooltip: pointerdown on trigger closes
                                if (isTT) {
                                    island._hDown = () => doClose();
                                    if (trig) trig.addEventListener('pointerdown', island._hDown);
                                }
                                // HoverCard: click-outside dismiss
                                if (!isTT) {
                                    island._hOut = (e) => {
                                        if (!ct.contains(e.target) && !(tw && tw.contains(e.target))) doClose();
                                    };
                                    setTimeout(() => document.addEventListener('pointerdown', island._hOut), 0);
                                }
                            }, openDelay);
                        } else {
                            // CLOSE REQUEST
                            if (island._hoverOT) { clearTimeout(island._hoverOT); island._hoverOT = null; }
                            if (!island._hoverOpen) return;
                            if (isTT) { doClose(); }
                            else { island._hoverCT = setTimeout(doClose, closeDelay); }
                        }
                        return;
                    }

                    // --- Shared menu helpers (used by modes 6, 7, 8) ---
                    const _mPad = 4;
                    function _mFloat(ref, flt, side, sideOff, align, pad) {
                        const r = ref.getBoundingClientRect();
                        const f = flt.getBoundingClientRect();
                        const vw = window.innerWidth, vh = window.innerHeight;
                        function ap(rs, rz, fz) { return align === 'start' ? rs : align === 'end' ? rs + rz - fz : rs + (rz - fz) / 2; }
                        let t, l, as = side;
                        if (side === 'bottom') { t = r.bottom + sideOff; l = ap(r.left, r.width, f.width); }
                        else if (side === 'top') { t = r.top - f.height - sideOff; l = ap(r.left, r.width, f.width); }
                        else if (side === 'right') { l = r.right + sideOff; t = ap(r.top, r.height, f.height); }
                        else { l = r.left - f.width - sideOff; t = ap(r.top, r.height, f.height); }
                        if (as === 'bottom' && t + f.height > vh - pad) { const n = r.top - f.height - sideOff; if (n >= pad) { t = n; as = 'top'; } }
                        else if (as === 'top' && t < pad) { const n = r.bottom + sideOff; if (n + f.height <= vh - pad) { t = n; as = 'bottom'; } }
                        else if (as === 'right' && l + f.width > vw - pad) { const n = r.left - f.width - sideOff; if (n >= pad) { l = n; as = 'left'; } }
                        else if (as === 'left' && l < pad) { const n = r.right + sideOff; if (n + f.width <= vw - pad) { l = n; as = 'right'; } }
                        l = Math.max(pad, Math.min(l, vw - f.width - pad));
                        t = Math.max(pad, Math.min(t, vh - f.height - pad));
                        flt.style.position = 'fixed'; flt.style.top = t + 'px'; flt.style.left = l + 'px';
                        flt.setAttribute('data-side', as); flt.setAttribute('data-align', align);
                    }
                    function _mFloatAt(flt, x, y, pad) {
                        const f = flt.getBoundingClientRect();
                        const vw = window.innerWidth, vh = window.innerHeight;
                        let l = x, t = y;
                        if (l + f.width > vw - pad) l = Math.max(pad, vw - f.width - pad);
                        if (t + f.height > vh - pad) t = Math.max(pad, vh - f.height - pad);
                        flt.style.position = 'fixed'; flt.style.top = t + 'px'; flt.style.left = l + 'px';
                        flt.setAttribute('data-side', 'right'); flt.setAttribute('data-align', 'start');
                    }
                    function _mGetItems(ct) {
                        return Array.from(ct.querySelectorAll(
                            '[data-menu-item], [data-menu-checkbox-item], [data-menu-radio-item], [data-menu-sub-trigger]'
                        )).filter(el => !el.hasAttribute('data-disabled') && !el.closest('[data-menu-sub-content]'));
                    }
                    function _mFocusItem(ct, item) {
                        _mGetItems(ct).forEach(i => i.removeAttribute('data-highlighted'));
                        if (item) { item.setAttribute('data-highlighted', ''); item.focus({ preventScroll: true }); }
                    }
                    function _mCloseSubmenu(st) {
                        const sc = st.parentElement && st.parentElement.querySelector('[data-menu-sub-content]');
                        if (!sc) return;
                        st.setAttribute('data-state', 'closed'); sc.setAttribute('data-state', 'closed'); sc.style.display = 'none';
                        sc.querySelectorAll('[data-highlighted]').forEach(el => el.removeAttribute('data-highlighted'));
                        if (st._subCleanup) { st._subCleanup(); st._subCleanup = null; }
                    }
                    function _mOpenSubmenu(st, menuClose) {
                        const sc = st.parentElement && st.parentElement.querySelector('[data-menu-sub-content]');
                        if (!sc) return;
                        st.setAttribute('data-state', 'open'); sc.style.display = ''; sc.setAttribute('data-state', 'open');
                        _mFloat(st, sc, 'right', -4, 'start', _mPad);
                        const subClean = _mActivate(sc, { onClose: () => { _mCloseSubmenu(st); subClean(); }, isSubmenu: true, menuClose: menuClose });
                        requestAnimationFrame(() => { const items = _mGetItems(sc); if (items.length > 0) _mFocusItem(sc, items[0]); });
                        st._subCleanup = subClean;
                    }
                    function _mSelectItem(item, ct, menuClose) {
                        if (!item || item.hasAttribute('data-disabled')) return;
                        if (item.hasAttribute('data-menu-checkbox-item')) {
                            const ck = item.getAttribute('data-state') === 'checked';
                            item.setAttribute('data-state', ck ? 'unchecked' : 'checked'); item.setAttribute('aria-checked', String(!ck));
                            const ind = item.querySelector('[data-menu-item-indicator]'); if (ind) ind.style.display = ck ? 'none' : '';
                            return;
                        }
                        if (item.hasAttribute('data-menu-radio-item')) {
                            const grp = item.closest('[data-menu-radio-group]');
                            if (grp) { grp.querySelectorAll('[data-menu-radio-item]').forEach(ri => { ri.setAttribute('data-state', 'unchecked'); ri.setAttribute('aria-checked', 'false'); const ind = ri.querySelector('[data-menu-item-indicator]'); if (ind) ind.style.display = 'none'; }); }
                            item.setAttribute('data-state', 'checked'); item.setAttribute('aria-checked', 'true');
                            const ind = item.querySelector('[data-menu-item-indicator]'); if (ind) ind.style.display = '';
                            return;
                        }
                        if (item.hasAttribute('data-menu-sub-trigger')) { _mOpenSubmenu(item, menuClose); return; }
                        setTimeout(() => menuClose(), 0);
                    }
                    function _mActivate(ct, opts) {
                        const onClose = opts.onClose || (() => {}); const isSubmenu = opts.isSubmenu || false;
                        const menuClose = opts.menuClose || onClose;
                        const onNavL = opts.onNavigateLeft || null; const onNavR = opts.onNavigateRight || null;
                        let sBuf = '', sTmr = null;
                        function ta(key) {
                            sBuf += key; clearTimeout(sTmr); sTmr = setTimeout(() => { sBuf = ''; }, 1000);
                            const items = _mGetItems(ct); const vals = items.map(el => el.getAttribute('data-text-value') || el.textContent.trim());
                            const cur = ct.querySelector('[data-highlighted]'); const curTxt = cur ? (cur.getAttribute('data-text-value') || cur.textContent.trim()) : undefined;
                            const chars = sBuf.split(''); const norm = chars.every(c => c === chars[0]) ? chars[0] : sBuf;
                            let cands = vals; if (curTxt) { const ci = vals.indexOf(curTxt); if (ci >= 0) cands = [...vals.slice(ci+1), ...vals.slice(0, ci+1)]; }
                            let match; if (norm.length === 1) { match = cands.find(v => v.toLowerCase().startsWith(norm.toLowerCase()) && v !== curTxt) || cands.find(v => v.toLowerCase().startsWith(norm.toLowerCase())); } else { match = cands.find(v => v.toLowerCase().startsWith(norm.toLowerCase())); }
                            if (match) { const mi = vals.indexOf(match); if (mi >= 0) _mFocusItem(ct, items[mi]); }
                        }
                        function onKD(e) {
                            const items = _mGetItems(ct); const cur = ct.querySelector('[data-highlighted]'); const idx = cur ? items.indexOf(cur) : -1;
                            if (e.key === 'Tab') { e.preventDefault(); return; }
                            if (e.key === 'Escape') { if (isSubmenu) { e.stopPropagation(); onClose(); } else { menuClose(); } return; }
                            if (e.key === 'ArrowDown') { e.preventDefault(); _mFocusItem(ct, items[idx < items.length-1 ? idx+1 : 0]); return; }
                            if (e.key === 'ArrowUp') { e.preventDefault(); _mFocusItem(ct, items[idx > 0 ? idx-1 : items.length-1]); return; }
                            if (e.key === 'Home' || e.key === 'PageUp') { e.preventDefault(); if (items.length) _mFocusItem(ct, items[0]); return; }
                            if (e.key === 'End' || e.key === 'PageDown') { e.preventDefault(); if (items.length) _mFocusItem(ct, items[items.length-1]); return; }
                            if (e.key === 'ArrowRight') { if (cur && cur.hasAttribute('data-menu-sub-trigger')) { e.preventDefault(); _mOpenSubmenu(cur, menuClose); return; } if (onNavR) { e.preventDefault(); onNavR(); return; } }
                            if (e.key === 'ArrowLeft') { if (isSubmenu) { e.preventDefault(); onClose(); return; } if (onNavL) { e.preventDefault(); onNavL(); return; } }
                            if (e.key === 'Enter' || (e.key === ' ' && sBuf === '')) { e.preventDefault(); if (cur) _mSelectItem(cur, ct, menuClose); return; }
                            if (e.key.length === 1 && !e.ctrlKey && !e.altKey && !e.metaKey) { e.preventDefault(); ta(e.key); }
                        }
                        function onPM(e) { if (e.pointerType === 'touch' || e.pointerType === 'pen') return; const item = e.target.closest('[data-menu-item], [data-menu-checkbox-item], [data-menu-radio-item], [data-menu-sub-trigger]'); if (item && !item.hasAttribute('data-disabled') && ct.contains(item) && !item.closest('[data-menu-sub-content]')) _mFocusItem(ct, item); }
                        function onPL(e) { if (e.pointerType === 'touch' || e.pointerType === 'pen') return; _mGetItems(ct).forEach(i => i.removeAttribute('data-highlighted')); ct.focus({ preventScroll: true }); }
                        function onCK(e) { const item = e.target.closest('[data-menu-item], [data-menu-checkbox-item], [data-menu-radio-item], [data-menu-sub-trigger]'); if (item && ct.contains(item) && !item.closest('[data-menu-sub-content]')) _mSelectItem(item, ct, menuClose); }
                        ct.addEventListener('keydown', onKD); ct.addEventListener('pointermove', onPM); ct.addEventListener('pointerleave', onPL); ct.addEventListener('click', onCK);
                        return function() { ct.removeEventListener('keydown', onKD); ct.removeEventListener('pointermove', onPM); ct.removeEventListener('pointerleave', onPL); ct.removeEventListener('click', onCK); clearTimeout(sTmr); sBuf = ''; ct.querySelectorAll('[data-menu-sub-trigger]').forEach(st => { if (st._subCleanup) { st._subCleanup(); st._subCleanup = null; } }); };
                    }
                    // Shared open/close helpers for menu modes
                    function _mMenuOpen(island, content, doClose, trigEls) {
                        if (++_scrollLockCount === 1) document.body.style.overflow = 'hidden';
                        if (!window._therapyFocusGuards) { const g = () => { const s = document.createElement('span'); s.tabIndex = 0; s.setAttribute('data-focus-guard',''); s.style.cssText = 'position:fixed;opacity:0;pointer-events:none'; return s; }; window._therapyFocusGuards = [g(), g()]; document.body.prepend(window._therapyFocusGuards[0]); document.body.append(window._therapyFocusGuards[1]); }
                        island._modalPE = document.body.style.pointerEvents; document.body.style.pointerEvents = 'none'; content.style.pointerEvents = 'auto';
                        island._menuOutside = (e) => { if (!content.contains(e.target) && !(trigEls && trigEls.some(t => t && t.contains(e.target)))) doClose(); };
                        setTimeout(() => document.addEventListener('pointerdown', island._menuOutside), 0);
                    }
                    function _mMenuClose(island, content) {
                        if (island._menuCleanup) { island._menuCleanup(); island._menuCleanup = null; }
                        if (island._menuScroll) { window.removeEventListener('scroll', island._menuScroll, true); island._menuScroll = null; }
                        if (island._menuResize) { window.removeEventListener('resize', island._menuResize); island._menuResize = null; }
                        if (island._menuOutside) { document.removeEventListener('pointerdown', island._menuOutside); island._menuOutside = null; }
                        if (--_scrollLockCount <= 0) { _scrollLockCount = 0; document.body.style.overflow = ''; }
                        if (window._therapyFocusGuards) { window._therapyFocusGuards.forEach(g => g.remove()); window._therapyFocusGuards = null; }
                        document.body.style.pointerEvents = island._modalPE || ''; content.style.pointerEvents = '';
                        content.querySelectorAll('[data-highlighted]').forEach(el => el.removeAttribute('data-highlighted'));
                        content.setAttribute('data-state', 'closed');
                        const h = () => { content.style.display = 'none'; content.style.position = ''; content.style.top = ''; content.style.left = ''; };
                        content.addEventListener('animationend', h, { once: true }); setTimeout(h, 250);
                    }

                    // Mode 6: dropdown_menu
                    if (mode === 6) {
                        const tw = island.querySelector('[data-dropdown-menu-trigger-wrapper]');
                        const trigger = tw ? (tw.firstElementChild || tw) : null;
                        const content = island.querySelector('[data-dropdown-menu-content]');
                        if (!trigger || !content) return;
                        const dSide = content.getAttribute('data-side-preference') || 'bottom';
                        const dSideOff = parseInt(content.getAttribute('data-side-offset') || '4', 10);
                        const dAlign = content.getAttribute('data-align-preference') || 'start';

                        if (state) {
                            if (island._menuOpen) return;
                            island._menuOpen = true; island._modalPrev = document.activeElement;
                            content.style.visibility = 'hidden'; content.style.display = ''; content.setAttribute('data-state', 'open');
                            requestAnimationFrame(() => { _mFloat(trigger, content, dSide, dSideOff, dAlign, _mPad); content.style.visibility = ''; });
                            function doMenuClose() { const btn = island.querySelector('[data-dropdown-menu-trigger-wrapper]'); if (btn) btn.click(); }
                            _mMenuOpen(island, content, doMenuClose, [tw]);
                            island._menuCleanup = _mActivate(content, { onClose: doMenuClose, menuClose: doMenuClose });
                            requestAnimationFrame(() => { const items = _mGetItems(content); if (items.length > 0) _mFocusItem(content, items[0]); });
                            island._menuScroll = () => _mFloat(trigger, content, dSide, dSideOff, dAlign, _mPad);
                            island._menuResize = island._menuScroll;
                            window.addEventListener('scroll', island._menuScroll, true); window.addEventListener('resize', island._menuResize);
                            if (!island._menuTrigKD) { island._menuTrigKD = (e) => { if (!island._menuOpen && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) { e.preventDefault(); tw.click(); } }; trigger.addEventListener('keydown', island._menuTrigKD); }
                        } else {
                            if (!island._menuOpen) return; island._menuOpen = false;
                            _mMenuClose(island, content);
                            const prev = island._modalPrev; if (prev && prev.focus) setTimeout(() => prev.focus({ preventScroll: true }), 0);
                        }
                        return;
                    }

                    // Mode 7: context_menu — right-click opens at pointer position
                    if (mode === 7) {
                        const tw = island.querySelector('[data-context-menu-trigger-wrapper]');
                        const trigEl = tw ? (tw.firstElementChild || tw) : null;
                        const content = island.querySelector('[data-context-menu-content]');
                        if (!trigEl || !content) return;

                        // Install contextmenu + long-press listeners (once)
                        if (!island._ctxInstalled) {
                            island._ctxInstalled = true;
                            island._ctxFromMenu = false;
                            trigEl.addEventListener('contextmenu', (e) => {
                                if (trigEl.hasAttribute('data-disabled')) return;
                                e.preventDefault(); island._ctxX = e.clientX; island._ctxY = e.clientY; island._ctxFromMenu = true;
                                if (island._menuOpen) { tw.click(); setTimeout(() => { island._ctxFromMenu = true; tw.click(); }, 10); }
                                else { tw.click(); }
                            });
                            // Block regular left-clicks from reaching Wasm handler
                            tw.addEventListener('click', (e) => { if (island._ctxFromMenu) { island._ctxFromMenu = false; } else { e.stopImmediatePropagation(); } }, { capture: true });
                            // Touch long-press (700ms)
                            let lpT = null;
                            trigEl.addEventListener('pointerdown', (e) => { if (e.pointerType === 'mouse') return; clearTimeout(lpT); lpT = setTimeout(() => { island._ctxX = e.clientX; island._ctxY = e.clientY; island._ctxFromMenu = true; if (!island._menuOpen) tw.click(); }, 700); });
                            trigEl.addEventListener('pointermove', (e) => { if (e.pointerType !== 'mouse') clearTimeout(lpT); });
                            trigEl.addEventListener('pointerup', (e) => { if (e.pointerType !== 'mouse') clearTimeout(lpT); });
                            trigEl.addEventListener('pointercancel', () => clearTimeout(lpT));
                            trigEl.style.webkitTouchCallout = 'none';
                        }

                        if (state) {
                            if (island._menuOpen) return;
                            island._menuOpen = true; island._modalPrev = document.activeElement;
                            content.style.visibility = 'hidden'; content.style.display = ''; content.setAttribute('data-state', 'open');
                            requestAnimationFrame(() => { _mFloatAt(content, island._ctxX || 0, island._ctxY || 0, _mPad); content.style.visibility = ''; });
                            function doCtxClose() { island._ctxFromMenu = true; tw.click(); }
                            _mMenuOpen(island, content, doCtxClose, [tw]);
                            island._menuCleanup = _mActivate(content, { onClose: doCtxClose, menuClose: doCtxClose });
                            requestAnimationFrame(() => { const items = _mGetItems(content); if (items.length > 0) _mFocusItem(content, items[0]); });
                        } else {
                            if (!island._menuOpen) return; island._menuOpen = false;
                            _mMenuClose(island, content);
                            const prev = island._modalPrev; if (prev && prev.focus) setTimeout(() => prev.focus({ preventScroll: true }), 0);
                        }
                        return;
                    }

                    // Mode 8: menubar — horizontal menu bar with multiple dropdown menus
                    if (mode === 8) {
                        const bar = island.querySelector('[data-menubar]') || island;
                        const loop = bar.getAttribute('data-loop') !== 'false';
                        const menuEls = Array.from(bar.querySelectorAll('[data-menubar-menu]'));
                        const trigMarkers = Array.from(bar.querySelectorAll('[data-menubar-trigger-marker]'));
                        function getTrigBtns() { return Array.from(bar.querySelectorAll('[data-menubar-trigger]')).filter(t => !t.hasAttribute('data-disabled')); }

                        // Install one-time behaviors
                        if (!island._mbInstalled) {
                            island._mbInstalled = true;
                            // Roving tabindex init
                            const btns = getTrigBtns();
                            btns.forEach((t, i) => t.setAttribute('tabindex', i === 0 ? '0' : '-1'));
                            // Per-trigger: hover-switch + keyboard nav
                            trigMarkers.forEach((marker, mi) => {
                                const btn = marker.querySelector('[data-menubar-trigger]') || marker.firstElementChild;
                                if (!btn) return;
                                // Hover-switch: if a menu is open and user hovers a different trigger, switch
                                btn.addEventListener('pointerenter', () => {
                                    if (island._menuOpen && island._mbActiveIdx !== mi + 1) { marker.click(); }
                                });
                                // Keyboard on trigger
                                btn.addEventListener('keydown', (e) => {
                                    const trigs = getTrigBtns(); const idx = trigs.indexOf(btn);
                                    if (e.key === 'ArrowDown') { e.preventDefault(); if (!island._menuOpen) marker.click(); }
                                    else if (e.key === 'ArrowRight') { e.preventDefault(); let n = idx + 1; if (loop) n = n % trigs.length; else n = Math.min(n, trigs.length - 1); trigs[n].setAttribute('tabindex', '0'); trigs[n].focus({ preventScroll: true }); if (idx !== n) btn.setAttribute('tabindex', '-1'); }
                                    else if (e.key === 'ArrowLeft') { e.preventDefault(); let n = idx - 1; if (loop) n = (n + trigs.length) % trigs.length; else n = Math.max(n, 0); trigs[n].setAttribute('tabindex', '0'); trigs[n].focus({ preventScroll: true }); if (idx !== n) btn.setAttribute('tabindex', '-1'); }
                                    else if (e.key === 'Home') { e.preventDefault(); trigs[0].setAttribute('tabindex', '0'); trigs[0].focus({ preventScroll: true }); if (idx !== 0) btn.setAttribute('tabindex', '-1'); }
                                    else if (e.key === 'End') { e.preventDefault(); trigs[trigs.length-1].setAttribute('tabindex', '0'); trigs[trigs.length-1].focus({ preventScroll: true }); if (idx !== trigs.length-1) btn.setAttribute('tabindex', '-1'); }
                                });
                            });
                        }

                        const menuIdx = state; // 0=close, 1+=open menu N
                        const prevIdx = island._mbActiveIdx || 0;

                        // Close previously active menu
                        if (prevIdx > 0 && prevIdx !== menuIdx) {
                            const pMenu = menuEls[prevIdx - 1]; if (pMenu) {
                                const pTrig = pMenu.querySelector('[data-menubar-trigger]');
                                const pCont = pMenu.querySelector('[data-menubar-content]');
                                if (island._menuCleanup) { island._menuCleanup(); island._menuCleanup = null; }
                                if (island._menuScroll) { window.removeEventListener('scroll', island._menuScroll, true); island._menuScroll = null; }
                                if (island._menuResize) { window.removeEventListener('resize', island._menuResize); island._menuResize = null; }
                                if (island._menuOutside) { document.removeEventListener('pointerdown', island._menuOutside); island._menuOutside = null; }
                                if (pCont) { pCont.querySelectorAll('[data-highlighted]').forEach(el => el.removeAttribute('data-highlighted')); pCont.setAttribute('data-state', 'closed'); const h = () => { if (pCont.getAttribute('data-state') === 'closed') { pCont.style.display = 'none'; pCont.style.position = ''; pCont.style.top = ''; pCont.style.left = ''; } }; pCont.addEventListener('animationend', h, { once: true }); setTimeout(h, 250); }
                                if (pTrig) { pTrig.setAttribute('data-state', 'closed'); pTrig.setAttribute('aria-expanded', 'false'); }
                                if (island._menuOpen) { if (--_scrollLockCount <= 0) { _scrollLockCount = 0; document.body.style.overflow = ''; } if (window._therapyFocusGuards) { window._therapyFocusGuards.forEach(g => g.remove()); window._therapyFocusGuards = null; } document.body.style.pointerEvents = island._modalPE || ''; }
                            }
                        }

                        island._mbActiveIdx = menuIdx;

                        if (menuIdx > 0) {
                            // OPEN menu at index
                            island._menuOpen = true; island._modalPrev = document.activeElement;
                            const mEl = menuEls[menuIdx - 1]; if (!mEl) return;
                            const trig = mEl.querySelector('[data-menubar-trigger]');
                            const cont = mEl.querySelector('[data-menubar-content]');
                            if (!trig || !cont) return;
                            const cSide = cont.getAttribute('data-side-preference') || 'bottom';
                            const cOff = parseInt(cont.getAttribute('data-side-offset') || '4', 10);
                            const cAlign = cont.getAttribute('data-align-preference') || 'start';
                            trig.setAttribute('data-state', 'open'); trig.setAttribute('aria-expanded', 'true');
                            cont.style.visibility = 'hidden'; cont.style.display = ''; cont.setAttribute('data-state', 'open');
                            requestAnimationFrame(() => { _mFloat(trig, cont, cSide, cOff, cAlign, _mPad); cont.style.visibility = ''; });
                            // Roving tabindex: focus this trigger
                            const btns = getTrigBtns(); btns.forEach(b => b.setAttribute('tabindex', '-1')); trig.setAttribute('tabindex', '0');
                            // Scroll lock + focus guards
                            if (prevIdx === 0) {
                                if (++_scrollLockCount === 1) document.body.style.overflow = 'hidden';
                                if (!window._therapyFocusGuards) { const g = () => { const s = document.createElement('span'); s.tabIndex = 0; s.setAttribute('data-focus-guard',''); s.style.cssText = 'position:fixed;opacity:0;pointer-events:none'; return s; }; window._therapyFocusGuards = [g(), g()]; document.body.prepend(window._therapyFocusGuards[0]); document.body.append(window._therapyFocusGuards[1]); }
                                island._modalPE = document.body.style.pointerEvents; document.body.style.pointerEvents = 'none';
                            }
                            cont.style.pointerEvents = 'auto';
                            // Navigate between menus from within content (ArrowLeft/Right)
                            function navMenubar(dir) {
                                const ts = getTrigBtns(); const ci = ts.indexOf(trig); let ni = ci + dir;
                                if (loop) ni = (ni + ts.length) % ts.length; else ni = Math.max(0, Math.min(ts.length - 1, ni));
                                const nextBtn = ts[ni]; if (!nextBtn || ni === ci) return;
                                const nextMarker = nextBtn.closest('[data-menubar-trigger-marker]');
                                if (nextMarker) { ts.forEach(b => b.setAttribute('tabindex', '-1')); nextBtn.setAttribute('tabindex', '0'); nextBtn.focus({ preventScroll: true }); nextMarker.click(); }
                            }
                            island._menuCleanup = _mActivate(cont, { onClose: () => { const mk = trig.closest('[data-menubar-trigger-marker]'); if (mk) mk.click(); }, menuClose: () => { const mk = trig.closest('[data-menubar-trigger-marker]'); if (mk) mk.click(); }, onNavigateLeft: () => navMenubar(-1), onNavigateRight: () => navMenubar(1) });
                            requestAnimationFrame(() => { const items = _mGetItems(cont); if (items.length > 0) _mFocusItem(cont, items[0]); });
                            island._menuScroll = () => _mFloat(trig, cont, cSide, cOff, cAlign, _mPad); island._menuResize = island._menuScroll;
                            window.addEventListener('scroll', island._menuScroll, true); window.addEventListener('resize', island._menuResize);
                            // Click-outside dismiss (exclude all trigger markers)
                            island._menuOutside = (e) => { if (!cont.contains(e.target) && !trigMarkers.some(m => m.contains(e.target))) { const mk = trig.closest('[data-menubar-trigger-marker]'); if (mk) mk.click(); } };
                            setTimeout(() => document.addEventListener('pointerdown', island._menuOutside), 0);
                        } else {
                            // CLOSE all
                            island._menuOpen = false;
                            if (island._menuCleanup) { island._menuCleanup(); island._menuCleanup = null; }
                            if (island._menuScroll) { window.removeEventListener('scroll', island._menuScroll, true); island._menuScroll = null; }
                            if (island._menuResize) { window.removeEventListener('resize', island._menuResize); island._menuResize = null; }
                            if (island._menuOutside) { document.removeEventListener('pointerdown', island._menuOutside); island._menuOutside = null; }
                            if (prevIdx > 0) {
                                if (--_scrollLockCount <= 0) { _scrollLockCount = 0; document.body.style.overflow = ''; }
                                if (window._therapyFocusGuards) { window._therapyFocusGuards.forEach(g => g.remove()); window._therapyFocusGuards = null; }
                                document.body.style.pointerEvents = island._modalPE || '';
                            }
                            const prev = island._modalPrev; if (prev && prev.focus) setTimeout(() => prev.focus({ preventScroll: true }), 0);
                        }
                        return;
                    }

                    // Mode 9: nav_menu — hover-triggered content panels with timers + motion
                    if (mode === 9) {
                        const navRoot = island.querySelector('[data-nav-menu]') || island;
                        const markers = Array.from(navRoot.querySelectorAll('[data-nav-menu-trigger-marker]'));
                        const indicator = navRoot.querySelector('[data-nav-menu-indicator]');
                        const delayDuration = parseInt(navRoot.getAttribute('data-delay-duration') || '200', 10);
                        const skipDelayDuration = parseInt(navRoot.getAttribute('data-skip-delay-duration') || '300', 10);

                        // One-time install: hover handlers, keyboard, Escape, click-outside
                        if (!island._navInstalled) {
                            island._navInstalled = true;
                            island._navOpenTimer = null;
                            island._navCloseTimer = null;
                            island._navSkipTimer = null;
                            island._navIsSkip = false;
                            island._navWasEscape = false;
                            island._navActiveIdx = 0;

                            markers.forEach((marker, mi) => {
                                const trigger = marker.querySelector('[data-nav-menu-trigger]') || marker.firstElementChild;
                                const item = marker.closest('[data-nav-menu-item]');
                                const content = item ? item.querySelector('[data-nav-menu-content]') : null;
                                const idx = mi + 1;
                                if (!trigger) return;

                                // Hover on trigger — delayed open
                                trigger.addEventListener('pointerenter', (e) => {
                                    if (e.pointerType === 'touch') return;
                                    if (island._navWasEscape) { island._navWasEscape = false; return; }
                                    clearTimeout(island._navCloseTimer);
                                    if (island._navIsSkip || island._navActiveIdx > 0) {
                                        if (island._navActiveIdx !== idx) marker.click();
                                    } else {
                                        island._navOpenTimer = setTimeout(() => {
                                            if (island._navActiveIdx !== idx) marker.click();
                                        }, delayDuration);
                                    }
                                });
                                trigger.addEventListener('pointerleave', (e) => {
                                    if (e.pointerType === 'touch') return;
                                    clearTimeout(island._navOpenTimer);
                                    island._navCloseTimer = setTimeout(() => {
                                        if (island._navActiveIdx === idx) marker.click();
                                    }, 150);
                                });

                                // Content hover — keep open / start close
                                if (content) {
                                    content.addEventListener('pointerenter', (e) => {
                                        if (e.pointerType === 'touch') return;
                                        clearTimeout(island._navCloseTimer);
                                    });
                                    content.addEventListener('pointerleave', (e) => {
                                        if (e.pointerType === 'touch') return;
                                        island._navCloseTimer = setTimeout(() => {
                                            if (island._navActiveIdx > 0) {
                                                const mk = markers[island._navActiveIdx - 1];
                                                if (mk) mk.click();
                                            }
                                        }, 150);
                                    });
                                }

                                // Keyboard on trigger: ArrowDown/Enter/Space opens + focuses first link
                                trigger.addEventListener('keydown', (e) => {
                                    if (e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') {
                                        e.preventDefault();
                                        if (island._navActiveIdx !== idx) marker.click();
                                        if (content) {
                                            requestAnimationFrame(() => {
                                                const first = content.querySelector('a, button, [tabindex="0"]');
                                                if (first) first.focus({ preventScroll: true });
                                            });
                                        }
                                    }
                                });
                            });

                            // Escape to close + return focus
                            navRoot.addEventListener('keydown', (e) => {
                                if (e.key === 'Escape' && island._navActiveIdx > 0) {
                                    e.preventDefault(); e.stopPropagation();
                                    island._navWasEscape = true;
                                    const ai = island._navActiveIdx;
                                    const mk = markers[ai - 1];
                                    if (mk) {
                                        const trig = mk.querySelector('[data-nav-menu-trigger]') || mk.firstElementChild;
                                        mk.click();
                                        if (trig) trig.focus({ preventScroll: true });
                                    }
                                }
                            });

                            // Click outside to close
                            document.addEventListener('pointerdown', (e) => {
                                if (island._navActiveIdx > 0 && !navRoot.contains(e.target)) {
                                    const mk = markers[island._navActiveIdx - 1];
                                    if (mk) mk.click();
                                }
                            });
                        }

                        // Handle signal change
                        const navIdx = state;
                        const navPrev = island._navActiveIdx || 0;
                        island._navActiveIdx = navIdx;
                        const allItems = Array.from(navRoot.querySelectorAll('[data-nav-menu-item]'));

                        function _navParts(i) {
                            if (i <= 0 || i > markers.length) return null;
                            const mk = markers[i - 1];
                            const it = mk.closest('[data-nav-menu-item]');
                            const tr = mk.querySelector('[data-nav-menu-trigger]') || mk.firstElementChild;
                            const ct = it ? it.querySelector('[data-nav-menu-content]') : null;
                            return { mk, it, tr, ct };
                        }

                        if (navIdx > 0) {
                            const cur = _navParts(navIdx);
                            if (!cur) return;

                            // Close previous item (if switching)
                            if (navPrev > 0 && navPrev !== navIdx) {
                                const prev = _navParts(navPrev);
                                if (prev) {
                                    if (prev.tr) { prev.tr.setAttribute('data-state', 'closed'); prev.tr.setAttribute('aria-expanded', 'false'); }
                                    if (prev.ct) {
                                        const pii = prev.it ? allItems.indexOf(prev.it) : -1;
                                        const cii = cur.it ? allItems.indexOf(cur.it) : -1;
                                        prev.ct.setAttribute('data-motion', cii > pii ? 'to-start' : 'to-end');
                                        prev.ct.setAttribute('data-state', 'closed');
                                        const h = prev.ct;
                                        const hide = () => { if (h.getAttribute('data-state') === 'closed') h.style.display = 'none'; };
                                        h.addEventListener('animationend', hide, { once: true }); setTimeout(hide, 300);
                                    }
                                }
                            }

                            // Open current item
                            if (cur.tr) { cur.tr.setAttribute('data-state', 'open'); cur.tr.setAttribute('aria-expanded', 'true'); }
                            if (cur.ct) {
                                cur.ct.style.display = '';
                                cur.ct.setAttribute('data-state', 'open');
                                if (navPrev > 0) {
                                    const prev = _navParts(navPrev);
                                    const pii = prev && prev.it ? allItems.indexOf(prev.it) : -1;
                                    const cii = cur.it ? allItems.indexOf(cur.it) : -1;
                                    cur.ct.setAttribute('data-motion', cii > pii ? 'from-end' : 'from-start');
                                } else {
                                    cur.ct.removeAttribute('data-motion');
                                }
                            }

                            // Update indicator
                            if (indicator && cur.tr) {
                                indicator.setAttribute('data-state', 'visible');
                                indicator.style.display = '';
                                const list = navRoot.querySelector('[data-nav-menu-list]');
                                if (list) {
                                    const lr = list.getBoundingClientRect();
                                    const tr = cur.tr.getBoundingClientRect();
                                    indicator.style.position = 'absolute';
                                    indicator.style.left = (tr.left - lr.left) + 'px';
                                    indicator.style.width = tr.width + 'px';
                                    indicator.style.transition = 'left 0.2s ease, width 0.2s ease';
                                }
                            }
                        } else if (navPrev > 0) {
                            // CLOSE all
                            markers.forEach((mk) => {
                                const it = mk.closest('[data-nav-menu-item]');
                                const tr = mk.querySelector('[data-nav-menu-trigger]') || mk.firstElementChild;
                                const ct = it ? it.querySelector('[data-nav-menu-content]') : null;
                                if (tr) { tr.setAttribute('data-state', 'closed'); tr.setAttribute('aria-expanded', 'false'); }
                                if (ct) {
                                    ct.setAttribute('data-state', 'closed');
                                    const h = ct;
                                    const hide = () => { if (h.getAttribute('data-state') === 'closed') h.style.display = 'none'; };
                                    h.addEventListener('animationend', hide, { once: true }); setTimeout(hide, 300);
                                }
                            });

                            // Hide indicator
                            if (indicator) {
                                indicator.setAttribute('data-state', 'hidden');
                                setTimeout(() => { if (indicator.getAttribute('data-state') === 'hidden') indicator.style.display = 'none'; }, 200);
                            }

                            // Start skip delay timer
                            clearTimeout(island._navSkipTimer);
                            island._navIsSkip = true;
                            island._navSkipTimer = setTimeout(() => { island._navIsSkip = false; }, skipDelayDuration);
                        }
                        return;
                    }

                    // Mode 10: select — custom floating select dropdown
                    if (mode === 10) {
                        const tw = island.querySelector('[data-select-trigger-wrapper]');
                        const trigger = tw ? (tw.firstElementChild || tw) : null;
                        const content = island.querySelector('[data-select-content]');
                        if (!trigger || !content) return;
                        const selRoot = island.firstElementChild || island;
                        if (!island._selInstalled) {
                            island._selInstalled = true;
                            island._selHL = null; island._selTS = ''; island._selTT = null;
                            island._selVal = selRoot.getAttribute('data-select-value') || '';
                            function selGetItems() { return Array.from(content.querySelectorAll('[data-select-item]:not([data-disabled])')); }
                            function selHL(item) {
                                if (island._selHL) island._selHL.removeAttribute('data-highlighted');
                                island._selHL = item;
                                if (item) { item.setAttribute('data-highlighted', ''); item.focus(); }
                            }
                            function selUpdateDisplay() {
                                const disp = trigger.querySelector('[data-select-display]');
                                if (!disp) return;
                                content.querySelectorAll('[data-select-item]').forEach(item => {
                                    const v = item.getAttribute('data-select-item-value') || '';
                                    if (v === island._selVal && island._selVal !== '') {
                                        const txt = item.querySelector('[data-select-item-text-content]');
                                        disp.textContent = txt ? txt.textContent : item.textContent.trim();
                                        disp.removeAttribute('data-placeholder');
                                        item.setAttribute('data-state', 'checked'); item.setAttribute('aria-selected', 'true');
                                        const ind = item.querySelector('[data-select-item-indicator]'); if (ind) ind.style.display = '';
                                    } else {
                                        item.setAttribute('data-state', 'unchecked'); item.setAttribute('aria-selected', 'false');
                                        const ind = item.querySelector('[data-select-item-indicator]'); if (ind) ind.style.display = 'none';
                                    }
                                });
                            }
                            function selSelect(item) {
                                if (!item) return;
                                island._selVal = item.getAttribute('data-select-item-value') || '';
                                selRoot.setAttribute('data-select-value', island._selVal);
                                selUpdateDisplay(); tw.click();
                            }
                            function selTypeahead(key) {
                                clearTimeout(island._selTT); island._selTS += key.toLowerCase();
                                const allSame = island._selTS.split('').every(c => c === island._selTS[0]);
                                const search = allSame ? island._selTS[0] : island._selTS;
                                const items = selGetItems(); const ci = island._selHL ? items.indexOf(island._selHL) : -1;
                                const si = search.length === 1 ? ci + 1 : 0;
                                for (let i = 0; i < items.length; i++) {
                                    const idx = (si + i) % items.length;
                                    const txt = items[idx].querySelector('[data-select-item-text-content]');
                                    const t = (txt ? txt.textContent : items[idx].textContent).trim().toLowerCase();
                                    if (t.startsWith(search)) { selHL(items[idx]); break; }
                                }
                                island._selTT = setTimeout(() => { island._selTS = ''; }, 1000);
                            }
                            trigger.addEventListener('pointerdown', (e) => { if (e.button !== 0 || (e.ctrlKey && /Mac/.test(navigator.platform))) return; e.preventDefault(); });
                            trigger.addEventListener('keydown', (e) => {
                                if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
                                    if (island._selTS.length > 0 && e.key === ' ') { e.preventDefault(); selTypeahead(' '); return; }
                                    selTypeahead(e.key); return;
                                }
                                if (['ArrowDown','ArrowUp','Enter',' '].includes(e.key)) { e.preventDefault(); if (!island._selOpen) tw.click(); }
                            });
                            content.addEventListener('keydown', (e) => {
                                if (e.key === 'Tab') { e.preventDefault(); return; }
                                const items = selGetItems(); const ci = island._selHL ? items.indexOf(island._selHL) : -1;
                                if (e.key === 'ArrowDown') { e.preventDefault(); selHL(items[ci + 1 < items.length ? ci + 1 : 0]); }
                                else if (e.key === 'ArrowUp') { e.preventDefault(); selHL(items[ci - 1 >= 0 ? ci - 1 : items.length - 1]); }
                                else if (e.key === 'Home') { e.preventDefault(); selHL(items[0]); }
                                else if (e.key === 'End') { e.preventDefault(); selHL(items[items.length - 1]); }
                                else if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); if (island._selHL) selSelect(island._selHL); }
                                else if (e.key === 'Escape') { e.preventDefault(); tw.click(); }
                                else if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
                                    if (island._selTS.length > 0 && e.key === ' ') { e.preventDefault(); selTypeahead(' '); return; }
                                    selTypeahead(e.key);
                                }
                            });
                            content.addEventListener('pointerup', (e) => { const item = e.target.closest('[data-select-item]:not([data-disabled])'); if (item && content.contains(item)) selSelect(item); });
                            content.addEventListener('pointermove', (e) => { const item = e.target.closest('[data-select-item]:not([data-disabled])'); if (item && content.contains(item)) selHL(item); });
                            const su = content.querySelector('[data-select-scroll-up]'), sd = content.querySelector('[data-select-scroll-down]');
                            let sInt = null;
                            if (su) { su.addEventListener('pointerdown', () => { sInt = setInterval(() => { content.scrollTop -= 32; }, 50); }); su.addEventListener('pointerup', () => clearInterval(sInt)); su.addEventListener('pointerleave', () => clearInterval(sInt)); }
                            if (sd) { sd.addEventListener('pointerdown', () => { sInt = setInterval(() => { content.scrollTop += 32; }, 50); }); sd.addEventListener('pointerup', () => clearInterval(sInt)); sd.addEventListener('pointerleave', () => clearInterval(sInt)); }
                            selUpdateDisplay();
                        }
                        if (state) {
                            if (island._selOpen) return;
                            if (selRoot.hasAttribute('data-disabled')) return;
                            island._selOpen = true; island._modalPrev = document.activeElement;
                            const dSide = content.getAttribute('data-select-side') || 'bottom';
                            const dOff = parseInt(content.getAttribute('data-select-side-offset') || '4', 10);
                            const dAlign = content.getAttribute('data-select-align') || 'start';
                            trigger.setAttribute('data-state', 'open'); trigger.setAttribute('aria-expanded', 'true');
                            content.style.visibility = 'hidden'; content.style.display = ''; content.setAttribute('data-state', 'open');
                            requestAnimationFrame(() => {
                                _mFloat(trigger, content, dSide, dOff, dAlign, _mPad); content.style.visibility = '';
                                const items = Array.from(content.querySelectorAll('[data-select-item]:not([data-disabled])'));
                                const sel = items.find(i => i.getAttribute('data-state') === 'checked');
                                if (sel) { sel.setAttribute('data-highlighted', ''); sel.focus(); island._selHL = sel; }
                                else if (items[0]) { items[0].setAttribute('data-highlighted', ''); items[0].focus(); island._selHL = items[0]; }
                            });
                            _mMenuOpen(island, content, () => tw.click(), [tw]);
                            island._selScroll = () => _mFloat(trigger, content, dSide, dOff, dAlign, _mPad);
                            island._selResize = island._selScroll;
                            window.addEventListener('scroll', island._selScroll, true); window.addEventListener('resize', island._selResize);
                        } else {
                            if (!island._selOpen) return; island._selOpen = false;
                            trigger.setAttribute('data-state', 'closed'); trigger.setAttribute('aria-expanded', 'false');
                            content.setAttribute('data-state', 'closed');
                            if (island._selHL) { island._selHL.removeAttribute('data-highlighted'); island._selHL = null; }
                            if (island._selScroll) { window.removeEventListener('scroll', island._selScroll, true); island._selScroll = null; }
                            if (island._selResize) { window.removeEventListener('resize', island._selResize); island._selResize = null; }
                            _mMenuClose(island, content);
                            const prev = island._modalPrev; if (prev && prev.focus) setTimeout(() => prev.focus({ preventScroll: true }), 0);
                        }
                        return;
                    }

                    // Mode 11: command — always-active command palette with filtering and keyboard nav
                    if (mode === 11) {
                        if (state && !island._cmdInstalled) {
                            island._cmdInstalled = true;
                            const cmdRoot = island.firstElementChild || island;
                            const shouldFilter = cmdRoot.getAttribute('data-command-filter') !== 'false';
                            const loop = cmdRoot.getAttribute('data-command-loop') !== 'false';
                            const input = island.querySelector('[data-command-input]');
                            const emptyEl = island.querySelector('[data-command-empty]');
                            let selItem = null;
                            function cmdScore(str, abbr) {
                                if (!abbr || !str) return 0; if (abbr.length > str.length) return 0; if (abbr === str) return 1;
                                const ls = str.toLowerCase(), la = abbr.toLowerCase(), memo = {};
                                function inner(si, ai) {
                                    if (ai === abbr.length) return si === str.length ? 1 : 0.99;
                                    const key = si + ',' + ai; if (memo[key] !== undefined) return memo[key];
                                    let hi = 0;
                                    for (let i = si; i < str.length; i++) {
                                        if (ls[i] !== la[ai]) continue; let sc = inner(i + 1, ai + 1); if (sc <= 0) continue;
                                        if (i === si) sc *= 1; else if (i > 0) { const p = str[i-1]; if (p === ' ' || p === '-') sc *= 0.9; else if ('\\/_+.#"@[({&'.includes(p)) sc *= 0.8; else sc *= 0.17; }
                                        if (str[i] !== abbr[ai]) sc *= 0.9999; if (sc > hi) hi = sc;
                                    }
                                    memo[key] = hi; return hi;
                                }
                                return inner(0, 0);
                            }
                            function cmdGetItems() { return Array.from(island.querySelectorAll('[data-command-item]:not([data-disabled="true"])')); }
                            function cmdGetVisible() { return cmdGetItems().filter(i => i.style.display !== 'none'); }
                            function cmdHL(item) {
                                if (selItem) { selItem.setAttribute('data-selected', 'false'); selItem.setAttribute('aria-selected', 'false'); }
                                selItem = item;
                                if (item) { item.setAttribute('data-selected', 'true'); item.setAttribute('aria-selected', 'true'); item.scrollIntoView({ block: 'nearest' }); }
                            }
                            function cmdFilter(search) {
                                if (!shouldFilter || !search) {
                                    island.querySelectorAll('[data-command-item]').forEach(i => { i.style.display = ''; });
                                    island.querySelectorAll('[data-command-group]').forEach(g => { g.style.display = ''; });
                                    if (emptyEl) emptyEl.style.display = 'none';
                                    cmdHL(cmdGetVisible()[0] || null); return;
                                }
                                island.querySelectorAll('[data-command-item]').forEach(item => {
                                    const v = item.getAttribute('data-command-item-value') || item.textContent.trim();
                                    const kw = item.getAttribute('data-command-item-keywords') || '';
                                    const st = kw ? v + ' ' + kw.replace(/,/g, ' ') : v;
                                    item.style.display = cmdScore(st, search) > 0 ? '' : 'none';
                                });
                                island.querySelectorAll('[data-command-group]').forEach(g => {
                                    g.style.display = g.querySelector('[data-command-item]:not([style*="display: none"])') ? '' : 'none';
                                });
                                const vis = cmdGetVisible();
                                if (emptyEl) emptyEl.style.display = vis.length === 0 ? '' : 'none';
                                cmdHL(vis[0] || null);
                            }
                            if (input) input.addEventListener('input', (e) => { cmdFilter(e.target.value); });
                            island.addEventListener('keydown', (e) => {
                                if (e.isComposing) return;
                                const items = cmdGetVisible(); const ci = selItem ? items.indexOf(selItem) : -1;
                                if (e.key === 'ArrowDown' || (e.ctrlKey && (e.key === 'n' || e.key === 'j'))) {
                                    e.preventDefault(); let n = ci + 1; if (n >= items.length) n = loop ? 0 : items.length - 1; cmdHL(items[n]);
                                } else if (e.key === 'ArrowUp' || (e.ctrlKey && (e.key === 'p' || e.key === 'k'))) {
                                    e.preventDefault(); let p = ci - 1; if (p < 0) p = loop ? items.length - 1 : 0; cmdHL(items[p]);
                                } else if (e.key === 'Home') { e.preventDefault(); cmdHL(items[0]); }
                                else if (e.key === 'End') { e.preventDefault(); cmdHL(items[items.length - 1]); }
                                else if (e.key === 'Enter') { e.preventDefault(); if (selItem) selItem.click(); }
                            });
                            island.addEventListener('click', (e) => { const item = e.target.closest('[data-command-item]:not([data-disabled="true"])'); if (item && island.contains(item)) cmdHL(item); });
                            island.addEventListener('pointermove', (e) => { const item = e.target.closest('[data-command-item]:not([data-disabled="true"])'); if (item && island.contains(item)) cmdHL(item); });
                            cmdFilter('');
                        }
                        return;
                    }

                    // Mode 12: command_dialog — dialog wrapper for command palette
                    if (mode === 12) {
                        const dlg = island.querySelector('[data-command-dialog]') || island;
                        const overlay = dlg.querySelector('[data-command-dialog-overlay]');
                        const marker = island.querySelector('[data-command-dialog-trigger-marker]');
                        if (!island._cmdDlgInstalled) {
                            island._cmdDlgInstalled = true;
                            if (marker) {
                                island._suiteOpen = () => { if (!island._cmdDlgOpen) marker.click(); };
                                island._suiteClose = () => { if (island._cmdDlgOpen) marker.click(); };
                            }
                        }
                        if (state) {
                            if (island._cmdDlgOpen) return; island._cmdDlgOpen = true;
                            island._modalPrev = document.activeElement;
                            dlg.style.display = ''; dlg.setAttribute('data-state', 'open');
                            if (++_scrollLockCount === 1) document.body.style.overflow = 'hidden';
                            if (!window._therapyFocusGuards) { const g = () => { const s = document.createElement('span'); s.tabIndex = 0; s.setAttribute('data-focus-guard',''); s.style.cssText = 'position:fixed;opacity:0;pointer-events:none'; return s; }; window._therapyFocusGuards = [g(), g()]; document.body.prepend(window._therapyFocusGuards[0]); document.body.append(window._therapyFocusGuards[1]); }
                            const cmdInput = dlg.querySelector('[data-command-input]');
                            if (cmdInput) requestAnimationFrame(() => cmdInput.focus());
                            island._cmdDlgEsc = (e) => { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); marker.click(); } };
                            dlg.addEventListener('keydown', island._cmdDlgEsc);
                            if (overlay) { island._cmdDlgOvr = (e) => { if (e.target === overlay) marker.click(); }; overlay.addEventListener('pointerdown', island._cmdDlgOvr); }
                        } else {
                            if (!island._cmdDlgOpen) return; island._cmdDlgOpen = false;
                            dlg.setAttribute('data-state', 'closed');
                            if (--_scrollLockCount <= 0) { _scrollLockCount = 0; document.body.style.overflow = ''; }
                            if (window._therapyFocusGuards) { window._therapyFocusGuards.forEach(g => g.remove()); window._therapyFocusGuards = null; }
                            if (island._cmdDlgEsc) { dlg.removeEventListener('keydown', island._cmdDlgEsc); island._cmdDlgEsc = null; }
                            if (island._cmdDlgOvr && overlay) { overlay.removeEventListener('pointerdown', island._cmdDlgOvr); island._cmdDlgOvr = null; }
                            setTimeout(() => { if (dlg.getAttribute('data-state') === 'closed') dlg.style.display = 'none'; }, 200);
                            const prev = island._modalPrev; if (prev && prev.focus) setTimeout(() => prev.focus({ preventScroll: true }), 0);
                        }
                        return;
                    }

                    // Mode 13: slider — drag + keyboard range input (fire-and-forget init, signal=1)
                    if (mode === 13) {
                        if (island._sliderInit) return;
                        island._sliderInit = true;
                        const sr = island.firstElementChild;
                        if (!sr) return;
                        const thumb = sr.querySelector('[data-slider-thumb]');
                        const track = sr.querySelector('[data-slider-track]');
                        const range = sr.querySelector('[data-slider-range]');
                        if (!thumb || !track || !range) return;
                        const isV = sr.getAttribute('data-orientation') === 'vertical';
                        const sMin = parseFloat(sr.getAttribute('data-min') || '0');
                        const sMax = parseFloat(sr.getAttribute('data-max') || '100');
                        const sStep = parseFloat(sr.getAttribute('data-step') || '1');
                        const isDis = () => sr.hasAttribute('data-disabled');
                        const snap = (v) => {
                            const st = Math.round((v - sMin) / sStep) * sStep + sMin;
                            const d = (sStep.toString().split('.')[1] || '').length;
                            return parseFloat(Math.min(sMax, Math.max(sMin, st)).toFixed(d));
                        };
                        const upd = (v) => {
                            const p = sMax > sMin ? ((v - sMin) / (sMax - sMin)) * 100 : 0;
                            sr.setAttribute('data-value', String(v));
                            thumb.setAttribute('aria-valuenow', String(v));
                            if (isV) {
                                range.style.height = p + '%'; range.style.bottom = '0';
                                thumb.style.bottom = p + '%'; thumb.style.left = '50%';
                                thumb.style.transform = 'translate(-50%, 50%)';
                                thumb.style.position = 'absolute'; thumb.style.top = '';
                            } else {
                                range.style.width = p + '%'; range.style.left = '0';
                                thumb.style.left = p + '%'; thumb.style.top = '50%';
                                thumb.style.transform = 'translate(-50%, -50%)';
                                thumb.style.position = 'absolute'; thumb.style.bottom = '';
                            }
                        };
                        const setV = (nv) => {
                            const s = snap(nv);
                            if (s === parseFloat(sr.getAttribute('data-value') || '0')) return;
                            upd(s);
                            sr.dispatchEvent(new CustomEvent('suite:slider:change', { detail: { value: s }, bubbles: true }));
                        };
                        const fromPtr = (e) => {
                            const r = track.getBoundingClientRect();
                            let p = isV ? 1 - ((e.clientY - r.top) / r.height) : (e.clientX - r.left) / r.width;
                            return sMin + Math.min(1, Math.max(0, p)) * (sMax - sMin);
                        };
                        let drag = false;
                        sr.addEventListener('pointerdown', (e) => {
                            if (isDis()) return; e.preventDefault(); drag = true;
                            sr.setPointerCapture(e.pointerId); setV(fromPtr(e)); thumb.focus();
                        });
                        sr.addEventListener('pointermove', (e) => { if (drag && sr.hasPointerCapture(e.pointerId)) setV(fromPtr(e)); });
                        sr.addEventListener('pointerup', (e) => { if (drag) { drag = false; sr.releasePointerCapture(e.pointerId); } });
                        thumb.addEventListener('keydown', (e) => {
                            if (isDis()) return;
                            const c = parseFloat(sr.getAttribute('data-value') || '0');
                            let n = c; const b = sStep * 10;
                            switch (e.key) {
                                case 'ArrowRight': case 'ArrowUp': n = c + (e.shiftKey ? b : sStep); break;
                                case 'ArrowLeft': case 'ArrowDown': n = c - (e.shiftKey ? b : sStep); break;
                                case 'PageUp': n = c + b; break; case 'PageDown': n = c - b; break;
                                case 'Home': n = sMin; break; case 'End': n = sMax; break;
                                default: return;
                            }
                            e.preventDefault(); setV(n);
                        });
                        return;
                    }

                    // Mode 14: calendar — month grid, day selection, keyboard nav (fire-and-forget init, signal=1)
                    if (mode === 14) {
                        if (island._calInit) return;
                        island._calInit = true;
                        const cr = island.firstElementChild;
                        if (!cr) return;
                        const cid = cr.getAttribute('data-calendar');
                        const cMode = cr.getAttribute('data-calendar-mode') || 'single';
                        const cS = {
                            month: parseInt(cr.getAttribute('data-calendar-month')) || (new Date().getMonth() + 1),
                            year: parseInt(cr.getAttribute('data-calendar-year')) || new Date().getFullYear(),
                            selected: (cr.getAttribute('data-calendar-selected') || '').split(',').map(s => s.trim()).filter(s => s),
                            disabled: (cr.getAttribute('data-calendar-disabled') || '').split(',').map(s => s.trim()).filter(s => s),
                            mode: cMode,
                            showOutside: cr.getAttribute('data-calendar-show-outside') !== 'false',
                            fixedWeeks: cr.getAttribute('data-calendar-fixed-weeks') === 'true',
                            monthsCount: parseInt(cr.getAttribute('data-calendar-months-count')) || 1,
                            focusedDate: null
                        };
                        const MN = ['January','February','March','April','May','June','July','August','September','October','November','December'];
                        const DA = ['Mo','Tu','We','Th','Fr','Sa','Su'];
                        const DN = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];

                        function calWeeks(y, m) {
                            const fd = new Date(y, m - 1, 1), ld = new Date(y, m, 0);
                            const td = new Date(); td.setHours(0, 0, 0, 0);
                            let sd = fd.getDay(); sd = sd === 0 ? 6 : sd - 1;
                            const gs = new Date(fd); gs.setDate(gs.getDate() - sd);
                            let ed = ld.getDay(); ed = ed === 0 ? 6 : ed - 1;
                            const ge = new Date(ld); ge.setDate(ge.getDate() + (6 - ed));
                            const weeks = []; let cur = new Date(gs);
                            while (cur <= ge) {
                                const week = [];
                                for (let d = 0; d < 7; d++) {
                                    const iso = cur.getFullYear() + '-' + String(cur.getMonth() + 1).padStart(2, '0') + '-' + String(cur.getDate()).padStart(2, '0');
                                    const dow = cur.getDay(); const dowIdx = dow === 0 ? 6 : dow - 1;
                                    week.push({ dayNum: cur.getDate(), outside: cur.getMonth() !== m - 1, isToday: cur.getTime() === td.getTime(), isoDate: iso, label: DN[dowIdx] + ', ' + MN[cur.getMonth()] + ' ' + cur.getDate() + ', ' + cur.getFullYear() });
                                    cur.setDate(cur.getDate() + 1);
                                }
                                weeks.push(week);
                            }
                            while (cS.fixedWeeks && weeks.length < 6) {
                                const week = [];
                                for (let d = 0; d < 7; d++) {
                                    const iso = cur.getFullYear() + '-' + String(cur.getMonth() + 1).padStart(2, '0') + '-' + String(cur.getDate()).padStart(2, '0');
                                    const dow = cur.getDay(); const dowIdx = dow === 0 ? 6 : dow - 1;
                                    week.push({ dayNum: cur.getDate(), outside: true, isToday: false, isoDate: iso, label: DN[dowIdx] + ', ' + MN[cur.getMonth()] + ' ' + cur.getDate() + ', ' + cur.getFullYear() });
                                    cur.setDate(cur.getDate() + 1);
                                }
                                weeks.push(week);
                            }
                            return weeks;
                        }

                        function calBuild(y, m) {
                            const ml = MN[m - 1] + ' ' + y;
                            const weeks = calWeeks(y, m);
                            const ms = (cS.mode === 'multiple' || cS.mode === 'range') ? ' aria-multiselectable="true"' : '';
                            let h = '<div class="flex items-center justify-center h-7 relative"><span class="text-sm font-medium select-none" role="status" aria-live="polite" data-calendar-caption="' + cid + '">' + ml + '</span></div>';
                            h += '<table role="grid" aria-label="' + ml + '" class="w-full border-collapse" data-calendar-grid="' + cid + '" data-calendar-grid-month="' + m + '" data-calendar-grid-year="' + y + '"' + ms + '>';
                            h += '<thead aria-hidden="true"><tr class="flex">';
                            for (let i = 0; i < 7; i++) h += '<th scope="col" class="text-warm-600 dark:text-warm-500 rounded-md flex-1 font-normal text-xs select-none w-9 text-center" aria-label="' + DN[i] + '">' + DA[i] + '</th>';
                            h += '</tr></thead><tbody class="suite-calendar-weeks">';
                            for (const wk of weeks) {
                                h += '<tr class="flex w-full mt-2">';
                                for (const d of wk) {
                                    if (d.outside && !cS.showOutside) { h += '<td class="relative w-9 h-9 p-0 text-center" role="gridcell"></td>'; }
                                    else {
                                        const oa = d.outside ? ' data-outside="true"' : '';
                                        const ta = d.isToday ? ' data-today="true"' : '';
                                        const oc = d.outside ? 'text-warm-400 dark:text-warm-600 opacity-50' : 'text-warm-800 dark:text-warm-300';
                                        const tc = d.isToday ? ' bg-warm-100 dark:bg-warm-900' : '';
                                        h += '<td class="relative w-9 h-9 p-0 text-center select-none group/day" role="gridcell"' + oa + ta + '>';
                                        h += '<button type="button" class="relative flex items-center justify-center cursor-pointer w-9 h-9 rounded-md text-sm font-normal p-0 border-0 hover:bg-warm-100 dark:hover:bg-warm-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent-600 transition-colors ' + oc + tc + '" tabindex="-1" data-calendar-day-btn="' + d.isoDate + '" aria-label="' + d.label + '">' + d.dayNum + '</button></td>';
                                    }
                                }
                                h += '</tr>';
                            }
                            h += '</tbody></table>';
                            return '<div class="flex flex-col gap-4 w-full">' + h + '</div>';
                        }

                        function calRender() {
                            const container = cr.querySelector('.flex.gap-4');
                            if (!container) return;
                            const panels = [];
                            for (let i = 0; i < cS.monthsCount; i++) {
                                let m = cS.month + i, y = cS.year;
                                while (m > 12) { m -= 12; y++; }
                                panels.push(calBuild(y, m));
                            }
                            container.innerHTML = panels.join('');
                            const cap = cr.querySelector('[data-calendar-caption="' + cid + '"]');
                            if (cap) cap.textContent = MN[cS.month - 1] + ' ' + cS.year;
                            calApply();
                            if (cS.focusedDate) {
                                const t = cr.querySelector('[data-calendar-day-btn="' + cS.focusedDate + '"]');
                                if (t) { cr.querySelectorAll('[data-calendar-day-btn]').forEach(b => b.setAttribute('tabindex', '-1')); t.setAttribute('tabindex', '0'); t.focus(); }
                            } else calInitFocus();
                            cr.setAttribute('data-calendar-month', String(cS.month));
                            cr.setAttribute('data-calendar-year', String(cS.year));
                        }

                        function calApply() {
                            cr.querySelectorAll('[data-calendar-day-btn]').forEach(btn => {
                                const ds = btn.getAttribute('data-calendar-day-btn');
                                const cell = btn.closest('td');
                                btn.removeAttribute('data-selected'); btn.removeAttribute('aria-selected');
                                if (cell) { cell.removeAttribute('data-selected'); cell.removeAttribute('data-range-start'); cell.removeAttribute('data-range-middle'); cell.removeAttribute('data-range-end'); }
                                if (cS.disabled.includes(ds)) { btn.setAttribute('aria-disabled', 'true'); btn.style.opacity = '0.5'; btn.style.pointerEvents = 'none'; return; }
                                if (cS.mode === 'range' && cS.selected.length === 2) {
                                    const [from, to] = cS.selected;
                                    if (ds === from || ds === to) { btn.setAttribute('data-selected', 'true'); btn.setAttribute('aria-selected', 'true'); if (cell) { cell.setAttribute('data-selected', 'true'); cell.setAttribute(ds === from ? 'data-range-start' : 'data-range-end', 'true'); } btn.classList.add('suite-cal-selected'); }
                                    else if (ds > from && ds < to) { btn.setAttribute('aria-selected', 'true'); if (cell) cell.setAttribute('data-range-middle', 'true'); btn.classList.add('suite-cal-range-middle'); }
                                } else if (cS.selected.includes(ds)) { btn.setAttribute('data-selected', 'true'); btn.setAttribute('aria-selected', 'true'); if (cell) cell.setAttribute('data-selected', 'true'); btn.classList.add('suite-cal-selected'); }
                            });
                        }

                        function calInitFocus() {
                            let t = null;
                            if (cS.selected.length > 0) t = cr.querySelector('[data-calendar-day-btn="' + cS.selected[0] + '"]');
                            if (!t) { const td = cr.querySelector('[data-today="true"] [data-calendar-day-btn]'); if (td) t = td; }
                            if (!t) { for (const btn of cr.querySelectorAll('[data-calendar-day-btn]')) { const c = btn.closest('td'); if (c && !c.hasAttribute('data-outside')) { t = btn; break; } } }
                            if (t) { t.setAttribute('tabindex', '0'); cS.focusedDate = t.getAttribute('data-calendar-day-btn'); }
                        }

                        function calSelect(ds) {
                            if (cS.mode === 'single') { cS.selected = cS.selected.length === 1 && cS.selected[0] === ds ? [] : [ds]; }
                            else if (cS.mode === 'multiple') { const i = cS.selected.indexOf(ds); if (i >= 0) cS.selected.splice(i, 1); else cS.selected.push(ds); }
                            else if (cS.mode === 'range') {
                                if (cS.selected.length === 0 || cS.selected.length === 2) cS.selected = [ds];
                                else if (cS.selected.length === 1) { const f = cS.selected[0]; cS.selected = ds < f ? [ds, f] : [f, ds]; }
                            }
                            cr.setAttribute('data-calendar-selected', cS.selected.join(','));
                            calApply();
                            cr.dispatchEvent(new CustomEvent('suite:calendar:select', { bubbles: true, detail: { selected: [...cS.selected], mode: cS.mode } }));
                            // DatePicker integration: update display and auto-close
                            const dp = cr.closest('[data-datepicker]');
                            if (dp) {
                                calUpdateDP(dp);
                                if (cS.mode === 'single' || (cS.mode === 'range' && cS.selected.length === 2)) {
                                    setTimeout(() => { const mk = dp.closest('therapy-island').querySelector('[data-datepicker-trigger-marker]'); if (mk && dp._suiteIsOpen) mk.click(); }, 150);
                                }
                            }
                        }

                        function calUpdateDP(dp) {
                            const ve = dp.querySelector('[data-datepicker-value]');
                            if (!ve) return;
                            dp.setAttribute('data-datepicker-selected', cS.selected.join(','));
                            if (cS.selected.length === 0) { ve.textContent = ve.textContent || 'Pick a date'; ve.classList.add('text-warm-400', 'dark:text-warm-600'); return; }
                            ve.classList.remove('text-warm-400', 'dark:text-warm-600');
                            const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                            const dn = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
                            if (cS.mode === 'single' && cS.selected.length === 1) { const d = new Date(cS.selected[0] + 'T00:00:00'); ve.textContent = dn[d.getDay()] + ', ' + MN[d.getMonth()] + ' ' + d.getDate() + ', ' + d.getFullYear(); }
                            else if (cS.mode === 'range' && cS.selected.length === 2) { const d1 = new Date(cS.selected[0] + 'T00:00:00'), d2 = new Date(cS.selected[1] + 'T00:00:00'); ve.textContent = ms[d1.getMonth()] + ' ' + d1.getDate() + ', ' + d1.getFullYear() + ' \u2013 ' + ms[d2.getMonth()] + ' ' + d2.getDate() + ', ' + d2.getFullYear(); }
                            else if (cS.mode === 'range' && cS.selected.length === 1) { const d = new Date(cS.selected[0] + 'T00:00:00'); ve.textContent = ms[d.getMonth()] + ' ' + d.getDate() + ', ' + d.getFullYear() + ' \u2013 ...'; }
                            else if (cS.mode === 'multiple') ve.textContent = cS.selected.length + ' date' + (cS.selected.length === 1 ? '' : 's') + ' selected';
                        }

                        // Install handlers
                        const prevBtn = cr.querySelector('[data-calendar-prev="' + cid + '"]');
                        const nextBtn = cr.querySelector('[data-calendar-next="' + cid + '"]');
                        if (prevBtn) prevBtn.addEventListener('click', () => { cS.month--; if (cS.month < 1) { cS.month = 12; cS.year--; } calRender(); });
                        if (nextBtn) nextBtn.addEventListener('click', () => { cS.month++; if (cS.month > 12) { cS.month = 1; cS.year++; } calRender(); });
                        calApply();
                        calInitFocus();
                        cr.addEventListener('click', (e) => {
                            const db = e.target.closest('[data-calendar-day-btn]');
                            if (!db) return;
                            const ds = db.getAttribute('data-calendar-day-btn');
                            if (cS.disabled.includes(ds)) return;
                            calSelect(ds);
                        });
                        cr.addEventListener('keydown', (e) => {
                            const db = e.target.closest('[data-calendar-day-btn]');
                            if (!db) return;
                            const ds = db.getAttribute('data-calendar-day-btn');
                            const cd = new Date(ds + 'T00:00:00');
                            let nd = null, handled = false;
                            switch (e.key) {
                                case 'ArrowLeft': nd = new Date(cd); if (e.shiftKey) nd.setMonth(nd.getMonth() - 1); else nd.setDate(nd.getDate() - 1); handled = true; break;
                                case 'ArrowRight': nd = new Date(cd); if (e.shiftKey) nd.setMonth(nd.getMonth() + 1); else nd.setDate(nd.getDate() + 1); handled = true; break;
                                case 'ArrowUp': nd = new Date(cd); if (e.shiftKey) nd.setFullYear(nd.getFullYear() - 1); else nd.setDate(nd.getDate() - 7); handled = true; break;
                                case 'ArrowDown': nd = new Date(cd); if (e.shiftKey) nd.setFullYear(nd.getFullYear() + 1); else nd.setDate(nd.getDate() + 7); handled = true; break;
                                case 'PageUp': nd = new Date(cd); if (e.shiftKey) nd.setFullYear(nd.getFullYear() - 1); else nd.setMonth(nd.getMonth() - 1); handled = true; break;
                                case 'PageDown': nd = new Date(cd); if (e.shiftKey) nd.setFullYear(nd.getFullYear() + 1); else nd.setMonth(nd.getMonth() + 1); handled = true; break;
                                case 'Home': nd = new Date(cd); { const dw = nd.getDay(); nd.setDate(nd.getDate() + (dw === 0 ? -6 : 1 - dw)); } handled = true; break;
                                case 'End': nd = new Date(cd); { const dw = nd.getDay(); nd.setDate(nd.getDate() + (dw === 0 ? 0 : 7 - dw)); } handled = true; break;
                                case 'Enter': case ' ': e.preventDefault(); if (!cS.disabled.includes(ds)) calSelect(ds); return;
                            }
                            if (handled && nd) {
                                e.preventDefault(); e.stopPropagation();
                                const nds = nd.getFullYear() + '-' + String(nd.getMonth() + 1).padStart(2, '0') + '-' + String(nd.getDate()).padStart(2, '0');
                                let tb = cr.querySelector('[data-calendar-day-btn="' + nds + '"]');
                                if (!tb) { cS.month = nd.getMonth() + 1; cS.year = nd.getFullYear(); cS.focusedDate = nds; calRender(); tb = cr.querySelector('[data-calendar-day-btn="' + nds + '"]'); }
                                if (tb) { cr.querySelectorAll('[data-calendar-day-btn]').forEach(b => b.setAttribute('tabindex', '-1')); tb.setAttribute('tabindex', '0'); tb.focus(); cS.focusedDate = nds; }
                            }
                        });
                        return;
                    }

                    // Mode 15: datepicker — popover wrapper for calendar (open/close toggle)
                    if (mode === 15) {
                        const dp = island.firstElementChild;
                        if (!dp) return;
                        const marker = dp.querySelector('[data-datepicker-trigger-marker]');
                        const trigger = dp.querySelector('[data-datepicker-trigger]');
                        const content = dp.querySelector('[data-datepicker-content]');
                        if (!content) return;
                        if (state) {
                            // OPEN
                            dp._suiteIsOpen = true;
                            content.style.display = ''; content.setAttribute('data-state', 'open');
                            if (trigger) trigger.setAttribute('aria-expanded', 'true');
                            // Floating position
                            const ref = trigger || dp;
                            const side = content.getAttribute('data-datepicker-side') || 'bottom';
                            const sideOff = parseInt(content.getAttribute('data-datepicker-side-offset') || '0', 10);
                            const align = content.getAttribute('data-datepicker-align') || 'start';
                            const pad = 4;
                            requestAnimationFrame(() => {
                                const r = ref.getBoundingClientRect();
                                const f = content.getBoundingClientRect();
                                const vw = window.innerWidth, vh = window.innerHeight;
                                const ap = (rs, rz, fz) => align === 'start' ? rs : align === 'end' ? rs + rz - fz : rs + (rz - fz) / 2;
                                let t, l, as = side;
                                if (side === 'bottom') { t = r.bottom + sideOff; l = ap(r.left, r.width, f.width); }
                                else if (side === 'top') { t = r.top - f.height - sideOff; l = ap(r.left, r.width, f.width); }
                                else if (side === 'right') { l = r.right + sideOff; t = ap(r.top, r.height, f.height); }
                                else { l = r.left - f.width - sideOff; t = ap(r.top, r.height, f.height); }
                                if (as === 'bottom' && t + f.height > vh - pad) { const n = r.top - f.height - sideOff; if (n >= pad) { t = n; as = 'top'; } }
                                else if (as === 'top' && t < pad) { const n = r.bottom + sideOff; if (n + f.height <= vh - pad) { t = n; as = 'bottom'; } }
                                l = Math.max(pad, Math.min(l, vw - f.width - pad));
                                t = Math.max(pad, Math.min(t, vh - f.height - pad));
                                content.style.position = 'fixed'; content.style.top = t + 'px'; content.style.left = l + 'px';
                                content.setAttribute('data-side', as);
                                const fb = content.querySelector('[data-calendar-day-btn][tabindex="0"]') || content.querySelector('[data-calendar-day-btn]');
                                if (fb) fb.focus();
                            });
                            // Escape close
                            island._dpEsc = (e) => { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); if (marker) marker.click(); } };
                            dp.addEventListener('keydown', island._dpEsc);
                            // Click outside
                            island._dpOut = (e) => { if (!dp.contains(e.target) && marker) marker.click(); };
                            setTimeout(() => document.addEventListener('pointerdown', island._dpOut), 0);
                        } else {
                            // CLOSE
                            dp._suiteIsOpen = false;
                            content.setAttribute('data-state', 'closed');
                            if (trigger) trigger.setAttribute('aria-expanded', 'false');
                            if (island._dpEsc) { dp.removeEventListener('keydown', island._dpEsc); island._dpEsc = null; }
                            if (island._dpOut) { document.removeEventListener('pointerdown', island._dpOut); island._dpOut = null; }
                            setTimeout(() => { if (content.getAttribute('data-state') === 'closed') { content.style.display = 'none'; content.style.position = ''; content.style.top = ''; content.style.left = ''; } }, 150);
                            if (trigger) setTimeout(() => trigger.focus({ preventScroll: true }), 0);
                        }
                        return;
                    }

                    // Mode 16: DataTable — sorting, filtering, pagination, selection, column visibility
                    if (mode === 16) {
                        const dt = island.firstElementChild;
                        if (!dt || island._dtInit) return;
                        island._dtInit = true;
                        const id = dt.getAttribute('data-datatable');
                        if (!id) return;
                        const pageSize = parseInt(dt.getAttribute('data-datatable-page-size') || '10', 10);
                        const sortable = dt.getAttribute('data-datatable-sortable') !== 'false';
                        const filterable = dt.getAttribute('data-datatable-filterable') !== 'false';
                        const selectable = dt.getAttribute('data-datatable-selectable') === 'true';
                        const hasColVis = dt.getAttribute('data-datatable-column-visibility') === 'true';

                        // Load data from embedded stores
                        const dataStore = dt.querySelector('[data-datatable-store="' + id + '"]');
                        const colStore = dt.querySelector('[data-datatable-columns="' + id + '"]');
                        if (!dataStore || !colStore) return;
                        let allData, columns;
                        try { allData = JSON.parse(dataStore.textContent); columns = JSON.parse(colStore.textContent); } catch (e) { return; }

                        const st = { data: allData, filtered: allData.slice(), sorted: allData.slice(), page: 0, pageSize, sortKey: null, sortDir: null, filterText: '', filterColumns: [], selected: new Set(), hiddenCols: new Set(), columns };

                        const filterInput = dt.querySelector('[data-datatable-filter="' + id + '"]');
                        if (filterInput) {
                            const fc = filterInput.getAttribute('data-datatable-filter-columns') || '';
                            st.filterColumns = fc ? fc.split(',').map(s => s.trim()).filter(s => s) : [];
                        }

                        function dtPipeline() {
                            const text = st.filterText;
                            if (text) {
                                const fk = st.filterColumns.length > 0 ? st.filterColumns : st.columns.map(c => c.key);
                                st.filtered = st.data.filter(row => fk.some(k => { const v = row[k]; return v != null && String(v).toLowerCase().includes(text); }));
                            } else { st.filtered = st.data.slice(); }
                            if (st.sortKey && st.sortDir) {
                                const k = st.sortKey, d = st.sortDir === 'asc' ? 1 : -1;
                                st.sorted = st.filtered.slice().sort((a, b) => { let va = a[k], vb = b[k]; if (va == null) va = ''; if (vb == null) vb = ''; return (typeof va === 'number' && typeof vb === 'number') ? (va - vb) * d : String(va).localeCompare(String(vb)) * d; });
                            } else { st.sorted = st.filtered.slice(); }
                            dtRender();
                        }

                        function dtRender() {
                            const tbody = dt.querySelector('[data-datatable-body="' + id + '"]');
                            if (!tbody) return;
                            const start = st.page * st.pageSize, end = Math.min(start + st.pageSize, st.sorted.length);
                            const pageData = st.sorted.slice(start, end);
                            const totalPages = Math.max(1, Math.ceil(st.sorted.length / st.pageSize));
                            tbody.innerHTML = '';
                            if (pageData.length === 0) {
                                const colspan = st.columns.filter(c => !st.hiddenCols.has(c.key)).length + (selectable ? 1 : 0);
                                const tr = document.createElement('tr'); tr.className = 'border-b border-warm-200 dark:border-warm-700';
                                const td = document.createElement('td'); td.colSpan = colspan; td.className = 'p-2 align-middle text-center text-warm-500 dark:text-warm-600 h-24'; td.textContent = 'No results.';
                                tr.appendChild(td); tbody.appendChild(tr);
                            } else {
                                pageData.forEach((row, i) => {
                                    const gi = start + i, isSel = st.selected.has(gi);
                                    const tr = document.createElement('tr');
                                    tr.className = 'border-b border-warm-200 dark:border-warm-700 transition-colors hover:bg-warm-100/50 dark:hover:bg-warm-900/50';
                                    tr.setAttribute('data-datatable-row', id); tr.setAttribute('data-row-index', String(gi));
                                    if (isSel) tr.setAttribute('data-state', 'selected');
                                    if (selectable) {
                                        const td = document.createElement('td'); td.className = 'w-12 px-2 align-middle';
                                        const cb = document.createElement('input'); cb.type = 'checkbox';
                                        cb.className = 'h-4 w-4 rounded border border-warm-300 dark:border-warm-600 accent-accent-600';
                                        cb.setAttribute('data-datatable-select-row', id); cb.value = String(gi);
                                        cb.setAttribute('aria-label', 'Select row'); cb.checked = isSel;
                                        cb.addEventListener('change', () => {
                                            if (cb.checked) { st.selected.add(gi); tr.setAttribute('data-state', 'selected'); }
                                            else { st.selected.delete(gi); tr.removeAttribute('data-state'); }
                                            dtUpdateSelInfo(); dtUpdateSelAll();
                                        });
                                        td.appendChild(cb); tr.appendChild(td);
                                    }
                                    st.columns.forEach(col => {
                                        if (st.hiddenCols.has(col.key)) return;
                                        const td = document.createElement('td');
                                        td.className = 'p-2 align-middle whitespace-nowrap ' + (col.align === 'right' ? 'text-right' : col.align === 'center' ? 'text-center' : 'text-left');
                                        td.setAttribute('data-datatable-col', col.key);
                                        const v = row[col.key]; td.textContent = v != null ? String(v) : '';
                                        tr.appendChild(td);
                                    });
                                    tbody.appendChild(tr);
                                });
                            }
                            dtUpdatePag(totalPages); dtUpdateSelInfo(); dtUpdateSelAll();
                        }

                        function dtUpdatePag(tp) {
                            const pi = dt.querySelector('[data-datatable-page-info="' + id + '"]');
                            if (pi) pi.textContent = 'Page ' + (st.page + 1) + ' of ' + tp;
                            const pb = dt.querySelector('[data-datatable-prev="' + id + '"]');
                            if (pb) { if (st.page <= 0) pb.setAttribute('disabled', 'disabled'); else pb.removeAttribute('disabled'); }
                            const nb = dt.querySelector('[data-datatable-next="' + id + '"]');
                            if (nb) { if (st.page >= tp - 1) nb.setAttribute('disabled', 'disabled'); else nb.removeAttribute('disabled'); }
                            const ri = dt.querySelector('[data-datatable-row-info="' + id + '"]');
                            if (ri) ri.textContent = st.sorted.length + ' row(s) total.';
                        }

                        function dtUpdateSelInfo() {
                            const info = dt.querySelector('[data-datatable-selection-info="' + id + '"]');
                            if (info) info.textContent = st.selected.size + ' of ' + st.sorted.length + ' row(s) selected.';
                        }

                        function dtUpdateSelAll() {
                            const sa = dt.querySelector('[data-datatable-select-all="' + id + '"]');
                            if (!sa) return;
                            const start = st.page * st.pageSize, end = Math.min(start + st.pageSize, st.sorted.length);
                            let allC = end > start, someC = false;
                            for (let i = start; i < end; i++) { if (st.selected.has(i)) someC = true; else allC = false; }
                            sa.checked = allC; sa.indeterminate = someC && !allC;
                        }

                        function dtUpdateSortIcons() {
                            dt.querySelectorAll('[data-datatable-sort="' + id + '"]').forEach(btn => {
                                const k = btn.value, svg = btn.querySelector('svg');
                                if (!svg) return;
                                if (k === st.sortKey && st.sortDir === 'asc') svg.innerHTML = '<path d="m7 9 5-5 5 5"/>';
                                else if (k === st.sortKey && st.sortDir === 'desc') svg.innerHTML = '<path d="m7 15 5 5 5-5"/>';
                                else svg.innerHTML = '<path d="m7 15 5 5 5-5"/><path d="m7 9 5-5 5 5"/>';
                            });
                        }

                        // Wire filter
                        if (filterInput) {
                            filterInput.addEventListener('input', () => { st.filterText = filterInput.value.toLowerCase(); st.page = 0; st.selected.clear(); dtPipeline(); });
                        }

                        // Wire sort
                        if (sortable) {
                            dt.querySelectorAll('[data-datatable-sort="' + id + '"]').forEach(btn => {
                                btn.addEventListener('click', () => {
                                    const k = btn.value;
                                    if (st.sortKey === k) { if (st.sortDir === 'asc') st.sortDir = 'desc'; else if (st.sortDir === 'desc') { st.sortDir = null; st.sortKey = null; } else st.sortDir = 'asc'; }
                                    else { st.sortKey = k; st.sortDir = 'asc'; }
                                    st.page = 0; dtPipeline(); dtUpdateSortIcons();
                                });
                            });
                        }

                        // Wire pagination
                        const prevBtn = dt.querySelector('[data-datatable-prev="' + id + '"]');
                        const nextBtn = dt.querySelector('[data-datatable-next="' + id + '"]');
                        if (prevBtn) prevBtn.addEventListener('click', () => { if (st.page > 0) { st.page--; dtRender(); } });
                        if (nextBtn) nextBtn.addEventListener('click', () => { const tp = Math.max(1, Math.ceil(st.sorted.length / st.pageSize)); if (st.page < tp - 1) { st.page++; dtRender(); } });

                        // Wire select all
                        if (selectable) {
                            const sa = dt.querySelector('[data-datatable-select-all="' + id + '"]');
                            if (sa) sa.addEventListener('change', () => {
                                const s = st.page * st.pageSize, e = Math.min(s + st.pageSize, st.sorted.length);
                                if (sa.checked) { for (let i = s; i < e; i++) st.selected.add(i); }
                                else { for (let i = s; i < e; i++) st.selected.delete(i); }
                                dtRender();
                            });
                        }

                        // Wire column visibility
                        if (hasColVis) {
                            const visTrig = dt.querySelector('[data-datatable-col-vis-trigger="' + id + '"]');
                            const visCont = dt.querySelector('[data-datatable-col-vis-content="' + id + '"]');
                            if (visTrig && visCont) {
                                visTrig.addEventListener('click', (e) => { e.stopPropagation(); visCont.classList.toggle('hidden'); });
                                document.addEventListener('click', (e) => { if (!visCont.contains(e.target) && e.target !== visTrig) visCont.classList.add('hidden'); });
                            }
                            dt.querySelectorAll('[data-datatable-col-toggle="' + id + '"]').forEach(cb => {
                                cb.addEventListener('change', () => {
                                    const k = cb.value;
                                    if (cb.checked) st.hiddenCols.delete(k); else st.hiddenCols.add(k);
                                    const chk = dt.querySelector('[data-datatable-col-check="' + k + '"]');
                                    if (chk) chk.textContent = cb.checked ? '\u2713 ' : '  ';
                                    st.columns.forEach(c => {
                                        const h = st.hiddenCols.has(c.key);
                                        dt.querySelectorAll('[data-datatable-col="' + c.key + '"]').forEach(el => { el.style.display = h ? 'none' : ''; });
                                        const th = dt.querySelector('th[data-datatable-col="' + c.key + '"]');
                                        if (th) th.style.display = h ? 'none' : '';
                                    });
                                    dtPipeline();
                                });
                            });
                        }
                        return;
                    }

                    // Mode 17: Form — validation, ID linking, ARIA
                    if (mode === 17) {
                        const form = island.firstElementChild;
                        if (!form || island._fmInit) return;
                        island._fmInit = true;
                        const validateOn = form.getAttribute('data-form-validate-on') || 'submit';

                        // Link IDs
                        form.querySelectorAll('[data-form-field]').forEach(field => {
                            const fid = field.getAttribute('data-form-field-id');
                            if (!fid) return;
                            const cid = fid + '-control', did = fid + '-description', mid = fid + '-message';
                            const cw = field.querySelector('[data-form-control]');
                            const ctrl = cw ? cw.querySelector('input, select, textarea') : null;
                            const lbl = field.querySelector('[data-form-label]');
                            const desc = field.querySelector('[data-form-description]');
                            const msg = field.querySelector('[data-form-message]');
                            if (ctrl) ctrl.id = cid;
                            if (desc) desc.id = did;
                            if (msg) msg.id = mid;
                            if (lbl) lbl.setAttribute('for', cid);
                            if (ctrl) { const db = []; if (desc) db.push(did); if (db.length) ctrl.setAttribute('aria-describedby', db.join(' ')); }
                        });

                        function fmGetCtrl(field) { const w = field.querySelector('[data-form-control]'); return w ? w.querySelector('input, select, textarea') : null; }

                        function fmValidate(field) {
                            const ctrl = fmGetCtrl(field);
                            if (!ctrl) return true;
                            const val = ctrl.value || '', errs = [];
                            const req = field.getAttribute('data-form-required');
                            if (req !== null && val.trim() === '') errs.push(req || 'This field is required');
                            const mnl = field.getAttribute('data-form-min-length');
                            if (mnl && val.length > 0 && val.length < parseInt(mnl)) errs.push(field.getAttribute('data-form-min-length-message') || 'Must be at least ' + mnl + ' characters');
                            const mxl = field.getAttribute('data-form-max-length');
                            if (mxl && val.length > parseInt(mxl)) errs.push(field.getAttribute('data-form-max-length-message') || 'Must be at most ' + mxl + ' characters');
                            const pat = field.getAttribute('data-form-pattern');
                            if (pat && val.length > 0 && !(new RegExp('^(?:' + pat + ')\$')).test(val)) errs.push(field.getAttribute('data-form-pattern-message') || 'Invalid format');
                            const mn = field.getAttribute('data-form-min');
                            if (mn && val.length > 0 && parseFloat(val) < parseFloat(mn)) errs.push('Must be at least ' + mn);
                            const mx = field.getAttribute('data-form-max');
                            if (mx && val.length > 0 && parseFloat(val) > parseFloat(mx)) errs.push('Must be at most ' + mx);
                            const hasErr = errs.length > 0;
                            const lbl = field.querySelector('[data-form-label]');
                            const msg = field.querySelector('[data-form-message]');
                            const fid = field.getAttribute('data-form-field-id');
                            const desc = field.querySelector('[data-form-description]');
                            ctrl.setAttribute('aria-invalid', hasErr ? 'true' : 'false');
                            if (lbl) lbl.setAttribute('data-error', hasErr ? 'true' : 'false');
                            if (msg) {
                                if (hasErr) {
                                    msg.textContent = errs[0]; msg.classList.remove('hidden');
                                    const parts = []; if (desc) parts.push(fid + '-description'); parts.push(fid + '-message');
                                    ctrl.setAttribute('aria-describedby', parts.join(' '));
                                } else {
                                    msg.textContent = ''; msg.classList.add('hidden');
                                    if (desc) ctrl.setAttribute('aria-describedby', fid + '-description');
                                    else ctrl.removeAttribute('aria-describedby');
                                }
                            }
                            return !hasErr;
                        }

                        // Wire validation events
                        const fields = form.querySelectorAll('[data-form-field]');
                        fields.forEach(field => {
                            const ctrl = fmGetCtrl(field);
                            if (!ctrl) return;
                            if (validateOn === 'change' || validateOn === 'all') ctrl.addEventListener('input', () => fmValidate(field));
                            if (validateOn === 'blur' || validateOn === 'all') ctrl.addEventListener('blur', () => fmValidate(field));
                        });

                        // Submit handler
                        form.addEventListener('submit', (e) => {
                            let valid = true;
                            fields.forEach(field => { if (!fmValidate(field)) valid = false; });
                            if (!valid) { e.preventDefault(); const fe = form.querySelector('[aria-invalid="true"]'); if (fe) fe.focus(); }
                        });
                        return;
                    }

                    // Mode 18: CodeBlock — copy-to-clipboard + Julia syntax highlighting
                    if (mode === 18) {
                        if (island._cbInit) return;
                        island._cbInit = true;

                        // Copy button
                        const copyBtn = island.querySelector('[data-codeblock-copy]');
                        if (copyBtn) {
                            copyBtn.addEventListener('click', () => {
                                const code = island.querySelector('code');
                                if (!code) return;
                                const text = code.textContent || '';
                                navigator.clipboard.writeText(text).then(() => {
                                    const original = copyBtn.innerHTML;
                                    copyBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
                                    setTimeout(() => { copyBtn.innerHTML = original; }, 2000);
                                });
                            });
                        }

                        // Julia syntax highlighting
                        const lang = island.getAttribute('data-codeblock-lang');
                        if (lang === 'julia' || lang === 'jl') {
                            const code = island.querySelector('code');
                            if (code && !code._hlDone) {
                                code._hlDone = true;
                                const txt = code.textContent || '';
                                if (txt.trim()) {
                                    const KW = new Set(['function','end','if','else','elseif','for','while','return','begin','let','do','try','catch','finally','struct','mutable','abstract','primitive','type','module','baremodule','using','import','export','const','local','global','macro','quote','where','in','isa','break','continue','new']);
                                    const SP = new Set(['true','false','nothing','missing','Inf','NaN','pi']);
                                    const TQ = '"'.repeat(3);
                                    const toks = []; let i = 0;
                                    while (i < txt.length) {
                                        if (txt[i]==='"'&&txt[i+1]==='"'&&txt[i+2]==='"') { const e = txt.indexOf(TQ, i+3); const j = e===-1?txt.length:e+3; toks.push({t:'s',v:txt.slice(i,j)}); i=j; }
                                        else if (txt[i]==='#') { const n=txt.indexOf('\\n',i); const j=n===-1?txt.length:n; toks.push({t:'c',v:txt.slice(i,j)}); i=j; }
                                        else if (txt[i]==='"') { let j=i+1; while(j<txt.length&&txt[j]!=='"'){if(txt[j]==='\\\\')j++;j++;} j=Math.min(j+1,txt.length); toks.push({t:'s',v:txt.slice(i,j)}); i=j; }
                                        else if (txt[i]==="'"&&(i===0||/[\\s(,=\\[{;]/.test(txt[i-1]))) { let j=i+1; while(j<txt.length&&txt[j]!=="'"){if(txt[j]==='\\\\')j++;j++;} j=Math.min(j+1,txt.length); toks.push({t:'s',v:txt.slice(i,j)}); i=j; }
                                        else if (txt[i]===':'&&i+1<txt.length&&/[a-zA-Z_]/.test(txt[i+1])&&(i===0||/[\\s(,=\\[{;]/.test(txt[i-1]))) { let j=i+1; while(j<txt.length&&/[a-zA-Z0-9_!]/.test(txt[j]))j++; toks.push({t:'y',v:txt.slice(i,j)}); i=j; }
                                        else if (/[0-9]/.test(txt[i])&&(i===0||/[\\s(,=\\[{;+\\-*\\/<>!^%&|~]/.test(txt[i-1]))) { let j=i; if(txt[j]==='0'&&j+1<txt.length&&'xob'.includes(txt[j+1])){j+=2;while(j<txt.length&&/[0-9a-fA-F_]/.test(txt[j]))j++;}else{while(j<txt.length&&/[0-9._eE+\\-]/.test(txt[j]))j++;} toks.push({t:'n',v:txt.slice(i,j)}); i=j; }
                                        else if (/[a-zA-Z_@]/.test(txt[i])) { let j=i; if(txt[i]==='@')j++; while(j<txt.length&&/[a-zA-Z0-9_!]/.test(txt[j]))j++; const w=txt.slice(i,j); if(j<txt.length&&txt[j]==='(')toks.push({t:'f',v:w}); else if(txt[i]==='@')toks.push({t:'m',v:w}); else if(KW.has(w))toks.push({t:'k',v:w}); else if(SP.has(w))toks.push({t:'sp',v:w}); else if(/^[A-Z]/.test(w)&&w.length>1)toks.push({t:'tp',v:w}); else toks.push({t:'p',v:w}); i=j; }
                                        else if (/[=!<>+\\-*\\/\\\\%^&|~]/.test(txt[i])) { let j=i+1; while(j<txt.length&&/[=!<>|>&:]/.test(txt[j])&&j-i<3)j++; toks.push({t:'o',v:txt.slice(i,j)}); i=j; }
                                        else if (txt[i]===':'&&i+1<txt.length&&txt[i+1]===':') { toks.push({t:'o',v:'::'}); i+=2; }
                                        else { toks.push({t:'p',v:txt[i]}); i++; }
                                    }
                                    const CLS = {s:'suite-hl-string',c:'suite-hl-comment',y:'suite-hl-symbol',n:'suite-hl-number',f:'suite-hl-funcall',m:'suite-hl-macro',k:'suite-hl-keyword',sp:'suite-hl-special',tp:'suite-hl-type',o:'suite-hl-operator'};
                                    code.innerHTML = toks.map(tk => { const e=tk.v.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); const cl=CLS[tk.t]; return cl ? '<span class="'+cl+'">'+e+'</span>' : e; }).join('');
                                }
                            }
                        }
                        return;
                    }

                    // Mode 19: TreeView — expand/collapse folders + keyboard navigation
                    if (mode === 19) {
                        if (island._tvInit) return;
                        island._tvInit = true;

                        const tree = island.querySelector('[role="tree"]');
                        if (!tree) return;

                        function tvGetVisible() {
                            const items = [];
                            const walk = (parent) => {
                                for (const li of parent.children) {
                                    if (li.tagName !== 'LI' || !li.hasAttribute('data-treeview-item')) continue;
                                    items.push(li);
                                    if (li.getAttribute('data-treeview-expanded') === 'true') {
                                        const group = li.querySelector(':scope > [data-treeview-children]');
                                        if (group) walk(group);
                                    }
                                }
                            };
                            walk(tree);
                            return items;
                        }

                        function tvExpand(item) {
                            item.setAttribute('data-treeview-expanded', 'true');
                            item.setAttribute('aria-expanded', 'true');
                            const ch = item.querySelector(':scope > [data-treeview-children]');
                            if (ch) ch.classList.remove('hidden');
                            const cv = item.querySelector(':scope > div [data-treeview-chevron]');
                            if (cv) cv.classList.add('rotate-90');
                        }

                        function tvCollapse(item) {
                            item.setAttribute('data-treeview-expanded', 'false');
                            item.setAttribute('aria-expanded', 'false');
                            const ch = item.querySelector(':scope > [data-treeview-children]');
                            if (ch) ch.classList.add('hidden');
                            const cv = item.querySelector(':scope > div [data-treeview-chevron]');
                            if (cv) cv.classList.remove('rotate-90');
                        }

                        function tvToggle(item) {
                            if (item.getAttribute('data-treeview-expanded') === 'true') tvCollapse(item);
                            else tvExpand(item);
                        }

                        function tvFocus(item) {
                            tree.querySelectorAll('[data-treeview-item] > div[tabindex="0"]').forEach(el => el.setAttribute('tabindex', '-1'));
                            const row = item.querySelector(':scope > div');
                            if (row) { row.setAttribute('tabindex', '0'); row.focus(); }
                        }

                        function tvSelect(item) {
                            tree.querySelectorAll('[data-treeview-selected="true"]').forEach(el => {
                                el.setAttribute('data-treeview-selected', 'false');
                                el.setAttribute('aria-selected', 'false');
                                const r = el.querySelector(':scope > div');
                                if (r) { r.classList.remove('bg-warm-100','dark:bg-warm-800','text-accent-700','dark:text-accent-400'); r.classList.add('text-warm-700','dark:text-warm-300'); }
                            });
                            item.setAttribute('data-treeview-selected', 'true');
                            item.setAttribute('aria-selected', 'true');
                            const row = item.querySelector(':scope > div');
                            if (row) { row.classList.add('bg-warm-100','dark:bg-warm-800','text-accent-700','dark:text-accent-400'); row.classList.remove('text-warm-700','dark:text-warm-300'); }
                            tvFocus(item);
                        }

                        // Click handler
                        tree.addEventListener('click', (e) => {
                            const row = e.target.closest('[data-treeview-item] > div');
                            if (!row) return;
                            const item = row.parentElement;
                            if (item.hasAttribute('data-disabled')) return;
                            if (item.hasAttribute('data-treeview-folder')) tvToggle(item);
                            tvSelect(item);
                        });

                        // Keyboard handler
                        tree.addEventListener('keydown', (e) => {
                            const item = e.target.closest('[data-treeview-item]');
                            if (!item) return;
                            const vis = tvGetVisible();
                            const idx = vis.indexOf(item);
                            if (idx === -1) return;

                            switch (e.key) {
                                case 'ArrowDown': e.preventDefault(); if (idx < vis.length - 1) tvFocus(vis[idx + 1]); break;
                                case 'ArrowUp': e.preventDefault(); if (idx > 0) tvFocus(vis[idx - 1]); break;
                                case 'ArrowRight': {
                                    e.preventDefault();
                                    if (item.hasAttribute('data-treeview-folder')) {
                                        if (item.getAttribute('data-treeview-expanded') !== 'true') { tvExpand(item); }
                                        else { const ch = item.querySelector('[data-treeview-children]'); if (ch) { const f = ch.querySelector('[data-treeview-item]'); if (f) tvFocus(f); } }
                                    }
                                    break;
                                }
                                case 'ArrowLeft': {
                                    e.preventDefault();
                                    if (item.hasAttribute('data-treeview-folder') && item.getAttribute('data-treeview-expanded') === 'true') { tvCollapse(item); }
                                    else { const pg = item.closest('[data-treeview-children]'); if (pg) { const pi = pg.closest('[data-treeview-item]'); if (pi) tvFocus(pi); } }
                                    break;
                                }
                                case 'Enter': case ' ': {
                                    e.preventDefault();
                                    if (item.hasAttribute('data-treeview-folder')) tvToggle(item);
                                    tvSelect(item);
                                    break;
                                }
                                case 'Home': e.preventDefault(); if (vis.length > 0) tvFocus(vis[0]); break;
                                case 'End': e.preventDefault(); if (vis.length > 0) tvFocus(vis[vis.length - 1]); break;
                            }
                        });
                        return;
                    }

                    // Mode 20: Carousel — scroll-snap navigation + autoplay
                    if (mode === 20) {
                        if (island._carInit) return;
                        island._carInit = true;

                        const orientation = island.getAttribute('data-carousel-orientation') || 'horizontal';
                        const loop = island.getAttribute('data-carousel-loop') === 'true';
                        const autoplay = island.getAttribute('data-carousel-autoplay') === 'true';
                        const interval = parseInt(island.getAttribute('data-carousel-autoplay-interval') || '4000', 10);

                        const content = island.querySelector('[data-carousel-content]');
                        const prevBtn = island.querySelector('[data-carousel-prev]');
                        const nextBtn = island.querySelector('[data-carousel-next]');
                        if (!content) return;

                        const getItems = () => Array.from(content.querySelectorAll('[data-carousel-item]'));

                        const scrollToIdx = (idx) => {
                            const items = getItems();
                            if (items.length === 0) return;
                            const target = items[Math.max(0, Math.min(idx, items.length - 1))];
                            target.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'start' });
                        };

                        const getCurrentIdx = () => {
                            const items = getItems();
                            if (items.length === 0) return 0;
                            const viewport = island.querySelector('[data-carousel-viewport]');
                            if (!viewport) return 0;
                            const rect = viewport.getBoundingClientRect();
                            const center = orientation === 'horizontal'
                                ? rect.left + rect.width / 2
                                : rect.top + rect.height / 2;
                            let closest = 0, minDist = Infinity;
                            items.forEach((item, i) => {
                                const ir = item.getBoundingClientRect();
                                const ic = orientation === 'horizontal'
                                    ? ir.left + ir.width / 2
                                    : ir.top + ir.height / 2;
                                const d = Math.abs(ic - center);
                                if (d < minDist) { minDist = d; closest = i; }
                            });
                            return closest;
                        };

                        const updateButtons = () => {
                            const items = getItems();
                            const idx = getCurrentIdx();
                            if (prevBtn) prevBtn.disabled = !loop && idx === 0;
                            if (nextBtn) nextBtn.disabled = !loop && idx >= items.length - 1;
                        };

                        const goPrev = () => {
                            const items = getItems();
                            const idx = getCurrentIdx();
                            if (idx > 0) scrollToIdx(idx - 1);
                            else if (loop && items.length > 0) scrollToIdx(items.length - 1);
                        };

                        const goNext = () => {
                            const items = getItems();
                            const idx = getCurrentIdx();
                            if (idx < items.length - 1) scrollToIdx(idx + 1);
                            else if (loop && items.length > 0) scrollToIdx(0);
                        };

                        if (prevBtn) prevBtn.addEventListener('click', () => { goPrev(); setTimeout(updateButtons, 350); });
                        if (nextBtn) nextBtn.addEventListener('click', () => { goNext(); setTimeout(updateButtons, 350); });

                        content.addEventListener('scrollend', updateButtons);
                        content.addEventListener('scroll', () => { clearTimeout(content._scrollTimer); content._scrollTimer = setTimeout(updateButtons, 150); });

                        island.addEventListener('keydown', (e) => {
                            if (orientation === 'horizontal') {
                                if (e.key === 'ArrowLeft') { e.preventDefault(); goPrev(); setTimeout(updateButtons, 350); }
                                if (e.key === 'ArrowRight') { e.preventDefault(); goNext(); setTimeout(updateButtons, 350); }
                            } else {
                                if (e.key === 'ArrowUp') { e.preventDefault(); goPrev(); setTimeout(updateButtons, 350); }
                                if (e.key === 'ArrowDown') { e.preventDefault(); goNext(); setTimeout(updateButtons, 350); }
                            }
                        });

                        if (autoplay && interval > 0) {
                            let timer = setInterval(() => { goNext(); setTimeout(updateButtons, 350); }, interval);
                            island.addEventListener('mouseenter', () => clearInterval(timer));
                            island.addEventListener('mouseleave', () => {
                                timer = setInterval(() => { goNext(); setTimeout(updateButtons, 350); }, interval);
                            });
                        }

                        requestAnimationFrame(updateButtons);
                        return;
                    }

                    // Mode 21: Resizable — drag-to-resize panels
                    if (mode === 21) {
                        if (island._resInit) return;
                        island._resInit = true;

                        const direction = island.getAttribute('data-resizable-direction') || 'horizontal';
                        const handles = Array.from(island.querySelectorAll(':scope > [data-resizable-handle]'));
                        const panels = Array.from(island.querySelectorAll(':scope > [data-resizable-panel]'));

                        handles.forEach(handle => {
                            handle.setAttribute('data-resizable-direction', direction);
                            handle.setAttribute('aria-orientation', direction === 'horizontal' ? 'vertical' : 'horizontal');
                        });

                        const explicitTotal = panels.reduce((sum, p) => sum + parseInt(p.getAttribute('data-resizable-default-size') || '0', 10), 0);
                        const unsized = panels.filter(p => parseInt(p.getAttribute('data-resizable-default-size') || '0', 10) === 0);
                        if (unsized.length > 0) {
                            const each = (100 - explicitTotal) / unsized.length;
                            unsized.forEach(p => { p.style.flexGrow = each; p.setAttribute('data-resizable-default-size', String(Math.round(each))); });
                        }

                        const getSizes = () => {
                            const total = panels.reduce((s, p) => s + parseFloat(p.style.flexGrow || 1), 0);
                            return panels.map(p => (parseFloat(p.style.flexGrow || 1) / total) * 100);
                        };

                        const setSizes = (sizes) => {
                            panels.forEach((p, i) => { p.style.flexGrow = sizes[i]; });
                            handles.forEach((h, i) => { if (panels[i]) h.setAttribute('aria-valuenow', Math.round(getSizes()[i])); });
                        };

                        const resize = (handleIdx, deltaPct) => {
                            const sizes = getSizes();
                            const bi = handleIdx, ai = handleIdx + 1;
                            if (bi >= panels.length || ai >= panels.length) return;
                            const bMin = parseInt(panels[bi].getAttribute('data-resizable-min-size') || '10', 10);
                            const bMax = parseInt(panels[bi].getAttribute('data-resizable-max-size') || '100', 10);
                            const aMin = parseInt(panels[ai].getAttribute('data-resizable-min-size') || '10', 10);
                            const aMax = parseInt(panels[ai].getAttribute('data-resizable-max-size') || '100', 10);
                            let nb = sizes[bi] + deltaPct, na = sizes[ai] - deltaPct;
                            if (nb < bMin) { na += (nb - bMin); nb = bMin; }
                            if (nb > bMax) { na += (nb - bMax); nb = bMax; }
                            if (na < aMin) { nb += (na - aMin); na = aMin; }
                            if (na > aMax) { nb += (na - aMax); na = aMax; }
                            sizes[bi] = Math.max(bMin, Math.min(bMax, nb));
                            sizes[ai] = Math.max(aMin, Math.min(aMax, na));
                            setSizes(sizes);
                        };

                        let _cursorSheet = null;
                        handles.forEach((handle, hIdx) => {
                            let dragging = false, startPos = 0, groupSize = 0;
                            handle.addEventListener('pointerdown', (e) => {
                                e.preventDefault(); dragging = true;
                                handle.setAttribute('data-resizable-handle', 'active');
                                startPos = direction === 'horizontal' ? e.clientX : e.clientY;
                                const rect = island.getBoundingClientRect();
                                groupSize = direction === 'horizontal' ? rect.width : rect.height;
                                handle.setPointerCapture(e.pointerId);
                                const cursor = direction === 'horizontal' ? 'col-resize' : 'row-resize';
                                if (!_cursorSheet) { _cursorSheet = new CSSStyleSheet(); document.adoptedStyleSheets = [...document.adoptedStyleSheets, _cursorSheet]; }
                                _cursorSheet.replaceSync('*, *:hover { cursor: ' + cursor + ' !important; }');
                                panels.forEach(p => p.style.pointerEvents = 'none');
                            });
                            handle.addEventListener('pointermove', (e) => {
                                if (!dragging) return;
                                const cur = direction === 'horizontal' ? e.clientX : e.clientY;
                                const deltaPx = cur - startPos;
                                const deltaPct = (deltaPx / groupSize) * 100;
                                startPos = cur;
                                resize(hIdx, deltaPct);
                            });
                            const onUp = (e) => {
                                if (!dragging) return;
                                dragging = false;
                                handle.setAttribute('data-resizable-handle', 'inactive');
                                handle.releasePointerCapture(e.pointerId);
                                if (_cursorSheet) { document.adoptedStyleSheets = document.adoptedStyleSheets.filter(s => s !== _cursorSheet); _cursorSheet = null; }
                                panels.forEach(p => p.style.pointerEvents = '');
                            };
                            handle.addEventListener('pointerup', onUp);
                            handle.addEventListener('pointercancel', onUp);
                            handle.addEventListener('pointerenter', () => { if (!dragging) handle.setAttribute('data-resizable-handle', 'hover'); });
                            handle.addEventListener('pointerleave', () => { if (!dragging) handle.setAttribute('data-resizable-handle', 'inactive'); });

                            handle.addEventListener('keydown', (e) => {
                                const step = 5;
                                if (direction === 'horizontal') {
                                    if (e.key === 'ArrowLeft') { e.preventDefault(); resize(hIdx, -step); }
                                    if (e.key === 'ArrowRight') { e.preventDefault(); resize(hIdx, step); }
                                } else {
                                    if (e.key === 'ArrowUp') { e.preventDefault(); resize(hIdx, -step); }
                                    if (e.key === 'ArrowDown') { e.preventDefault(); resize(hIdx, step); }
                                }
                                if (e.key === 'Home') { e.preventDefault(); resize(hIdx, -100); }
                                if (e.key === 'End') { e.preventDefault(); resize(hIdx, 100); }
                            });
                        });

                        handles.forEach((h, i) => {
                            const sizes = getSizes();
                            if (panels[i]) {
                                h.setAttribute('aria-valuenow', Math.round(sizes[i]));
                                h.setAttribute('aria-valuemin', panels[i].getAttribute('data-resizable-min-size') || '10');
                                h.setAttribute('aria-valuemax', panels[i].getAttribute('data-resizable-max-size') || '100');
                            }
                        });
                        return;
                    }

                    // Mode 22: Toast — Sonner-style notification system
                    if (mode === 22) {
                        if (island._toastInit) return;
                        island._toastInit = true;

                        const defaults = {
                            duration: parseInt(island.getAttribute('data-duration') || '4000', 10),
                            position: island.getAttribute('data-position') || 'bottom-right',
                            visibleToasts: parseInt(island.getAttribute('data-visible-toasts') || '3', 10),
                            gap: 14, swipeThreshold: 45
                        };

                        const toasts = [];
                        let counter = 0;

                        const _themeKey = (name) => {
                            const bp = document.documentElement.getAttribute('data-base-path') || '';
                            return bp ? name + ':' + bp : name;
                        };

                        const _posStyle = (pos) => {
                            const m = {
                                'top-left': 'top:24px;left:24px;', 'top-center': 'top:24px;left:50%;transform:translateX(-50%);',
                                'top-right': 'top:24px;right:24px;', 'bottom-left': 'bottom:24px;left:24px;',
                                'bottom-center': 'bottom:24px;left:50%;transform:translateX(-50%);', 'bottom-right': 'bottom:24px;right:24px;'
                            };
                            return m[pos] || m['bottom-right'];
                        };
                        const _posY = (pos) => pos.startsWith('top') ? 'top' : 'bottom';

                        const _iconSvg = (type) => {
                            const icons = {
                                success: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
                                error: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
                                warning: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
                                info: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>'
                            };
                            return icons[type] || '';
                        };

                        const _typeColors = (type) => {
                            const c = {
                                default: '', success: 'border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-950 text-green-800 dark:text-green-200',
                                error: 'border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-950 text-red-800 dark:text-red-200',
                                warning: 'border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-950 text-amber-800 dark:text-amber-200',
                                info: 'border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-950 text-blue-800 dark:text-blue-200'
                            };
                            return c[type] || '';
                        };

                        const _escapeHtml = (str) => { const d = document.createElement('div'); d.textContent = str; return d.innerHTML; };

                        const _updatePositions = () => {
                            const visible = toasts.filter(t => !t.dismissed);
                            visible.forEach((toast, index) => {
                                if (!toast.el) return;
                                const isVis = index < defaults.visibleToasts;
                                toast.el.style.zIndex = String(visible.length - index);
                                if (isVis) {
                                    toast.el.style.opacity = ''; toast.el.style.pointerEvents = '';
                                    let offset = 0;
                                    for (let i = 0; i < index; i++) offset += (visible[i].height || 0) + defaults.gap;
                                    const dir = _posY(defaults.position) === 'bottom' ? -1 : 1;
                                    toast.el.style.transform = 'translateY(' + (dir * offset) + 'px)';
                                } else {
                                    toast.el.style.opacity = '0'; toast.el.style.pointerEvents = 'none';
                                    toast.el.style.transform = 'translateY(0) scale(0.95)';
                                }
                            });
                        };

                        const _startTimer = (toast) => {
                            if (toast.duration === Infinity) return;
                            const dur = toast.duration || defaults.duration;
                            toast._remaining = dur; toast._timerStart = Date.now();
                            toast._timer = setTimeout(() => dismiss(toast.id), dur);
                        };
                        const _pauseTimer = (toast) => { if (toast._timer) { clearTimeout(toast._timer); toast._remaining -= (Date.now() - toast._timerStart); } };
                        const _resumeTimer = (toast) => {
                            if (toast._remaining > 0 && toast.duration !== Infinity) {
                                toast._timerStart = Date.now(); toast._timer = setTimeout(() => dismiss(toast.id), toast._remaining);
                            }
                        };

                        const _setupSwipe = (el, toast) => {
                            if (toast.dismissible === false) return;
                            let startX = 0, swiping = false;
                            el.addEventListener('pointerdown', (e) => {
                                if (e.button !== 0) return;
                                startX = e.clientX; swiping = true;
                                el.setPointerCapture(e.pointerId); el.style.transition = 'none'; el.setAttribute('data-swiping', 'true');
                            });
                            el.addEventListener('pointermove', (e) => {
                                if (!swiping) return;
                                const dx = e.clientX - startX;
                                if (dx > 0) { el.style.transform = 'translateX(' + dx + 'px)'; el.style.opacity = Math.max(0, 1 - dx / 150); }
                            });
                            el.addEventListener('pointerup', (e) => {
                                if (!swiping) return;
                                swiping = false; el.removeAttribute('data-swiping'); el.style.transition = '';
                                const dx = e.clientX - startX;
                                if (dx >= defaults.swipeThreshold) {
                                    el.style.transition = 'transform 200ms ease-out, opacity 200ms ease-out';
                                    el.style.transform = 'translateX(100%)'; el.style.opacity = '0';
                                    setTimeout(() => dismiss(toast.id), 200);
                                } else { el.style.transform = ''; el.style.opacity = ''; }
                            });
                        };

                        const _createToastEl = (toast) => {
                            const li = document.createElement('li');
                            li.setAttribute('role', 'status');
                            li.setAttribute('aria-live', toast.type === 'error' ? 'assertive' : 'polite');
                            li.setAttribute('aria-atomic', 'true');
                            li.setAttribute('data-toast', toast.id);
                            li.setAttribute('data-type', toast.type);
                            li.setAttribute('data-mounted', 'false');
                            li.setAttribute('data-dismissed', 'false');
                            li.setAttribute('tabindex', '0');
                            const tc = _typeColors(toast.type);
                            const base = 'pointer-events-auto relative flex items-start gap-3 w-[356px] max-w-[calc(100vw-48px)] rounded-md border p-4 shadow-lg transition-all duration-300';
                            const def = 'border-warm-200 dark:border-warm-700 bg-warm-50 dark:bg-warm-900 text-warm-800 dark:text-warm-300';
                            li.className = base + ' ' + (tc || def);
                            const icon = _iconSvg(toast.type);
                            let iconHtml = '';
                            if (icon) {
                                const cm = { success:'text-green-600 dark:text-green-400', error:'text-red-600 dark:text-red-400', warning:'text-amber-600 dark:text-amber-400', info:'text-blue-600 dark:text-blue-400' };
                                iconHtml = '<div class="flex-shrink-0 ' + (cm[toast.type]||'') + '">' + icon + '</div>';
                            }
                            let ch = '<div class="flex-1 min-w-0">';
                            if (toast.title) ch += '<div class="text-sm font-semibold">' + _escapeHtml(toast.title) + '</div>';
                            if (toast.description) ch += '<div class="text-sm opacity-80 mt-0.5">' + _escapeHtml(toast.description) + '</div>';
                            ch += '</div>';
                            let closeHtml = '';
                            if (toast.dismissible !== false) {
                                closeHtml = '<button type="button" aria-label="Dismiss" class="flex-shrink-0 rounded-md p-0.5 opacity-50 hover:opacity-100 transition-opacity cursor-pointer focus:outline-none focus-visible:ring-2 focus-visible:ring-accent-600">' +
                                    '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>';
                            }
                            let actionHtml = '';
                            if (toast.action) {
                                actionHtml = '<button type="button" data-toast-action class="flex-shrink-0 text-sm font-medium px-3 py-1 rounded-md bg-accent-600 text-white hover:bg-accent-700 transition-colors cursor-pointer">' + _escapeHtml(toast.action.label) + '</button>';
                            }
                            li.innerHTML = iconHtml + ch + actionHtml + closeHtml;
                            const closeBtn = li.querySelector('button[aria-label="Dismiss"]');
                            if (closeBtn) closeBtn.addEventListener('click', () => dismiss(toast.id));
                            const actionBtn = li.querySelector('[data-toast-action]');
                            if (actionBtn && toast.action && toast.action.onClick) actionBtn.addEventListener('click', (e) => { toast.action.onClick(e); dismiss(toast.id); });
                            _setupSwipe(li, toast);
                            return li;
                        };

                        const show = (title, opts = {}) => {
                            const id = ++counter;
                            const toast = { id, title, description: opts.description || '', type: opts.type || 'default', duration: opts.duration, dismissible: opts.dismissible, action: opts.action, dismissed: false, el: null, height: 0, _timer: null, _remaining: 0, _timerStart: 0 };
                            toast.el = _createToastEl(toast);
                            let list = island.querySelector('ol[data-toast-list]');
                            if (!list) {
                                list = document.createElement('ol');
                                list.setAttribute('data-toast-list', '');
                                list.style.cssText = 'position:fixed;' + _posStyle(defaults.position) + 'z-index:999999;list-style:none;margin:0;padding:0;display:flex;flex-direction:column;pointer-events:none;';
                                island.appendChild(list);
                            }
                            if (_posY(defaults.position) === 'bottom') list.prepend(toast.el); else list.appendChild(toast.el);
                            toasts.unshift(toast);
                            requestAnimationFrame(() => { toast.height = toast.el.getBoundingClientRect().height; toast.el.setAttribute('data-mounted', 'true'); _updatePositions(); });
                            toast.el.addEventListener('mouseenter', () => _pauseTimer(toast));
                            toast.el.addEventListener('mouseleave', () => _resumeTimer(toast));
                            _startTimer(toast);
                            return id;
                        };

                        const dismiss = (id) => {
                            const idx = toasts.findIndex(t => t.id === id);
                            if (idx === -1) return;
                            const toast = toasts[idx];
                            if (toast.dismissed) return;
                            toast.dismissed = true;
                            if (toast._timer) clearTimeout(toast._timer);
                            if (toast.el) {
                                toast.el.setAttribute('data-dismissed', 'true');
                                toast.el.style.transition = 'transform 300ms ease-out, opacity 300ms ease-out';
                                toast.el.style.opacity = '0'; toast.el.style.transform = 'translateX(100%)';
                                setTimeout(() => { if (toast.el && toast.el.parentNode) toast.el.parentNode.removeChild(toast.el); toasts.splice(toasts.findIndex(t => t.id === id), 1); _updatePositions(); }, 300);
                            }
                            _updatePositions();
                        };

                        const dismissAll = () => { [...toasts].forEach(t => dismiss(t.id)); };

                        // Expose global Suite.toast() API
                        if (!window.Suite) window.Suite = {};
                        window.Suite.toast = function(title, opts) { return show(title, opts); };
                        window.Suite.toast.success = function(title, opts) { return show(title, { ...opts, type: 'success' }); };
                        window.Suite.toast.error = function(title, opts) { return show(title, { ...opts, type: 'error' }); };
                        window.Suite.toast.warning = function(title, opts) { return show(title, { ...opts, type: 'warning' }); };
                        window.Suite.toast.info = function(title, opts) { return show(title, { ...opts, type: 'info' }); };
                        window.Suite.toast.dismiss = function(id) { return dismiss(id); };
                        window.Suite.toast.dismissAll = function() { return dismissAll(); };
                        window.Suite.Toast = { show, dismiss, dismissAll,
                            success: (t,o={}) => show(t,{...o,type:'success'}), error: (t,o={}) => show(t,{...o,type:'error'}),
                            warning: (t,o={}) => show(t,{...o,type:'warning'}), info: (t,o={}) => show(t,{...o,type:'info'}) };
                        return;
                    }

                    // Mode 23: ThemeSwitcher — theme selection dropdown
                    if (mode === 23) {
                        if (island._tsInit) return;
                        island._tsInit = true;

                        const trigger = island.querySelector('[data-theme-switcher-trigger]');
                        const content = island.querySelector('[data-theme-switcher-content]');
                        if (!trigger || !content) return;

                        const _themeKey = (name) => {
                            const bp = document.documentElement.getAttribute('data-base-path') || '';
                            return bp ? name + ':' + bp : name;
                        };

                        const updateChecks = () => {
                            const current = document.documentElement.getAttribute('data-theme') || 'default';
                            island.querySelectorAll('[data-theme-check]').forEach(check => {
                                const key = check.getAttribute('data-theme-check');
                                if (key === current) check.classList.remove('hidden');
                                else check.classList.add('hidden');
                            });
                        };

                        const open = () => { content.classList.remove('hidden'); trigger.setAttribute('aria-expanded', 'true'); updateChecks(); };
                        const close = () => { content.classList.add('hidden'); trigger.setAttribute('aria-expanded', 'false'); };

                        const applyTheme = (theme) => {
                            const html = document.documentElement;
                            if (theme === 'default') html.removeAttribute('data-theme');
                            else html.setAttribute('data-theme', theme);
                            try { localStorage.setItem(_themeKey('suite-active-theme'), theme); } catch (e) {}
                        };

                        trigger.addEventListener('click', (e) => {
                            e.stopPropagation();
                            if (!content.classList.contains('hidden')) close(); else open();
                        });

                        island.querySelectorAll('[data-theme-option]').forEach(option => {
                            option.addEventListener('click', () => {
                                applyTheme(option.getAttribute('data-theme-option'));
                                updateChecks(); close();
                            });
                        });

                        document.addEventListener('pointerdown', (e) => {
                            if (!island.contains(e.target) && !content.classList.contains('hidden')) close();
                        });
                        document.addEventListener('keydown', (e) => {
                            if (e.key === 'Escape' && !content.classList.contains('hidden')) { close(); trigger.focus(); }
                        });

                        updateChecks();
                        return;
                    }

                    const root = mode === 3
                        ? island.querySelector('[data-popover-content]')
                        : island.querySelector('[style*="display:none"], [style*="display: none"]');
                    const overlay = island.querySelector('[data-dialog-overlay], [data-alert-dialog-overlay], [data-sheet-overlay], [data-drawer-overlay]');
                    const content = island.querySelector('[role="dialog"], [role="alertdialog"]');

                    if (state) {
                        // === OPEN ===
                        // Mode 3 (popover): skip generic show — floating code handles visibility sequence
                        if (mode !== 3 && root) root.style.display = '';
                        if (overlay) overlay.style.display = '';

                        // Scroll lock
                        if (++_scrollLockCount === 1) document.body.style.overflow = 'hidden';

                        // Focus guards
                        if (!window._therapyFocusGuards) {
                            const g = () => { const s = document.createElement('span'); s.tabIndex = 0; s.setAttribute('data-focus-guard',''); s.style.cssText = 'position:fixed;opacity:0;pointer-events:none'; return s; };
                            window._therapyFocusGuards = [g(), g()];
                            document.body.prepend(window._therapyFocusGuards[0]);
                            document.body.append(window._therapyFocusGuards[1]);
                        }

                        // Focus first tabbable in content
                        if (content) {
                            const FOCUSABLE = 'a[href],button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex]:not([tabindex="-1"])';
                            let target = null;
                            if (mode === 1) {
                                target = content.querySelector('[data-alert-dialog-cancel] button, [data-alert-dialog-cancel]');
                            }
                            if (!target) {
                                const all = content.querySelectorAll(FOCUSABLE);
                                target = Array.from(all).find(e => e.tagName !== 'A') || all[0];
                            }
                            if (target) target.focus({ preventScroll: true });
                            else content.focus({ preventScroll: true });
                        }

                        island._modalPrev = document.activeElement;

                        // Body pointer-events
                        island._modalPE = document.body.style.pointerEvents;
                        document.body.style.pointerEvents = 'none';
                        if (content) content.style.pointerEvents = 'auto';
                        if (overlay) overlay.style.pointerEvents = 'auto';

                        // Escape handler (mode 0=dialog, 2=drawer, 3=popover — not mode 1=alert_dialog)
                        if (mode === 0 || mode === 2 || mode === 3) {
                            island._modalEsc = (e) => {
                                if (e.key !== 'Escape') return;
                                const btn = island.querySelector('[data-dialog-close], [data-sheet-close], [data-drawer-close], [data-popover-close]')
                                    || island.querySelector('[data-popover-trigger-wrapper]');
                                if (btn) btn.click();
                            };
                            document.addEventListener('keydown', island._modalEsc);
                        }

                        // Focus trap: Tab key cycling
                        island._modalTab = (e) => {
                            if (e.key !== 'Tab' || !content) return;
                            const FOCUSABLE = 'a[href],button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex]:not([tabindex="-1"])';
                            const tabbable = Array.from(content.querySelectorAll(FOCUSABLE)).filter(el => el.offsetParent !== null);
                            if (!tabbable.length) { e.preventDefault(); return; }
                            const first = tabbable[0], last = tabbable[tabbable.length - 1];
                            if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus({ preventScroll: true }); }
                            else if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus({ preventScroll: true }); }
                        };
                        document.addEventListener('keydown', island._modalTab);

                        // Drawer: reset transform and install drag handlers (mode 2)
                        if (mode === 2 && content) {
                            content.style.transform = '';
                            content.style.transition = '';
                            const dir = content.getAttribute('data-drawer-direction') || 'bottom';
                            const isV = dir === 'bottom' || dir === 'top';
                            let dragging = false, dStart = 0, dTime = 0, dSize = 0;
                            island._drawerDown = (e) => {
                                if (e.target.closest('select, [data-no-drag]')) return;
                                const sc = e.target.closest('[style*="overflow"]');
                                if (sc && sc.scrollTop > 0) return;
                                dragging = true;
                                dStart = isV ? e.clientY : e.clientX;
                                dTime = Date.now();
                                dSize = isV ? content.getBoundingClientRect().height : content.getBoundingClientRect().width;
                                content.style.transition = 'none';
                                content.setPointerCapture(e.pointerId);
                            };
                            island._drawerMove = (e) => {
                                if (!dragging) return;
                                const cur = isV ? e.clientY : e.clientX;
                                let delta = cur - dStart;
                                if (dir === 'top' || dir === 'left') delta = -delta;
                                if (delta < 0) {
                                    const d = -8 * (Math.log(Math.abs(delta) + 1) - 2);
                                    const axis = isV ? 'translateY' : 'translateX';
                                    const sign = (dir === 'bottom' || dir === 'right') ? 1 : -1;
                                    content.style.transform = axis + '(' + (sign * Math.max(Math.min(d, 20), -20)) + 'px)';
                                } else {
                                    const axis = isV ? 'translateY' : 'translateX';
                                    const sign = (dir === 'bottom' || dir === 'right') ? 1 : -1;
                                    content.style.transform = axis + '(' + (sign * delta) + 'px)';
                                    if (overlay) overlay.style.opacity = Math.max(0, Math.min(1, 1 - delta / dSize));
                                }
                            };
                            island._drawerUp = (e) => {
                                if (!dragging) return;
                                dragging = false;
                                const cur = isV ? e.clientY : e.clientX;
                                let delta = cur - dStart;
                                if (dir === 'top' || dir === 'left') delta = -delta;
                                if (overlay) overlay.style.opacity = '';
                                if (delta <= 0) {
                                    content.style.transition = 'transform 0.5s cubic-bezier(0.32, 0.72, 0, 1)';
                                    content.style.transform = '';
                                    return;
                                }
                                const elapsed = (Date.now() - dTime) / 1000;
                                const velocity = Math.abs(delta) / elapsed / 1000;
                                const vis = Math.min(dSize, isV ? window.innerHeight : window.innerWidth);
                                if (velocity > 0.4 || delta >= vis * 0.25) {
                                    const btn = island.querySelector('[data-drawer-close]');
                                    if (btn) btn.click();
                                } else {
                                    content.style.transition = 'transform 0.5s cubic-bezier(0.32, 0.72, 0, 1)';
                                    content.style.transform = '';
                                }
                            };
                            content.addEventListener('pointerdown', island._drawerDown);
                            content.addEventListener('pointermove', island._drawerMove);
                            content.addEventListener('pointerup', island._drawerUp);
                        }

                        // Popover: floating positioning (mode 3)
                        if (mode === 3 && content) {
                            // Find trigger element for positioning reference
                            const triggerWrap = island.querySelector('[data-popover-trigger-wrapper]');
                            const trigger = triggerWrap ? (triggerWrap.firstElementChild || triggerWrap) : null;

                            // Read positioning params from content data attributes
                            const side = content.getAttribute('data-popover-side') || 'bottom';
                            const sideOffset = parseInt(content.getAttribute('data-popover-side-offset') || '0', 10);
                            const align = content.getAttribute('data-popover-align') || 'center';
                            const pad = 4;

                            function floatUpdate() {
                                if (!trigger || !content) return;
                                const ref = trigger.getBoundingClientRect();
                                const flt = content.getBoundingClientRect();
                                const vw = window.innerWidth;
                                const vh = window.innerHeight;

                                function alignPos(refStart, refSize, fltSize) {
                                    if (align === 'start') return refStart;
                                    if (align === 'end') return refStart + refSize - fltSize;
                                    return refStart + (refSize - fltSize) / 2;
                                }

                                let top, left, actualSide = side;
                                if (side === 'bottom') { top = ref.bottom + sideOffset; left = alignPos(ref.left, ref.width, flt.width); }
                                else if (side === 'top') { top = ref.top - flt.height - sideOffset; left = alignPos(ref.left, ref.width, flt.width); }
                                else if (side === 'right') { left = ref.right + sideOffset; top = alignPos(ref.top, ref.height, flt.height); }
                                else { left = ref.left - flt.width - sideOffset; top = alignPos(ref.top, ref.height, flt.height); }

                                // Flip if colliding
                                if (actualSide === 'bottom' && top + flt.height > vh - pad) { const f = ref.top - flt.height - sideOffset; if (f >= pad) { top = f; actualSide = 'top'; } }
                                else if (actualSide === 'top' && top < pad) { const f = ref.bottom + sideOffset; if (f + flt.height <= vh - pad) { top = f; actualSide = 'bottom'; } }
                                else if (actualSide === 'right' && left + flt.width > vw - pad) { const f = ref.left - flt.width - sideOffset; if (f >= pad) { left = f; actualSide = 'left'; } }
                                else if (actualSide === 'left' && left < pad) { const f = ref.right + sideOffset; if (f + flt.width <= vw - pad) { left = f; actualSide = 'right'; } }

                                // Shift to keep in viewport
                                left = Math.max(pad, Math.min(left, vw - flt.width - pad));
                                top = Math.max(pad, Math.min(top, vh - flt.height - pad));

                                content.style.position = 'fixed';
                                content.style.top = top + 'px';
                                content.style.left = left + 'px';
                                content.setAttribute('data-side', actualSide);
                                content.setAttribute('data-align', align);
                            }

                            // Make visible for measurement, then position
                            content.style.visibility = 'hidden';
                            content.style.display = '';
                            requestAnimationFrame(() => {
                                floatUpdate();
                                content.style.visibility = '';
                            });

                            // Update on scroll/resize
                            island._floatScroll = () => floatUpdate();
                            island._floatResize = () => floatUpdate();
                            window.addEventListener('scroll', island._floatScroll, true);
                            window.addEventListener('resize', island._floatResize);

                            // Click-outside dismiss for popover
                            island._popoverOutside = (e) => {
                                if (!content.contains(e.target) && !(triggerWrap && triggerWrap.contains(e.target))) {
                                    const btn = island.querySelector('[data-popover-close]')
                                        || island.querySelector('[data-popover-trigger-wrapper]');
                                    if (btn) btn.click();
                                }
                            };
                            setTimeout(() => document.addEventListener('pointerdown', island._popoverOutside), 0);
                        }
                    } else {
                        // === CLOSE ===
                        if (--_scrollLockCount <= 0) { _scrollLockCount = 0; document.body.style.overflow = ''; }
                        if (window._therapyFocusGuards) { window._therapyFocusGuards.forEach(g => g.remove()); window._therapyFocusGuards = null; }
                        if (island._modalEsc) { document.removeEventListener('keydown', island._modalEsc); island._modalEsc = null; }
                        if (island._modalTab) { document.removeEventListener('keydown', island._modalTab); island._modalTab = null; }

                        document.body.style.pointerEvents = island._modalPE || '';
                        if (content) content.style.pointerEvents = '';

                        // Remove drawer drag handlers (mode 2)
                        if (content && island._drawerDown) {
                            content.removeEventListener('pointerdown', island._drawerDown);
                            content.removeEventListener('pointermove', island._drawerMove);
                            content.removeEventListener('pointerup', island._drawerUp);
                            island._drawerDown = island._drawerMove = island._drawerUp = null;
                        }

                        // Remove popover floating handlers (mode 3)
                        if (island._floatScroll) { window.removeEventListener('scroll', island._floatScroll, true); island._floatScroll = null; }
                        if (island._floatResize) { window.removeEventListener('resize', island._floatResize); island._floatResize = null; }
                        if (island._popoverOutside) { document.removeEventListener('pointerdown', island._popoverOutside); island._popoverOutside = null; }

                        // Drawer close: slide out via transform, then hide
                        if (mode === 2 && content) {
                            const dir = content.getAttribute('data-drawer-direction') || 'bottom';
                            const rect = content.getBoundingClientRect();
                            let tf = '';
                            if (dir === 'bottom') tf = 'translateY(' + rect.height + 'px)';
                            else if (dir === 'top') tf = 'translateY(-' + rect.height + 'px)';
                            else if (dir === 'right') tf = 'translateX(' + rect.width + 'px)';
                            else if (dir === 'left') tf = 'translateX(-' + rect.width + 'px)';
                            content.style.transition = 'transform 0.5s cubic-bezier(0.32, 0.72, 0, 1)';
                            content.style.transform = tf;
                        }

                        const hide = () => {
                            if (root) root.style.display = 'none';
                            if (overlay) overlay.style.display = 'none';
                            if (mode === 2 && content) { content.style.transform = ''; content.style.transition = ''; }
                            if (mode === 3 && content) { content.style.position = ''; content.style.top = ''; content.style.left = ''; }
                        };
                        const evt = mode === 2 ? 'transitionend' : 'animationend';
                        if (content) content.addEventListener(evt, hide, { once: true });
                        setTimeout(hide, mode === 2 ? 600 : (mode === 3 ? 250 : 500));

                        const prev = island._modalPrev;
                        if (prev && prev.focus) setTimeout(() => prev.focus({ preventScroll: true }), 0);
                    }
                }
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

        // Connect modal trigger bindings (JS-side click/hover handlers for BindModal)
        $(generate_modal_trigger_js(analysis, query_base))

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
Modal trigger selectors by BindModal mode. Maps mode -> (selectors, event_type).
Event types: :click (toggle 0↔1), :hover (enter=1/leave=0), :contextmenu (toggle).
"""
const MODAL_TRIGGER_MAP = Dict{Int32, Tuple{Vector{String}, Symbol}}(
    Int32(0) => (["[data-dialog-trigger-wrapper]"], :click),
    Int32(1) => (["[data-alert-dialog-trigger-wrapper]"], :click),
    Int32(2) => (["[data-sheet-trigger-wrapper]", "[data-drawer-trigger-wrapper]"], :click),
    Int32(3) => (["[data-popover-trigger-wrapper]"], :click),
    Int32(4) => (["[data-tooltip-trigger-wrapper]"], :hover),
    Int32(5) => (["[data-hover-card-trigger-wrapper]"], :hover),
    Int32(6) => (["[data-dropdown-menu-trigger-wrapper]"], :click),
    Int32(7) => (["[data-context-menu-trigger-wrapper]"], :contextmenu),
    Int32(8) => (["[data-select-trigger-wrapper]"], :click),
    Int32(9) => (["[data-nav-menu-trigger-marker]"], :click),
    Int32(10) => (["[data-menubar-trigger-marker]"], :click),
    Int32(11) => (["[data-command-dialog-trigger-marker]"], :click),
    Int32(12) => (["[data-collapsible-trigger]"], :click),
    Int32(15) => (["[data-datepicker-trigger-marker]"], :click),
    Int32(23) => (["[data-theme-switcher-trigger]"], :click),
)

"""
Generate JavaScript to bind trigger elements to BindModal signals.

For each BindModal binding, finds the trigger element in the DOM and attaches
event handlers that toggle the Wasm signal. This bridges the gap when the
component's click handlers aren't compiled to Wasm (because they're injected
into children that don't exist during no-argument analysis).
"""
function generate_modal_trigger_js(analysis::ComponentAnalysis, query_base::String)
    if isempty(analysis.modal_bindings)
        return ""
    end

    parts = String[]
    for binding in analysis.modal_bindings
        info = get(MODAL_TRIGGER_MAP, binding.mode, nothing)
        info === nothing && continue

        selectors, event_type = info
        signal_id = binding.signal_id

        # Build the selector query (try each selector in order)
        selector_js = join(["$(query_base).querySelector('$(sel)')" for sel in selectors], " || ")

        if event_type === :click
            push!(parts, """
    // Modal trigger binding (mode $(binding.mode))
    {
        const trigger = $(selector_js);
        if (trigger) {
            trigger.addEventListener('click', (e) => {
                const current = wasm.get_signal_$(signal_id)();
                wasm.set_signal_$(signal_id)(current ? 0 : 1);
            });
        }
    }""")
        elseif event_type === :hover
            push!(parts, """
    // Modal trigger binding (mode $(binding.mode), hover)
    {
        const trigger = $(selector_js);
        if (trigger) {
            trigger.addEventListener('pointerenter', () => { wasm.set_signal_$(signal_id)(1); });
            trigger.addEventListener('pointerleave', () => { wasm.set_signal_$(signal_id)(0); });
        }
    }""")
        elseif event_type === :contextmenu
            push!(parts, """
    // Modal trigger binding (mode $(binding.mode), contextmenu)
    {
        const trigger = $(selector_js);
        if (trigger) {
            trigger.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                wasm.set_signal_$(signal_id)(1);
            });
        }
    }""")
        end
    end

    return join(parts, "\n")
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

  // ─── Per-island state (reset before each hydration call) ───
  let _cursor = null;
  const _elements = [];
  const _bindings = [];
  const _strings = [];
  let _propValues = [];

  // ─── Event state ───
  let _currentEvent = null;
  let _keyCode = 0, _modifiers = 0;
  let _pointerX = 0.0, _pointerY = 0.0, _pointerId = 0;
  let _targetValueF64 = 0.0, _targetChecked = 0;

  // ─── Timer state ───
  const _timers = {};
  let _timerCounter = 0;

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
  function buildImports(instRef) {
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
      add_class: (el, cls) => { const e = _elements[el]; if (e) e.classList.add(_strings[cls]); },
      remove_class: (el, cls) => { const e = _elements[el]; if (e) e.classList.remove(_strings[cls]); },
      toggle_class: (el, cls) => { const e = _elements[el]; if (e) e.classList.toggle(_strings[cls]); },
      // Imports 8-10: Attribute/style
      set_attribute: (el, attr, val) => { const e = _elements[el]; if (e) e.setAttribute(_strings[attr], _strings[val]); },
      remove_attribute: (el, attr) => { const e = _elements[el]; if (e) e.removeAttribute(_strings[attr]); },
      set_style: (el, prop, val) => { const e = _elements[el]; if (e) e.style.setProperty(_strings[prop], _strings[val]); },
      // Imports 11-16: DOM state + text + display
      set_data_state: (el, val) => { const e = _elements[el]; if (e) e.dataset.state = _strings[val]; },
      set_data_motion: (el, val) => { const e = _elements[el]; if (e) e.dataset.motion = _strings[val]; },
      set_text_content: (el, val) => { const e = _elements[el]; if (e) e.textContent = _strings[val]; },
      set_hidden: (el, val) => { const e = _elements[el]; if (e) e.hidden = !!val; },
      show_element: (el) => { const e = _elements[el]; if (e) e.style.display = ''; },
      hide_element: (el) => { const e = _elements[el]; if (e) e.style.display = 'none'; },
      // Imports 17-19: Focus
      focus_element: (el) => { const e = _elements[el]; if (e) e.focus(); },
      focus_element_prevent_scroll: (el) => { const e = _elements[el]; if (e) e.focus({preventScroll: true}); },
      blur_element: (el) => { const e = _elements[el]; if (e) e.blur(); },
      // Import 20: Active element
      get_active_element: () => { const ae = document.activeElement; if (!ae) return -1; const id = _elements.indexOf(ae); return id >= 0 ? id : -1; },
      // Imports 21-24: Focus management
      focus_first_tabbable: (el) => {},
      focus_last_tabbable: (el) => {},
      install_focus_guards: () => {},
      uninstall_focus_guards: () => {},
      // Imports 25-27: Scroll
      lock_scroll: () => { document.body.style.overflow = 'hidden'; },
      unlock_scroll: () => { document.body.style.overflow = ''; },
      scroll_into_view: (el) => { const e = _elements[el]; if (e) e.scrollIntoView({block: 'nearest'}); },
      // Imports 28-33: Geometry
      get_bounding_rect_x: (el) => { const e = _elements[el]; return e ? e.getBoundingClientRect().x : 0; },
      get_bounding_rect_y: (el) => { const e = _elements[el]; return e ? e.getBoundingClientRect().y : 0; },
      get_bounding_rect_w: (el) => { const e = _elements[el]; return e ? e.getBoundingClientRect().width : 0; },
      get_bounding_rect_h: (el) => { const e = _elements[el]; return e ? e.getBoundingClientRect().height : 0; },
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
      storage_get_i32: (key) => { try { return parseInt(localStorage.getItem(_strings[key])) || 0; } catch(e) { return 0; } },
      storage_set_i32: (key, val) => { try { localStorage.setItem(_strings[key], String(val)); } catch(e) {} },
      copy_to_clipboard: (id) => { navigator.clipboard?.writeText(_strings[id]); },
      // Imports 44-47: Pointer/drag
      capture_pointer: (el) => { const e = _elements[el]; if (e) e.setPointerCapture(_pointerId); },
      release_pointer: (el) => { const e = _elements[el]; if (e) e.releasePointerCapture(_pointerId); },
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
        if (!_cursor) { console.warn('[Hydration] cursor_current: null cursor'); return -1; }
        const id = _elements.length;
        _elements.push(_cursor);
        return id;
      },
      cursor_set: (el_id) => {
        if (el_id >= 0 && el_id < _elements.length) _cursor = _elements[el_id];
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
        const el = _elements[el_id];
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
        _bindings.push({ el_id, signal_idx, type: 'text' });
      },
      register_visibility_binding: (el_id, signal_idx) => {
        _bindings.push({ el_id, signal_idx, type: 'visibility' });
      },
      register_attribute_binding: (el_id, attr_id, signal_idx) => {
        _bindings.push({ el_id, attr_id, signal_idx, type: 'attribute' });
      },
      trigger_bindings: (signal_idx, value) => {
        const DATA_STATE_MODES = [['closed','open'], ['off','on'], ['unchecked','checked'], ['inactive','active']];
        const ARIA_ATTRS = ['aria-pressed', 'aria-checked', 'aria-expanded', 'aria-selected'];
        for (const b of _bindings) {
          if (b.signal_idx !== signal_idx) continue;
          const el = _elements[b.el_id];
          if (!el) continue;
          if (b.type === 'text') {
            el.textContent = String(value);
          } else if (b.type === 'visibility') {
            el.style.display = value ? '' : 'none';
          } else if (b.type === 'attribute') {
            el.setAttribute(_strings[b.attr_id] || '', String(value));
          } else if (b.type === 'data_state') {
            const pair = DATA_STATE_MODES[b.mode] || DATA_STATE_MODES[0];
            el.dataset.state = value ? pair[1] : pair[0];
          } else if (b.type === 'aria') {
            const attr = ARIA_ATTRS[b.attr_code] || ARIA_ATTRS[0];
            el.setAttribute(attr, value ? 'true' : 'false');
          } else if (b.type === 'modal') {
            if (value) {
              el.style.display = '';
              document.body.style.overflow = 'hidden';
            } else {
              el.style.display = 'none';
              document.body.style.overflow = '';
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
        const id = _strings.length;
        _strings.push(s);
        return id;
      },
      // ─── T31 BindBool/BindModal binding registration (71-73) ───
      register_data_state_binding: (el_id, signal_idx, mode) => {
        _bindings.push({ el_id, signal_idx, mode, type: 'data_state' });
      },
      register_aria_binding: (el_id, signal_idx, attr_code) => {
        _bindings.push({ el_id, signal_idx, attr_code, type: 'aria' });
      },
      register_modal_binding: (el_id, signal_idx, mode) => {
        _bindings.push({ el_id, signal_idx, mode, type: 'modal' });
      },
      // ─── T31 Per-child pattern support (74-75) ───
      get_event_data_index: () => {
        if (_currentEvent && _currentEvent.target && _currentEvent.target.dataset && _currentEvent.target.dataset.index !== undefined) {
          return parseInt(_currentEvent.target.dataset.index) || 0;
        }
        return 0;
      },
      register_match_binding: (el_id, signal_idx, match_value) => {
        _bindings.push({ el_id, signal_idx, match_value, type: 'match' });
      },
      // ─── T31 Per-child match/bit state bindings (76-79) ───
      register_match_data_state_binding: (el_id, signal_idx, match_value, mode) => {
        _bindings.push({ el_id, signal_idx, match_value, mode, type: 'match_data_state' });
      },
      register_match_aria_binding: (el_id, signal_idx, match_value, attr_code) => {
        _bindings.push({ el_id, signal_idx, match_value, attr_code, type: 'match_aria' });
      },
      register_bit_data_state_binding: (el_id, signal_idx, bit_index, mode) => {
        _bindings.push({ el_id, signal_idx, bit_index, mode, type: 'bit_data_state' });
      },
      register_bit_aria_binding: (el_id, signal_idx, bit_index, attr_code) => {
        _bindings.push({ el_id, signal_idx, bit_index, attr_code, type: 'bit_aria' });
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

    // Instantiate with circular reference for handler callbacks
    let instance = null;
    const imports = buildImports({ get exports() { return instance.exports; } });
    instance = await WebAssembly.instantiate(_moduleCache[name], imports);

    // Parse props (alphabetical key order)
    const props = JSON.parse(el.dataset.props || '{}');
    const propKeys = Object.keys(props).sort();
    _propValues = propKeys.map(k => props[k]);

    // Parse string table (for imports that use string IDs)
    _strings.length = 0;
    if (el.dataset.strings) {
      try { JSON.parse(el.dataset.strings).forEach(s => _strings.push(s)); } catch(e) {}
    }

    // Reset per-island state
    _cursor = el;
    _elements.length = 0;
    _bindings.length = 0;

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

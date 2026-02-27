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
                // mode: 0=dialog, 1=alert_dialog, 2=drawer, 3=popover, 4=tooltip (hover+floating), 5=hover_card (hover+floating+dismiss)
                // Modes 0-3: scroll lock, focus trap, etc. Modes 4-5: hover-based floating with timers.
                modal_state: (el, mode, state) => {
                    const island = elements[el];
                    if (!island) return;

                    // Mode 4 (tooltip) and Mode 5 (hover_card) — hover-based floating components
                    if (mode === 4 || mode === 5) {
                        const isTT = mode === 4;
                        const ct = island.querySelector(isTT ? '[data-suite-tooltip-content]' : '[data-suite-hover-card-content]');
                        if (!ct) return;
                        const tw = island.querySelector(isTT ? '[data-suite-tooltip-trigger-wrapper]' : '[data-suite-hover-card-trigger-wrapper]');
                        const trig = tw ? (tw.firstElementChild || tw) : null;

                        // Read positioning params from content data attributes
                        const pfx = isTT ? 'data-suite-tooltip' : 'data-suite-hover-card';
                        const side = ct.getAttribute(pfx + '-side') || (isTT ? 'top' : 'bottom');
                        const sideOff = parseInt(ct.getAttribute(pfx + '-side-offset') || '4', 10);
                        const align = ct.getAttribute(pfx + '-align') || 'center';
                        const pad = 4;

                        // Read delay
                        const prov = isTT ? island.closest('[data-suite-tooltip-provider]') : null;
                        const openDelay = isTT
                            ? parseInt((prov || island).getAttribute('data-suite-tooltip-delay') || '700', 10)
                            : parseInt(island.getAttribute('data-suite-hover-card-open-delay') || '700', 10);
                        const closeDelay = isTT ? 0 : parseInt(island.getAttribute('data-suite-hover-card-close-delay') || '300', 10);

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

                    const root = mode === 3
                        ? island.querySelector('[data-suite-popover-content]')
                        : island.querySelector('[style*="display:none"], [style*="display: none"]');
                    const overlay = island.querySelector('[data-suite-dialog-overlay], [data-suite-alert-dialog-overlay], [data-suite-sheet-overlay], [data-suite-drawer-overlay]');
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
                                target = content.querySelector('[data-suite-alert-dialog-cancel] button, [data-suite-alert-dialog-cancel]');
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
                                const btn = island.querySelector('[data-suite-dialog-close], [data-suite-sheet-close], [data-suite-drawer-close], [data-suite-popover-close]')
                                    || island.querySelector('[data-suite-popover-trigger-wrapper]');
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
                            const dir = content.getAttribute('data-suite-drawer-direction') || 'bottom';
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
                                    const btn = island.querySelector('[data-suite-drawer-close]');
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
                            const triggerWrap = island.querySelector('[data-suite-popover-trigger-wrapper]');
                            const trigger = triggerWrap ? (triggerWrap.firstElementChild || triggerWrap) : null;

                            // Read positioning params from content data attributes
                            const side = content.getAttribute('data-suite-popover-side') || 'bottom';
                            const sideOffset = parseInt(content.getAttribute('data-suite-popover-side-offset') || '0', 10);
                            const align = content.getAttribute('data-suite-popover-align') || 'center';
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
                                    const btn = island.querySelector('[data-suite-popover-close]')
                                        || island.querySelector('[data-suite-popover-trigger-wrapper]');
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
                            const dir = content.getAttribute('data-suite-drawer-direction') || 'bottom';
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

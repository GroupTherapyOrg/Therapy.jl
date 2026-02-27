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
                // mode: 0=dialog, 1=alert_dialog, 2=drawer, 3=popover, 4=tooltip, 5=hover_card, 6=dropdown_menu, 7=context_menu, 8=menubar, 9=nav_menu, 10=select, 11=command, 12=command_dialog
                // Modes 0-3: scroll lock, focus trap, etc. Modes 4-5: hover-based floating with timers. Modes 6-8: floating menu with keyboard nav. Mode 9: hover-timed nav panels. Mode 10: floating select. Mode 11: command filtering/nav. Mode 12: command dialog.
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
                            '[data-suite-menu-item], [data-suite-menu-checkbox-item], [data-suite-menu-radio-item], [data-suite-menu-sub-trigger]'
                        )).filter(el => !el.hasAttribute('data-disabled') && !el.closest('[data-suite-menu-sub-content]'));
                    }
                    function _mFocusItem(ct, item) {
                        _mGetItems(ct).forEach(i => i.removeAttribute('data-highlighted'));
                        if (item) { item.setAttribute('data-highlighted', ''); item.focus({ preventScroll: true }); }
                    }
                    function _mCloseSubmenu(st) {
                        const sc = st.parentElement && st.parentElement.querySelector('[data-suite-menu-sub-content]');
                        if (!sc) return;
                        st.setAttribute('data-state', 'closed'); sc.setAttribute('data-state', 'closed'); sc.style.display = 'none';
                        sc.querySelectorAll('[data-highlighted]').forEach(el => el.removeAttribute('data-highlighted'));
                        if (st._subCleanup) { st._subCleanup(); st._subCleanup = null; }
                    }
                    function _mOpenSubmenu(st, menuClose) {
                        const sc = st.parentElement && st.parentElement.querySelector('[data-suite-menu-sub-content]');
                        if (!sc) return;
                        st.setAttribute('data-state', 'open'); sc.style.display = ''; sc.setAttribute('data-state', 'open');
                        _mFloat(st, sc, 'right', -4, 'start', _mPad);
                        const subClean = _mActivate(sc, { onClose: () => { _mCloseSubmenu(st); subClean(); }, isSubmenu: true, menuClose: menuClose });
                        requestAnimationFrame(() => { const items = _mGetItems(sc); if (items.length > 0) _mFocusItem(sc, items[0]); });
                        st._subCleanup = subClean;
                    }
                    function _mSelectItem(item, ct, menuClose) {
                        if (!item || item.hasAttribute('data-disabled')) return;
                        if (item.hasAttribute('data-suite-menu-checkbox-item')) {
                            const ck = item.getAttribute('data-state') === 'checked';
                            item.setAttribute('data-state', ck ? 'unchecked' : 'checked'); item.setAttribute('aria-checked', String(!ck));
                            const ind = item.querySelector('[data-suite-menu-item-indicator]'); if (ind) ind.style.display = ck ? 'none' : '';
                            return;
                        }
                        if (item.hasAttribute('data-suite-menu-radio-item')) {
                            const grp = item.closest('[data-suite-menu-radio-group]');
                            if (grp) { grp.querySelectorAll('[data-suite-menu-radio-item]').forEach(ri => { ri.setAttribute('data-state', 'unchecked'); ri.setAttribute('aria-checked', 'false'); const ind = ri.querySelector('[data-suite-menu-item-indicator]'); if (ind) ind.style.display = 'none'; }); }
                            item.setAttribute('data-state', 'checked'); item.setAttribute('aria-checked', 'true');
                            const ind = item.querySelector('[data-suite-menu-item-indicator]'); if (ind) ind.style.display = '';
                            return;
                        }
                        if (item.hasAttribute('data-suite-menu-sub-trigger')) { _mOpenSubmenu(item, menuClose); return; }
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
                            if (e.key === 'ArrowRight') { if (cur && cur.hasAttribute('data-suite-menu-sub-trigger')) { e.preventDefault(); _mOpenSubmenu(cur, menuClose); return; } if (onNavR) { e.preventDefault(); onNavR(); return; } }
                            if (e.key === 'ArrowLeft') { if (isSubmenu) { e.preventDefault(); onClose(); return; } if (onNavL) { e.preventDefault(); onNavL(); return; } }
                            if (e.key === 'Enter' || (e.key === ' ' && sBuf === '')) { e.preventDefault(); if (cur) _mSelectItem(cur, ct, menuClose); return; }
                            if (e.key.length === 1 && !e.ctrlKey && !e.altKey && !e.metaKey) { e.preventDefault(); ta(e.key); }
                        }
                        function onPM(e) { if (e.pointerType === 'touch' || e.pointerType === 'pen') return; const item = e.target.closest('[data-suite-menu-item], [data-suite-menu-checkbox-item], [data-suite-menu-radio-item], [data-suite-menu-sub-trigger]'); if (item && !item.hasAttribute('data-disabled') && ct.contains(item) && !item.closest('[data-suite-menu-sub-content]')) _mFocusItem(ct, item); }
                        function onPL(e) { if (e.pointerType === 'touch' || e.pointerType === 'pen') return; _mGetItems(ct).forEach(i => i.removeAttribute('data-highlighted')); ct.focus({ preventScroll: true }); }
                        function onCK(e) { const item = e.target.closest('[data-suite-menu-item], [data-suite-menu-checkbox-item], [data-suite-menu-radio-item], [data-suite-menu-sub-trigger]'); if (item && ct.contains(item) && !item.closest('[data-suite-menu-sub-content]')) _mSelectItem(item, ct, menuClose); }
                        ct.addEventListener('keydown', onKD); ct.addEventListener('pointermove', onPM); ct.addEventListener('pointerleave', onPL); ct.addEventListener('click', onCK);
                        return function() { ct.removeEventListener('keydown', onKD); ct.removeEventListener('pointermove', onPM); ct.removeEventListener('pointerleave', onPL); ct.removeEventListener('click', onCK); clearTimeout(sTmr); sBuf = ''; ct.querySelectorAll('[data-suite-menu-sub-trigger]').forEach(st => { if (st._subCleanup) { st._subCleanup(); st._subCleanup = null; } }); };
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
                        const tw = island.querySelector('[data-suite-dropdown-menu-trigger-wrapper]');
                        const trigger = tw ? (tw.firstElementChild || tw) : null;
                        const content = island.querySelector('[data-suite-dropdown-menu-content]');
                        if (!trigger || !content) return;
                        const dSide = content.getAttribute('data-side-preference') || 'bottom';
                        const dSideOff = parseInt(content.getAttribute('data-side-offset') || '4', 10);
                        const dAlign = content.getAttribute('data-align-preference') || 'start';

                        if (state) {
                            if (island._menuOpen) return;
                            island._menuOpen = true; island._modalPrev = document.activeElement;
                            content.style.visibility = 'hidden'; content.style.display = ''; content.setAttribute('data-state', 'open');
                            requestAnimationFrame(() => { _mFloat(trigger, content, dSide, dSideOff, dAlign, _mPad); content.style.visibility = ''; });
                            function doMenuClose() { const btn = island.querySelector('[data-suite-dropdown-menu-trigger-wrapper]'); if (btn) btn.click(); }
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
                        const tw = island.querySelector('[data-suite-context-menu-trigger-wrapper]');
                        const trigEl = tw ? (tw.firstElementChild || tw) : null;
                        const content = island.querySelector('[data-suite-context-menu-content]');
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
                        const bar = island.querySelector('[data-suite-menubar]') || island;
                        const loop = bar.getAttribute('data-loop') !== 'false';
                        const menuEls = Array.from(bar.querySelectorAll('[data-suite-menubar-menu]'));
                        const trigMarkers = Array.from(bar.querySelectorAll('[data-suite-menubar-trigger-marker]'));
                        function getTrigBtns() { return Array.from(bar.querySelectorAll('[data-suite-menubar-trigger]')).filter(t => !t.hasAttribute('data-disabled')); }

                        // Install one-time behaviors
                        if (!island._mbInstalled) {
                            island._mbInstalled = true;
                            // Roving tabindex init
                            const btns = getTrigBtns();
                            btns.forEach((t, i) => t.setAttribute('tabindex', i === 0 ? '0' : '-1'));
                            // Per-trigger: hover-switch + keyboard nav
                            trigMarkers.forEach((marker, mi) => {
                                const btn = marker.querySelector('[data-suite-menubar-trigger]') || marker.firstElementChild;
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
                                const pTrig = pMenu.querySelector('[data-suite-menubar-trigger]');
                                const pCont = pMenu.querySelector('[data-suite-menubar-content]');
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
                            const trig = mEl.querySelector('[data-suite-menubar-trigger]');
                            const cont = mEl.querySelector('[data-suite-menubar-content]');
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
                                const nextMarker = nextBtn.closest('[data-suite-menubar-trigger-marker]');
                                if (nextMarker) { ts.forEach(b => b.setAttribute('tabindex', '-1')); nextBtn.setAttribute('tabindex', '0'); nextBtn.focus({ preventScroll: true }); nextMarker.click(); }
                            }
                            island._menuCleanup = _mActivate(cont, { onClose: () => { const mk = trig.closest('[data-suite-menubar-trigger-marker]'); if (mk) mk.click(); }, menuClose: () => { const mk = trig.closest('[data-suite-menubar-trigger-marker]'); if (mk) mk.click(); }, onNavigateLeft: () => navMenubar(-1), onNavigateRight: () => navMenubar(1) });
                            requestAnimationFrame(() => { const items = _mGetItems(cont); if (items.length > 0) _mFocusItem(cont, items[0]); });
                            island._menuScroll = () => _mFloat(trig, cont, cSide, cOff, cAlign, _mPad); island._menuResize = island._menuScroll;
                            window.addEventListener('scroll', island._menuScroll, true); window.addEventListener('resize', island._menuResize);
                            // Click-outside dismiss (exclude all trigger markers)
                            island._menuOutside = (e) => { if (!cont.contains(e.target) && !trigMarkers.some(m => m.contains(e.target))) { const mk = trig.closest('[data-suite-menubar-trigger-marker]'); if (mk) mk.click(); } };
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
                        const navRoot = island.querySelector('[data-suite-nav-menu]') || island;
                        const markers = Array.from(navRoot.querySelectorAll('[data-suite-nav-menu-trigger-marker]'));
                        const indicator = navRoot.querySelector('[data-suite-nav-menu-indicator]');
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
                                const trigger = marker.querySelector('[data-suite-nav-menu-trigger]') || marker.firstElementChild;
                                const item = marker.closest('[data-suite-nav-menu-item]');
                                const content = item ? item.querySelector('[data-suite-nav-menu-content]') : null;
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
                                        const trig = mk.querySelector('[data-suite-nav-menu-trigger]') || mk.firstElementChild;
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
                        const allItems = Array.from(navRoot.querySelectorAll('[data-suite-nav-menu-item]'));

                        function _navParts(i) {
                            if (i <= 0 || i > markers.length) return null;
                            const mk = markers[i - 1];
                            const it = mk.closest('[data-suite-nav-menu-item]');
                            const tr = mk.querySelector('[data-suite-nav-menu-trigger]') || mk.firstElementChild;
                            const ct = it ? it.querySelector('[data-suite-nav-menu-content]') : null;
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
                                const list = navRoot.querySelector('[data-suite-nav-menu-list]');
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
                                const it = mk.closest('[data-suite-nav-menu-item]');
                                const tr = mk.querySelector('[data-suite-nav-menu-trigger]') || mk.firstElementChild;
                                const ct = it ? it.querySelector('[data-suite-nav-menu-content]') : null;
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
                        const tw = island.querySelector('[data-suite-select-trigger-wrapper]');
                        const trigger = tw ? (tw.firstElementChild || tw) : null;
                        const content = island.querySelector('[data-suite-select-content]');
                        if (!trigger || !content) return;
                        const selRoot = island.firstElementChild || island;
                        if (!island._selInstalled) {
                            island._selInstalled = true;
                            island._selHL = null; island._selTS = ''; island._selTT = null;
                            island._selVal = selRoot.getAttribute('data-suite-select-value') || '';
                            function selGetItems() { return Array.from(content.querySelectorAll('[data-suite-select-item]:not([data-disabled])')); }
                            function selHL(item) {
                                if (island._selHL) island._selHL.removeAttribute('data-highlighted');
                                island._selHL = item;
                                if (item) { item.setAttribute('data-highlighted', ''); item.focus(); }
                            }
                            function selUpdateDisplay() {
                                const disp = trigger.querySelector('[data-suite-select-display]');
                                if (!disp) return;
                                content.querySelectorAll('[data-suite-select-item]').forEach(item => {
                                    const v = item.getAttribute('data-suite-select-item-value') || '';
                                    if (v === island._selVal && island._selVal !== '') {
                                        const txt = item.querySelector('[data-suite-select-item-text-content]');
                                        disp.textContent = txt ? txt.textContent : item.textContent.trim();
                                        disp.removeAttribute('data-placeholder');
                                        item.setAttribute('data-state', 'checked'); item.setAttribute('aria-selected', 'true');
                                        const ind = item.querySelector('[data-suite-select-item-indicator]'); if (ind) ind.style.display = '';
                                    } else {
                                        item.setAttribute('data-state', 'unchecked'); item.setAttribute('aria-selected', 'false');
                                        const ind = item.querySelector('[data-suite-select-item-indicator]'); if (ind) ind.style.display = 'none';
                                    }
                                });
                            }
                            function selSelect(item) {
                                if (!item) return;
                                island._selVal = item.getAttribute('data-suite-select-item-value') || '';
                                selRoot.setAttribute('data-suite-select-value', island._selVal);
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
                                    const txt = items[idx].querySelector('[data-suite-select-item-text-content]');
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
                            content.addEventListener('pointerup', (e) => { const item = e.target.closest('[data-suite-select-item]:not([data-disabled])'); if (item && content.contains(item)) selSelect(item); });
                            content.addEventListener('pointermove', (e) => { const item = e.target.closest('[data-suite-select-item]:not([data-disabled])'); if (item && content.contains(item)) selHL(item); });
                            const su = content.querySelector('[data-suite-select-scroll-up]'), sd = content.querySelector('[data-suite-select-scroll-down]');
                            let sInt = null;
                            if (su) { su.addEventListener('pointerdown', () => { sInt = setInterval(() => { content.scrollTop -= 32; }, 50); }); su.addEventListener('pointerup', () => clearInterval(sInt)); su.addEventListener('pointerleave', () => clearInterval(sInt)); }
                            if (sd) { sd.addEventListener('pointerdown', () => { sInt = setInterval(() => { content.scrollTop += 32; }, 50); }); sd.addEventListener('pointerup', () => clearInterval(sInt)); sd.addEventListener('pointerleave', () => clearInterval(sInt)); }
                            selUpdateDisplay();
                        }
                        if (state) {
                            if (island._selOpen) return;
                            if (selRoot.hasAttribute('data-disabled')) return;
                            island._selOpen = true; island._modalPrev = document.activeElement;
                            const dSide = content.getAttribute('data-suite-select-side') || 'bottom';
                            const dOff = parseInt(content.getAttribute('data-suite-select-side-offset') || '4', 10);
                            const dAlign = content.getAttribute('data-suite-select-align') || 'start';
                            trigger.setAttribute('data-state', 'open'); trigger.setAttribute('aria-expanded', 'true');
                            content.style.visibility = 'hidden'; content.style.display = ''; content.setAttribute('data-state', 'open');
                            requestAnimationFrame(() => {
                                _mFloat(trigger, content, dSide, dOff, dAlign, _mPad); content.style.visibility = '';
                                const items = Array.from(content.querySelectorAll('[data-suite-select-item]:not([data-disabled])'));
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
                            const shouldFilter = cmdRoot.getAttribute('data-suite-command-filter') !== 'false';
                            const loop = cmdRoot.getAttribute('data-suite-command-loop') !== 'false';
                            const input = island.querySelector('[data-suite-command-input]');
                            const emptyEl = island.querySelector('[data-suite-command-empty]');
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
                            function cmdGetItems() { return Array.from(island.querySelectorAll('[data-suite-command-item]:not([data-disabled="true"])')); }
                            function cmdGetVisible() { return cmdGetItems().filter(i => i.style.display !== 'none'); }
                            function cmdHL(item) {
                                if (selItem) { selItem.setAttribute('data-selected', 'false'); selItem.setAttribute('aria-selected', 'false'); }
                                selItem = item;
                                if (item) { item.setAttribute('data-selected', 'true'); item.setAttribute('aria-selected', 'true'); item.scrollIntoView({ block: 'nearest' }); }
                            }
                            function cmdFilter(search) {
                                if (!shouldFilter || !search) {
                                    island.querySelectorAll('[data-suite-command-item]').forEach(i => { i.style.display = ''; });
                                    island.querySelectorAll('[data-suite-command-group]').forEach(g => { g.style.display = ''; });
                                    if (emptyEl) emptyEl.style.display = 'none';
                                    cmdHL(cmdGetVisible()[0] || null); return;
                                }
                                island.querySelectorAll('[data-suite-command-item]').forEach(item => {
                                    const v = item.getAttribute('data-suite-command-item-value') || item.textContent.trim();
                                    const kw = item.getAttribute('data-suite-command-item-keywords') || '';
                                    const st = kw ? v + ' ' + kw.replace(/,/g, ' ') : v;
                                    item.style.display = cmdScore(st, search) > 0 ? '' : 'none';
                                });
                                island.querySelectorAll('[data-suite-command-group]').forEach(g => {
                                    g.style.display = g.querySelector('[data-suite-command-item]:not([style*="display: none"])') ? '' : 'none';
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
                            island.addEventListener('click', (e) => { const item = e.target.closest('[data-suite-command-item]:not([data-disabled="true"])'); if (item && island.contains(item)) cmdHL(item); });
                            island.addEventListener('pointermove', (e) => { const item = e.target.closest('[data-suite-command-item]:not([data-disabled="true"])'); if (item && island.contains(item)) cmdHL(item); });
                            cmdFilter('');
                        }
                        return;
                    }

                    // Mode 12: command_dialog — dialog wrapper for command palette
                    if (mode === 12) {
                        const dlg = island.querySelector('[data-suite-command-dialog]') || island;
                        const overlay = dlg.querySelector('[data-suite-command-dialog-overlay]');
                        const marker = island.querySelector('[data-suite-command-dialog-trigger-marker]');
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
                            const cmdInput = dlg.querySelector('[data-suite-command-input]');
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

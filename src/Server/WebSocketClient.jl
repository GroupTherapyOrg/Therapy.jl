# WebSocketClient.jl - Client-side WebSocket JavaScript generation
#
# Generates JavaScript that connects to the Therapy.jl WebSocket server,
# handles reconnection, and updates signals in real-time.

using JSON3
# Note: RawHtml is available from SSR/Render.jl which is included before this file

"""
    websocket_client_script(; signals, reconnect_delay, max_reconnect_delay)

Generate client-side JavaScript for WebSocket connectivity.

# Arguments
- `signals::Vector{String}`: Signal names to auto-subscribe to on connect
- `reconnect_delay::Int`: Initial reconnect delay in ms (default: 1000)
- `max_reconnect_delay::Int`: Maximum reconnect delay in ms (default: 30000)

# Features
- Auto-connects to ws://host/ws on page load
- Exponential backoff reconnection
- Graceful degradation: shows warning on static sites (no server)
- Updates Wasm signals on server updates
- Exposes window.TherapyWS API for programmatic use
"""
function websocket_client_script(;
    signals::Vector{String}=String[],
    reconnect_delay::Int=1000,
    max_reconnect_delay::Int=30000
)
    signals_json = JSON3.write(signals)

    RawHtml("""
<script>
// Therapy.jl WebSocket Client
(function() {
    'use strict';

    // CRITICAL: Prevent re-execution during SPA navigation
    // ClientRouter extracts and re-executes scripts containing 'TherapyWS' after each navigation.
    // Without this guard, each navigation creates a NEW scope with its own `let ws = null`,
    // causing the duplicate connection check (ws.readyState) to fail and create new connections.
    // This single check fixes the WebSocket connection leak issue.
    if (window.TherapyWS) {
        console.log('[WS] Script already executed, skipping re-initialization');
        return;
    }

    const CONFIG = {
        reconnectDelay: $reconnect_delay,
        maxReconnectDelay: $max_reconnect_delay,
        signals: $signals_json
    };

    let ws = null;
    let reconnectAttempts = 0;
    let connectionId = null;
    let isStaticMode = false;

    // Dev mode: localhost/127.0.0.1 gets exponential backoff reconnection.
    // Production: non-localhost gets fast static mode detection (1 retry).
    const isDevMode = (window.location.hostname === 'localhost' ||
                       window.location.hostname === '127.0.0.1');

    // Track signal values for patch application
    let signalValues = {};

    /**
     * Get WebSocket URL based on current page protocol
     */
    function getWsUrl() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        return protocol + '//' + window.location.host + '/ws';
    }

    /**
     * Connect to WebSocket server
     */
    function connect() {
        if (isStaticMode) return;

        // Prevent duplicate connections - check if already connected or connecting
        // This fixes connection leaks during SPA navigation
        if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
            return;
        }

        try {
            ws = new WebSocket(getWsUrl());

            ws.onopen = function() {
                console.log('[WS] Connected to server');
                reconnectAttempts = 0;

                // Subscribe to configured signals
                CONFIG.signals.forEach(function(sig) {
                    subscribe(sig);
                });

                // Auto-discover and subscribe to signals from data-server-signal attributes
                discoverAndSubscribe();

                // Dispatch connected event
                window.dispatchEvent(new CustomEvent('therapy:ws:connected'));
            };

            ws.onmessage = function(e) {
                try {
                    const msg = JSON.parse(e.data);
                    handleMessage(msg);
                } catch (err) {
                    console.warn('[WS] Failed to parse message:', e.data);
                }
            };

            ws.onclose = function(e) {
                connectionId = null;

                // Dispatch disconnected event
                window.dispatchEvent(new CustomEvent('therapy:ws:disconnected'));

                // Attempt reconnect unless it was a clean close
                if (e.code !== 1000) {
                    if (isDevMode) {
                        // Dev server: exponential backoff reconnection
                        // Handles server restarts, code changes, crashes
                        scheduleReconnect();
                    } else if (reconnectAttempts >= 1) {
                        // Production: two failures → static hosting, stop trying
                        showStaticModeWarning();
                    } else {
                        // Production: first failure → retry once quickly
                        reconnectAttempts++;
                        setTimeout(connect, 500);
                    }
                }
            };

            ws.onerror = function(err) {
                // Dev mode: log connection errors for debugging
                if (isDevMode) {
                    console.warn('[WS] Connection error - server may not be running');
                }
                // Production: suppress verbose logs during static mode detection
            };

        } catch (e) {
            showStaticModeWarning();
        }
    }

    /**
     * Schedule a reconnection attempt with exponential backoff (dev mode only)
     */
    function scheduleReconnect() {
        if (isStaticMode) return;

        const delay = Math.min(
            CONFIG.reconnectDelay * Math.pow(2, reconnectAttempts),
            CONFIG.maxReconnectDelay
        );
        reconnectAttempts++;

        console.log('[WS] Reconnecting in', delay, 'ms (attempt', reconnectAttempts + ')');
        setTimeout(connect, delay);
    }

    /**
     * Handle incoming WebSocket message
     */
    function handleMessage(msg) {
        switch (msg.type) {
            case 'connected':
                connectionId = msg.connection_id;
                console.log('[WS] Connection ID:', connectionId);
                break;

            case 'signal_update':
                handleSignalUpdate(msg.signal, msg.value);
                break;

            case 'signal_patch':
                handleSignalPatch(msg.signal, msg.patch);
                break;

            case 'channel_message':
                handleChannelMessage(msg.channel, msg.data);
                break;

            case 'error':
                console.error('[WS] Server error:', msg.message);
                break;

            case 'pong':
                // Keepalive response, ignore
                break;

            default:
                console.log('[WS] Unknown message type:', msg.type, msg);
        }
    }

    /**
     * Handle a signal update from the server (full value)
     */
    function handleSignalUpdate(signalName, value) {
        console.log('[WS] Signal update:', signalName, '=', value);

        // Store the value for future patch application
        signalValues[signalName] = value;

        // Update via TherapySignals if available (Wasm integration)
        if (window.TherapySignals && window.TherapySignals[signalName]) {
            window.TherapySignals[signalName].set(value);
        }

        // Also update DOM elements with data-server-signal attribute
        updateSignalDOM(signalName, value);

        // Dispatch custom event for custom handlers
        window.dispatchEvent(new CustomEvent('therapy:signal:' + signalName, {
            detail: { value: value }
        }));
    }

    /**
     * Handle a signal patch from the server (RFC 6902 JSON Patch)
     */
    function handleSignalPatch(signalName, patch) {
        console.log('[WS] Signal patch:', signalName, patch);

        // Get current value or initialize
        let value = signalValues[signalName];
        if (value === undefined) {
            value = null;
        }

        // Apply each patch operation
        for (const op of patch) {
            value = applyPatchOp(value, op);
        }

        // Store the new value
        signalValues[signalName] = value;

        // Update via TherapySignals if available (Wasm integration)
        if (window.TherapySignals && window.TherapySignals[signalName]) {
            window.TherapySignals[signalName].set(value);
        }

        // Update DOM elements
        updateSignalDOM(signalName, value);

        // Dispatch custom event
        window.dispatchEvent(new CustomEvent('therapy:signal:' + signalName, {
            detail: { value: value }
        }));
    }

    /**
     * Apply a single JSON patch operation (RFC 6902)
     */
    function applyPatchOp(value, op) {
        const path = op.path;
        const operation = op.op;

        // Root replacement
        if (path === '' || path === '/') {
            if (operation === 'replace' || operation === 'add') {
                return op.value;
            }
            return null;
        }

        // Parse path: "/foo/bar/0" -> ["foo", "bar", "0"]
        const parts = path.split('/').filter(p => p !== '');

        // Handle nested path
        if (operation === 'add' || operation === 'replace') {
            return setAtPath(value, parts, op.value);
        } else if (operation === 'remove') {
            return removeAtPath(value, parts);
        }

        return value;
    }

    /**
     * Set a value at a nested path in an object/array
     */
    function setAtPath(obj, parts, newValue) {
        if (!obj) {
            obj = {};
        }
        if (parts.length === 0) {
            return newValue;
        }

        // Clone to avoid mutation
        obj = JSON.parse(JSON.stringify(obj));

        let current = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            const part = parts[i];
            if (Array.isArray(current)) {
                const idx = parseInt(part, 10);
                if (!current[idx]) {
                    current[idx] = {};
                }
                current = current[idx];
            } else {
                if (!current[part]) {
                    current[part] = {};
                }
                current = current[part];
            }
        }

        const finalPart = parts[parts.length - 1];
        if (Array.isArray(current)) {
            const idx = finalPart === '-' ? current.length : parseInt(finalPart, 10);
            current[idx] = newValue;
        } else {
            current[finalPart] = newValue;
        }

        return obj;
    }

    /**
     * Remove a value at a nested path
     */
    function removeAtPath(obj, parts) {
        if (!obj || parts.length === 0) {
            return obj;
        }

        // Clone to avoid mutation
        obj = JSON.parse(JSON.stringify(obj));

        let current = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            const part = parts[i];
            if (Array.isArray(current)) {
                current = current[parseInt(part, 10)];
            } else {
                current = current[part];
            }
            if (!current) return obj;
        }

        const finalPart = parts[parts.length - 1];
        if (Array.isArray(current)) {
            current.splice(parseInt(finalPart, 10), 1);
        } else {
            delete current[finalPart];
        }

        return obj;
    }

    /**
     * Update DOM elements with data-server-signal or data-bidirectional-signal attribute
     * Leptos-style reactive bindings:
     * - data-server-signal="name" - updates textContent/value
     * - data-signal-html="name" - updates innerHTML (for rich content)
     * - data-signal-class="name:class1,class2" - adds classes when signal is truthy
     * - data-signal-match="name:value:class" - adds class when signal equals value
     */
    function updateSignalDOM(signalName, value) {
        // Update read-only server signal elements (textContent)
        document.querySelectorAll('[data-server-signal="' + signalName + '"]').forEach(function(el) {
            if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                el.value = value;
            } else {
                el.textContent = value;
            }
        });

        // Update innerHTML bindings (for rich HTML content like cell output)
        document.querySelectorAll('[data-signal-html="' + signalName + '"]').forEach(function(el) {
            el.innerHTML = value || '';
            // Show/hide based on content
            if (el.hasAttribute('data-signal-hide-empty')) {
                el.classList.toggle('hidden', !value);
            }
        });

        // Update class bindings (add classes when signal is truthy)
        document.querySelectorAll('[data-signal-class^="' + signalName + ':"]').forEach(function(el) {
            const binding = el.getAttribute('data-signal-class');
            const [, classes] = binding.split(':');
            if (classes) {
                const classList = classes.split(',').map(c => c.trim()).filter(c => c);
                if (value) {
                    el.classList.add(...classList);
                } else {
                    el.classList.remove(...classList);
                }
            }
        });

        // Update match bindings (add class when signal equals specific value)
        // Format: data-signal-match="signalName:matchValue:className"
        document.querySelectorAll('[data-signal-match]').forEach(function(el) {
            const bindings = el.getAttribute('data-signal-match').split(';');
            bindings.forEach(function(binding) {
                const parts = binding.trim().split(':');
                if (parts.length >= 3 && parts[0] === signalName) {
                    const matchValue = parts[1];
                    const className = parts[2];
                    if (String(value) === matchValue) {
                        el.classList.add(className);
                    } else {
                        el.classList.remove(className);
                    }
                }
            });
        });

        // Update bidirectional signal elements (only if not focused, to avoid cursor jump)
        document.querySelectorAll('[data-bidirectional-signal="' + signalName + '"]').forEach(function(el) {
            if (document.activeElement === el) {
                // Don't update if user is currently typing in this element
                return;
            }
            if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                el.value = value;
            } else {
                el.textContent = value;
            }
        });
    }

    /**
     * Compute a JSON patch between old and new values (client-side)
     * Simplified version - handles basic types
     */
    function computePatch(oldValue, newValue) {
        const patches = [];

        // Handle simple values
        if (typeof oldValue !== 'object' || typeof newValue !== 'object' ||
            oldValue === null || newValue === null ||
            Array.isArray(oldValue) !== Array.isArray(newValue)) {
            if (oldValue !== newValue) {
                patches.push({ op: 'replace', path: '', value: newValue });
            }
            return patches;
        }

        // Handle objects
        if (!Array.isArray(newValue)) {
            // Added or changed keys
            for (const key of Object.keys(newValue)) {
                if (!(key in oldValue)) {
                    patches.push({ op: 'add', path: '/' + key, value: newValue[key] });
                } else if (JSON.stringify(oldValue[key]) !== JSON.stringify(newValue[key])) {
                    patches.push({ op: 'replace', path: '/' + key, value: newValue[key] });
                }
            }
            // Removed keys
            for (const key of Object.keys(oldValue)) {
                if (!(key in newValue)) {
                    patches.push({ op: 'remove', path: '/' + key });
                }
            }
            return patches;
        }

        // For arrays, just replace if different (computing array diff is complex)
        if (JSON.stringify(oldValue) !== JSON.stringify(newValue)) {
            patches.push({ op: 'replace', path: '', value: newValue });
        }
        return patches;
    }

    /**
     * Update a bidirectional signal from the client
     * Sends changes to server, which validates and broadcasts to other clients
     */
    function setBidirectional(signalName, newValue) {
        if (!ws || ws.readyState !== WebSocket.OPEN) {
            console.warn('[WS] Cannot update signal - not connected');
            return false;
        }

        // Get current value
        const oldValue = signalValues[signalName];

        // Compute patch
        const patch = computePatch(oldValue, newValue);

        if (patch.length === 0) {
            return true; // No change needed
        }

        // Optimistic update - update local state immediately
        signalValues[signalName] = newValue;
        updateSignalDOM(signalName, newValue);

        // Send patch to server
        send({
            type: 'bidirectional_update',
            signal: signalName,
            patch: patch
        });

        console.log('[WS] Bidirectional update:', signalName, patch);
        return true;
    }

    /**
     * Get current value of a signal (for use before setBidirectional)
     */
    function getSignalValue(signalName) {
        return signalValues[signalName];
    }

    /**
     * Handle a channel message from the server
     */
    function handleChannelMessage(channelName, data) {
        console.log('[WS] Channel message:', channelName, data);

        // Dispatch custom event for this channel
        window.dispatchEvent(new CustomEvent('therapy:channel:' + channelName, {
            detail: data
        }));

        // Also dispatch a general channel event
        window.dispatchEvent(new CustomEvent('therapy:channel', {
            detail: { channel: channelName, data: data }
        }));
    }

    /**
     * Send a message on a channel
     */
    function sendMessage(channelName, data) {
        if (!ws || ws.readyState !== WebSocket.OPEN) {
            console.warn('[WS] Cannot send message - not connected');
            return false;
        }

        send({
            type: 'channel_message',
            channel: channelName,
            data: data
        });

        console.log('[WS] Sent channel message:', channelName, data);
        return true;
    }

    /**
     * Subscribe to channel messages (convenience for addEventListener)
     */
    function onChannelMessage(channelName, callback) {
        window.addEventListener('therapy:channel:' + channelName, function(e) {
            callback(e.detail);
        });
    }

    /**
     * Add warning banner to a single ws-example element
     */
    function addWarningToElement(el) {
        if (el.querySelector('.ws-warning')) return;

        const warning = document.createElement('div');
        warning.className = 'ws-warning';
        warning.style.cssText = 'background: linear-gradient(135deg, #fef3c7, #fde68a); border: 1px solid #f59e0b; border-radius: 8px; padding: 16px; margin-bottom: 16px; color: #92400e;';
        warning.innerHTML = '<strong style="display: block; margin-bottom: 4px;">\\u26A0\\uFE0F Live Demo Unavailable</strong>' +
            '<span style="font-size: 14px;">This example requires a WebSocket server. Run locally with:</span>' +
            '<code style="display: block; margin-top: 8px; padding: 8px; background: rgba(0,0,0,0.1); border-radius: 4px; font-family: monospace;">julia docs/app.jl dev</code>';
        el.insertBefore(warning, el.firstChild);
    }

    /**
     * Show warning when running in static mode (no WebSocket server)
     */
    function showStaticModeWarning() {
        if (isStaticMode) return;
        isStaticMode = true;

        console.log('[WS] Static mode detected - WebSocket features unavailable');

        // Find all WebSocket example containers and add warning
        document.querySelectorAll('[data-ws-example]').forEach(addWarningToElement);

        // Dispatch static mode event
        window.dispatchEvent(new CustomEvent('therapy:ws:static_mode'));
    }

    /**
     * Add warnings to any new ws-example elements loaded after static mode was detected
     * Called by ClientRouter after SPA navigation
     */
    function showStaticModeWarningOnNewElements() {
        if (!isStaticMode) return;

        // Find any new ws-example elements that don't have warnings yet
        document.querySelectorAll('[data-ws-example]').forEach(addWarningToElement);
    }

    // Track subscribed signals to avoid duplicates
    let subscribedSignals = new Set();

    /**
     * Subscribe to a server signal
     */
    function subscribe(signalName) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            if (!subscribedSignals.has(signalName)) {
                subscribedSignals.add(signalName);
                ws.send(JSON.stringify({
                    type: 'subscribe',
                    signal: signalName
                }));
            }
        }
    }

    /**
     * Discover and subscribe to signals from all reactive data attributes
     * Called on connect and after SPA navigation
     */
    function discoverAndSubscribe() {
        // Subscribe to read-only server signals
        document.querySelectorAll('[data-server-signal]').forEach(function(el) {
            var signalName = el.getAttribute('data-server-signal');
            if (signalName && !subscribedSignals.has(signalName)) {
                console.log('[WS] Auto-subscribing to:', signalName);
                subscribe(signalName);
            }
        });

        // Subscribe to bidirectional signals (also need to receive updates)
        document.querySelectorAll('[data-bidirectional-signal]').forEach(function(el) {
            var signalName = el.getAttribute('data-bidirectional-signal');
            if (signalName && !subscribedSignals.has(signalName)) {
                console.log('[WS] Auto-subscribing to bidirectional:', signalName);
                subscribe(signalName);
            }
        });

        // Subscribe to HTML signal bindings (innerHTML updates for rich content)
        document.querySelectorAll('[data-signal-html]').forEach(function(el) {
            var signalName = el.getAttribute('data-signal-html');
            if (signalName && !subscribedSignals.has(signalName)) {
                console.log('[WS] Auto-subscribing to html signal:', signalName);
                subscribe(signalName);
            }
        });

        // Subscribe to class match bindings (parse signal names from pattern)
        // Format: "signalName:value:class;signalName2:value2:class2"
        document.querySelectorAll('[data-signal-match]').forEach(function(el) {
            var pattern = el.getAttribute('data-signal-match');
            if (pattern) {
                // Extract unique signal names from pattern
                var parts = pattern.split(';');
                parts.forEach(function(part) {
                    var signalName = part.split(':')[0];
                    if (signalName && !subscribedSignals.has(signalName)) {
                        console.log('[WS] Auto-subscribing to match signal:', signalName);
                        subscribe(signalName);
                    }
                });
            }
        });

        // Subscribe to class toggle bindings
        // Format: "signalName:class1,class2"
        document.querySelectorAll('[data-signal-class]').forEach(function(el) {
            var binding = el.getAttribute('data-signal-class');
            if (binding) {
                var signalName = binding.split(':')[0];
                if (signalName && !subscribedSignals.has(signalName)) {
                    console.log('[WS] Auto-subscribing to class signal:', signalName);
                    subscribe(signalName);
                }
            }
        });
    }

    /**
     * Unsubscribe from a server signal
     */
    function unsubscribe(signalName) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
                type: 'unsubscribe',
                signal: signalName
            }));
        }
    }

    /**
     * Send a custom action to the server
     */
    function sendAction(signalName, action, payload) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
                type: 'action',
                signal: signalName,
                action: action,
                payload: payload
            }));
        }
    }

    /**
     * Send raw message to server
     */
    function send(msg) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(msg));
        }
    }

    /**
     * Check if WebSocket is connected
     */
    function isConnected() {
        return ws && ws.readyState === WebSocket.OPEN;
    }

    /**
     * Get current connection ID
     */
    function getConnectionId() {
        return connectionId;
    }

    /**
     * Manually disconnect
     */
    function disconnect() {
        if (ws) {
            ws.close(1000, 'Client disconnect');
            ws = null;
        }
    }

    // Expose API globally
    window.TherapyWS = {
        connect: connect,
        disconnect: disconnect,
        subscribe: subscribe,
        unsubscribe: unsubscribe,
        discoverAndSubscribe: discoverAndSubscribe,
        showStaticModeWarningOnNewElements: showStaticModeWarningOnNewElements,
        sendAction: sendAction,
        send: send,
        isConnected: isConnected,
        getConnectionId: getConnectionId,
        isStaticMode: function() { return isStaticMode; },
        // Bidirectional signals
        setBidirectional: setBidirectional,
        getSignalValue: getSignalValue,
        computePatch: computePatch,
        // Channel messaging
        sendMessage: sendMessage,
        onChannelMessage: onChannelMessage
    };

    /**
     * Handle data-action clicks (Leptos-style server actions)
     * Elements with data-action="channelName" send channel messages on click
     * Additional data-* attributes are included in the message payload
     */
    function setupActionHandlers() {
        document.addEventListener('click', function(e) {
            const el = e.target.closest('[data-action]');
            if (!el) return;

            const action = el.getAttribute('data-action');
            if (!action) return;

            // Collect all data-* attributes as payload
            const payload = {};
            for (const attr of el.attributes) {
                if (attr.name.startsWith('data-') && attr.name !== 'data-action') {
                    // Convert data-cell-id to cell_id
                    const key = attr.name.substring(5).replace(/-/g, '_');
                    payload[key] = attr.value;
                }
            }

            // Check for confirmation
            if (el.hasAttribute('data-confirm')) {
                const msg = el.getAttribute('data-confirm');
                if (!confirm(msg)) return;
            }

            // Send channel message
            sendMessage(action, payload);

            // Prevent default for links/buttons
            e.preventDefault();
        });
    }

    // Auto-connect when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            connect();
            setupActionHandlers();
        });
    } else {
        connect();
        setupActionHandlers();
    }
})();
</script>
""")
end

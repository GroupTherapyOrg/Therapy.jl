# WebSocketClient.jl - Client-side WebSocket JavaScript generation
#
# Generates JavaScript that connects to the Therapy.jl WebSocket server,
# handles reconnection, and provides a basic messaging API.
# Server signals, bidirectional signals, and channels are planned for future.

using JSON3
# Note: RawHtml is available from SSR/Render.jl which is included before this file

"""
    websocket_client_script(; reconnect_delay, max_reconnect_delay)

Generate client-side JavaScript for WebSocket connectivity.

# Arguments
- `reconnect_delay::Int`: Initial reconnect delay in ms (default: 1000)
- `max_reconnect_delay::Int`: Maximum reconnect delay in ms (default: 30000)

# Features
- Auto-connects to ws://host/ws on page load
- Exponential backoff reconnection
- Graceful degradation: shows warning on static sites (no server)
- Exposes window.TherapyWS API for programmatic use
"""
function websocket_client_script(;
    signals::Vector{String}=String[],
    reconnect_delay::Int=1000,
    max_reconnect_delay::Int=30000
)
    RawHtml("""
<script>
// Therapy.jl WebSocket Client
(function() {
    'use strict';

    // Prevent re-execution during SPA navigation
    if (window.TherapyWS) {
        return;
    }

    const CONFIG = {
        reconnectDelay: $reconnect_delay,
        maxReconnectDelay: $max_reconnect_delay
    };

    let ws = null;
    let reconnectAttempts = 0;
    let connectionId = null;
    let isStaticMode = false;

    const isDevMode = (window.location.hostname === 'localhost' ||
                       window.location.hostname === '127.0.0.1');

    function getWsUrl() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        return protocol + '//' + window.location.host + '/ws';
    }

    function connect() {
        if (isStaticMode) return;
        if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
            return;
        }

        try {
            ws = new WebSocket(getWsUrl());

            ws.onopen = function() {
                console.log('[WS] Connected to server');
                reconnectAttempts = 0;
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
                window.dispatchEvent(new CustomEvent('therapy:ws:disconnected'));
                if (e.code !== 1000) {
                    if (isDevMode) {
                        scheduleReconnect();
                    } else if (reconnectAttempts >= 1) {
                        showStaticModeWarning();
                    } else {
                        reconnectAttempts++;
                        setTimeout(connect, 500);
                    }
                }
            };

            ws.onerror = function(err) {
                if (isDevMode) {
                    console.warn('[WS] Connection error - server may not be running');
                }
            };

        } catch (e) {
            showStaticModeWarning();
        }
    }

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

    function handleMessage(msg) {
        switch (msg.type) {
            case 'connected':
                connectionId = msg.connection_id;
                console.log('[WS] Connection ID:', connectionId);
                break;
            case 'error':
                console.error('[WS] Server error:', msg.message);
                break;
            case 'pong':
                break;
            default:
                // Dispatch as custom event for application-level handling
                window.dispatchEvent(new CustomEvent('therapy:ws:message', {
                    detail: msg
                }));
        }
    }

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

    function showStaticModeWarning() {
        if (isStaticMode) return;
        isStaticMode = true;
        console.log('[WS] Static mode detected - WebSocket features unavailable');
        document.querySelectorAll('[data-ws-example]').forEach(addWarningToElement);
        window.dispatchEvent(new CustomEvent('therapy:ws:static_mode'));
    }

    function showStaticModeWarningOnNewElements() {
        if (!isStaticMode) return;
        document.querySelectorAll('[data-ws-example]').forEach(addWarningToElement);
    }

    function send(msg) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(msg));
        }
    }

    function sendAction(action, payload) {
        send({ type: 'action', action: action, payload: payload });
    }

    function isConnected() {
        return ws && ws.readyState === WebSocket.OPEN;
    }

    function getConnectionId() {
        return connectionId;
    }

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
        showStaticModeWarningOnNewElements: showStaticModeWarningOnNewElements,
        sendAction: sendAction,
        send: send,
        isConnected: isConnected,
        getConnectionId: getConnectionId,
        isStaticMode: function() { return isStaticMode; }
    };

    // Handle data-action clicks
    function setupActionHandlers() {
        document.addEventListener('click', function(e) {
            const el = e.target.closest('[data-action]');
            if (!el) return;

            const action = el.getAttribute('data-action');
            if (!action) return;

            const payload = {};
            for (const attr of el.attributes) {
                if (attr.name.startsWith('data-') && attr.name !== 'data-action') {
                    const key = attr.name.substring(5).replace(/-/g, '_');
                    payload[key] = attr.value;
                }
            }

            if (el.hasAttribute('data-confirm')) {
                const msg = el.getAttribute('data-confirm');
                if (!confirm(msg)) return;
            }

            sendAction(action, payload);
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

# SignalRuntime.jl - Cross-island signal pub/sub runtime
#
# Provides a tiny JS runtime (~400 bytes) for cross-island signal communication.
# Intra-island signals compile to local `let` variables (no runtime needed).
# Cross-island signals (server signals, shared state) use this pub/sub store.
#
# API: window.__therapy.reg(name, initial, setter)
#      window.__therapy.set(name, value)
#      window.__therapy.get(name)

"""
    signal_runtime_js() -> String

Return the cross-island signal runtime JavaScript (~400 bytes).

This runtime provides a minimal pub/sub store for signals that need to
communicate across island boundaries (e.g., server signals via WebSocket).

Signals within a single island don't use this — they compile to local
`let` variables with direct DOM mutation. Only signals that cross
island boundaries register here.

## API

- `window.__therapy.reg(name, initial, setter)` — Register a signal subscriber.
  Called by island IIFEs for signals that receive external updates.
  If the runtime already has a different value (e.g., set by server before
  island hydrated), the setter is called immediately with the current value.

- `window.__therapy.set(name, value)` — Set a signal value and notify all
  subscribers. Called by WebSocket client on server signal updates, or by
  one island to notify others.

- `window.__therapy.get(name)` — Get current signal value. Returns undefined
  if signal not registered.
"""
function signal_runtime_js()::String
    return """
window.__therapy=window.__therapy||{_s:{},reg:function(n,v,fn){var s=this._s[n];if(!s){s={v:v,fn:[]};this._s[n]=s}s.fn.push(fn);if(s.v!==v)fn(s.v)},set:function(n,v){var s=this._s[n];if(!s){this._s[n]={v:v,fn:[]};return}s.v=v;for(var i=0;i<s.fn.length;i++)s.fn[i](v)},get:function(n){var s=this._s[n];return s?s.v:void 0}};"""
end

"""
    signal_runtime_script() -> RawHtml

Return the signal runtime wrapped in a `<script>` tag.
Include this once per page, before any island scripts.
"""
function signal_runtime_script()::RawHtml
    RawHtml("<script>" * signal_runtime_js() * "</script>\n")
end

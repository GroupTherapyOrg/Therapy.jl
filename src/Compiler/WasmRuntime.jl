# WasmRuntime.jl — WASM island loader runtime
#
# Provides the JS import object for WebAssembly.instantiate().
# DOM operations use externref — each call receives the DOM node directly.
# No querySelector per call. Matches Leptos's wasm-bindgen shim pattern.
#
# API:
#   window.__tw.io(island) → import object for WebAssembly.instantiate

"""
    therapy_wasm_runtime_js() -> String

Return the WASM island runtime JavaScript.

Provides `window.__tw` with:
- `__tw.io(el)` — creates the import object for `WebAssembly.instantiate()`,
  including Math.pow and DOM bridge functions (externref-based).

The DOM shims are thin one-liner wrappers matching wasm-bindgen's pattern:
WASM passes externref DOM nodes, JS calls the actual DOM API.
"""
function therapy_wasm_runtime_js()::String
    shims = dom_shims_js()
    return """
(function(){
var _dispatch=function(){};
window.__tw={
io:function(el){return{Math:{pow:Math.pow},dom:$(shims)};},
setDispatch:function(fn){_dispatch=fn;}
};
})();"""
end

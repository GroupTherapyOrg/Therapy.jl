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
io:function(el){var m=window.MakieThreeJS;var mk;if(m){mk={heatmap:function(a,r,c){return m.heatmap(el,a,r,c);},lines:function(a,n){return m.lines(el,a,n);},scatter:function(a,n){return m.scatter(el,a,n);},display:function(f){return m.display(el,f);}};}else{mk={heatmap:function(){return 0n;},lines:function(){return 0n;},scatter:function(){return 0n;},display:function(){return 0n;}};}return{Math:{pow:Math.pow},dom:$(shims),makie:mk};},
setDispatch:function(fn){_dispatch=fn;},
toWasm:function(ex,str){var enc=new TextEncoder().encode(str);var buf=ex._u8_new(BigInt(enc.length));for(var i=0;i<enc.length;i++)ex['_u8_set!'](buf,BigInt(i+1),BigInt(enc[i]));return ex._str_from_bytes(buf);},
fromWasm:function(ex,ref){var len=Number(ex._str_len(ref));var s='';for(var i=1;i<=len;i++)s+=String.fromCharCode(Number(ex._str_byte(ref,BigInt(i))));return s;}
};
})();"""
end

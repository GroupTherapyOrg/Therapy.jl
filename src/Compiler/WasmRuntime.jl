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
io:function(el){var _ctx=null;var _cv=el.querySelector('canvas');if(_cv)_ctx=_cv.getContext('2d');return{Math:{pow:Math.pow},dom:$(shims),canvas2d:{begin_path:function(){if(_ctx)_ctx.beginPath();return 0n;},close_path:function(){if(_ctx)_ctx.closePath();return 0n;},move_to:function(x,y){if(_ctx)_ctx.moveTo(x,y);return 0n;},line_to:function(x,y){if(_ctx)_ctx.lineTo(x,y);return 0n;},arc:function(x,y,r,sa,ea){if(_ctx)_ctx.arc(x,y,r,sa,ea);return 0n;},stroke:function(){if(_ctx)_ctx.stroke();return 0n;},fill:function(){if(_ctx)_ctx.fill();return 0n;},fill_rect:function(x,y,w,h){if(_ctx)_ctx.fillRect(x,y,w,h);return 0n;},clear_rect:function(x,y,w,h){if(_ctx)_ctx.clearRect(x,y,w,h);return 0n;},stroke_rect:function(x,y,w,h){if(_ctx)_ctx.strokeRect(x,y,w,h);return 0n;},set_stroke_rgb:function(r,g,b){if(_ctx)_ctx.strokeStyle='rgb('+r+','+g+','+b+')';return 0n;},set_fill_rgb:function(r,g,b){if(_ctx)_ctx.fillStyle='rgb('+r+','+g+','+b+')';return 0n;},set_fill_rgba:function(r,g,b,a){if(_ctx)_ctx.fillStyle='rgba('+r+','+g+','+b+','+a+')';return 0n;},set_line_width:function(w){if(_ctx)_ctx.lineWidth=w;return 0n;},set_font_size:function(s){if(_ctx)_ctx.font=s+'px sans-serif';return 0n;},fill_text_char:function(c,x,y){if(_ctx)_ctx.fillText(String.fromCharCode(c),x,y);return 0n;},save:function(){if(_ctx)_ctx.save();return 0n;},restore:function(){if(_ctx)_ctx.restore();return 0n;},translate:function(x,y){if(_ctx)_ctx.translate(x,y);return 0n;},rotate:function(a){if(_ctx)_ctx.rotate(a);return 0n;},set_line_dash_solid:function(){if(_ctx)_ctx.setLineDash([]);return 0n;},set_line_dash_dashed:function(){if(_ctx)_ctx.setLineDash([6,4]);return 0n;},set_line_dash_dotted:function(){if(_ctx)_ctx.setLineDash([2,3]);return 0n;}}};},
setDispatch:function(fn){_dispatch=fn;},
toWasm:function(ex,str){var enc=new TextEncoder().encode(str);var buf=ex._u8_new(BigInt(enc.length));for(var i=0;i<enc.length;i++)ex['_u8_set!'](buf,BigInt(i+1),BigInt(enc[i]));return ex._str_from_bytes(buf);},
fromWasm:function(ex,ref){var len=Number(ex._str_len(ref));var s='';for(var i=1;i<=len;i++)s+=String.fromCharCode(Number(ex._str_byte(ref,BigInt(i))));return s;}
};
})();"""
end

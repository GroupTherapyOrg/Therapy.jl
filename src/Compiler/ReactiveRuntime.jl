# ReactiveRuntime.jl — SolidJS-style fine-grained reactive runtime
#
# This is the core reactive engine that ships once per page (~1KB).
# It replaces all static signal wiring with automatic dependency tracking:
#
#   var s0 = __t.signal(0);              // [getter, setter]
#   __t.effect(() => console.log(s0[0]())); // auto-tracks s0
#   s0[1](5);                            // effect re-runs automatically
#
# Based on SolidJS's reactive model:
# - Auto-tracking: reading a signal inside an effect registers it as a dependency
# - Cleanup: effects clear old subscriptions before re-running (dynamic deps)
# - Batch: multiple writes → single update pass
# - Memo: cached derived value (signal + effect)

"""
    therapy_reactive_runtime_js() -> String

Return the reactive runtime JavaScript (~1KB minified).

Provides `window.__t` with:
- `__t.signal(initial)` → `[getter, setter]`
- `__t.effect(fn)` → runs fn, auto-tracks signal reads, re-runs on changes
- `__t.memo(fn)` → cached derived signal, recomputes only when deps change
- `__t.batch(fn)` → defer all effect execution until fn completes
"""
function therapy_reactive_runtime_js()::String
    return """
(function(){
var _L=null,_B=0,_Q=[],_O=null;
function signal(v){
var subs=[];
function get(){
if(_L){subs.push(_L);_L._d.push(subs);}
return v;
}
function set(n){
if(v===n)return;
v=n;
var s=subs.slice();
for(var i=0;i<s.length;i++){
if(s[i]===_L)continue;
if(_B>0){if(_Q.indexOf(s[i])<0)_Q.push(s[i]);}
else{s[i]._r();}
}
}
return[get,set];
}
function effect(fn){
var e={_fn:fn,_d:[],_c:[],_r:function(){
for(var i=0;i<e._c.length;i++)e._c[i]();
e._c=[];
for(var i=0;i<e._d.length;i++){
var a=e._d[i],j=a.indexOf(e);
if(j>=0)a.splice(j,1);
}
e._d=[];
var p=_L;_L=e;
try{fn();}finally{_L=p;}
}};
if(_O){_O._cleanups.push(function(){
for(var i=0;i<e._d.length;i++){
var a=e._d[i],j=a.indexOf(e);
if(j>=0)a.splice(j,1);
}
e._d=[];e._c=[];
});}
e._r();
return function(){
for(var i=0;i<e._c.length;i++)e._c[i]();
for(var i=0;i<e._d.length;i++){
var a=e._d[i],j=a.indexOf(e);
if(j>=0)a.splice(j,1);
}
e._d=[];e._c=[];
};
}
function memo(fn){
var s=signal(undefined);
var prev;
var first=true;
effect(function(){
var nv=fn();
if(first||prev!==nv){prev=nv;s[1](nv);first=false;}
});
return s[0];
}
function batch(fn){
_B++;
try{fn();}finally{
_B--;
if(_B===0){
_B++;
while(_Q.length>0){
var q=_Q.slice();_Q=[];
for(var i=0;i<q.length;i++)q[i]._r();
}
_B--;
}
}
}
function onCleanup(fn){if(_O)_O._cleanups.push(fn);else if(_L)_L._c.push(fn);}
function onMount(fn){queueMicrotask(fn);}
function createOwner(){
var o={_children:[],_cleanups:[],_parent:null};
if(_O){o._parent=_O;_O._children.push(o);}
return o;
}
function runWithOwner(o,fn){
var p=_O;_O=o;
try{return fn();}finally{_O=p;}
}
function dispose(o){
var i;
for(i=0;i<o._cleanups.length;i++)o._cleanups[i]();
for(i=0;i<o._children.length;i++)dispose(o._children[i]);
if(o._parent){var idx=o._parent._children.indexOf(o);if(idx>=0)o._parent._children.splice(idx,1);}
o._cleanups=[];o._children=[];
}
var _S={};
function shared(name,v){if(!_S[name])_S[name]=signal(v);return _S[name];}
window.__t={signal:signal,effect:effect,memo:memo,batch:batch,onCleanup:onCleanup,onMount:onMount,shared:shared,createOwner:createOwner,runWithOwner:runWithOwner,dispose:dispose};
})();"""
end

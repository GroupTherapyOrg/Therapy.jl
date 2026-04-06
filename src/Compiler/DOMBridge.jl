# DOMBridge.jl — Externref-based DOM imports for WASM islands
#
# Leptos-equivalent: tachys/src/renderer/dom.rs
# Each function maps to a web-sys call. JS provides one-liner shims.
# WASM holds DOM node references as externref globals.
#
# Pattern: WASM calls imported functions with externref DOM nodes.
# No querySelector per call — nodes are resolved once at hydration.

import WasmTarget
const _WT = WasmTarget

# ─── DOM Import Registration ───

"""
    add_dom_imports!(mod::WasmModule) -> Dict{String, UInt32}

Add all DOM bridge imports to a WASM module. Returns a dict of
import name → function index for use in compiled effect/handler code.

Matches Leptos's web-sys import surface:
- Text: set_node_value (Leptos: Node.set_node_value)
- Attrs: set_attribute, remove_attribute
- Tree: append_child, remove_child, insert_before
- Create: create_element, create_text_node, create_comment
- Navigate: first_child, next_sibling, parent_node
- HTML: set_inner_html, get_inner_html
- Style: set_style_display
- Value: set_value, get_value
- Class: set_class_name
- Event: add_event_listener_delegated
"""
function add_dom_imports!(mod::_WT.WasmModule)::Dict{String, UInt32}
    imports = Dict{String, UInt32}()
    ER = _WT.ExternRef

    # Text content (Leptos: Rndr::set_text → Node.set_node_value)
    imports["set_text_content"] = _WT.add_import!(mod, "dom", "set_text_content",
        _WT.WasmValType[ER, ER], _WT.WasmValType[])

    # Attributes (Leptos: Rndr::set_attribute / remove_attribute)
    imports["set_attribute"] = _WT.add_import!(mod, "dom", "set_attribute",
        _WT.WasmValType[ER, ER, ER], _WT.WasmValType[])
    imports["remove_attribute"] = _WT.add_import!(mod, "dom", "remove_attribute",
        _WT.WasmValType[ER, ER], _WT.WasmValType[])

    # Tree manipulation (Leptos: Rndr::insert_node / remove_node)
    imports["append_child"] = _WT.add_import!(mod, "dom", "append_child",
        _WT.WasmValType[ER, ER], _WT.WasmValType[])
    imports["remove_child"] = _WT.add_import!(mod, "dom", "remove_child",
        _WT.WasmValType[ER, ER], _WT.WasmValType[])
    imports["insert_before"] = _WT.add_import!(mod, "dom", "insert_before",
        _WT.WasmValType[ER, ER, ER], _WT.WasmValType[])

    # Element creation (Leptos: Rndr::create_element / create_text_node)
    imports["create_element"] = _WT.add_import!(mod, "dom", "create_element",
        _WT.WasmValType[ER], _WT.WasmValType[ER])
    imports["create_text_node"] = _WT.add_import!(mod, "dom", "create_text_node",
        _WT.WasmValType[ER], _WT.WasmValType[ER])
    imports["create_comment"] = _WT.add_import!(mod, "dom", "create_comment",
        _WT.WasmValType[], _WT.WasmValType[ER])

    # DOM navigation (Leptos: Rndr::first_child / next_sibling / get_parent)
    imports["first_child"] = _WT.add_import!(mod, "dom", "first_child",
        _WT.WasmValType[ER], _WT.WasmValType[ER])
    imports["next_sibling"] = _WT.add_import!(mod, "dom", "next_sibling",
        _WT.WasmValType[ER], _WT.WasmValType[ER])
    imports["parent_node"] = _WT.add_import!(mod, "dom", "parent_node",
        _WT.WasmValType[ER], _WT.WasmValType[ER])

    # innerHTML (for Show() content swap — will move to WASM in P3)
    imports["set_inner_html"] = _WT.add_import!(mod, "dom", "set_inner_html",
        _WT.WasmValType[ER, ER], _WT.WasmValType[])
    imports["get_inner_html"] = _WT.add_import!(mod, "dom", "get_inner_html",
        _WT.WasmValType[ER], _WT.WasmValType[ER])

    # Style (display toggle for Show)
    imports["set_style_display"] = _WT.add_import!(mod, "dom", "set_style_display",
        _WT.WasmValType[ER, _WT.I32], _WT.WasmValType[])

    # Form values (for input bindings)
    imports["set_value"] = _WT.add_import!(mod, "dom", "set_value",
        _WT.WasmValType[ER, ER], _WT.WasmValType[])
    imports["get_value"] = _WT.add_import!(mod, "dom", "get_value",
        _WT.WasmValType[ER], _WT.WasmValType[ER])

    # Class (for className bindings)
    imports["set_class_name"] = _WT.add_import!(mod, "dom", "set_class_name",
        _WT.WasmValType[ER, ER], _WT.WasmValType[])

    # Event delegation (P2 will use this)
    imports["add_event_listener"] = _WT.add_import!(mod, "dom", "add_event_listener",
        _WT.WasmValType[ER, ER, _WT.I32], _WT.WasmValType[])

    # Event data access (P2)
    imports["event_target"] = _WT.add_import!(mod, "dom", "event_target",
        _WT.WasmValType[ER], _WT.WasmValType[ER])
    imports["input_value"] = _WT.add_import!(mod, "dom", "input_value",
        _WT.WasmValType[ER], _WT.WasmValType[ER])
    imports["checked"] = _WT.add_import!(mod, "dom", "checked",
        _WT.WasmValType[ER], _WT.WasmValType[_WT.I32])
    imports["prevent_default"] = _WT.add_import!(mod, "dom", "prevent_default",
        _WT.WasmValType[ER], _WT.WasmValType[])

    # Document-level queries
    imports["query_selector"] = _WT.add_import!(mod, "dom", "query_selector",
        _WT.WasmValType[ER, ER], _WT.WasmValType[ER])

    # Number↔string conversion for DOM text updates
    imports["i64_to_string"] = _WT.add_import!(mod, "dom", "i64_to_string",
        _WT.WasmValType[_WT.I64], _WT.WasmValType[ER])
    imports["f64_to_string"] = _WT.add_import!(mod, "dom", "f64_to_string",
        _WT.WasmValType[_WT.F64], _WT.WasmValType[ER])
    imports["i32_to_string"] = _WT.add_import!(mod, "dom", "i32_to_string",
        _WT.WasmValType[_WT.I32], _WT.WasmValType[ER])

    # Fragment creation (for For() — P3)
    imports["create_fragment_from_html"] = _WT.add_import!(mod, "dom", "create_fragment_from_html",
        _WT.WasmValType[ER], _WT.WasmValType[ER])

    # Clone node (Leptos template pattern)
    imports["clone_node"] = _WT.add_import!(mod, "dom", "clone_node",
        _WT.WasmValType[ER], _WT.WasmValType[ER])

    # Show swap: move children between container and fragment
    # show_swap(container, fragment, show: i32)
    # If show=1: move fragment children → container (show content)
    # If show=0: move container children → fragment (hide content)
    imports["show_swap"] = _WT.add_import!(mod, "dom", "show_swap",
        _WT.WasmValType[ER, ER, _WT.I32], _WT.WasmValType[])

    # Show swap with fallback
    # show_swap_fb(container, frag, fb_container, fb_frag, show: i32)
    imports["show_swap_fb"] = _WT.add_import!(mod, "dom", "show_swap_fb",
        _WT.WasmValType[ER, ER, ER, ER, _WT.I32], _WT.WasmValType[])

    return imports
end

# ─── Externref Global Registration ───

"""
    add_hk_globals!(mod::WasmModule, hk_ids::Vector{Int}) -> Dict{Int, UInt32}

Add mutable externref globals for each hydration key element.
Returns hk_id → global_index mapping.

At hydration time, JS stores DOM nodes into these globals:
  ex.hk_3.value = island.querySelector('[data-hk="3"]')
"""
function add_hk_globals!(mod::_WT.WasmModule, hk_ids::Vector{Int})::Dict{Int, UInt32}
    hk_globals = Dict{Int, UInt32}()
    for hk in sort(hk_ids)
        global_idx = _WT.add_global!(mod, _WT.ExternRef, true, nothing)
        _WT.add_global_export!(mod, "hk_$(hk)", global_idx)
        hk_globals[hk] = global_idx
    end
    return hk_globals
end

# ─── JS Shim Generation ───

"""
    dom_shims_js() -> String

Generate the JS implementation of DOM imports. These are the thin shims
that bridge WASM externref calls to actual DOM APIs.

Equivalent to wasm-bindgen's auto-generated __wbg_* functions.
"""
function dom_shims_js()::String
    return """{
set_text_content:function(n,t){if(n)n.textContent=t;},
set_attribute:function(n,a,v){if(n)n.setAttribute(a,v);},
remove_attribute:function(n,a){if(n)n.removeAttribute(a);},
append_child:function(p,c){if(p)p.appendChild(c);},
remove_child:function(p,c){if(p&&c)p.removeChild(c);},
insert_before:function(p,n,r){if(p)p.insertBefore(n,r);},
create_element:function(t){return document.createElement(t);},
create_text_node:function(t){return document.createTextNode(t);},
create_comment:function(){return document.createComment('');},
first_child:function(n){return n?n.firstChild:null;},
next_sibling:function(n){return n?n.nextSibling:null;},
parent_node:function(n){return n?n.parentNode:null;},
set_inner_html:function(n,h){if(n)n.innerHTML=h;},
get_inner_html:function(n){return n?n.innerHTML:'';},
set_style_display:function(n,s){if(n)n.style.display=s?'':'none';},
set_value:function(n,v){if(n)n.value=v;},
get_value:function(n){return n?n.value:'';},
set_class_name:function(n,c){if(n)n.className=c;},
add_event_listener:function(n,e,i){if(n)n.addEventListener(e,function(ev){_dispatch(i,ev);});},
event_target:function(e){return e?e.target:null;},
input_value:function(n){return n?n.value:'';},
checked:function(n){return n&&n.checked?1:0;},
prevent_default:function(e){if(e)e.preventDefault();},
query_selector:function(r,s){return r?r.querySelector(s):null;},
i64_to_string:function(v){return String(Number(v));},
f64_to_string:function(v){return String(v);},
i32_to_string:function(v){return String(v);},
create_fragment_from_html:function(h){var t=document.createElement('template');t.innerHTML=h;return t.content;},
clone_node:function(n){return n?n.cloneNode(true):null;},
show_swap:function(c,f,s){if(s){while(f.firstChild)c.appendChild(f.firstChild);}else{while(c.firstChild)f.appendChild(c.firstChild);}},
show_swap_fb:function(c,f,fc,ff,s){if(s){while(fc.firstChild)ff.appendChild(fc.firstChild);while(f.firstChild)c.appendChild(f.firstChild);}else{while(c.firstChild)f.appendChild(c.firstChild);while(ff.firstChild)fc.appendChild(ff.firstChild);}}
}"""
end

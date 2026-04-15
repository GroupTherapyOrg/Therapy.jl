# DOMBridge.jl — Externref-based DOM imports for WASM islands
#
# Leptos-equivalent: tachys/src/renderer/dom.rs + wasm-bindgen JS glue
# Each function maps to a web-sys call. JS shims are AUTO-GENERATED from
# the same registry that defines WASM imports — impossible to drift.
#
# Pattern: WASM calls imported functions with externref DOM nodes.
# No querySelector per call — nodes are resolved once at hydration.
#
# LEPTOS-2001: Unified DOM_IMPORTS registry. Both add_dom_imports!() and
# dom_shims_js() are generated from DOM_IMPORTS. Adding a new DOM operation
# is a single-line addition to the registry.

import WasmTarget
const _WT = WasmTarget

# ─── DOM Import Registry ───

"""
    DOMImport(name, js_params, wasm_params, wasm_results, js_body)

Pairs a WASM import declaration with its JS shim implementation.
Both `add_dom_imports!()` and `dom_shims_js()` read from this registry.

Leptos parallel: wasm-bindgen generates `__wbg_*` shims from `#[wasm_bindgen]`
annotations. We do the same from this registry.
"""
struct DOMImport
    name::String                         # Import name (e.g., "set_text_content")
    js_params::String                    # JS parameter names (e.g., "n,t")
    wasm_params::Vector{_WT.WasmValType} # WASM parameter types
    wasm_results::Vector{_WT.WasmValType} # WASM result types
    js_body::String                      # JS function body (uses js_params)
end

const ER = _WT.ExternRef

"""
Registry of all DOM bridge imports. Single source of truth.

Adding a new DOM operation: add one entry here. Both the WASM import
and JS shim are generated automatically.
"""
const DOM_IMPORTS = DOMImport[
    # ─── Text content (Leptos: Rndr::set_text → Node.set_node_value) ───
    DOMImport("set_text_content", "n,t",
        _WT.WasmValType[ER, ER], _WT.WasmValType[],
        "if(n)n.textContent=t"),

    # ─── Attributes (Leptos: Rndr::set_attribute / remove_attribute) ───
    DOMImport("set_attribute", "n,a,v",
        _WT.WasmValType[ER, ER, ER], _WT.WasmValType[],
        "if(n)n.setAttribute(a,v)"),
    DOMImport("remove_attribute", "n,a",
        _WT.WasmValType[ER, ER], _WT.WasmValType[],
        "if(n)n.removeAttribute(a)"),

    # ─── Tree manipulation (Leptos: Rndr::insert_node / remove_node) ───
    DOMImport("append_child", "p,c",
        _WT.WasmValType[ER, ER], _WT.WasmValType[],
        "if(p)p.appendChild(c)"),
    DOMImport("remove_child", "p,c",
        _WT.WasmValType[ER, ER], _WT.WasmValType[],
        "if(p&&c)p.removeChild(c)"),
    DOMImport("insert_before", "p,n,r",
        _WT.WasmValType[ER, ER, ER], _WT.WasmValType[],
        "if(p)p.insertBefore(n,r)"),

    # ─── Element creation (Leptos: Rndr::create_element / create_text_node) ───
    DOMImport("create_element", "t",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return document.createElement(t)"),
    DOMImport("create_text_node", "t",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return document.createTextNode(t)"),
    DOMImport("create_comment", "",
        _WT.WasmValType[], _WT.WasmValType[ER],
        "return document.createComment('')"),

    # ─── DOM navigation (Leptos: Rndr::first_child / next_sibling / get_parent) ───
    DOMImport("first_child", "n",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return n?n.firstChild:null"),
    DOMImport("next_sibling", "n",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return n?n.nextSibling:null"),
    DOMImport("parent_node", "n",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return n?n.parentNode:null"),

    # ─── innerHTML (for Show() content swap — will move to WASM in P3) ───
    DOMImport("set_inner_html", "n,h",
        _WT.WasmValType[ER, ER], _WT.WasmValType[],
        "if(n)n.innerHTML=h"),
    DOMImport("get_inner_html", "n",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return n?n.innerHTML:''"),

    # ─── Style (display toggle for Show) ───
    DOMImport("set_style_display", "n,s",
        _WT.WasmValType[ER, _WT.I32], _WT.WasmValType[],
        "if(n)n.style.display=s?'':'none'"),

    # ─── Form values (for input bindings) ───
    DOMImport("set_value", "n,v",
        _WT.WasmValType[ER, ER], _WT.WasmValType[],
        "if(n)n.value=v"),
    DOMImport("get_value", "n",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return n?n.value:''"),

    # ─── Class (for className bindings) ───
    DOMImport("set_class_name", "n,c",
        _WT.WasmValType[ER, ER], _WT.WasmValType[],
        "if(n)n.className=c"),

    # ─── Event delegation (P2 will use this) ───
    DOMImport("add_event_listener", "n,e,i",
        _WT.WasmValType[ER, ER, _WT.I32], _WT.WasmValType[],
        "if(n)n.addEventListener(e,function(ev){_dispatch(i,ev);})"),

    # ─── Event data access (P2) ───
    DOMImport("event_target", "e",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return e?e.target:null"),
    DOMImport("input_value", "n",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return n?n.value:''"),
    DOMImport("checked", "n",
        _WT.WasmValType[ER], _WT.WasmValType[_WT.I32],
        "return n&&n.checked?1:0"),
    DOMImport("prevent_default", "e",
        _WT.WasmValType[ER], _WT.WasmValType[],
        "if(e)e.preventDefault()"),

    # ─── Document-level queries ───
    DOMImport("query_selector", "r,s",
        _WT.WasmValType[ER, ER], _WT.WasmValType[ER],
        "return r?r.querySelector(s):null"),

    # ─── Number↔string conversion for DOM text updates ───
    DOMImport("i64_to_string", "v",
        _WT.WasmValType[_WT.I64], _WT.WasmValType[ER],
        "return String(Number(v))"),
    DOMImport("f64_to_string", "v",
        _WT.WasmValType[_WT.F64], _WT.WasmValType[ER],
        "return String(v)"),
    DOMImport("i32_to_string", "v",
        _WT.WasmValType[_WT.I32], _WT.WasmValType[ER],
        "return v?'true':'false'"),

    # ─── Fragment creation (for For() — P3) ───
    DOMImport("create_fragment_from_html", "h",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "var t=document.createElement('template');t.innerHTML=h;return t.content"),

    # ─── Clone node (Leptos template pattern) ───
    DOMImport("clone_node", "n",
        _WT.WasmValType[ER], _WT.WasmValType[ER],
        "return n?n.cloneNode(true):null"),

    # ─── Show swap: move children between container and fragment ───
    # show_swap(container, fragment, show: i32)
    # If show=1: move fragment children → container (show content)
    # If show=0: move container children → fragment (hide content)
    DOMImport("show_swap", "c,f,s",
        _WT.WasmValType[ER, ER, _WT.I32], _WT.WasmValType[],
        "if(s){while(f.firstChild)c.appendChild(f.firstChild);}else{while(c.firstChild)f.appendChild(c.firstChild);}"),

    # ─── Show swap with fallback ───
    # show_swap_fb(container, frag, fb_container, fb_frag, show: i32)
    DOMImport("show_swap_fb", "c,f,fc,ff,s",
        _WT.WasmValType[ER, ER, ER, ER, _WT.I32], _WT.WasmValType[],
        "if(s){while(fc.firstChild)ff.appendChild(fc.firstChild);while(f.firstChild)c.appendChild(f.firstChild);}else{while(c.firstChild)f.appendChild(c.firstChild);while(ff.firstChild)fc.appendChild(ff.firstChild);}"),
]

# ─── Auto-Generated Functions ───

"""
    add_dom_imports!(mod::WasmModule) -> Dict{String, UInt32}

Add all DOM bridge imports to a WASM module. Returns a dict of
import name → function index for use in compiled effect/handler code.

Auto-generated from DOM_IMPORTS registry.
"""
function add_dom_imports!(mod::_WT.WasmModule)::Dict{String, UInt32}
    imports = Dict{String, UInt32}()
    for di in DOM_IMPORTS
        imports[di.name] = _WT.add_import!(mod, "dom", di.name,
            di.wasm_params, di.wasm_results)
    end
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

Generate the JS implementation of DOM imports. Auto-generated from
DOM_IMPORTS registry — same source as add_dom_imports!().

Equivalent to wasm-bindgen's auto-generated __wbg_* functions.
"""
function dom_shims_js()::String
    parts = String[]
    for di in DOM_IMPORTS
        push!(parts, "$(di.name):function($(di.js_params)){$(di.js_body);}")
    end
    return "{\n" * join(parts, ",\n") * "\n}"
end

# ForRuntime.jl — For() list rendering: JS runtime + render function compiler
#
# SolidJS-inspired architecture:
# 1. therapyFor JS runtime manages a container's children via innerHTML
# 2. Marker-based template analysis detects item-dependent values in VNode trees
# 3. VNode walker generates JS render functions (item → HTML string)
# 4. Event handlers inside For items are compiled + wired via event delegation

# ─── Marker types for template analysis ───

"""Marker for item-dependent values in For() render functions."""
struct _ForItemRef end

Base.string(::_ForItemRef) = ""
Base.show(io::IO, ::_ForItemRef) = print(io, "")
Base.show(io::IO, ::MIME"text/plain", ::_ForItemRef) = print(io, "")
Base.iterate(::_ForItemRef) = (_ForItemRef(), nothing)
Base.iterate(::_ForItemRef, ::Nothing) = nothing
Base.length(::_ForItemRef) = 1
Base.getindex(::_ForItemRef, ::Any) = _ForItemRef()
Base.eltype(::Type{_ForItemRef}) = _ForItemRef
Base.:(==)(::_ForItemRef, ::Any) = false
Base.:(==)(::Any, ::_ForItemRef) = false
Base.:(==)(::_ForItemRef, ::_ForItemRef) = true

"""Sentinel value used as the index parameter during marker analysis.
Any captured variable with this exact value is replaced with the `idx` parameter
in the compiled event handler."""
const _FOR_INDEX_SENTINEL = 999_999_937

# ─── JS Runtime ───

"""
Return the therapyFor JavaScript runtime with keyed reconciliation.

SolidJS-style diffing:
1. Skip common prefix (same reference items at start)
2. Skip common suffix (same reference items at end)
3. HashMap for middle section — reuse/move/create/dispose DOM nodes
4. O(delta) for most real-world updates

`therapyFor(container, renderItem)` returns an update(newItems) function.
`renderItem(item, idx)` returns an HTML string for one item.
Each item's DOM is tracked by reference identity for reuse.
"""
function therapy_for_runtime_js()::String
    return """
function _escH(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function therapyFor(container,renderFn){
var items=[],nodes=[];
function makeNode(item,idx){
var t=document.createElement('template');
t.innerHTML=renderFn(item,idx);
return t.content.firstChild;
}
return function(newItems){
if(!newItems||newItems.length===0){
container.innerHTML='';items=[];nodes=[];return;
}
var newLen=newItems.length,oldLen=items.length;
if(oldLen===0){
var f=document.createDocumentFragment();
var nn=new Array(newLen);
for(var i=0;i<newLen;i++){nn[i]=makeNode(newItems[i],i+1);f.appendChild(nn[i]);}
container.innerHTML='';container.appendChild(f);
items=newItems.slice();nodes=nn;return;
}
var newNodes=new Array(newLen);
var start=0,end=Math.min(oldLen,newLen)-1;
var oEnd=oldLen-1,nEnd=newLen-1;
while(start<=end&&items[start]===newItems[start]){newNodes[start]=nodes[start];start++;}
while(oEnd>=start&&nEnd>=start&&items[oEnd]===newItems[nEnd]){newNodes[nEnd]=nodes[oEnd];oEnd--;nEnd--;}
var map=new Map();
for(var i=start;i<=oEnd;i++)map.set(items[i],i);
for(var j=start;j<=nEnd;j++){
var item=newItems[j];
var oi=map.get(item);
if(oi!==undefined){newNodes[j]=nodes[oi];map.delete(item);}
else{newNodes[j]=makeNode(item,j+1);}
}
map.forEach(function(oi){var n=nodes[oi];if(n&&n.parentNode)n.parentNode.removeChild(n);});
var f=document.createDocumentFragment();
for(var j=0;j<newLen;j++)f.appendChild(newNodes[j]);
container.innerHTML='';container.appendChild(f);
items=newItems.slice();nodes=newNodes;
};
}"""
end

# ─── Compilation result ───

"""Result of compiling a For() render function."""
struct ForRenderResult
    render_js::String                               # JS render function code
    item_handlers::Vector{Tuple{Symbol, Function}}  # [(event_symbol, handler_fn), ...]
    item_tag::String                                # Tag of top-level rendered element (for event targeting)
end

# ─── Render function compiler ───

"""
    _compile_for_render(render_fn, for_id) -> ForRenderResult

Compile a For() render function to JS. Returns the render function code
plus any event handlers found on the top-level rendered element.
"""
function _compile_for_render(render_fn::Function, for_id::Int)::ForRenderResult
    marker = _ForItemRef()

    # Call render with marker item + sentinel index to detect item-dependent values
    marker_vnode = try
        Base.invokelatest(render_fn, marker, _FOR_INDEX_SENTINEL)
    catch
        Base.invokelatest(render_fn, marker)
    end

    # Extract event handlers from the top-level VNode
    item_handlers = Tuple{Symbol, Function}[]
    item_tag = ""
    if marker_vnode isa VNode
        item_tag = string(marker_vnode.tag)
        for (key, val) in marker_vnode.props
            key_str = string(key)
            if startswith(key_str, "on_") && (val isa Function)
                push!(item_handlers, (key, val))
            end
        end
    end

    # Generate the JS render function
    parts = String[]
    push!(parts, "      function _for_$(for_id)_render(item, idx) {")
    push!(parts, "        var html = '';")
    _vnode_to_js_html!(parts, marker_vnode, "item", "idx")
    push!(parts, "        return html;")
    push!(parts, "      }")

    return ForRenderResult(join(parts, "\n"), item_handlers, item_tag)
end

# ─── VNode → JS HTML walker ───

function _vnode_to_js_html!(parts::Vector{String}, node::VNode, item_var::String, idx_var::String)
    tag = string(node.tag)
    push!(parts, "        html += '<$(tag)';")

    for (key, val) in node.props
        key_str = string(key)
        startswith(key_str, "on_") && continue
        key == :dark_mode && continue
        attr_name = replace(key_str, "_" => "-")

        if val isa _ForItemRef
            push!(parts, "        html += ' $(attr_name)=\"' + _escH($(item_var)) + '\"';")
        elseif val isa String
            push!(parts, "        html += ' $(attr_name)=\"$(_esc_html_attr(val))\"';")
        elseif val isa Number
            push!(parts, "        html += ' $(attr_name)=\"$(val)\"';")
        elseif val isa Bool
            val && push!(parts, "        html += ' $(attr_name)';")
        end
    end

    is_void = node.tag in VOID_ELEMENTS
    if is_void
        push!(parts, "        html += ' />';")
        return
    end
    push!(parts, "        html += '>';")

    for child in node.children
        _vnode_to_js_html!(parts, child, item_var, idx_var)
    end

    push!(parts, "        html += '</$(tag)>';")
end

function _vnode_to_js_html!(parts::Vector{String}, ::_ForItemRef, item_var::String, idx_var::String)
    push!(parts, "        html += _escH($(item_var));")
end

function _vnode_to_js_html!(parts::Vector{String}, node::ForNode, item_var::String, idx_var::String)
    inner_item = item_var * "_j"
    inner_idx = idx_var * "_j"
    items_js = node.items isa _ForItemRef ? item_var : "[]"

    inner_marker = _ForItemRef()
    inner_vnode = try
        Base.invokelatest(node.render, inner_marker, 1)
    catch
        Base.invokelatest(node.render, inner_marker)
    end

    push!(parts, "        for (var $(inner_idx) = 0; $(inner_idx) < $(items_js).length; $(inner_idx)++) {")
    push!(parts, "          var $(inner_item) = $(items_js)[$(inner_idx)];")
    _vnode_to_js_html!(parts, inner_vnode, inner_item, inner_idx)
    push!(parts, "        }")
end

function _vnode_to_js_html!(parts::Vector{String}, node::Fragment, item_var::String, idx_var::String)
    for child in node.children
        _vnode_to_js_html!(parts, child, item_var, idx_var)
    end
end

function _vnode_to_js_html!(parts::Vector{String}, node::AbstractString, item_var::String, idx_var::String)
    push!(parts, "        html += '$(_esc_js_str(node))';")
end

function _vnode_to_js_html!(parts::Vector{String}, node::Number, item_var::String, idx_var::String)
    push!(parts, "        html += '$(node)';")
end

function _vnode_to_js_html!(parts::Vector{String}, node, item_var::String, idx_var::String)
end

# ─── For item event handler compilation ───

"""
    _compile_for_item_handler(handler, for_id, event_name, analysis, sig_idx) -> NamedTuple or nothing

Compile a For item event handler to WASM. The handler closure captures signal
getters/setters (mapped to WasmGlobal) and the For index sentinel.

Returns (func_js, modified_signals, idx_var_name) or nothing on failure.

NOTE: For item handlers are complex (capture index sentinel + signals).
WASM compilation of For handlers is deferred to TWASM-400+.
Currently returns nothing (For item events will not be interactive until then).
"""
function _compile_for_item_handler(handler::Function, for_id::Int, event_name::Symbol,
                                    analysis, sig_idx::Dict{UInt64, Int})
    # TODO: TWASM-400+ — implement For item handler WASM compilation
    # For now, return nothing. For() rendering works but item click handlers are skipped.
    @debug "For item handler compilation not yet implemented for WASM" for_id event_name
    return nothing
end

# ─── Helpers ───

function _esc_html_attr(s::String)::String
    s = replace(s, "&" => "&amp;")
    s = replace(s, "\"" => "&quot;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    return s
end

function _esc_js_str(s)::String
    str = string(s)
    str = replace(str, "\\" => "\\\\")
    str = replace(str, "'" => "\\'")
    str = replace(str, "\n" => "\\n")
    str = replace(str, "\r" => "\\r")
    return str
end

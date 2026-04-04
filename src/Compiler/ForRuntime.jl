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
Base.getindex(::Vector, ::_ForItemRef) = _ForItemRef()
Base.to_index(::_ForItemRef) = 1
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
var items=[],nodes=[],owners=[];
function makeNode(item,idx){
var o=__t.createOwner();
var t=document.createElement('template');
__t.runWithOwner(o,function(){t.innerHTML=renderFn(item,idx);});
return{node:t.content.firstChild,owner:o};
}
return function(newItems){
if(!newItems||newItems.length===0){
for(var i=0;i<owners.length;i++)__t.dispose(owners[i]);
container.innerHTML='';items=[];nodes=[];owners=[];return;
}
var newLen=newItems.length,oldLen=items.length;
if(oldLen===0){
var f=document.createDocumentFragment();
var nn=new Array(newLen),no=new Array(newLen);
for(var i=0;i<newLen;i++){var r=makeNode(newItems[i],i+1);nn[i]=r.node;no[i]=r.owner;f.appendChild(nn[i]);}
container.innerHTML='';container.appendChild(f);
items=newItems.slice();nodes=nn;owners=no;return;
}
var newNodes=new Array(newLen),newOwners=new Array(newLen);
var start=0,end=Math.min(oldLen,newLen)-1;
var oEnd=oldLen-1,nEnd=newLen-1;
while(start<=end&&items[start]===newItems[start]){newNodes[start]=nodes[start];newOwners[start]=owners[start];start++;}
while(oEnd>=start&&nEnd>=start&&items[oEnd]===newItems[nEnd]){newNodes[nEnd]=nodes[oEnd];newOwners[nEnd]=owners[oEnd];oEnd--;nEnd--;}
var map=new Map();
for(var i=start;i<=oEnd;i++)map.set(items[i],i);
for(var j=start;j<=nEnd;j++){
var item=newItems[j];
var oi=map.get(item);
if(oi!==undefined){newNodes[j]=nodes[oi];newOwners[j]=owners[oi];map.delete(item);}
else{var r=makeNode(item,j+1);newNodes[j]=r.node;newOwners[j]=r.owner;}
}
map.forEach(function(oi){__t.dispose(owners[oi]);var n=nodes[oi];if(n&&n.parentNode)n.parentNode.removeChild(n);});
var f=document.createDocumentFragment();
for(var j=0;j<newLen;j++)f.appendChild(newNodes[j]);
container.innerHTML='';container.appendChild(f);
items=newItems.slice();nodes=newNodes;owners=newOwners;
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

Compile a For item event handler to JS via IR extraction.
Uses event delegation on the container element.

Returns (func_js, modified_signals, idx_var_name) or nothing on failure.

The handler closure captures signal getters/setters and the For index sentinel.
Signal operations are extracted from IR and emitted as pure JS.
The index sentinel (_FOR_INDEX_SENTINEL) is replaced with the runtime `idx` variable.
"""
function _compile_for_item_handler(handler::Function, for_id::Int, event_name::Symbol,
                                    analysis, sig_idx::Dict{UInt64, Int})
    try
        closure_type = typeof(handler)
        fnames = fieldnames(closure_type)
        isempty(fnames) && return nothing

        # Extract signal ops from IR as JS
        ops_js = _extract_for_handler_ops_js(handler, analysis, sig_idx, for_id)
        isempty(ops_js) && return nothing

        idx_var = "_for_$(for_id)_idx"
        event_short = string(event_name)[4:end]  # strip "on_"
        fn_name = "_for_$(for_id)_$(event_short)"

        func_lines = String[]
        push!(func_lines, "        function $(fn_name)() {")
        for op in ops_js
            push!(func_lines, "          $op")
        end
        push!(func_lines, "        }")

        return (func_js=join(func_lines, "\n"), idx_var=idx_var)
    catch e
        @debug "For item handler JS extraction failed" for_id event_name exception=e
        return nothing
    end
end

"""
Extract signal operations from a For item handler's IR and emit as JS.
Replaces the index sentinel with the runtime `idx` variable.
"""
function _extract_for_handler_ops_js(handler::Function, analysis, sig_idx::Dict{UInt64, Int}, for_id::Int)::Vector{String}
    ops = String[]
    typed_results = Base.code_typed(handler, ())
    isempty(typed_results) && return ops
    code_info = typed_results[1][1]
    closure_type = typeof(handler)

    # Map getfield SSAs to field names
    ssa_field = Dict{Int, Symbol}()
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3
            if stmt.args[1] isa GlobalRef && stmt.args[1].name === :getfield && stmt.args[3] isa QuoteNode
                ssa_field[i] = stmt.args[3].value::Symbol
            end
        end
    end

    # Map SSAs to getter JS expressions
    ssa_getter_js = Dict{Int, String}()
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 2
            src = stmt.args[2]
            src_id = src isa Core.SSAValue ? src.id : nothing
            fname = src_id !== nothing ? get(ssa_field, src_id, nothing) : nothing
            fname === nothing && continue
            if fname in fieldnames(closure_type)
                captured = getfield(handler, fname)
                gid = get(analysis.getter_map, captured, nothing)
                if gid !== nothing
                    idx = get(sig_idx, gid, nothing)
                    idx !== nothing && (ssa_getter_js[i] = "s$(idx)[0]()")
                end
            end
        end
    end

    # Find setter calls and emit JS
    for (i, stmt) in enumerate(code_info.code)
        if stmt isa Expr && stmt.head === :invoke && length(stmt.args) >= 3
            ci_or_mi = stmt.args[1]
            mi = if ci_or_mi isa Core.CodeInstance; ci_or_mi.def
            elseif ci_or_mi isa Core.MethodInstance; ci_or_mi
            else; nothing; end
            mi === nothing && continue
            mi isa Core.MethodInstance || continue
            mi.specTypes === nothing && continue
            params = mi.specTypes.parameters
            length(params) >= 1 || continue
            params[1] <: SignalSetter || continue

            setter_src = stmt.args[2]
            setter_src_id = setter_src isa Core.SSAValue ? setter_src.id : nothing
            setter_fname = setter_src_id !== nothing ? get(ssa_field, setter_src_id, nothing) : nothing
            setter_fname === nothing && continue
            if setter_fname in fieldnames(closure_type)
                captured = getfield(handler, setter_fname)
                sid = get(analysis.setter_map, captured, nothing)
                sid === nothing && continue
                idx = get(sig_idx, sid, nothing)
                idx === nothing && continue

                val_arg = stmt.args[3]
                val_js = _resolve_for_value_js(val_arg, code_info, ssa_getter_js, for_id)
                push!(ops, "s$(idx)[1]($val_js);")
                push!(ops, "ex.signal_$(idx).value=BigInt(s$(idx)[0]());")
            end
        end
    end
    return ops
end

"""Resolve an IR value to a JS expression, replacing the For index sentinel with the runtime idx var."""
function _resolve_for_value_js(val, code_info, ssa_getter_js, for_id)::String
    if val isa Core.SSAValue
        js = get(ssa_getter_js, val.id, nothing)
        js !== nothing && return js

        stmt = code_info.code[val.id]
        if stmt isa Expr && stmt.head === :call && length(stmt.args) >= 3
            fname = stmt.args[1]
            op_name = if fname isa GlobalRef; fname.name
            elseif fname isa Core.IntrinsicFunction; nameof(fname)
            else; nothing; end

            if op_name !== nothing
                a = _resolve_for_value_js(stmt.args[2], code_info, ssa_getter_js, for_id)
                b = _resolve_for_value_js(stmt.args[3], code_info, ssa_getter_js, for_id)
                if op_name === :sub_int; return "($a - $b)"
                elseif op_name === :add_int; return "($a + $b)"
                elseif op_name === :mul_int; return "($a * $b)"
                end
            end
        end
        return "undefined"
    elseif val isa Integer
        # Check for the index sentinel
        if val == _FOR_INDEX_SENTINEL
            return "_for_$(for_id)_idx"
        end
        return string(val)
    elseif val isa AbstractString
        return "'$(val)'"
    else
        return string(val)
    end
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

# StringTable.jl - Compile-time string table for Wasm DOM imports
#
# Wasm cannot pass strings to JS. All strings (class names, attribute names,
# attribute values, style properties, style values) are registered at compile
# time into a numbered table. Wasm passes integer IDs; JS looks up the string.

"""
    StringTable

Compile-time string registry for Wasm DOM bridge imports.

Wasm components reference strings (class names, attributes, etc.) by integer ID.
The string table maps these IDs to actual string values, emitted as a JS array
alongside the Wasm module.

String IDs are deterministic: strings are sorted alphabetically before ID
assignment, ensuring identical input always produces identical output (cacheable).

# Example
```julia
st = StringTable()
register_string!(st, "hidden")
register_string!(st, "bg-warm-100")
register_string!(st, "data-state")
emit_string_table(st)
# => `["bg-warm-100","data-state","hidden"]`
# IDs: bg-warm-100=0, data-state=1, hidden=2 (alphabetical order)
```
"""
mutable struct StringTable
    strings::Set{String}           # Collected strings (unordered during registration)
    frozen::Bool                   # True after IDs have been assigned
    id_map::Dict{String, Int32}    # String -> ID (populated when frozen)
    sorted::Vector{String}         # Sorted strings (populated when frozen)

    StringTable() = new(Set{String}(), false, Dict{String, Int32}(), String[])
end

"""
    register_string!(table::StringTable, str::String) -> Nothing

Register a string in the table. Can be called multiple times with the same
string (duplicates are ignored). Must be called before the table is frozen.
"""
function register_string!(table::StringTable, str::String)
    table.frozen && error("Cannot register strings after table is frozen")
    push!(table.strings, str)
    return nothing
end

"""
    freeze!(table::StringTable) -> Nothing

Freeze the table: sort strings alphabetically and assign deterministic IDs.
After freezing, no new strings can be registered, but IDs can be looked up.
Calling freeze! on an already-frozen table is a no-op.
"""
function freeze!(table::StringTable)
    table.frozen && return nothing
    table.sorted = sort!(collect(table.strings))
    for (i, str) in enumerate(table.sorted)
        table.id_map[str] = Int32(i - 1)  # 0-indexed
    end
    table.frozen = true
    return nothing
end

"""
    get_id(table::StringTable, str::String) -> Int32

Get the integer ID for a registered string. Freezes the table if not already frozen.
Throws an error if the string was not registered.
"""
function get_id(table::StringTable, str::String)::Int32
    if !table.frozen
        freeze!(table)
    end
    haskey(table.id_map, str) || error("String not registered in table: $(repr(str))")
    return table.id_map[str]
end

"""
    emit_string_table(table::StringTable) -> String

Generate a JavaScript array literal containing all registered strings.
Freezes the table if not already frozen. Returns `[]` if no strings are registered.

Strings are properly escaped for JavaScript (backslashes and double quotes).
"""
function emit_string_table(table::StringTable)::String
    if !table.frozen
        freeze!(table)
    end
    if isempty(table.sorted)
        return "[]"
    end
    # Escape strings for JS (handle backslashes, then quotes)
    escaped = [replace(replace(s, "\\" => "\\\\"), "\"" => "\\\"") for s in table.sorted]
    return "[" * join(["\"$s\"" for s in escaped], ",") * "]"
end

Base.length(table::StringTable) = length(table.strings)
Base.isempty(table::StringTable) = isempty(table.strings)

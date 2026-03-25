# Interactive data table — SSR provides data, island adds sort/filter interactivity
# Pattern: SSR function builds data → passes as props → island renders interactively

# SSR component: builds sample data and passes to the DataExplorer island
function DataTable()
    # This runs in Julia at serve/build time — full Julia available
    columns = ["Name", "Age", "Score", "City"]
    rows = [
        ["Alice",  "28", "95.2", "Portland"],
        ["Bob",    "35", "87.1", "Austin"],
        ["Carol",  "42", "91.8", "Denver"],
        ["Dave",   "23", "78.4", "Seattle"],
        ["Eve",    "31", "93.6", "Boston"],
        ["Frank",  "45", "82.3", "Chicago"],
        ["Grace",  "27", "96.1", "Miami"]
    ]

    # Pass to island as props — serialized as JSON for hydration
    DataExplorer(columns=columns, rows=rows)
end

# Island: receives data as props, adds interactive sorting
@island function DataExplorer(; columns::Vector{String} = String[], rows::Vector{Vector{String}} = Vector{String}[])
    sort_col, set_sort_col = create_signal(0)

    create_effect(() -> begin
        col = sort_col()
        js("var el = document.getElementById('therapy-table')")
        js("if (!el) return")
        js("var cols = \$1", columns)
        js("var rows = \$1", rows)
        js("var c = \$1", col)

        # Sort rows by column
        js("var sorted = rows.slice()")
        js("if (c !== 0) { var ci = Math.abs(c) - 1; var dir = c > 0 ? 1 : -1; sorted.sort(function(a, b) { var va = ci === 1 ? Number(a[ci]) : ci === 2 ? Number(a[ci]) : a[ci]; var vb = ci === 1 ? Number(b[ci]) : ci === 2 ? Number(b[ci]) : b[ci]; return dir * (va < vb ? -1 : va > vb ? 1 : 0) }) }")

        # Render table
        js("var h = '<table class=\"w-full text-sm\"><thead><tr>'")
        js("for (var i = 0; i < cols.length; i++) { var ci = i + 1; var arrow = Math.abs(c) === ci ? (c > 0 ? ' ↑' : ' ↓') : ''; h += '<th class=\"text-left px-4 py-2.5 border-b-2 border-warm-200 dark:border-warm-700 font-semibold text-warm-700 dark:text-warm-300 cursor-pointer hover:text-accent-500 transition-colors select-none\" data-col=\"' + ci + '\">' + cols[i] + '<span class=\"text-accent-500 ml-1\">' + arrow + '</span></th>' }")
        js("h += '</tr></thead><tbody>'")
        js("for (var j = 0; j < sorted.length; j++) { var r = sorted[j]; var stripe = j % 2 === 0 ? '' : ' bg-warm-50 dark:bg-warm-900/30'; h += '<tr class=\"border-b border-warm-100 dark:border-warm-900' + stripe + '\"><td class=\"px-4 py-2 font-medium\">' + r[0] + '</td><td class=\"px-4 py-2 font-mono text-warm-600 dark:text-warm-400\">' + r[1] + '</td><td class=\"px-4 py-2 font-mono text-warm-600 dark:text-warm-400\">' + r[2] + '</td><td class=\"px-4 py-2 text-warm-500 dark:text-warm-400\">' + r[3] + '</td></tr>' }")
        js("h += '</tbody></table>'")
        js("el.innerHTML = h")

        # Sort on header click — toggle direction
        js("el.querySelectorAll('th[data-col]').forEach(function(th) { th.addEventListener('click', function() { var ci = Number(th.dataset.col); \$1(Math.abs(\$2()) === ci ? -\$2() : ci) }) })", set_sort_col, sort_col)
    end)

    Div(:id => "therapy-table",
        :class => "w-full max-w-3xl rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden")
end

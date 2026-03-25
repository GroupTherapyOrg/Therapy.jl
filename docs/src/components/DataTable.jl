# Interactive data table — sortable columns, pure Julia data compiled to JS
@island function DataTable()
    sort_col, set_sort_col = create_signal(0)

    create_effect(() -> begin
        col = sort_col()

        # Sample data — plain Julia arrays compiled to JS
        names = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace"]
        ages = [28, 35, 42, 23, 31, 45, 27]
        scores = [95.2, 87.1, 91.8, 78.4, 93.6, 82.3, 96.1]

        js("var el = document.getElementById('therapy-table')")
        js("if (!el) return")

        # Sort by selected column (col: 0=none, 1=name, 2=age, 3=score, negative=desc)
        js("var idx = Array.from({length: \$1.length}, function(_, i) { return i })", names)
        js("var c = \$1", col)
        js("if (c !== 0) { var abs_c = Math.abs(c); var dir = c > 0 ? 1 : -1; idx.sort(function(a, b) { var va = abs_c === 1 ? \$1[a] : abs_c === 2 ? \$2[a] : \$3[a]; var vb = abs_c === 1 ? \$1[b] : abs_c === 2 ? \$2[b] : \$3[b]; return dir * (va < vb ? -1 : va > vb ? 1 : 0) }) }", names, ages, scores)

        # Render sorted table
        js("var h = '<table class=\"w-full text-sm\"><thead><tr>'")
        js("var cols = ['Name', 'Age', 'Score']")
        js("for (var i = 0; i < 3; i++) { var ci = i + 1; var arrow = Math.abs(c) === ci ? (c > 0 ? ' ↑' : ' ↓') : ''; h += '<th class=\"text-left px-4 py-2 border-b border-warm-200 dark:border-warm-800 cursor-pointer hover:text-accent-500 transition-colors select-none\" data-col=\"' + ci + '\">' + cols[i] + arrow + '</th>' }")
        js("h += '</tr></thead><tbody>'")
        js("for (var j = 0; j < idx.length; j++) { var k = idx[j]; h += '<tr class=\"border-b border-warm-100 dark:border-warm-900 hover:bg-warm-100/50 dark:hover:bg-warm-900/50\"><td class=\"px-4 py-2 font-medium\">' + \$1[k] + '</td><td class=\"px-4 py-2 font-mono\">' + \$2[k] + '</td><td class=\"px-4 py-2 font-mono\">' + \$3[k].toFixed(1) + '</td></tr>' }", names, ages, scores)
        js("h += '</tbody></table>'")
        js("el.innerHTML = h")

        # Attach click handlers to column headers
        js("el.querySelectorAll('th[data-col]').forEach(function(th) { th.addEventListener('click', function() { var ci = Number(th.dataset.col); \$1(Math.abs(\$2()) === ci ? -\$2() : ci) }) })", set_sort_col, sort_col)
    end)

    Div(:id => "therapy-table",
        :class => "w-full max-w-2xl rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden")
end

# ── NotebookDemo ──
# Step-by-step notebook UI stress test.
# Builds toward a complete published notebook UI, one piece at a time.

# ─── Step 1: Static Code Cell ───
# A read-only code block + rendered output. The atom of a notebook.

function NotebookCell(; code::String, output::String, cell_num::Int = 1)
    Div(:class => "group relative",
        # Cell number (subtle, left gutter)
        Div(:class => "absolute -left-8 top-3 text-xs text-warm-400 dark:text-warm-600 font-mono select-none opacity-0 group-hover:opacity-100 transition-opacity",
            string(cell_num)),
        # Code block
        Div(:class => "border border-warm-200 dark:border-warm-800 rounded-t-lg overflow-hidden",
            Pre(:class => "bg-warm-100 dark:bg-warm-900 p-4 font-mono text-sm text-warm-800 dark:text-warm-200 overflow-x-auto m-0",
                Code(:class => "language-julia", code))
        ),
        # Output
        Div(:class => "border border-t-0 border-warm-200 dark:border-warm-800 rounded-b-lg bg-white dark:bg-warm-950 px-4 py-3 text-sm text-warm-700 dark:text-warm-300 font-mono",
            output)
    )
end

function NotebookDemo()
    Div(:class => "w-full max-w-3xl mx-auto space-y-2 pl-10",
        NotebookCell(
            cell_num = 1,
            code = "x = [1, 2, 3, 4, 5]\nsum(x)",
            output = "15"
        ),
        NotebookCell(
            cell_num = 2,
            code = "using Statistics\nmean(x), std(x)",
            output = "(3.0, 1.5811388300841898)"
        ),
        NotebookCell(
            cell_num = 3,
            code = "cumsum(x)",
            output = "[1, 3, 6, 10, 15]"
        )
    )
end

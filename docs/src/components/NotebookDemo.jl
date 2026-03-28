# ── NotebookDemo ──
# Step-by-step notebook UI stress test.
# Builds toward a complete published notebook UI, one piece at a time.
# Styling matches Sessions.jl's notebook panel.

import PlotlyBase

# ═══════════════════════════════════════════════════════════
# REUSABLE CELL COMPONENTS (SSR — pure Julia functions)
# ═══════════════════════════════════════════════════════════

# Shared cell wrapper: accent bar + gutter number + hover controls
function _cell_wrap(children...; cell_num::Int)
    Div(:class => "group relative pl-7 py-[3px]",
        # Cell number in left gutter (visible on hover)
        Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none",
            string(cell_num)),
        children...
    )
end

# Code cell: accent bar left edge, rounded, proper dark/light backgrounds
function NotebookCell(; code::String, output::String = "", cell_num::Int = 1, hide_output::Bool = false)
    Div(:class => "group relative pl-7 py-[3px]",
        Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none",
            string(cell_num)),
        # Code block with left accent bar
        Div(:class => "relative rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
            Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500 dark:bg-accent-400 opacity-30 group-hover:opacity-60 transition-opacity rounded-l-lg"),
            Pre(:class => "bg-warm-50 dark:bg-[#1a2332] pl-4 pr-4 py-3 font-mono text-[13px] leading-[1.6] text-warm-800 dark:text-warm-200 overflow-x-auto m-0",
                Code(:class => "language-julia", code))
        ),
        hide_output ? Span() :
        Div(:class => "mt-1 px-1",
            Div(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf] leading-[1.5] py-1",
                output))
    )
end

# Markdown cell: prose content between code cells
function NotebookMarkdown(children...; cell_num::Int = 1)
    _cell_wrap(cell_num=cell_num,
        Div(:class => "px-1 py-2 text-warm-700 dark:text-warm-300 text-[14px] leading-[1.7]",
            children...)
    )
end

# Cell gap divider
function CellGap()
    Div(:class => "flex items-center justify-center h-[20px] my-[2px] group/gap",
        Div(:class => "flex items-center gap-1.5 opacity-0 group-hover/gap:opacity-100 transition-opacity",
            Div(:class => "h-px w-10 bg-warm-200 dark:bg-warm-800"),
            Div(:class => "text-[10px] text-warm-400 dark:text-warm-600 select-none", "+"),
            Div(:class => "h-px w-10 bg-warm-200 dark:bg-warm-800")
        )
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 1: Static Code Cells (pure SSR)
# ═══════════════════════════════════════════════════════════

function NotebookStep1()
    Div(:class => "w-full max-w-[750px] mx-auto",
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Array Operations"),
            P(:class => "text-warm-600 dark:text-warm-400", "Basic array creation, reduction, and cumulative operations.")),
        CellGap(),
        NotebookCell(
            cell_num = 2,
            code = "x = [1, 2, 3, 4, 5]\nsum(x)",
            output = "15"
        ),
        CellGap(),
        NotebookCell(
            cell_num = 3,
            code = "using Statistics\nmean(x), std(x)",
            output = "(3.0, 1.5811388300841898)"
        ),
        CellGap(),
        NotebookCell(
            cell_num = 4,
            code = "cumsum(x)",
            output = "[1, 3, 6, 10, 15]"
        )
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 2: Markdown + Collapsible Code (uses Show, create_signal)
# ═══════════════════════════════════════════════════════════

@island function NotebookStep2(;
        code_1::String = "",
        output_1::String = "",
        code_2::String = "",
        output_2::String = ""
    )
    code_visible, set_code_visible = create_signal(1)

    on_mount(() -> println("Notebook cells hydrated"))

    return Div(:class => "w-full max-w-[750px] mx-auto",
        # Toggle button
        Div(:class => "flex items-center gap-2 mb-2",
            Button(
                :class => "flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-mono border border-warm-200 dark:border-warm-800 text-warm-500 dark:text-warm-400 hover:text-accent-500 dark:hover:text-accent-400 hover:border-accent-300 dark:hover:border-accent-700 cursor-pointer transition-colors",
                :on_click => () -> set_code_visible(1 - code_visible()),
                Span(:class => "text-[10px]", code_visible() == 1 ? "◉" : "○"),
                " toggle code"
            )
        ),

        # Cell 1: Markdown (always shown)
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Data Analysis"),
            P(:class => "text-warm-600 dark:text-warm-400", "Summary statistics computed below. Toggle code visibility with the button above.")),
        CellGap(),

        # Cell 2: Code with Show toggle
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "2"),
            Show(code_visible) do
                Div(:class => "relative rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden mb-1 transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
                    Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500 dark:bg-accent-400 opacity-30 group-hover:opacity-60 transition-opacity rounded-l-lg"),
                    Pre(:class => "bg-warm-50 dark:bg-[#1a2332] pl-4 pr-4 py-3 font-mono text-[13px] leading-[1.6] text-warm-800 dark:text-warm-200 overflow-x-auto m-0",
                        Code(:class => "language-julia", code_1)))
            end,
            Div(:class => "px-1",
                Div(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf] leading-[1.5] py-1",
                    output_1))
        ),
        CellGap(),

        # Cell 3: Second code cell
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "3"),
            Show(code_visible) do
                Div(:class => "relative rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden mb-1 transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
                    Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500 dark:bg-accent-400 opacity-30 group-hover:opacity-60 transition-opacity rounded-l-lg"),
                    Pre(:class => "bg-warm-50 dark:bg-[#1a2332] pl-4 pr-4 py-3 font-mono text-[13px] leading-[1.6] text-warm-800 dark:text-warm-200 overflow-x-auto m-0",
                        Code(:class => "language-julia", code_2)))
            end,
            Div(:class => "px-1",
                Div(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf] leading-[1.5] py-1",
                    output_2))
        )
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 3: Slider → Reactive Output (the @bind pattern)
# Uses: create_signal, create_memo, create_effect
# ═══════════════════════════════════════════════════════════

@island function NotebookStep3(; n_init::Int = 10)
    n, set_n = create_signal(n_init)

    # Memo: dependent cell computation
    total = create_memo(() -> begin
        count = n()
        s = 0
        for i in 1:count
            s = s + i
        end
        s
    end)

    create_effect(() -> println("n=", n(), " sum=", total()))

    return Div(:class => "w-full max-w-[750px] mx-auto",
        # Markdown
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Interactive Computation"),
            P(:class => "text-warm-600 dark:text-warm-400", "Drag the slider — the dependent cell recomputes reactively. Open console to see effect logging.")),
        CellGap(),

        # @bind cell
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "2"),
            Div(:class => "relative rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
                Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500 dark:bg-accent-400 opacity-30 group-hover:opacity-60 transition-opacity rounded-l-lg"),
                Pre(:class => "bg-warm-50 dark:bg-[#1a2332] pl-4 pr-4 py-3 font-mono text-[13px] leading-[1.6] text-warm-800 dark:text-warm-200 m-0",
                    Code(:class => "language-julia", "@bind n Slider(1:50)"))
            ),
            # Slider output
            Div(:class => "mt-1 px-1",
                Div(:class => "flex items-center gap-3 py-1",
                    Input(:type => "range", :min => "1", :max => "50",
                        :value => n, :on_input => set_n,
                        :class => "flex-1 accent-accent-500 h-[6px]"),
                    Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", n)
                )
            )
        ),
        CellGap(),

        # Dependent cell
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "3"),
            Div(:class => "relative rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
                Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500 dark:bg-accent-400 opacity-30 group-hover:opacity-60 transition-opacity rounded-l-lg"),
                Pre(:class => "bg-warm-50 dark:bg-[#1a2332] pl-4 pr-4 py-3 font-mono text-[13px] leading-[1.6] text-warm-800 dark:text-warm-200 m-0",
                    Code(:class => "language-julia", "sum(1:n)"))
            ),
            # Reactive output
            Div(:class => "mt-1 px-1",
                Div(:class => "flex items-center gap-2 py-1",
                    Span(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf]", total),
                    Span(:class => "text-[10px] font-mono px-1.5 py-px rounded-full bg-accent-500/10 text-accent-600 dark:text-accent-400 border border-accent-500/20", "reactive")
                )
            )
        )
    )
end

# ═══════════════════════════════════════════════════════════
# SSR ENTRY POINTS
# ═══════════════════════════════════════════════════════════

function NotebookDemo()
    NotebookStep1()
end

function NotebookDemo2()
    NotebookStep2(
        code_1 = "mean(x), median(x), std(x)",
        output_1 = "(3.0, 3.0, 1.5811388300841898)",
        code_2 = "cumsum(x)",
        output_2 = "[1, 3, 6, 10, 15]"
    )
end

function NotebookDemo3()
    NotebookStep3(n_init=10)
end

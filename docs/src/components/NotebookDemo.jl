# ── NotebookDemo ──
# Step-by-step notebook UI stress test.
# Builds toward a complete published notebook UI, one piece at a time.
# Styling matches Sessions.jl / Pluto.jl notebook panel.
# OUTPUT ABOVE CODE — Pluto convention.

import PlotlyBase

# ═══════════════════════════════════════════════════════════
# SVG ICONS
# ═══════════════════════════════════════════════════════════

# Eye open (code visible)
const EYE_OPEN_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>"""

# Eye closed (code hidden)
const EYE_CLOSED_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>"""

# ═══════════════════════════════════════════════════════════
# REUSABLE CELL COMPONENTS
# ═══════════════════════════════════════════════════════════

# Code block element (used inside cells)
function _code_block(code::String)
    Div(:class => "relative rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
        # Left accent bar
        Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500/40 dark:bg-accent-400/40 group-hover:bg-accent-500/70 dark:group-hover:bg-accent-400/70 transition-all rounded-l-lg"),
        # Code
        Pre(:class => "bg-warm-50 dark:bg-[#1a2332] py-2.5 pl-4 pr-3 m-0 overflow-x-auto",
            Code(:class => "language-julia text-[13px] leading-[1.6] font-mono text-warm-800 dark:text-warm-200", code))
    )
end

# Output element (shown above code — Pluto style)
function _output_block(output)
    Div(:class => "px-1 py-1.5",
        Div(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf] leading-[1.5]",
            output))
end

# Static code cell: output on top, code below
function NotebookCell(; code::String, output::String = "", cell_num::Int = 1, hide_output::Bool = false)
    Div(:class => "group relative pl-7 py-[3px]",
        # Gutter number
        Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-start pt-2 justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none",
            string(cell_num)),
        # Output ABOVE code (Pluto style)
        hide_output || output == "" ? Span() : _output_block(output),
        # Code
        _code_block(code)
    )
end

# Markdown cell
function NotebookMarkdown(children...; cell_num::Int = 1)
    Div(:class => "group relative pl-7 py-[3px]",
        Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-start pt-3 justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none",
            string(cell_num)),
        Div(:class => "px-1 py-2 text-warm-700 dark:text-warm-300 text-[14px] leading-[1.7]",
            children...)
    )
end

# Cell gap divider
function CellGap()
    Div(:class => "flex items-center justify-center h-[18px] my-[1px] group/gap",
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
        NotebookCell(cell_num=2, code="x = [1, 2, 3, 4, 5]\nsum(x)", output="15"),
        CellGap(),
        NotebookCell(cell_num=3, code="using Statistics\nmean(x), std(x)", output="(3.0, 1.5811388300841898)"),
        CellGap(),
        NotebookCell(cell_num=4, code="cumsum(x)", output="[1, 3, 6, 10, 15]")
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 2: Markdown + Collapsible Code (Show, create_signal, on_mount)
# Eye toggle: open/closed SVG icons
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
        # Markdown
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Data Analysis"),
            P(:class => "text-warm-600 dark:text-warm-400", "Summary statistics computed below. Click the eye icon in the gutter to toggle code.")),
        CellGap(),

        # Cell 2: output above, code below (toggleable)
        Div(:class => "group relative pl-7 py-[3px]",
            # Eye toggle in gutter
            Button(
                :class => "absolute left-0 top-0 bottom-0 w-6 flex items-start pt-2 justify-center text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400 opacity-0 group-hover:opacity-100 transition-all cursor-pointer select-none",
                :on_click => () -> set_code_visible(1 - code_visible()),
                Span(:class => "inline-block", code_visible() == 1 ? EYE_OPEN_SVG : EYE_CLOSED_SVG)
            ),
            # Output (always visible, above code)
            _output_block(output_1),
            # Code (toggleable)
            Show(code_visible) do
                _code_block(code_1)
            end
        ),
        CellGap(),

        # Cell 3
        Div(:class => "group relative pl-7 py-[3px]",
            Button(
                :class => "absolute left-0 top-0 bottom-0 w-6 flex items-start pt-2 justify-center text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400 opacity-0 group-hover:opacity-100 transition-all cursor-pointer select-none",
                :on_click => () -> set_code_visible(1 - code_visible()),
                Span(:class => "inline-block", code_visible() == 1 ? EYE_OPEN_SVG : EYE_CLOSED_SVG)
            ),
            _output_block(output_2),
            Show(code_visible) do
                _code_block(code_2)
            end
        )
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 3: Slider → Reactive Output (the @bind pattern)
# Uses: create_signal, create_memo, create_effect
# Output above code (Pluto style)
# ═══════════════════════════════════════════════════════════

@island function NotebookStep3(; n_init::Int = 10)
    n, set_n = create_signal(n_init)

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
            P(:class => "text-warm-600 dark:text-warm-400", "Drag the slider — the dependent cell recomputes reactively.")),
        CellGap(),

        # @bind cell: output (slider) above code
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-start pt-2 justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "2"),
            # Slider output (above code)
            Div(:class => "px-1 py-1.5",
                Div(:class => "flex items-center gap-3",
                    Input(:type => "range", :min => "1", :max => "50",
                        :value => n, :on_input => set_n,
                        :class => "flex-1 accent-accent-500 h-[6px]"),
                    Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", n)
                )
            ),
            # Code
            _code_block("@bind n Slider(1:50)")
        ),
        CellGap(),

        # Dependent cell: reactive output above code
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-start pt-2 justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "3"),
            # Reactive output (above code)
            Div(:class => "px-1 py-1.5",
                Div(:class => "flex items-center gap-2",
                    Span(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf]", total),
                    Span(:class => "text-[10px] font-mono px-1.5 py-px rounded-full bg-accent-500/10 text-accent-600 dark:text-accent-400 border border-accent-500/20", "reactive")
                )
            ),
            # Code
            _code_block("sum(1:n)")
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

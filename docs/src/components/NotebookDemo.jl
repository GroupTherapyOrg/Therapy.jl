# ── NotebookDemo ──
# Step-by-step notebook UI stress test.
# Styling follows Sessions.jl's notebook panel 1:1 but in pure Tailwind.
# OUTPUT ABOVE CODE — Pluto convention.

import PlotlyBase

# ═══════════════════════════════════════════════════════════
# SVG ICONS (same as Sessions.jl)
# ═══════════════════════════════════════════════════════════

const _EYE_OPEN = """<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>"""
const _EYE_CLOSED = """<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19M1 1l22 22"/></svg>"""
const _PLUS = """<svg width="8" height="8" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M8 2v12M2 8h12"/></svg>"""

# ═══════════════════════════════════════════════════════════
# REUSABLE CELL COMPONENTS
# ═══════════════════════════════════════════════════════════

# Code block: single Div, whitespace-pre, no <pre>/<code> defaults
function _code_block(code::String; runtime::String = "")
    Div(:class => "relative rounded-lg border border-warm-200 dark:border-warm-800 bg-warm-50 dark:bg-[#1a2332] overflow-hidden transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
        # Left accent bar
        Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500/40 dark:bg-accent-400/40 group-hover:bg-accent-500/70 dark:group-hover:bg-accent-400/70 transition-all"),
        # Runtime badge (top-right, hover visible)
        runtime == "" ? Span() :
        Div(:class => "absolute top-1 right-1.5 z-10 opacity-0 group-hover:opacity-100 transition-opacity",
            _runtime_badge(runtime)),
        # Code text
        Div(:class => "py-2.5 pl-4 pr-3 overflow-x-auto whitespace-pre font-mono text-[13px] leading-[1.6] text-warm-800 dark:text-warm-200",
            code)
    )
end

# Output block (above code)
function _output_block(output)
    Div(:class => "px-1 py-1.5 overflow-x-auto",
        Div(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf] leading-[1.5]",
            output))
end

# Runtime badge (shows execution time)
function _runtime_badge(time_str::String)
    Span(:class => "text-[10px] font-mono px-[7px] py-px rounded-full text-accent-600 dark:text-accent-400 opacity-80 border border-accent-500/15 bg-accent-500/10",
        time_str)
end

# Static code cell: output on top, code below, runtime badge on hover
function NotebookCell(; code::String, output::String = "", cell_num::Int = 1, runtime::String = "")
    Div(:class => "group relative pl-7 py-[3px]",
        Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none",
            string(cell_num)),
        output == "" ? Span() : _output_block(output),
        _code_block(code; runtime=runtime)
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

# Cell gap: subtle divider with + button (Sessions style)
function CellGap()
    Div(:class => "flex items-center justify-center h-[26px] my-[2px] group/gap",
        Div(:class => "flex items-center gap-1 opacity-0 group-hover/gap:opacity-100 transition-opacity",
            Div(:class => "h-px w-14 bg-warm-200 dark:bg-warm-800"),
            Div(:class => "flex items-center gap-1 rounded-full text-[10px] font-sans px-2.5 py-px border border-warm-200 dark:border-warm-800 text-warm-400 dark:text-warm-600 cursor-pointer hover:text-warm-600 dark:hover:text-warm-400 hover:border-warm-300 dark:hover:border-warm-700 transition-colors",
                RawHtml(_PLUS),
                "Code"),
            Div(:class => "h-px w-14 bg-warm-200 dark:bg-warm-800")
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
        NotebookCell(cell_num=2, code="x = [1, 2, 3, 4, 5]\nsum(x)", output="15", runtime="0.3 ms"),
        CellGap(),
        NotebookCell(cell_num=3, code="using Statistics\nmean(x), std(x)", output="(3.0, 1.5811388300841898)", runtime="12.1 ms"),
        CellGap(),
        NotebookCell(cell_num=4, code="cumsum(x)", output="[1, 3, 6, 10, 15]", runtime="0.1 ms")
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 2: Collapsible Code (Show + eye toggle, Sessions style)
# Eye: open eye always visible, closed eye layered underneath via Show
# Follows Sessions CellToggle pattern exactly
# ═══════════════════════════════════════════════════════════

@island function NotebookStep2(;
        code_1::String = "",
        output_1::String = "",
        code_2::String = "",
        output_2::String = ""
    )
    # Independent signals — each cell toggles independently
    vis_1, set_vis_1 = create_signal(1)
    vis_2, set_vis_2 = create_signal(1)

    on_mount(() -> println("Notebook cells hydrated"))

    return Div(:class => "w-full max-w-[750px] mx-auto",
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Data Analysis"),
            P(:class => "text-warm-600 dark:text-warm-400", "Summary statistics computed below. Click the eye icon in the gutter to toggle code.")),
        CellGap(),

        # Cell 2: eye toggle + output above + toggleable code
        Div(:class => "group relative pl-7 py-[3px]",
            # Eye toggle (vertically centered in gutter)
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer z-10 select-none",
                :on_click => () -> set_vis_1(1 - vis_1()),
                Div(:class => "relative w-[14px] h-[14px] text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400 transition-colors",
                    RawHtml(_EYE_CLOSED),
                    Show(vis_1) do
                        Div(:class => "absolute inset-0 bg-warm-100 dark:bg-warm-950 text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400",
                            RawHtml(_EYE_OPEN))
                    end)
            ),
            _output_block(output_1),
            Show(vis_1) do
                _code_block(code_1; runtime="0.8 ms")
            end
        ),
        CellGap(),

        # Cell 3: independent toggle
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer z-10 select-none",
                :on_click => () -> set_vis_2(1 - vis_2()),
                Div(:class => "relative w-[14px] h-[14px] text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400 transition-colors",
                    RawHtml(_EYE_CLOSED),
                    Show(vis_2) do
                        Div(:class => "absolute inset-0 bg-warm-100 dark:bg-warm-950 text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400",
                            RawHtml(_EYE_OPEN))
                    end)
            ),
            _output_block(output_2),
            Show(vis_2) do
                _code_block(code_2; runtime="0.1 ms")
            end
        )
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 3: Slider → Reactive Output (the @bind pattern)
# Output above code (Pluto style), runtime badge, full signals
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
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Interactive Computation"),
            P(:class => "text-warm-600 dark:text-warm-400", "Drag the slider — the dependent cell recomputes reactively.")),
        CellGap(),

        # @bind cell: slider output above code
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "2"),
            Div(:class => "px-1 py-1.5",
                Div(:class => "flex items-center gap-3",
                    Input(:type => "range", :min => "1", :max => "50",
                        :value => n, :on_input => set_n,
                        :class => "flex-1 accent-accent-500 h-[6px]"),
                    Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", n)
                )
            ),
            _code_block("@bind n Slider(1:50)"; runtime="0.2 ms")
        ),
        CellGap(),

        # Dependent cell: reactive output above code
        Div(:class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "3"),
            Div(:class => "px-1 py-1.5",
                Div(:class => "flex items-center gap-2",
                    Span(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf]", total),
                    _runtime_badge("reactive")
                )
            ),
            _code_block("sum(1:n)"; runtime="0.1 ms")
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

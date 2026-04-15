# ── NotebookDemo ──
# Published-notebook UI built on @island + WasmPlot. Six steps, each a standalone
# island composed of the same primitives:
#   • create_signal / create_memo / create_effect
#   • Show(signal) do ... end
#   • on_mount
#   • <range> + :on_input → set_signal
#   • Canvas() at island root; WasmPlot render! writes to it
#
# Convention: OUTPUT ABOVE CODE (Pluto-style).

using WasmPlot

# ═══════════════════════════════════════════════════════════
# SVG icons
# ═══════════════════════════════════════════════════════════

const _EYE_OPEN   = """<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>"""
const _EYE_CLOSED = """<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19M1 1l22 22"/></svg>"""
const _PLUS       = """<svg width="8" height="8" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M8 2v12M2 8h12"/></svg>"""

# ═══════════════════════════════════════════════════════════
# Shared SSR primitives
# ═══════════════════════════════════════════════════════════

function _code_block(code::String; runtime::String = "")
    Div(
        :class => "relative rounded-lg border border-warm-200 dark:border-warm-800 bg-warm-50 dark:bg-[#1a2332] overflow-hidden transition-[border-color] duration-200 hover:border-warm-300 dark:hover:border-warm-700",
        Div(:class => "absolute left-0 top-0 bottom-0 w-[3px] bg-accent-500/40 dark:bg-accent-400/40 group-hover:bg-accent-500/70 dark:group-hover:bg-accent-400/70 transition-all"),
        runtime == "" ? Span() :
            Div(
                :class => "absolute top-1 right-1.5 z-10 opacity-0 group-hover:opacity-100 transition-opacity",
                _runtime_badge(runtime),
            ),
        Div(
            :class => "py-2.5 pl-4 pr-3 overflow-x-auto whitespace-pre font-mono text-[13px] leading-[1.6] text-warm-800 dark:text-warm-200",
            code,
        ),
    )
end

function _output_block(output)
    Div(
        :class => "px-1 py-1.5 overflow-x-auto",
        Div(
            :class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf] leading-[1.5]",
            output,
        ),
    )
end

function _runtime_badge(time_str)
    Span(
        :class => "text-[10px] font-mono px-[7px] py-px rounded-full text-accent-600 dark:text-accent-400 opacity-80 border border-accent-500/15 bg-accent-500/10",
        time_str,
    )
end

# Tiny unstyled Button used as the cell's eye-toggle gutter.
# Button (not Div) is the only event target tested across every working
# Therapy example — delegation on arbitrary Divs is flaky in the current
# runtime, so the gutter is a button with all native styling stripped.
function _toggle_button(visible, setter)
    Button(
        :type  => "button",
        :class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center appearance-none bg-transparent border-0 p-0 m-0 opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer z-10 select-none focus:outline-none",
        :on_click => () -> setter(1 - visible()),
        Div(
            :class => "relative w-[14px] h-[14px] text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400 transition-colors",
            RawHtml(_EYE_CLOSED),
            Show(visible) do
                Div(
                    :class => "absolute inset-0 bg-warm-100 dark:bg-warm-950 text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400",
                    RawHtml(_EYE_OPEN),
                )
            end,
        ),
    )
end

function NotebookCell(; code::String, output::String = "", cell_num::Int = 1, runtime::String = "")
    Div(
        :class => "group relative pl-7 py-[3px]",
        Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none",
            string(cell_num)),
        output == "" ? Span() : _output_block(output),
        _code_block(code; runtime=runtime),
    )
end

function NotebookMarkdown(children...; cell_num::Int = 1)
    Div(
        :class => "group relative pl-7 py-[3px]",
        Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-start pt-3 justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none",
            string(cell_num)),
        Div(
            :class => "px-1 py-2 text-warm-700 dark:text-warm-300 text-[14px] leading-[1.7]",
            children...,
        ),
    )
end

function CellGap()
    Div(
        :class => "flex items-center justify-center h-[26px] my-[2px] group/gap",
        Div(
            :class => "flex items-center gap-1 opacity-0 group-hover/gap:opacity-100 transition-opacity",
            Div(:class => "h-px w-14 bg-warm-200 dark:bg-warm-800"),
            Div(
                :class => "flex items-center gap-1 rounded-full text-[10px] font-sans px-2.5 py-px border border-warm-200 dark:border-warm-800 text-warm-400 dark:text-warm-600 cursor-pointer hover:text-warm-600 dark:hover:text-warm-400 hover:border-warm-300 dark:hover:border-warm-700 transition-colors",
                RawHtml(_PLUS),
                "Code",
            ),
            Div(:class => "h-px w-14 bg-warm-200 dark:bg-warm-800"),
        ),
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 1 — Static code cells (pure SSR)
# ═══════════════════════════════════════════════════════════

function NotebookStep1()
    Div(
        :class => "w-full max-w-[750px] mx-auto",
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Array Operations"),
            P(:class => "text-warm-600 dark:text-warm-400", "Read-only code cells with their output rendered above."),
        ),
        CellGap(),
        NotebookCell(cell_num=2, code="x = [1, 2, 3, 4, 5]\nsum(x)", output="15", runtime="0.3 ms"),
        CellGap(),
        NotebookCell(cell_num=3, code="using Statistics\nmean(x), std(x)", output="(3.0, 1.5811388300841898)", runtime="12.1 ms"),
        CellGap(),
        NotebookCell(cell_num=4, code="cumsum(x)", output="[1, 3, 6, 10, 15]", runtime="0.1 ms"),
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 2 — Toggleable cells (Show + signal + Button gutter)
# ═══════════════════════════════════════════════════════════

@island function NotebookStep2()
    vis_1, set_vis_1 = create_signal(1)
    vis_2, set_vis_2 = create_signal(1)

    on_mount(() -> js("console.log('Notebook Step 2 hydrated')"))

    return Div(
        :class => "w-full max-w-[750px] mx-auto",
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Cell Visibility"),
            P(:class => "text-warm-600 dark:text-warm-400",
                "Two patterns. Hover the gutter to reveal the eye — clicking it toggles the code via ",
                Code(:class => "font-mono text-accent-500", "Show"),
                ". The first cell renders its output above the code (Pluto convention). The second cell ends with ",
                Code(:class => "font-mono text-accent-500", ";"),
                " — Pluto's suppression marker — so it shows code only, no output."),
        ),
        CellGap(),

        # Cell 2 — toggleable, output above code
        Div(
            :class => "group relative pl-7 py-[3px]",
            _toggle_button(vis_1, set_vis_1),
            _output_block("(3.0, 3.0, 1.5811388300841898)"),
            Show(vis_1) do
                _code_block("mean(x), median(x), std(x)"; runtime="0.8 ms")
            end,
        ),
        CellGap(),

        # Cell 3 — toggleable, suppressed (ends with ;) → no output rendered
        Div(
            :class => "group relative pl-7 py-[3px]",
            _toggle_button(vis_2, set_vis_2),
            Show(vis_2) do
                _code_block("results = Dict(:mean => mean(x), :std => std(x));"; runtime="1.2 ms")
            end,
        ),
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 3 — Slider → reactive memo
# ═══════════════════════════════════════════════════════════

@island function NotebookStep3(; n_init::Int = 10)
    n, set_n = create_signal(n_init)

    total = create_memo(() -> begin
        count = n()
        s = Int64(0)
        i = Int64(1)
        while i <= count
            s = s + i
            i = i + Int64(1)
        end
        s
    end)

    create_effect(() -> js("console.log('n:', \$1, 'sum:', \$2)", n(), total()))

    return Div(
        :class => "w-full max-w-[750px] mx-auto",
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Interactive Computation"),
            P(:class => "text-warm-600 dark:text-warm-400", "Drag the slider — the dependent cell recomputes reactively."),
        ),
        CellGap(),

        # Cell 2 — @bind slider
        Div(
            :class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "2"),
            Div(
                :class => "px-1 py-1.5",
                Div(
                    :class => "flex items-center gap-3",
                    Input(:type => "range", :min => "1", :max => "50",
                          :value => n, :on_input => set_n,
                          :class => "flex-1 accent-accent-500 h-[6px]"),
                    Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", n),
                ),
            ),
            _code_block("@bind n Slider(1:50)"; runtime="0.2 ms"),
        ),
        CellGap(),

        # Cell 3 — dependent memo
        Div(
            :class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "3"),
            Div(
                :class => "px-1 py-1.5",
                Div(
                    :class => "flex items-center gap-2",
                    Span(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf]", total),
                    _runtime_badge("reactive"),
                ),
            ),
            _code_block("sum(1:n)"; runtime="0.1 ms"),
        ),
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 4 — Slider → WasmPlot lines! plot
# Canvas lives at island root. Toggle only wraps the code block.
# ═══════════════════════════════════════════════════════════

@island function NotebookStep4(; freq_init::Int = 5)
    freq, set_freq = create_signal(freq_init)
    vis_bind,  set_vis_bind  = create_signal(1)

    create_effect(() -> begin
        f = Float64(freq())
        xs = Float64[]
        ys = Float64[]
        i = Int64(1)
        while i <= Int64(100)
            xi = Float64(i) * 0.1
            push!(xs, xi)
            push!(ys, sin(xi * f))
            i = i + Int64(1)
        end

        fig = WasmPlot.Figure(size=(680, 220))
        ax  = Axis(fig[1, 1]; title="sin(x * freq)", xlabel="x", ylabel="y")
        lines!(ax, xs, ys; color=:blue, linewidth=2.0)
        render!(fig)
    end)

    create_effect(() -> js("console.log('freq:', \$1)", freq()))

    return Div(
        :class => "w-full max-w-[750px] mx-auto",

        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Reactive Plot"),
            P(:class => "text-warm-600 dark:text-warm-400", "Slider drives a chain: ",
                Code(:class => "font-mono text-accent-500", "@bind"),
                " cell → compute → WasmPlot redraws into the next cell."),
        ),
        CellGap(),

        # Cell 2 — @bind freq (toggleable code, slider widget)
        Div(
            :class => "group relative pl-7 py-[3px]",
            _toggle_button(vis_bind, set_vis_bind),
            Div(
                :class => "px-1 py-1.5",
                Div(
                    :class => "flex items-center gap-3",
                    Input(:type => "range", :min => "1", :max => "20",
                          :value => freq, :on_input => set_freq,
                          :class => "flex-1 accent-accent-500 h-[6px]"),
                    Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", freq),
                ),
            ),
            Show(vis_bind) do
                _code_block("@bind freq Slider(1:20)"; runtime="0.2 ms")
            end,
        ),
        CellGap(),

        # Cell 3 — output (canvas). Plot is its own cell, gutter "3", canvas
        # never wrapped in Show so WasmPlot's ctx binding stays stable.
        Div(
            :class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "3"),
            Canvas(:width => 680, :height => 220,
                   :class => "w-full rounded-lg border border-warm-200 dark:border-warm-800",
                   :style => "display:block;"),
            _code_block("lines!(ax, x, sin.(x .* freq))"; runtime="4.2 ms"),
        ),
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 5 — Two sliders → one memo (auto-batched)
# ═══════════════════════════════════════════════════════════

@island function NotebookStep5(; freq_init::Int = 5, amp_init::Int = 10)
    freq, set_freq = create_signal(freq_init)
    amp,  set_amp  = create_signal(amp_init)

    # Integer-domain memo — sum_{i=1..20} (freq + amp) * i  (deliberately Int64
    # so the computation lives in the same WasmTarget-friendly domain as Step 3.
    # We can swap in sin/Float64 once the runtime trap on Float64 memos is fixed.)
    result = create_memo(() -> begin
        f = freq()
        a = amp()
        s = Int64(0)
        i = Int64(1)
        while i <= Int64(20)
            s = s + (f + a) * i
            i = i + Int64(1)
        end
        s
    end)

    create_effect(() -> js("console.log('freq:', \$1, 'amp:', \$2)", freq(), amp()))

    return Div(
        :class => "w-full max-w-[750px] mx-auto",
        NotebookMarkdown(
            P(:class => "font-semibold text-[15px] text-warm-800 dark:text-warm-200 mb-1", "Multiple Inputs"),
            P(:class => "text-warm-600 dark:text-warm-400", "Two sliders feed one ",
                Code(:class => "font-mono text-accent-500", "create_memo"),
                ". Handlers are auto-batched — moving either slider fires the dependent effect once."),
        ),
        CellGap(),

        # Cell — @bind freq
        Div(
            :class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "2"),
            Div(
                :class => "px-1 py-1.5",
                Div(
                    :class => "flex items-center gap-3",
                    Span(:class => "text-[12px] font-mono text-warm-500 dark:text-warm-500 min-w-[3ch]", "freq"),
                    Input(:type => "range", :min => "1", :max => "20",
                          :value => freq, :on_input => set_freq,
                          :class => "flex-1 accent-accent-500 h-[6px]"),
                    Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", freq),
                ),
            ),
            _code_block("@bind freq Slider(1:20)"; runtime="0.1 ms"),
        ),
        CellGap(),

        # Cell — @bind amp
        Div(
            :class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "3"),
            Div(
                :class => "px-1 py-1.5",
                Div(
                    :class => "flex items-center gap-3",
                    Span(:class => "text-[12px] font-mono text-warm-500 dark:text-warm-500 min-w-[3ch]", "amp"),
                    Input(:type => "range", :min => "1", :max => "20",
                          :value => amp, :on_input => set_amp,
                          :class => "flex-1 accent-accent-500 h-[6px]"),
                    Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", amp),
                ),
            ),
            _code_block("@bind amp Slider(1:20)"; runtime="0.1 ms"),
        ),
        CellGap(),

        # Cell — dependent memo
        Div(
            :class => "group relative pl-7 py-[3px]",
            Div(:class => "absolute left-0 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "4"),
            Div(
                :class => "px-1 py-1.5",
                Div(
                    :class => "flex items-center gap-2",
                    Span(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf]", result),
                    _runtime_badge("reactive"),
                ),
            ),
            _code_block("sum(sin.(x .* freq) .* amp)"; runtime="1.3 ms"),
        ),
    )
end

# ═══════════════════════════════════════════════════════════
# STEP 6 — Full published-notebook layout with WasmPlot heatmap
# ═══════════════════════════════════════════════════════════

@island function NotebookStep6(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)
    vis_bind, set_vis_bind = create_signal(1)

    create_effect(() -> begin
        f = Float64(freq())
        nx = Int64(20)
        ny = Int64(20)
        values = Float64[]
        row = Int64(0)
        while row < ny
            col = Int64(0)
            while col < nx
                x = Float64(col) / Float64(nx)
                y = Float64(row) / Float64(ny)
                push!(values, sin(x * f) * cos(y * f))
                col = col + Int64(1)
            end
            row = row + Int64(1)
        end

        fig = WasmPlot.Figure(size=(680, 260))
        ax  = Axis(fig[1, 1]; title="sin(x*f) * cos(y*f)", xlabel="x", ylabel="y")
        heatmap!(ax, (0.0, 1.0), (0.0, 1.0), Int(nx), Int(ny), values)
        render!(fig)
    end)

    create_effect(() -> js("console.log('notebook freq:', \$1)", freq()))
    on_mount(() -> js("console.log('Full notebook mounted')"))

    return Div(
        :class => "w-full max-w-[750px] mx-auto rounded-xl border border-warm-200 dark:border-warm-800 bg-white dark:bg-warm-950 overflow-hidden shadow-lg shadow-black/10 dark:shadow-black/30",

        # Tab bar
        Div(
            :class => "h-[38px] flex items-stretch bg-warm-100 dark:bg-[#0a0e14] border-b border-warm-200 dark:border-warm-800 shrink-0",
            Div(
                :class => "flex items-center gap-1.5 px-3.5 font-mono text-xs text-warm-800 dark:text-warm-200 bg-white dark:bg-[#151c25] border-r border-warm-200 dark:border-warm-800",
                Span(:class => "w-[5px] h-[5px] rounded-full bg-accent-500"),
                "analysis.jl",
            ),
        ),

        Div(
            :class => "px-5 pt-4 pb-6",
            Div(
                :class => "max-w-[700px] mx-auto pl-7",

                # Cell 2 — markdown
                Div(
                    :class => "py-[3px]",
                    Div(
                        :class => "px-1 py-2 text-warm-700 dark:text-warm-300 text-[14px] leading-[1.7]",
                        P(:class => "font-semibold text-[16px] text-warm-800 dark:text-warm-200 mb-1", "2D Wave Analysis"),
                        P(:class => "text-warm-600 dark:text-warm-400", "Interactive heatmap of sin(x*f) · cos(y*f). Adjust the frequency parameter below."),
                    ),
                ),
                CellGap(),

                # Cell 3 — @bind freq (its own cell — slider widget + toggleable code)
                Div(
                    :class => "group relative py-[3px]",
                    Button(
                        :type  => "button",
                        :class => "absolute -left-7 top-0 bottom-0 w-6 flex items-center justify-center appearance-none bg-transparent border-0 p-0 m-0 opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer z-10 select-none focus:outline-none",
                        :on_click => () -> set_vis_bind(1 - vis_bind()),
                        Div(
                            :class => "relative w-[14px] h-[14px] text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400 transition-colors",
                            RawHtml(_EYE_CLOSED),
                            Show(vis_bind) do
                                Div(:class => "absolute inset-0 bg-white dark:bg-warm-950 text-warm-400 dark:text-warm-600 hover:text-accent-500 dark:hover:text-accent-400",
                                    RawHtml(_EYE_OPEN))
                            end,
                        ),
                    ),
                    Div(
                        :class => "px-1 py-1.5",
                        Div(
                            :class => "flex items-center gap-3",
                            Input(:type => "range", :min => "1", :max => "15",
                                  :value => freq, :on_input => set_freq,
                                  :class => "flex-1 accent-accent-500 h-[6px]"),
                            Span(:class => "font-mono text-[13px] text-warm-600 dark:text-[#7ca0bf] min-w-[3ch] text-right", freq),
                        ),
                    ),
                    Show(vis_bind) do
                        _code_block("@bind freq Slider(1:15)"; runtime="0.2 ms")
                    end,
                ),
                CellGap(),

                # Cell 4 — output (canvas, its own cell). Canvas never inside Show.
                Div(
                    :class => "group relative py-[3px]",
                    Div(:class => "absolute -left-7 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "4"),
                    Canvas(:width => 680, :height => 260,
                           :class => "w-full rounded-lg border border-warm-200 dark:border-warm-800 my-1",
                           :style => "display:block;"),
                    _code_block("heatmap!(ax, (0,1), (0,1), nx, ny, values)"; runtime="8.4 ms"),
                ),
                CellGap(),

                # Cell 5 — static
                Div(
                    :class => "group relative py-[3px]",
                    Div(:class => "absolute -left-7 top-0 bottom-0 w-6 flex items-center justify-center text-[10px] font-mono text-warm-400 dark:text-warm-600 opacity-0 group-hover:opacity-100 transition-opacity select-none", "5"),
                    Div(
                        :class => "px-1 py-1.5 overflow-x-auto",
                        Div(
                            :class => "flex items-center gap-2",
                            Span(:class => "text-[13px] font-mono text-warm-600 dark:text-[#7ca0bf]", "CSV written: 1,200 rows"),
                            Span(:class => "text-[10px] font-mono px-1.5 py-px rounded-full text-warm-500 dark:text-warm-500 border border-warm-300 dark:border-warm-700 bg-warm-100 dark:bg-warm-900", "static"),
                        ),
                    ),
                    _code_block("CSV.write(\"output.csv\", df)"; runtime="45.2 ms"),
                ),
            ),
        ),
    )
end

# ═══════════════════════════════════════════════════════════
# SSR entry points
# ═══════════════════════════════════════════════════════════

NotebookDemo()  = NotebookStep1()
NotebookDemo2() = NotebookStep2()
NotebookDemo3() = NotebookStep3(n_init=10)
NotebookDemo4() = NotebookStep4(freq_init=5)
NotebookDemo5() = NotebookStep5(freq_init=5, amp_init=10)
NotebookDemo6() = NotebookStep6(freq_init=3)

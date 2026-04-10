# ── InteractivePlot ──
# @island component — WasmPlot Canvas2D plotting compiled to WebAssembly.
# The effect builds Figure + Axis + LinePlot structs (all WasmGC),
# computes viewport/ticks, and renders via Canvas2D imports.

using WasmPlot

@island function InteractivePlot(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)

    create_effect(() -> begin
        f = Float64(freq())
        n = Int64(200)

        # Build data
        xs = Float64[]
        ys = Float64[]
        i = Int64(1)
        while i <= n
            xi = Float64(i) / Float64(n) * 6.28318
            push!(xs, xi)
            push!(ys, sin(xi * f))
            i = i + Int64(1)
        end

        # Makie-like API: Figure → Axis → LinePlot → render!
        fig = Figure(Int64(800), Int64(400),
            RGBA(1.0, 1.0, 1.0, 1.0), 12.0, WasmPlot.Axis[])
        ax = WasmPlot.Axis(
            LinePlot[LinePlot(xs, ys, RGBA(0.0, 0.447, 0.698, 1.0), 2.0, Int64(0), "")],
            ScatterPlot[], BarPlot[], HeatmapPlot[],
            "", "", "",
            NaN, NaN, NaN, NaN, Int64(0), Int64(0),
            RGBA(1.0, 1.0, 1.0, 1.0), true, true,
            RGBA(0.0, 0.0, 0.0, 0.12), RGBA(0.0, 0.0, 0.0, 1.0),
            Int64(0), Int64(1), Int64(1))
        push!(fig.axes, ax)

        # Render — all Canvas2D calls compiled to WASM imports
        render!(fig)
    end)

    return Div(:class => "flex flex-col items-center gap-4 w-full",
        Div(:class => "w-full max-w-3xl rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
            RawHtml("<canvas width=\"800\" height=\"400\" style=\"display:block;width:100%;height:auto;\"></canvas>")
        ),
        Div(:class => "flex items-center gap-3",
            Span(:class => "text-xs font-mono text-warm-500 dark:text-warm-400", "freq"),
            Button(:on_click => () -> set_freq(max(Int64(1), freq() - Int64(1))),
                :class => "w-8 h-8 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 cursor-pointer transition-colors font-mono text-sm select-none active:scale-95",
                "-"),
            Span(:class => "text-lg font-mono text-warm-900 dark:text-warm-100 min-w-[2ch] text-center",
                freq),
            Button(:on_click => () -> set_freq(freq() + Int64(1)),
                :class => "w-8 h-8 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 cursor-pointer transition-colors font-mono text-sm select-none active:scale-95",
                "+")
        )
    )
end

# ── InteractivePlot ──
# @island component — WasmPlot Canvas2D plotting compiled to WebAssembly.
# Demonstrates the Makie-like API: Figure(), Axis(), lines!(), render!()
# All structs + rendering compile to WasmGC via WasmTarget.

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

        # Makie-like API (WasmPlot.Figure avoids ambiguity with Therapy's HTML <figure>)
        fig = WasmPlot.Figure(size=(800, 400))
        ax = Axis(fig[1, 1])
        lines!(ax, xs, ys; color=:blue, linewidth=2.0)
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

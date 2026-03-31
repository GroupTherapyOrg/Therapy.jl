# TEMPORARILY DISABLED — home-page-only rebuild
#=
# ── HeatmapDemo ──
# 2D heatmap with interactive slider — demonstrates ND arrays + Plotly.
# zeros(m,n) transpiles to nested JS arrays [[...],[...]] which Plotly
# natively accepts as the `z` parameter for heatmap traces.

import PlotlyBase

@island function HeatmapDemo(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)

    create_effect(() -> begin
        f = Float64(freq())
        rows = 30
        cols = 30

        z = zeros(rows, cols)
        for i in 1:rows
            for j in 1:cols
                x = Float64(i) / Float64(rows)
                y = Float64(j) / Float64(cols)
                z[i, j] = sin(x * f) * cos(y * f)
            end
        end

        PlotlyBase.Plot(
            [PlotlyBase.heatmap(z=z, colorscale="Viridis")],
            PlotlyBase.Layout(title="sin(x*f) * cos(y*f)")
        )
    end)

    return Div(:class => "w-full max-w-2xl space-y-4",
        Div(:id => "therapy-heatmap",
            :class => "w-full h-72 rounded-lg border border-warm-200 dark:border-warm-800"),
        Div(:class => "flex items-center gap-4",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono min-w-[4ch]",
                freq),
            Input(:type => "range", :min => "1", :max => "20",
                :value => freq, :on_input => set_freq,
                :class => "flex-1 accent-accent-500")
        )
    )
end
=#

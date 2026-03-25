# ── InteractivePlot ──
# @island component — standard PlotlyBase API compiled to Plotly.js via JST.
# Demonstrates: create_signal, create_effect, PlotlyBase integration.
# PlotlyBase is auto-compiled via TherapyPlotlyBaseExt package extension.

import PlotlyBase

@island function InteractivePlot(; frequency::Int = 5)
    # Signal: slider value
    freq, set_freq = create_signal(frequency)

    # Effect: recomputes plot data whenever freq changes
    create_effect(() -> begin
        f = freq()

        # Build x/y arrays (compiles to JS arrays via JST)
        x = Float64[]
        for i in 1:100
            push!(x, Float64(i) * 0.1)
        end
        y = sin.(x .* Float64(f))

        # Standard PlotlyBase — auto-compiled to Plotly.newPlot by extension
        PlotlyBase.Plot(
            [PlotlyBase.scatter(x=x, y=y, mode="lines")],
            PlotlyBase.Layout(title="sin(x * frequency)")
        )
    end)

    # Return: plot container + slider
    return Div(:class => "w-full max-w-2xl space-y-4",
        Div(:id => "therapy-plot",
            :class => "w-full h-64 rounded-lg border border-warm-200 dark:border-warm-800"),
        Div(:class => "flex items-center gap-4",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono min-w-[4ch]",
                freq),
            Input(:type => "range", :min => "1", :max => "20",
                :value => freq, :on_input => set_freq,
                :class => "flex-1 accent-accent-500")
        )
    )
end

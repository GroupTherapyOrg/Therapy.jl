# Interactive plot — pure Julia code compiled to Plotly.js via JST
# No js() needed — scatter(), Layout(), plotly() compile automatically
@island function InteractivePlot(; frequency::Int = 5)
    freq, set_freq = create_signal(frequency)

    create_effect(() -> begin
        f = freq()
        x = Float64[]
        for i in 1:100
            push!(x, Float64(i) * 0.1)
        end
        y = sin.(x .* Float64(f))

        plotly("therapy-plot",
            [scatter(x=x, y=y, mode="lines")],
            Layout(title="sin(x * frequency)")
        )
    end)

    Div(:class => "w-full max-w-2xl space-y-4",
        Div(:id => "therapy-plot", :class => "w-full h-64 rounded-lg border border-warm-200 dark:border-warm-800"),
        Div(:class => "flex items-center gap-4",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono min-w-[4ch]", freq),
            Input(:type => "range", :min => "1", :max => "20", :value => freq,
                :on_input => set_freq,
                :class => "flex-1 accent-accent-500")
        )
    )
end

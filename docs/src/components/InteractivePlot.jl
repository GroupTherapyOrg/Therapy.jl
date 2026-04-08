# ── InteractivePlot ──
# @island component — Standard Makie API compiled to WASM via WasmTargetMakieExt.
# Figure/Axis/lines!/display calls are overlaid to lightweight WASM types +
# Three.js import stubs by WasmTargetMakieExt package extension.
# Demonstrates: create_signal, create_effect, sin wave with reactive frequency.

@island function InteractivePlot(; frequency::Int = 5)
    # Signal: slider value
    freq, set_freq = create_signal(frequency)

    # Effect: recomputes plot data whenever freq changes
    create_effect(() -> begin
        f = freq()

        # Standard Makie API — overlaid to WasmFigure/WasmAxis in WASM
        fig = Makie.Figure()
        ax = Makie.Axis(fig)

        # Build x/y arrays — sin wave with reactive frequency
        x = Vector{Float64}(undef, 100)
        y = Vector{Float64}(undef, 100)
        for i in Int64(1):Int64(100)
            x[i] = Float64(i) * 0.1
            y[i] = sin(x[i] * Float64(f))
        end

        # lines! overlay calls Three.js line renderer via import
        Makie.lines!(ax, x, y)

        # display overlay triggers Three.js render
        display(fig)
    end)

    # Return: canvas container + slider
    return Div(:class => "w-full max-w-2xl space-y-4",
        Div(:id => "makie-canvas",
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

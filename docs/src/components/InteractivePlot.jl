# ── InteractivePlot ──
# @island component — WasmTarget Makie types compiled to WASM → Three.js rendering.
# Uses WasmFigure/WasmAxis/lines! import stubs directly (same as what
# WasmTargetMakieExt overlays produce from standard Makie API).
# Demonstrates: create_signal, create_effect, sin wave with reactive frequency.

using WasmTarget: WasmFigure, WasmAxis, _wasm_lines, _wasm_display

@island function InteractivePlot(; frequency::Int = 5)
    # Signal: slider value
    freq, set_freq = create_signal(frequency)

    # Effect: recomputes plot data whenever freq changes
    create_effect(() -> begin
        f = freq()

        # Create Figure + Axis (same as Makie.Figure() / Makie.Axis() overlays)
        fig = WasmFigure(Int64(1))
        ax = WasmAxis(fig.id, Int64(1))

        # Build x/y arrays — sin wave with reactive frequency
        x = Vector{Float64}(undef, 100)
        y = Vector{Float64}(undef, 100)
        for i in Int64(1):Int64(100)
            x[i] = Float64(i) * 0.1
            y[i] = sin(x[i] * Float64(f))
        end

        # lines! import → calls Three.js line renderer
        _wasm_lines(ax.id, Int64(length(x)))

        # display import → triggers Three.js render
        _wasm_display(fig.id)
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

# ── HeatmapDemo ──
# @island component — Standard Makie API (import WGLMakie as Mke) compiled to WASM.
# Demonstrates: 2D heatmap with sin*cos pattern, reactive frequency slider.

@island function HeatmapDemo(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)

    # Effect: recomputes heatmap data whenever freq changes
    create_effect(() -> begin
        f = Float64(freq())

        # Standard Makie API — overlaid to WasmFigure/WasmAxis in WASM
        fig = Mke.Figure()
        ax = Mke.Axis(fig)

        # Build flattened z data — sin*cos pattern with reactive frequency
        # heatmap! overlay accepts Vector{Float64} (flattened row-major)
        nrows = Int64(30)
        ncols = Int64(30)
        z = Vector{Float64}(undef, nrows * ncols)
        for i in Int64(1):nrows
            for j in Int64(1):ncols
                x = Float64(i) / Float64(nrows)
                y = Float64(j) / Float64(ncols)
                z[(i - Int64(1)) * ncols + j] = sin(x * f) * cos(y * f)
            end
        end

        # heatmap! overlay calls Three.js heatmap renderer via import
        Mke.heatmap!(ax, z)

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

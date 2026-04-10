# ── InteractivePlot ──
# @island component — compiled to WebAssembly via WasmTarget.
# Demonstrates: WasmPlot.jl Canvas2D plotting inside a Therapy.jl island.
# The entire Figure → Axis → render! pipeline runs in WASM.

using WasmPlot: Figure, Axis, LinePlot, RGBA, AxisViewport,
    compute_viewport, compute_data_limits, compute_ticks, data_to_pixel,
    canvas_clear_rect, canvas_fill_rect, canvas_begin_path, canvas_move_to,
    canvas_line_to, canvas_stroke, canvas_set_stroke_rgb, canvas_set_fill_rgb,
    canvas_set_line_width, canvas_set_line_dash_solid, canvas_set_line_dash_dashed,
    canvas_stroke_rect, canvas_save, canvas_restore

@island function InteractivePlot(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)

    create_effect(() -> begin
        f = Float64(freq())

        # Build data arrays
        n = Int64(200)
        xs = Float64[]
        ys = Float64[]
        i = Int64(1)
        while i <= n
            xi = Float64(i) * 0.0314159
            push!(xs, xi)
            push!(ys, sin(xi * f))
            i = i + Int64(1)
        end

        # Build Figure + Axis + LinePlot (all WasmGC structs)
        fig = Figure(Int64(580), Int64(340),
            RGBA(1.0, 1.0, 1.0, 1.0), 12.0,
            WasmPlot.Axis[])

        ax = WasmPlot.Axis(
            LinePlot[LinePlot(xs, ys, RGBA(0.0, 0.447, 0.698, 1.0), 2.0, Int64(0), "")],
            WasmPlot.ScatterPlot[],
            WasmPlot.BarPlot[],
            "", "", "",
            NaN, NaN, NaN, NaN,
            Int64(0), Int64(0),
            RGBA(1.0, 1.0, 1.0, 1.0),
            true, true,
            RGBA(0.0, 0.0, 0.0, 0.12),
            RGBA(0.0, 0.0, 0.0, 0.6),
            Int64(0), Int64(1), Int64(1)
        )
        push!(fig.axes, ax)

        # Render via Canvas2D (all calls become WASM imports)
        vp = compute_viewport(ax, fig)
        w = Float64(fig.width)
        h = Float64(fig.height)

        # Clear + background
        canvas_clear_rect(0.0, 0.0, w, h)
        canvas_set_fill_rgb(255.0, 255.0, 255.0)
        canvas_fill_rect(0.0, 0.0, w, h)

        # Grid
        canvas_set_line_width(0.5)
        canvas_set_stroke_rgb(0.0, 0.0, 0.0)
        canvas_set_line_dash_dashed()
        for t in vp.xticks
            px = data_to_pixel(t, vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
            canvas_begin_path()
            canvas_move_to(px, vp.plot_top)
            canvas_line_to(px, vp.plot_bottom)
            canvas_stroke()
        end
        for t in vp.yticks
            py = data_to_pixel(t, vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
            canvas_begin_path()
            canvas_move_to(vp.plot_left, py)
            canvas_line_to(vp.plot_right, py)
            canvas_stroke()
        end
        canvas_set_line_dash_solid()

        # Data line
        canvas_set_stroke_rgb(0.0, 114.0, 178.0)
        canvas_set_line_width(2.0)
        canvas_begin_path()
        j = Int64(1)
        while j <= Int64(length(xs))
            px = data_to_pixel(xs[j], vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
            py = data_to_pixel(ys[j], vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
            if j == Int64(1)
                canvas_move_to(px, py)
            else
                canvas_line_to(px, py)
            end
            j = j + Int64(1)
        end
        canvas_stroke()

        # Spines
        canvas_set_stroke_rgb(0.0, 0.0, 0.0)
        canvas_set_line_width(1.0)
        canvas_stroke_rect(vp.plot_left, vp.plot_top,
            vp.plot_right - vp.plot_left,
            vp.plot_bottom - vp.plot_top)
    end)

    return Div(:class => "flex flex-col items-center gap-4",
        Div(:class => "rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
            Svg(:xmlns => "http://www.w3.org/2000/svg", :width => "0", :height => "0"),
            RawHtml("<canvas width=\"580\" height=\"340\" style=\"display:block;\"></canvas>")
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

# ── InteractivePlot ──
# @island component — 4-panel interactive Canvas2D plotting via WasmPlot.jl.
# All Figure/Axis/Plot structs + rendering compiled to WasmGC.
# freq signal controls sin/cos frequency across all panels.

using WasmPlot: Figure, Axis, LinePlot, ScatterPlot, BarPlot, HeatmapPlot,
    RGBA, AxisViewport,
    compute_viewport, compute_data_limits, compute_ticks, data_to_pixel,
    canvas_clear_rect, canvas_fill_rect, canvas_begin_path, canvas_move_to,
    canvas_line_to, canvas_stroke, canvas_fill, canvas_arc,
    canvas_set_stroke_rgb, canvas_set_fill_rgb, canvas_set_fill_rgba,
    canvas_set_line_width, canvas_set_line_dash_solid, canvas_set_line_dash_dashed,
    canvas_set_line_dash_dotted,
    canvas_stroke_rect, canvas_save, canvas_restore,
    _viridis

@island function InteractivePlot(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)

    create_effect(() -> begin
        f = Float64(freq())
        W = Int64(900)
        H = Int64(600)
        n = Int64(200)

        # ─── Build data ───
        xs = Float64[]
        ys_sin = Float64[]
        ys_cos = Float64[]
        i = Int64(1)
        while i <= n
            xi = Float64(i) / Float64(n) * 6.28318
            push!(xs, xi)
            push!(ys_sin, sin(xi * f))
            push!(ys_cos, cos(xi * f))
            i = i + Int64(1)
        end

        # Scatter data (subsample)
        sx = Float64[]
        sy = Float64[]
        j = Int64(1)
        while j <= Int64(40)
            xj = Float64(j) / 40.0 * 6.28318
            push!(sx, xj)
            push!(sy, sin(xj * f) * 0.8)
            j = j + Int64(1)
        end

        # Bar data
        bx = Float64[1.0, 2.0, 3.0, 4.0, 5.0]
        bh = Float64[]
        k = Int64(1)
        while k <= Int64(5)
            push!(bh, sin(Float64(k) * f * 0.5) * 4.0 + 5.0)
            k = k + Int64(1)
        end

        # Heatmap data (20×20)
        hm_nx = Int64(20)
        hm_ny = Int64(20)
        hm_vals = Float64[]
        hy = Int64(0)
        while hy < hm_ny
            hx = Int64(0)
            while hx < hm_nx
                xv = Float64(hx) / Float64(hm_nx) * 6.28
                yv = Float64(hy) / Float64(hm_ny) * 6.28
                push!(hm_vals, sin(xv * f * 0.5) * cos(yv * f * 0.5))
                hx = hx + Int64(1)
            end
            hy = hy + Int64(1)
        end
        hm_vmin = -1.0
        hm_vmax = 1.0

        # ─── Build Figure with 4 axes ───
        fig = Figure(W, H, RGBA(0.98, 0.976, 0.965, 1.0), 11.0, WasmPlot.Axis[])

        # Panel 1: Line chart (row 1, col 1)
        ax1 = WasmPlot.Axis(
            LinePlot[
                LinePlot(xs, ys_sin, RGBA(0.0, 0.447, 0.698, 1.0), 2.0, Int64(0), ""),
                LinePlot(xs, ys_cos, RGBA(0.902, 0.624, 0.0, 1.0), 2.0, Int64(1), "")
            ],
            ScatterPlot[], BarPlot[], HeatmapPlot[],
            "", "", "",
            NaN, NaN, NaN, NaN, Int64(0), Int64(0),
            RGBA(1.0, 1.0, 1.0, 1.0), true, true,
            RGBA(0.0, 0.0, 0.0, 0.08), RGBA(0.0, 0.0, 0.0, 0.4),
            Int64(0), Int64(1), Int64(1))
        push!(fig.axes, ax1)

        # Panel 2: Scatter (row 1, col 2)
        ax2 = WasmPlot.Axis(
            LinePlot[],
            ScatterPlot[ScatterPlot(sx, sy, RGBA(0.584, 0.345, 0.698, 1.0), 6.0, Int64(0), RGBA(0.0, 0.0, 0.0, 1.0), 0.0, "")],
            BarPlot[], HeatmapPlot[],
            "", "", "",
            NaN, NaN, NaN, NaN, Int64(0), Int64(0),
            RGBA(1.0, 1.0, 1.0, 1.0), true, true,
            RGBA(0.0, 0.0, 0.0, 0.08), RGBA(0.0, 0.0, 0.0, 0.4),
            Int64(0), Int64(1), Int64(2))
        push!(fig.axes, ax2)

        # Panel 3: Bar chart (row 2, col 1)
        ax3 = WasmPlot.Axis(
            LinePlot[], ScatterPlot[],
            BarPlot[BarPlot(bx, bh, RGBA(0.0, 0.620, 0.451, 1.0), 0.7, RGBA(0.0, 0.0, 0.0, 1.0), 0.0, "")],
            HeatmapPlot[],
            "", "", "",
            NaN, NaN, NaN, NaN, Int64(0), Int64(0),
            RGBA(1.0, 1.0, 1.0, 1.0), true, true,
            RGBA(0.0, 0.0, 0.0, 0.08), RGBA(0.0, 0.0, 0.0, 0.4),
            Int64(0), Int64(2), Int64(1))
        push!(fig.axes, ax3)

        # Panel 4: Heatmap (row 2, col 2)
        ax4 = WasmPlot.Axis(
            LinePlot[], ScatterPlot[], BarPlot[],
            HeatmapPlot[HeatmapPlot(hm_nx, hm_ny, 0.0, 6.28, 0.0, 6.28, hm_vals, hm_vmin, hm_vmax)],
            "", "", "",
            NaN, NaN, NaN, NaN, Int64(0), Int64(0),
            RGBA(1.0, 1.0, 1.0, 1.0), false, false,
            RGBA(0.0, 0.0, 0.0, 0.08), RGBA(0.0, 0.0, 0.0, 0.4),
            Int64(0), Int64(2), Int64(2))
        push!(fig.axes, ax4)

        # ─── Render all 4 panels ───
        w = Float64(W)
        h = Float64(H)
        canvas_clear_rect(0.0, 0.0, w, h)
        canvas_set_fill_rgb(250.0, 249.0, 246.0)
        canvas_fill_rect(0.0, 0.0, w, h)

        # Render each axis
        for ax in fig.axes
            vp = compute_viewport(ax, fig)
            pw = vp.plot_right - vp.plot_left
            ph = vp.plot_bottom - vp.plot_top

            # Background
            canvas_set_fill_rgb(255.0, 255.0, 255.0)
            canvas_fill_rect(vp.plot_left, vp.plot_top, pw, ph)

            # Grid
            if ax.xgridvisible
                canvas_set_line_width(0.5)
                canvas_set_stroke_rgb(0.0, 0.0, 0.0)
                canvas_set_line_dash_dashed()
                for t in vp.xticks
                    px = data_to_pixel(t, vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
                    canvas_begin_path(); canvas_move_to(px, vp.plot_top)
                    canvas_line_to(px, vp.plot_bottom); canvas_stroke()
                end
                for t in vp.yticks
                    py = data_to_pixel(t, vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
                    canvas_begin_path(); canvas_move_to(vp.plot_left, py)
                    canvas_line_to(vp.plot_right, py); canvas_stroke()
                end
                canvas_set_line_dash_solid()
            end

            # Heatmaps
            for hm in ax.heatmap_plots
                cell_w = pw / Float64(hm.nx)
                cell_h = ph / Float64(hm.ny)
                rng = hm.vmax - hm.vmin
                ry = Int64(0)
                while ry < hm.ny
                    rx = Int64(0)
                    while rx < hm.nx
                        idx = ry * hm.nx + rx + Int64(1)
                        t = rng > 0.0 ? (hm.values[idx] - hm.vmin) / rng : 0.5
                        t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t)
                        cr, cg, cb = _viridis(t)
                        canvas_set_fill_rgb(cr, cg, cb)
                        cx = vp.plot_left + Float64(rx) * cell_w
                        cy = vp.plot_bottom - Float64(ry + Int64(1)) * cell_h
                        canvas_fill_rect(cx, cy, cell_w + 0.5, cell_h + 0.5)
                        rx = rx + Int64(1)
                    end
                    ry = ry + Int64(1)
                end
            end

            # Lines
            for lp in ax.line_plots
                canvas_set_stroke_rgb(lp.color.r * 255.0, lp.color.g * 255.0, lp.color.b * 255.0)
                canvas_set_line_width(lp.linewidth)
                if lp.linestyle == Int64(1); canvas_set_line_dash_dashed()
                elseif lp.linestyle == Int64(2); canvas_set_line_dash_dotted()
                else; canvas_set_line_dash_solid(); end
                canvas_begin_path()
                li = Int64(1)
                while li <= Int64(length(lp.x))
                    lpx = data_to_pixel(lp.x[li], vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
                    lpy = data_to_pixel(lp.y[li], vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
                    if li == Int64(1); canvas_move_to(lpx, lpy)
                    else; canvas_line_to(lpx, lpy); end
                    li = li + Int64(1)
                end
                canvas_stroke()
                canvas_set_line_dash_solid()
            end

            # Scatter
            for sp in ax.scatter_plots
                canvas_set_fill_rgb(sp.color.r * 255.0, sp.color.g * 255.0, sp.color.b * 255.0)
                si = Int64(1)
                while si <= Int64(length(sp.x))
                    spx = data_to_pixel(sp.x[si], vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
                    spy = data_to_pixel(sp.y[si], vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
                    canvas_begin_path()
                    canvas_arc(spx, spy, sp.markersize / 2.0, 0.0, 6.28318)
                    canvas_fill()
                    si = si + Int64(1)
                end
            end

            # Bars
            for bp in ax.bar_plots
                canvas_set_fill_rgb(bp.color.r * 255.0, bp.color.g * 255.0, bp.color.b * 255.0)
                hw = bp.width / 2.0
                bi = Int64(1)
                while bi <= Int64(length(bp.x))
                    bxl = data_to_pixel(bp.x[bi] - hw, vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
                    bxr = data_to_pixel(bp.x[bi] + hw, vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
                    byt = data_to_pixel(bp.heights[bi], vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
                    byb = data_to_pixel(0.0, vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
                    canvas_fill_rect(bxl, byt, bxr - bxl, byb - byt)
                    bi = bi + Int64(1)
                end
            end

            # Spines
            canvas_set_stroke_rgb(0.0, 0.0, 0.0)
            canvas_set_line_width(1.0)
            canvas_stroke_rect(vp.plot_left, vp.plot_top, pw, ph)

            # Tick marks
            canvas_set_line_width(1.0)
            for t in vp.xticks
                px = data_to_pixel(t, vp.xmin, vp.xmax, vp.plot_left, vp.plot_right)
                canvas_begin_path(); canvas_move_to(px, vp.plot_bottom)
                canvas_line_to(px, vp.plot_bottom + 4.0); canvas_stroke()
            end
            for t in vp.yticks
                py = data_to_pixel(t, vp.ymin, vp.ymax, vp.plot_bottom, vp.plot_top)
                canvas_begin_path(); canvas_move_to(vp.plot_left - 4.0, py)
                canvas_line_to(vp.plot_left, py); canvas_stroke()
            end
        end
    end)

    return Div(:class => "flex flex-col items-center gap-4 w-full",
        Div(:class => "w-full max-w-4xl rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden bg-warm-50 dark:bg-warm-900",
            RawHtml("<canvas width=\"900\" height=\"600\" style=\"display:block;width:100%;height:auto;\"></canvas>")
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

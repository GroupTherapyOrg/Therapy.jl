# ── InteractivePlotDashboard ──
# ONE @island, ONE <canvas>, ONE WasmPlot.Figure with a 2×2 grid of Axes —
# ALL 4 Makie plot types driven by THREE signals via a SINGLE reactive effect.
#
# Signal wiring (each signal affects multiple plots simultaneously):
#   freq    → lines (sin freq*x)        AND heatmap (sin(f*x)*cos(f*y))
#   n_pts   → lines (density)           AND scatter (point count)
#   shift   → barplot (bar rotation)    AND heatmap (phase)
#
# Any single signal change redraws every plot that depends on it — watch all
# four canvases update together in one render pass.
using WasmPlot

@island function InteractivePlotDashboard()
    freq,  set_freq  = create_signal(Int64(3))
    n_pts, set_n_pts = create_signal(Int64(12))
    shift, set_shift = create_signal(Int64(0))

    create_effect(() -> begin
        fi    = freq()                  # Int64 signal value
        f     = Float64(fi)             # Float64 for math
        npts  = n_pts()                 # Int64
        sh    = shift()                 # Int64
        phase = Float64(sh) * 0.5

        # Build the single 2×2 figure. Makie-style: `Axis(fig[row, col]; ...)`.
        fig = WasmPlot.Figure(size=(1000, 560))

        # [1,1] lines — depends on freq + n_pts
        ax_ln = Axis(fig[1, 1]; title="lines!", subtitle="depends on freq + n_pts", xlabel="x", ylabel="sin(freq*x)")
        n_ln = npts * Int64(12)
        xs_ln = Float64[]; ys_ln = Float64[]
        i = Int64(1)
        while i <= n_ln
            xi = Float64(i) / Float64(n_ln) * 6.28318
            push!(xs_ln, xi); push!(ys_ln, sin(xi * f))
            i = i + Int64(1)
        end
        lines!(ax_ln, xs_ln, ys_ln; color=:blue, linewidth=2.0)

        # [1,2] scatter — depends on n_pts
        ax_sc = Axis(fig[1, 2]; title="scatter!", subtitle="depends on n_pts", xlabel="x", ylabel="y")
        xs_sc = Float64[]; ys_sc = Float64[]
        seed = UInt64(1)
        j = Int64(1)
        while j <= npts
            seed = seed * UInt64(6364136223846793005) + UInt64(1442695040888963407)
            fx = Float64(seed >> 32) / Float64(typemax(UInt32))
            seed = seed * UInt64(6364136223846793005) + UInt64(1442695040888963407)
            fy = Float64(seed >> 32) / Float64(typemax(UInt32))
            push!(xs_sc, fx * 10.0); push!(ys_sc, fy * 10.0)
            j = j + Int64(1)
        end
        scatter!(ax_sc, xs_sc, ys_sc; color=:red, markersize=8.0)

        # [2,1] barplot — depends on shift
        ax_bp = Axis(fig[2, 1]; title="barplot!", subtitle="depends on shift", xlabel="category", ylabel="value")
        base = Float64[3.0, 7.0, 2.0, 5.0, 8.0, 4.0, 6.0]
        nb = length(base)
        xs_bp = Float64[]; hs_bp = Float64[]
        k = Int64(1)
        while k <= nb
            push!(xs_bp, Float64(k))
            idx = (k - Int64(1) + sh) % Int64(nb)
            if idx < Int64(0); idx = idx + Int64(nb); end
            push!(hs_bp, base[idx + Int64(1)])
            k = k + Int64(1)
        end
        barplot!(ax_bp, xs_bp, hs_bp; color=:green)

        # [2,2] heatmap — depends on freq + shift
        ax_hm = Axis(fig[2, 2]; title="heatmap!", subtitle="depends on freq + shift", xlabel="x", ylabel="y")
        nx = Int64(20); ny = Int64(12)
        values = Float64[]
        row = Int64(0)
        while row < ny
            col = Int64(0)
            while col < nx
                x = Float64(col) / Float64(nx) * 6.28318
                y = Float64(row) / Float64(ny) * 6.28318
                push!(values, sin(x * f + phase) * cos(y * f))
                col = col + Int64(1)
            end
            row = row + Int64(1)
        end
        heatmap!(ax_hm, (0.0, 10.0), (0.0, 6.0), Int(nx), Int(ny), values)

        render!(fig)  # single pass — all 4 subplots drawn in one go
    end)

    btn_cls = "w-8 h-8 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 cursor-pointer font-mono text-sm"

    Div(
        :class => "flex flex-col items-center gap-4 w-full",
        Div(
            :class => "w-full max-w-5xl rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
            Canvas(
                :width => 1000, :height => 560,
                :style => "display:block;width:100%;height:auto;",
            ),
        ),
        Div(
            :class => "flex flex-wrap justify-center gap-6 pt-1",
            Div(
                :class => "flex items-center gap-2",
                Span(:class => "text-xs font-mono text-warm-500 w-12 text-right", "freq"),
                Button(:on_click => () -> set_freq(max(Int64(1), freq() - Int64(1))), :class => btn_cls, "-"),
                Span(:class => "text-base font-mono min-w-[2ch] text-center", freq),
                Button(:on_click => () -> set_freq(freq() + Int64(1)), :class => btn_cls, "+"),
            ),
            Div(
                :class => "flex items-center gap-2",
                Span(:class => "text-xs font-mono text-warm-500 w-12 text-right", "n_pts"),
                Button(:on_click => () -> set_n_pts(max(Int64(4), n_pts() - Int64(4))), :class => btn_cls, "-"),
                Span(:class => "text-base font-mono min-w-[3ch] text-center", n_pts),
                Button(:on_click => () -> set_n_pts(n_pts() + Int64(4)), :class => btn_cls, "+"),
            ),
            Div(
                :class => "flex items-center gap-2",
                Span(:class => "text-xs font-mono text-warm-500 w-12 text-right", "shift"),
                Button(:on_click => () -> set_shift(shift() - Int64(1)), :class => btn_cls, "-"),
                Span(:class => "text-base font-mono min-w-[3ch] text-center", shift),
                Button(:on_click => () -> set_shift(shift() + Int64(1)), :class => btn_cls, "+"),
            ),
        ),
    )
end

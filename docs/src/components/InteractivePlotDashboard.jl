# ── InteractivePlotDashboard (WASMMAKIE E-003) ──
# ONE @island, ONE <canvas>, ONE WasmMakie.Figure with a 2×2 grid of Axes —
# four Makie plot types driven by THREE signals via a SINGLE reactive effect.
# The real Makie API (Figure/Axis/lines!/scatter!/barplot!/heatmap!) compiled
# to wasm through the generic canvas provider protocol (E-002).
#
# Signal wiring (each signal affects multiple plots simultaneously):
#   freq    → lines (sin freq*x)        AND heatmap (sin(f*x)*cos(f*y))
#   n_pts   → lines (density)           AND scatter (point count)
#   shift   → barplot (bar rotation)    AND heatmap (phase)
#
# `import WasmMakie as WM`: Therapy bulk-exports HTML tag names (Figure,
# Section, …), so the plotting types stay qualified.
import WasmMakie as WM
using WasmMakie: lines!, scatter!, barplot!, heatmap!

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

        # ONE 2×2 figure, Makie-style: `Axis(fig[row, col]; ...)`
        fig = WM.Figure(size = (1000.0, 560.0))

        # [1,1] lines — depends on freq + n_pts
        ax_ln = WM.Axis(fig[1, 1]; title = "lines!", subtitle = "freq + n_pts",
                        xlabel = "x", ylabel = "sin(freq*x)")
        n_ln = npts * Int64(12)
        xs_ln = Float64[]; ys_ln = Float64[]
        i = Int64(1)
        while i <= n_ln
            xi = Float64(i) / Float64(n_ln) * 6.28318
            push!(xs_ln, xi); push!(ys_ln, sin(xi * f))
            i = i + Int64(1)
        end
        lines!(ax_ln, xs_ln, ys_ln; color = :blue, linewidth = 2.0)

        # [1,2] scatter — depends on n_pts
        ax_sc = WM.Axis(fig[1, 2]; title = "scatter!", subtitle = "n_pts",
                        xlabel = "x", ylabel = "y")
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
        scatter!(ax_sc, xs_sc, ys_sc; color = :red, markersize = 8.0)

        # [2,1] barplot — depends on shift
        ax_bp = WM.Axis(fig[2, 1]; title = "barplot!", subtitle = "shift",
                        xlabel = "category", ylabel = "value")
        base = Float64[3.0, 7.0, 2.0, 5.0, 8.0, 4.0, 6.0]
        nb = Int64(length(base))
        xs_bp = Float64[]; hs_bp = Float64[]
        k = Int64(1)
        while k <= nb
            push!(xs_bp, Float64(k))
            idx = (k - Int64(1) + sh) % nb
            if idx < Int64(0); idx = idx + nb; end
            push!(hs_bp, base[idx + Int64(1)])
            k = k + Int64(1)
        end
        barplot!(ax_bp, xs_bp, hs_bp; color = :green)

        # [2,2] heatmap — depends on freq + shift (flat column-major values +
        # edge vectors: the wasm-kernel form of heatmap!)
        ax_hm = WM.Axis(fig[2, 2]; title = "heatmap!", subtitle = "freq + shift",
                        xlabel = "x", ylabel = "y")
        nx = Int64(20); ny = Int64(12)
        values = Float64[]
        col = Int64(0)
        while col < ny                      # column-major: j (y) outer
            rowi = Int64(0)
            while rowi < nx
                x = Float64(rowi) / Float64(nx) * 6.28318
                y = Float64(col) / Float64(ny) * 6.28318
                push!(values, sin(x * f + phase) * cos(y * f))
                rowi = rowi + Int64(1)
            end
            col = col + Int64(1)
        end
        xs_hm = Float64[]
        e = Int64(0)
        while e <= nx
            push!(xs_hm, Float64(e) / Float64(nx) * 10.0)
            e = e + Int64(1)
        end
        ys_hm = Float64[]
        e = Int64(0)
        while e <= ny
            push!(ys_hm, Float64(e) / Float64(ny) * 6.0)
            e = e + Int64(1)
        end
        heatmap!(ax_hm, xs_hm, ys_hm, values, nx, ny)

        WM.render!(fig, WM.WasmCtx())   # single pass — all 4 subplots
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

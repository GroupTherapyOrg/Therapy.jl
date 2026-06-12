# ── PlotGallery (WASMMAKIE U-004) ──
# Static WasmMakie plots rendered AT BUILD TIME through the embedding
# contract: html_snippet(fig) = <canvas> + the recorded Canvas2D command
# stream + the bundled replayer. Zero wasm, zero hydration — the page ships
# finished plots that draw instantly. (The interactive dashboard below is
# the wasm-compiled counterpart.)
#
# Fonts: the FIRST snippet embeds the bundled Makie FontFaces (registered
# document-wide); the rest reuse them with fonts=false.
import WasmMakie as WM
using WasmMakie: lines!, scatter!, barplot!, heatmap!, band!, density!, hist!
using Therapy: RawHtml

function _gallery_cell(title::String, subtitle::String, snippet::String)
    Div(
        :class => "rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden bg-white",
        Div(:class => "px-3 pt-2",
            Span(:class => "text-sm font-semibold text-warm-800", title),
            Span(:class => "text-xs text-warm-500 ml-2 font-mono", subtitle)),
        Div(:class => "p-1", RawHtml(snippet)),
    )
end

function PlotGallery()
    W, H = 380.0, 260.0
    fig_snip(build; fonts::Bool) = begin
        fig = WM.Figure(size = (W, H))
        build(fig)
        WM.html_snippet(fig; fonts)
    end

    xs = collect(0.0:0.05:6.3)
    sin_ys = [sin(x) for x in xs]
    cos_ys = [cos(x) * 0.6 for x in xs]

    cells = [
        _gallery_cell("lines!", "two waves, cycled colors",
            fig_snip(fonts = true) do fig
                ax = WM.Axis(fig[1, 1]; title = "waves", xlabel = "x", ylabel = "y")
                lines!(ax, xs, sin_ys; linewidth = 2.0)
                lines!(ax, xs, cos_ys; linewidth = 2.0)
            end),
        _gallery_cell("scatter!", "markers + sizes",
            fig_snip(fonts = false) do fig
                ax = WM.Axis(fig[1, 1]; title = "scatter")
                scatter!(ax, [1.0, 2.0, 3.0, 4.0, 5.0], [2.0, 4.5, 3.0, 5.5, 4.0];
                         color = :red, markersize = 12.0)
                scatter!(ax, [1.5, 2.5, 3.5, 4.5], [4.0, 2.0, 4.8, 2.8];
                         marker = :rect, markersize = 10.0, color = :purple)
            end),
        _gallery_cell("barplot!", "categorical bars",
            fig_snip(fonts = false) do fig
                ax = WM.Axis(fig[1, 1]; title = "bars", xlabel = "category")
                barplot!(ax, [1.0, 2.0, 3.0, 4.0, 5.0], [3.0, 7.0, 2.0, 5.0, 8.0];
                         color = :orange)
            end),
        _gallery_cell("heatmap! + Colorbar", "flat grid, viridis",
            fig_snip(fonts = false) do fig
                ax = WM.Axis(fig[1, 1]; title = "field")
                nx, ny = 24, 16
                vals = Float64[]
                for j in 0:(ny - 1), i in 0:(nx - 1)
                    push!(vals, sin(i / nx * 6.28) * cos(j / ny * 6.28))
                end
                xe = [Float64(i) for i in 0:nx]
                ye = [Float64(j) for j in 0:ny]
                hm = heatmap!(ax, xe, ye, vals, Int64(nx), Int64(ny))
                WM.Colorbar(fig[1, 2], hm)
            end),
        _gallery_cell("band!", "shaded interval",
            fig_snip(fonts = false) do fig
                ax = WM.Axis(fig[1, 1]; title = "band")
                lo = [sin(x) - 0.3 - 0.1 * x for x in xs]
                hi = [sin(x) + 0.3 + 0.1 * x for x in xs]
                band!(ax, xs, lo, hi)
                lines!(ax, xs, sin_ys; color = :black, linewidth = 1.5)
            end),
        _gallery_cell("density!", "kernel density",
            fig_snip(fonts = false) do fig
                ax = WM.Axis(fig[1, 1]; title = "density")
                vals = Float64[]
                seed = UInt64(7)
                for _ in 1:200
                    seed = seed * UInt64(6364136223846793005) + UInt64(1442695040888963407)
                    a = Float64(seed >> 32) / Float64(typemax(UInt32))
                    seed = seed * UInt64(6364136223846793005) + UInt64(1442695040888963407)
                    b = Float64(seed >> 32) / Float64(typemax(UInt32))
                    push!(vals, (a + b) * 3.0)
                end
                density!(ax, vals)
            end),
    ]

    Div(:class => "grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4", cells...)
end

# Plotting.jl — PlotlyBase-compatible plotting API for @island components
#
# These functions mirror PlotlyBase's API so users can write standard Julia
# plotting code that compiles to Plotly.js calls via JST.
#
# In Julia: builds Dict structures (for testing/SSR)
# In JS: compiles to Plotly.newPlot/react via JST package registry
#
# Usage:
#   using Therapy: scatter, Layout, plotly
#   create_effect(() -> plotly("my-plot", [scatter(x=x, y=y)], Layout(title="Test")))

import JavaScriptTarget as JST

# ─── Trace constructors ───

for trace_type in [:scatter, :bar, :heatmap, :contour, :surface,
                   :histogram, :box, :violin, :pie, :scatter3d,
                   :scattergl, :scatterpolar, :choropleth, :mesh3d]
    @eval begin
        @noinline function $(trace_type)(; kwargs...)
            d = Dict{String, Any}("type" => $(string(trace_type)))
            for (k, v) in kwargs
                d[string(k)] = v
            end
            return d
        end
    end
end

# ─── Layout constructor ───

@noinline function Layout(; kwargs...)
    d = Dict{String, Any}()
    for (k, v) in kwargs
        d[string(k)] = v
    end
    return d
end

# ─── Plot function ───

@noinline function plotly(divid::String, traces, layout=Dict{String,Any}())
    # In Julia: returns spec for testing
    return Dict{String, Any}("divid" => divid, "data" => traces, "layout" => layout)
end

# ─── Register with JST ───

function __init__()
    # Register this module's functions with JST's package compilation registry
    JST.register_plotly_compilations!(@__MODULE__)
end

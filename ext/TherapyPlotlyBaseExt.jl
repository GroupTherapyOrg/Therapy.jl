module TherapyPlotlyBaseExt

# Package extension: when both Therapy and PlotlyBase are loaded,
# registers JST compilations so standard PlotlyBase code compiles to Plotly.js.
#
#   using Therapy, PlotlyBase
#   @island function MyPlot(...)
#       Plot(
#           [scatter(x=x, y=y, mode="lines")],
#           Layout(title="My Plot")
#       )
#   end

import JavaScriptTarget as JST
import PlotlyBase

function __init__()
    # Register PlotlyBase's functions + types for JST compilation:
    # scatter, bar, ... → {type:"scatter", ...}
    # Layout(...)       → {title:..., ...}
    # Plot(traces, lay) → Plotly.newPlot(el, traces, layout)
    JST.register_plotly_compilations!(PlotlyBase)
end

end

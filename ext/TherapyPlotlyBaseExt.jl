module TherapyPlotlyBaseExt

# TEMPORARILY DISABLED — WasmTarget branch has no JavaScriptTarget
# TODO: rewrite for WasmTarget when PlotlyBase compilation is needed

#=
import JavaScriptTarget as JST
import PlotlyBase

function __init__()
    JST.register_plotly_compilations!(PlotlyBase)
end
=#

end

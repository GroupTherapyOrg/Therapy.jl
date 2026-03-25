# Plotting.jl — Package extension support for PlotlyBase
#
# All plotting functionality comes from PlotlyBase.jl via TherapyPlotlyBaseExt.
# Users write standard PlotlyBase code:
#
#   using Therapy, PlotlyBase
#   @island function MyPlot(...)
#       Plot([scatter(x=x, y=y)], Layout(title="..."))
#   end
#
# The package extension auto-registers JST compilations when both are loaded.
# No Therapy-specific plotting functions needed.

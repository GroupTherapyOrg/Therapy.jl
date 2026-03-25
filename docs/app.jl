#!/usr/bin/env julia
# Therapy.jl Documentation Site
#
# Usage (from Therapy.jl root directory):
#   julia --project=. docs/app.jl dev    # Development server with HMR
#   julia --project=. docs/app.jl build  # Build static site to docs/dist
#
# This site dogfoods Therapy.jl's App framework with:
# - File-based routing from src/routes/
# - Automatic component loading from src/components/
# - Interactive JavaScript components compiled via JavaScriptTarget.jl

# Ensure we're using the local Therapy.jl package
if !haskey(ENV, "JULIA_PROJECT")
    push!(LOAD_PATH, dirname(@__DIR__))
end

using Therapy

cd(@__DIR__)

# =============================================================================
# App Configuration
# =============================================================================

app = App(
    routes_dir = "src/routes",
    components_dir = "src/components",
    title = "Therapy.jl",
    output_dir = "dist",
    base_path = "/Therapy.jl",
    layout = :Layout
)

# =============================================================================
# Run - dev or build based on args
# =============================================================================

Therapy.run(app)

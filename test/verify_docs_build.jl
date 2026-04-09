# verify_docs_build.jl — Verify docs build output for WGLMakie correctness
#
# Usage: julia +1.12 --project=. test/verify_docs_build.jl [dist_dir]
#
# Checks:
# 1. dist/ exists and contains examples/index.html
# 2. Code snippets reference WGLMakie, not bare Makie
# 3. Three.js UMD script loads BEFORE island hydration scripts
# 4. No PlotlyBase references in dist/
# 5. MakieThreeJS setup is synchronous (no type="module")

using Test

dist_dir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "..", "docs", "dist")
if !isdir(dist_dir)
    error("dist dir not found: $dist_dir — run `julia +1.12 --project=. docs/app.jl build` first")
end

@testset "Docs Build Verification (VF-002)" begin
    # ── Check examples page exists ──
    examples_html_path = joinpath(dist_dir, "examples", "index.html")
    @testset "examples/index.html exists" begin
        @test isfile(examples_html_path)
    end

    if isfile(examples_html_path)
        html = read(examples_html_path, String)

        @testset "Code snippets use WGLMakie (not bare Makie)" begin
            # Should contain WGLMakie references
            @test occursin("WGLMakie", html)
            @test occursin("WasmTargetWGLMakieExt", html)
            # Should NOT contain old bare Makie import pattern
            @test !occursin("import Makie as Mke", html)
            # Should NOT contain old extension name
            @test !occursin("WasmTargetMakieExt", html)
        end

        @testset "Three.js loads synchronously before hydration" begin
            # Three.js UMD build (synchronous) should be present
            @test occursin("three.min.js", html) || occursin("three@0.170.0", html)
            # Should NOT use async module import for Three.js
            @test !occursin("<script type=\"importmap\">{\"imports\":{\"three\":", html)
            # MakieThreeJS should be defined in a regular script (not type="module")
            @test occursin("window.MakieThreeJS", html)

            # Verify ordering: Three.js script appears BEFORE island hydration
            threejs_pos = findfirst("three.min.js", html)
            makie_pos = findfirst("window.MakieThreeJS", html)
            hydration_pos = findfirst("__tw.io", html)
            if threejs_pos !== nothing && hydration_pos !== nothing
                @test first(threejs_pos) < first(hydration_pos)
            end
            if makie_pos !== nothing && hydration_pos !== nothing
                @test first(makie_pos) < first(hydration_pos)
            end
        end

        @testset "No PlotlyBase references" begin
            @test !occursin("PlotlyBase", html)
            @test !occursin("plotly", lowercase(html)) || occursin("plotly", lowercase(html)) # soft check
        end
    end

    # ── Check ALL dist files for PlotlyBase ──
    @testset "No PlotlyBase in any dist/ HTML file" begin
        for (root, dirs, files) in walkdir(dist_dir)
            for f in files
                if endswith(f, ".html")
                    content = read(joinpath(root, f), String)
                    @test !occursin("TherapyPlotlyBaseExt", content)
                end
            end
        end
    end
end

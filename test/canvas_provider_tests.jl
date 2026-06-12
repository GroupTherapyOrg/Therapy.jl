# Canvas provider protocol (WASMMAKIE E-002): Therapy consumes ANY package's
# import_specs()/js_glue() — zero plotting-package-specific code here.
using Test
using Therapy

@testset "canvas provider protocol (E-002)" begin
    # fake provider exercising both spec shapes
    struct _PSpec
        func
        name
        arg_types
        return_type
    end
    glue = "function canvas2d_imports(t){return {op_a:function(){return 0n;}};}"
    p = Therapy.register_canvas_provider!(name = "test-provider",
        import_specs = () -> Any[(identity, "op_a", (Float64, Int64), Int64),
                                 _PSpec(identity, "op_b", (Float64,), Float64)],
        js_glue = () -> glue)
    @test Therapy.active_canvas_provider() === p
    @test p.name == "test-provider"

    # spec normalization: tuple form passes through; property form extracted
    n1 = Therapy._normalize_canvas_spec((identity, "x", (Float64,), Int64))
    @test n1 == (identity, "x", (Float64,), Int64)
    n2 = Therapy._normalize_canvas_spec(_PSpec(identity, "y", (Int64, Int64), Float64))
    @test n2[2] == "y" && n2[3] == (Int64, Int64) && n2[4] === Float64

    # the page runtime embeds the provider glue and routes io() through it
    rt = Therapy.therapy_wasm_runtime_js()
    @test occursin(glue, rt)
    @test occursin("window.__tw_canvas_glue=canvas2d_imports", rt)
    @test occursin("window.__tw_canvas_glue&&_cv", rt)
    # the old inline 23-import object is GONE from the runtime path
    @test !occursin("set_line_dash_dotted:function", rt)

    # glue accessor mirrors the provider
    @test Therapy.canvas_glue_js() == glue

    # reset to the legacy fallback for any later tests
    Therapy._CANVAS_PROVIDER[] = nothing
end

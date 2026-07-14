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
    glue = "function canvas2d_imports(t){return {op_a:function(){return 0n;}};} function canvas2d_frame_presenter(c){return {target:c,present:function(){c.dataset.presented='1';}};}"
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
    @test occursin("window.__tw_canvas_presenter=typeof canvas2d_frame_presenter", rt)
    @test occursin("window.__tw_canvas_glue?window.__tw_canvas_glue(_target):{}", rt)
    @test occursin("present:_fp?function(){_fp.present();}:function(){}", rt)
    # the old inline 23-import object is GONE from the runtime path
    @test !occursin("set_line_dash_dotted:function", rt)

    # glue accessor mirrors the provider
    @test Therapy.canvas_glue_js() == glue

    # The closed-world compiler creates its own FunctionRegistry. Provider
    # stubs must therefore cross the compile boundary through import_stubs;
    # merely constructing a side registry leaves every canvas call as the
    # Julia-native no-op and produces a hydrated but blank canvas.
    compile_src = read(joinpath(dirname(pathof(Therapy)), "Compiler", "Compile.jl"), String)
    @test occursin("push!(canvas_import_stubs", compile_src)
    @test occursin("import_stubs=canvas_import_stubs", compile_src)

    # reset for any later tests (E-005: no legacy fallback — nothing means none)
    Therapy._CANVAS_PROVIDER[] = nothing
end

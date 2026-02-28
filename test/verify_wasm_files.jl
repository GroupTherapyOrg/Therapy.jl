# verify_wasm_files.jl — Verify all wasm files in a docs/dist build are real
#
# Usage: julia +1.12 --project=Therapy.jl Therapy.jl/test/verify_wasm_files.jl <dist_dir>
#
# Checks:
# 1. All .wasm files have valid magic bytes (0x00 0x61 0x73 0x6d)
# 2. No .wasm file matches the old stub hash (024f14e35f51263989bf32e7600ee01c)
# 3. All .wasm files are > 2279 bytes (old stub size)

using Test

dist_dir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "..", "..", "Suite.jl", "docs", "dist")
if !isdir(dist_dir)
    error("dist dir not found: $dist_dir")
end

wasm_files = filter(f -> endswith(f, ".wasm"), readdir(dist_dir))
OLD_STUB_SIZE = 2279
WASM_MAGIC = UInt8[0x00, 0x61, 0x73, 0x6d]

@testset "Wasm File Verification ($dist_dir)" begin
    @test length(wasm_files) >= 42  # At least 42 Suite.jl components

    @testset "Valid wasm magic bytes" begin
        for f in wasm_files
            path = joinpath(dist_dir, f)
            bytes = read(path)
            @test length(bytes) >= 4
            @test bytes[1:4] == WASM_MAGIC
        end
    end

    @testset "No old stub wasm files" begin
        for f in wasm_files
            path = joinpath(dist_dir, f)
            size = filesize(path)
            @test size > OLD_STUB_SIZE  # Old stubs were exactly 2279 bytes
        end
    end

    @testset "Previously-broken components have real wasm" begin
        broken_9 = ["accordion", "tabs", "togglegroup", "codeblock",
                     "treeview", "command", "carousel", "toaster",
                     "resizablepanelgroup"]
        for name in broken_9
            fname = "$name.wasm"
            @test fname in wasm_files
            path = joinpath(dist_dir, fname)
            @test filesize(path) > OLD_STUB_SIZE
        end
    end
end

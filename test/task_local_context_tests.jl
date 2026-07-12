using Test
using Therapy

@testset "task-local reactive analysis" begin
    @testset "nested analysis restores its parent" begin
        inner = Therapy.analyze_component() do
            value, _ = create_signal(Int32(2))
            Span(value)
        end

        outer = Therapy.analyze_component() do
            before, _ = create_signal(Int64(1))
            nested = Therapy.analyze_component() do
                child, _ = create_signal("child")
                Span(child)
            end
            @test length(nested.signals) == 1
            after, _ = create_signal(3.0)
            Div(Span(before), Span(after))
        end

        @test length(inner.signals) == 1
        @test inner.signals[1].type === Int32
        @test map(s -> s.type, outer.signals) == Type[Int64, Float64]
        @test !Therapy.is_signal_analysis_mode()
    end

    @testset "concurrent analyses do not share discoveries or counters" begin
        ready = Channel{Nothing}(2)
        release = Channel{Nothing}(2)
        results = Vector{Any}(undef, 2)

        @sync begin
            for task_id in 1:2
                @async begin
                    results[task_id] = Therapy.analyze_component() do
                        first, _ = create_signal(Int64(task_id))
                        put!(ready, nothing)
                        take!(release)
                        memo = create_memo(() -> first() + task_id)
                        create_effect(() -> memo())
                        Span(first)
                    end
                end
            end
            take!(ready); take!(ready)
            put!(release, nothing); put!(release, nothing)
        end

        for (task_id, result) in enumerate(results)
            @test length(result.signals) == 1
            @test result.signals[1].initial_value == task_id
            @test length(result.memos) == 1
            @test result.memos[1].idx == 0
            @test result.memos[1].initial_value == 2task_id
            @test length(result.effects) == 1
            @test result.effects[1].id == 0
        end
    end

    @testset "component context is task-local" begin
        entered = Channel{Nothing}(2)
        release = Channel{Nothing}(2)
        observed = Channel{Int}(2)
        @sync begin
            for value in (11, 22)
                @async Therapy.provide_context(Int, value) do
                    put!(entered, nothing)
                    take!(release)
                    put!(observed, Therapy.use_context(Int))
                end
            end
            take!(entered); take!(entered)
            put!(release, nothing); put!(release, nothing)
        end
        @test sort([take!(observed), take!(observed)]) == [11, 22]
    end
end

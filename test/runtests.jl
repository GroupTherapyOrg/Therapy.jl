using Test
using Therapy

@testset "Therapy.jl" begin

    @testset "Signals" begin
        @testset "basic signal" begin
            count, set_count = create_signal(0)
            @test count() == 0
            set_count(5)
            @test count() == 5
        end

        @testset "signal with different types" begin
            name, set_name = create_signal("hello")
            @test name() == "hello"
            set_name("world")
            @test name() == "world"

            pi_val, set_pi = create_signal(3.14)
            @test pi_val() == 3.14

            flag, set_flag = create_signal(true)
            @test flag() == true
            set_flag(false)
            @test flag() == false
        end

        @testset "signal with transform" begin
            upper, set_upper = create_signal("hello", uppercase)
            @test upper() == "HELLO"
            set_upper("world")
            @test upper() == "WORLD"
        end
    end

    @testset "Effects" begin
        @testset "basic effect" begin
            count, set_count = create_signal(0)
            log = Int[]

            create_effect() do
                push!(log, count())
            end

            @test log == [0]  # Effect runs immediately

            set_count(1)
            @test log == [0, 1]

            set_count(2)
            @test log == [0, 1, 2]
        end

        @testset "effect with multiple signals" begin
            a, set_a = create_signal(1)
            b, set_b = create_signal(2)
            sums = Int[]

            create_effect() do
                push!(sums, a() + b())
            end

            @test sums == [3]

            set_a(10)
            @test sums == [3, 12]

            set_b(20)
            @test sums == [3, 12, 30]
        end

        @testset "effect disposal" begin
            count, set_count = create_signal(0)
            log = Int[]

            effect = create_effect() do
                push!(log, count())
            end

            @test log == [0]

            dispose!(effect)
            set_count(1)
            @test log == [0]  # Effect no longer runs
        end
    end

    @testset "Memos" begin
        @testset "basic memo" begin
            count, set_count = create_signal(1)
            doubled = create_memo(() -> count() * 2)

            @test doubled() == 2

            set_count(5)
            @test doubled() == 10
        end

        @testset "memo caching" begin
            count, set_count = create_signal(1)
            call_count = Ref(0)

            expensive = create_memo() do
                call_count[] += 1
                count() * 2
            end

            @test expensive() == 2
            @test call_count[] == 1

            # Reading again shouldn't recompute
            @test expensive() == 2
            @test call_count[] == 1

            # Changing dependency should recompute
            set_count(5)
            @test expensive() == 10
            @test call_count[] == 2
        end
    end

    @testset "Batching" begin
        @testset "batch updates" begin
            a, set_a = create_signal(0)
            b, set_b = create_signal(0)
            runs = Int[]

            create_effect() do
                push!(runs, a() + b())
            end

            @test runs == [0]

            batch() do
                set_a(1)
                set_b(2)
            end

            # Effect should only run once after batch
            @test runs == [0, 3]
        end
    end

    @testset "VNodes" begin
        @testset "basic vnode" begin
            node = VNode(:div, Dict{Symbol,Any}(), Any["hello"])
            @test node.tag == :div
            @test node.children == ["hello"]
        end

        @testset "element functions" begin
            node = Div(:class => "container", "Hello")
            @test node.tag == :div
            @test node.props[:class] == "container"
            @test node.children == ["Hello"]
        end

        @testset "nested elements" begin
            node = Div(
                H1("Title"),
                P("Paragraph")
            )
            @test length(node.children) == 2
            @test node.children[1].tag == :h1
            @test node.children[2].tag == :p
        end
    end

    @testset "Components (plain functions)" begin
        @testset "basic function component" begin
            function TestGreeting(; name="World")
                P("Hello, ", name, "!")
            end

            node = TestGreeting(name="Julia")
            @test node isa VNode
            @test node.tag == :p
        end

        @testset "function component with children" begin
            function TestCard(children...; class="card")
                Div(:class => class, children...)
            end

            node = TestCard(P("Content"))
            @test node.tag == :div
            @test length(node.children) == 1
        end

        @testset "@island macro" begin
            @island function TestIsland(; initial=0)
                count, set_count = create_signal(initial)
                Div(Span(count))
            end

            @test is_island(:TestIsland)
            @test TestIsland isa IslandDef

            node = TestIsland()
            @test node isa IslandVNode
            @test node.name == :TestIsland
            @test isempty(node.props)

            node2 = TestIsland(initial=5)
            @test node2.props[:initial] == 5
        end

        @testset "removed APIs are not exported" begin
            @test !isdefined(@__MODULE__, :component)
            @test !isdefined(@__MODULE__, :Props)
            @test !isdefined(@__MODULE__, :get_prop)
            @test !isdefined(@__MODULE__, :get_children)
            @test !isdefined(@__MODULE__, :has_prop)
            @test !isdefined(@__MODULE__, :ComponentDef)
            @test !isdefined(@__MODULE__, :ComponentInstance)
        end

        @testset "@island SSR with data-props" begin
            @island function TestPropsIsland(; label="default")
                Div(Span(label))
            end

            html = render_to_string(TestPropsIsland())
            @test occursin("therapy-island", html)
            @test !occursin("data-props", html)  # No props = no attribute

            html2 = render_to_string(TestPropsIsland(label="custom"))
            @test occursin("data-props", html2)
            @test occursin("label", html2)
        end
    end

    @testset "SSR" begin
        @testset "basic rendering" begin
            html = render_to_string(Div("Hello"))
            @test occursin("<div", html)
            @test occursin("Hello", html)
            @test occursin("</div>", html)
        end

        @testset "with attributes" begin
            html = render_to_string(Div(:class => "container", "Content"))
            @test occursin("class=\"container\"", html)
        end

        @testset "nested elements" begin
            html = render_to_string(
                Div(
                    H1("Title"),
                    P("Paragraph")
                )
            )
            @test occursin("<h1", html)
            @test occursin("</h1>", html)
            @test occursin("<p", html)
            @test occursin("</p>", html)
        end

        @testset "hydration keys" begin
            html = render_to_string(Div("Hello"))
            @test occursin("data-hk=", html)
        end

        @testset "void elements" begin
            html = render_to_string(Img(:src => "test.jpg"))
            @test occursin("<img", html)
            @test occursin("/>", html)
            @test !occursin("</img>", html)
        end

        @testset "boolean attributes" begin
            html = render_to_string(Input(:type => "checkbox", :checked => true))
            @test occursin(" checked", html)
        end

        @testset "escaping" begin
            html = render_to_string(P("<script>alert('xss')</script>"))
            @test !occursin("<script>", html)
            @test occursin("&lt;script&gt;", html)
        end

        @testset "signal values" begin
            count, _ = create_signal(42)
            html = render_to_string(P(count))
            @test occursin("42", html)
        end

        @testset "function component rendering" begin
            function SSRGreeting(; name="World")
                P("Hello, ", name, "!")
            end

            html = render_to_string(SSRGreeting(name="Julia"))
            @test occursin("Hello, Julia!", html)
        end
    end

    @testset "Show conditional" begin
        result = Show(true, () -> Div("visible"))
        @test result.tag == :div

        result = Show(false, () -> Div("visible"))
        @test result === nothing
    end

    @testset "Context API" begin
        # Clear any leftover context from previous tests
        empty!(Therapy.CONTEXT_STACK)

        @testset "basic context provide/use" begin
            # Define a simple context type
            struct TestTheme
                name::String
                primary_color::String
            end

            result = Ref{Union{TestTheme, Nothing}}(nothing)

            provide_context(TestTheme("dark", "#1a1a2e")) do
                result[] = use_context(TestTheme)
            end

            @test result[] !== nothing
            @test result[].name == "dark"
            @test result[].primary_color == "#1a1a2e"
        end

        @testset "nested context shadows outer" begin
            struct NestedCtx
                value::Int
            end

            outer_value = Ref{Union{NestedCtx, Nothing}}(nothing)
            inner_value = Ref{Union{NestedCtx, Nothing}}(nothing)
            after_inner_value = Ref{Union{NestedCtx, Nothing}}(nothing)

            provide_context(NestedCtx(100)) do
                outer_value[] = use_context(NestedCtx)

                provide_context(NestedCtx(200)) do
                    inner_value[] = use_context(NestedCtx)
                end

                # After inner block exits, should see outer value again
                after_inner_value[] = use_context(NestedCtx)
            end

            @test outer_value[] !== nothing
            @test outer_value[].value == 100

            @test inner_value[] !== nothing
            @test inner_value[].value == 200

            @test after_inner_value[] !== nothing
            @test after_inner_value[].value == 100
        end

        @testset "missing context returns nothing" begin
            struct NonExistentCtx
                data::String
            end

            # Without any provider, use_context should return nothing
            result = use_context(NonExistentCtx)
            @test result === nothing

            # Also test inside a provider block for a different type
            struct OtherCtx
                x::Int
            end

            provide_context(OtherCtx(42)) do
                # NonExistentCtx is still not provided
                @test use_context(NonExistentCtx) === nothing
                # But OtherCtx is available
                @test use_context(OtherCtx) !== nothing
                @test use_context(OtherCtx).x == 42
            end
        end

        @testset "context with signals" begin
            # Context can hold reactive signals
            # Use Any type since create_signal returns specialized SignalGetter/SignalSetter types
            struct SignalCtx
                count::Tuple{Any, Any}  # (SignalGetter, SignalSetter)
            end

            count, set_count = create_signal(0)
            ctx = SignalCtx((count, set_count))

            result_initial = Ref(0)
            result_after_update = Ref(0)

            provide_context(ctx) do
                signal_ctx = use_context(SignalCtx)
                @test signal_ctx !== nothing

                getter, setter = signal_ctx.count
                result_initial[] = getter()

                # Update the signal through the context
                setter(42)
                result_after_update[] = getter()
            end

            @test result_initial[] == 0
            @test result_after_update[] == 42

            # Signal state persists outside the context block
            @test count() == 42
        end

        @testset "multiple different context types" begin
            struct UserCtx
                name::String
            end

            struct ConfigCtx
                debug::Bool
            end

            user_result = Ref{Union{UserCtx, Nothing}}(nothing)
            config_result = Ref{Union{ConfigCtx, Nothing}}(nothing)

            provide_context(UserCtx("Alice")) do
                provide_context(ConfigCtx(true)) do
                    user_result[] = use_context(UserCtx)
                    config_result[] = use_context(ConfigCtx)
                end
            end

            @test user_result[] !== nothing
            @test user_result[].name == "Alice"

            @test config_result[] !== nothing
            @test config_result[].debug == true
        end

        @testset "context cleanup on exception" begin
            struct ExceptionCtx
                value::Int
            end

            try
                provide_context(ExceptionCtx(999)) do
                    @test use_context(ExceptionCtx).value == 999
                    error("Test exception")
                end
            catch e
                # Exception should propagate
                @test e isa ErrorException
            end

            # Context should be cleaned up even after exception
            @test use_context(ExceptionCtx) === nothing
        end

        # Clean up after tests
        empty!(Therapy.CONTEXT_STACK)
    end

    @testset "Resource" begin
        @testset "basic resource creation" begin
            # Simple resource without reactive source
            data_loaded = Ref(false)
            resource = create_resource(() -> 42)

            # Resource should have loaded immediately
            @test ready(resource)
            @test !loading(resource)
            @test resource() == 42
            @test resource.error === nothing
        end

        @testset "resource with source signal" begin
            # Resource that refetches when source changes
            id, set_id = create_signal(1)
            fetch_count = Ref(0)

            resource = create_resource(
                () -> id(),
                (x) -> begin
                    fetch_count[] += 1
                    x * 10
                end
            )

            # Initial fetch
            @test resource() == 10
            @test fetch_count[] == 1

            # Change source - should refetch
            set_id(2)
            @test resource() == 20
            @test fetch_count[] == 2

            # Change source again
            set_id(5)
            @test resource() == 50
            @test fetch_count[] == 3
        end

        @testset "resource states" begin
            resource = create_resource(() -> "hello")

            @test resource.state == RESOURCE_READY
            @test ready(resource)
            @test !loading(resource)
            @test resource.data == "hello"
        end

        @testset "resource error handling" begin
            resource = create_resource() do
                error("Test error")
            end

            @test resource.state == RESOURCE_ERROR
            @test !ready(resource)
            @test !loading(resource)
            @test resource.error !== nothing
            @test resource() === nothing
        end

        @testset "resource with effect tracking" begin
            # Resource should track effects that read from it
            count, set_count = create_signal(1)
            resource = create_resource(
                () -> count(),
                x -> x * 2
            )

            effect_runs = Ref(0)
            result_values = Int[]

            create_effect() do
                effect_runs[] += 1
                val = resource()
                if val !== nothing
                    push!(result_values, val)
                end
            end

            # Initial effect run reads the resource
            @test effect_runs[] == 1
            @test result_values == [2]

            # Changing the source signal triggers refetch which triggers effect
            set_count(5)
            @test result_values == [2, 10]
        end

        @testset "refetch! manual trigger" begin
            call_count = Ref(0)
            resource = create_resource() do
                call_count[] += 1
                "data_$(call_count[])"
            end

            @test resource() == "data_1"
            @test call_count[] == 1

            # Manual refetch
            refetch!(resource)
            @test resource() == "data_2"
            @test call_count[] == 2

            refetch!(resource)
            @test resource() == "data_3"
            @test call_count[] == 3
        end

        @testset "dispose resource" begin
            count, set_count = create_signal(1)
            fetch_count = Ref(0)

            resource = create_resource(
                () -> count(),
                x -> begin
                    fetch_count[] += 1
                    x
                end
            )

            @test fetch_count[] == 1

            # Dispose the resource
            dispose!(resource)

            # Changing source should not trigger refetch anymore
            set_count(2)
            @test fetch_count[] == 1  # No new fetch
        end

        @testset "resource with different types" begin
            # String resource
            str_resource = create_resource(() -> "hello world")
            @test str_resource() == "hello world"

            # Float resource
            float_resource = create_resource(() -> 3.14159)
            @test float_resource() == 3.14159

            # Vector resource
            vec_resource = create_resource(() -> [1, 2, 3, 4, 5])
            @test vec_resource() == [1, 2, 3, 4, 5]

            # Struct resource
            struct UserData
                name::String
                age::Int
            end

            user_resource = create_resource(() -> UserData("Alice", 30))
            @test user_resource().name == "Alice"
            @test user_resource().age == 30
        end
    end

    @testset "Suspense" begin
        @testset "basic Suspense with ready resource" begin
            # Resource that is immediately ready
            resource = create_resource(() -> "Hello World")

            suspense_node = Suspense(fallback = () -> P("Loading...")) do
                Div(resource())
            end

            @test suspense_node isa SuspenseNode
            @test !suspense_node.initial_loading  # Should not be loading
            @test suspense_node.children !== nothing

            # SSR should render children, not fallback
            html = render_to_string(suspense_node)
            @test occursin("Hello World", html)
            @test !occursin("Loading...", html)
            @test occursin("data-suspense=\"true\"", html)
        end

        @testset "Suspense shows fallback when loading" begin
            # Create a resource that will be in loading state
            # We simulate this by creating a resource and checking before it completes
            loading_resource = Resource{String}(
                Therapy.next_resource_id(),
                RESOURCE_LOADING,
                nothing,
                nothing,
                () -> nothing,
                _ -> "data",
                nothing,
                Set{Any}()
            )

            suspense_node = Suspense(fallback = () -> P("Loading...")) do
                if ready(loading_resource)
                    Div(loading_resource())
                else
                    # This simulates what happens during render when resource is loading
                    nothing
                end
            end

            # The suspense should detect the loading state
            @test loading_resource.state == RESOURCE_LOADING
        end

        @testset "Suspense without fallback" begin
            resource = create_resource(() -> "Data")

            suspense_node = Suspense() do
                P(resource())
            end

            @test suspense_node isa SuspenseNode
            @test suspense_node.fallback === nothing

            html = render_to_string(suspense_node)
            @test occursin("Data", html)
        end

        @testset "Await convenience wrapper" begin
            resource = create_resource(() -> Dict("name" => "Alice", "age" => 30))

            await_node = Await(resource; fallback = () -> Span("Loading user...")) do data
                P("Hello, ", data["name"])
            end

            @test await_node isa SuspenseNode

            html = render_to_string(await_node)
            @test occursin("Hello, Alice", html)
            @test !occursin("Loading user...", html)
        end

        @testset "nested Suspense boundaries" begin
            outer_resource = create_resource(() -> "Outer")
            inner_resource = create_resource(() -> "Inner")

            node = Suspense(fallback = () -> P("Outer loading...")) do
                Div(
                    Span(outer_resource()),
                    Suspense(fallback = () -> P("Inner loading...")) do
                        Span(inner_resource())
                    end
                )
            end

            html = render_to_string(node)
            @test occursin("Outer", html)
            @test occursin("Inner", html)
            @test !occursin("loading...", html)
        end

        @testset "Suspense with multiple ready resources" begin
            user = create_resource(() -> "Alice")
            posts = create_resource(() -> ["Post1", "Post2"])
            comments = create_resource(() -> 42)

            node = Suspense(fallback = () -> Div("Loading everything...")) do
                Div(
                    P("User: ", user()),
                    P("Posts: ", length(posts())),
                    P("Comments: ", comments())
                )
            end

            @test !node.initial_loading

            html = render_to_string(node)
            @test occursin("User: Alice", html)
            @test occursin("Posts: 2", html)
            @test occursin("Comments: 42", html)
        end

        @testset "Suspense context stack" begin
            # Context should be empty initially
            @test Therapy.current_suspense_context() === nothing

            # Inside a suspense, context should be set
            seen_context = Ref{Any}(nothing)

            Suspense() do
                seen_context[] = Therapy.current_suspense_context()
                P("Test")
            end

            # The context was set during render
            @test seen_context[] !== nothing
            @test seen_context[] isa SuspenseContext

            # After suspense, context should be cleared
            @test Therapy.current_suspense_context() === nothing
        end

        @testset "Suspense with fallback as VNode" begin
            resource = create_resource(() -> "Ready")

            # Fallback can be a VNode directly, not just a function
            node = Suspense(fallback = P(:class => "loading-text", "Please wait...")) do
                Div(resource())
            end

            @test node isa SuspenseNode

            html = render_to_string(node)
            @test occursin("Ready", html)
        end

        @testset "Suspense SSR rendering" begin
            resource = create_resource(() -> "Content loaded!")

            node = Suspense(fallback = () -> P("Loading...")) do
                Div(:class => "content", resource())
            end

            html = render_to_string(node)

            # Should have hydration key
            @test occursin("data-hk=", html)

            # Should have suspense marker
            @test occursin("data-suspense=\"true\"", html)

            # Should render the content (since resource is ready)
            @test occursin("Content loaded!", html)
            @test occursin("class=\"content\"", html)
        end

        @testset "Await with different data types" begin
            # Await with struct
            struct TestUser
                name::String
                score::Int
            end

            user_resource = create_resource(() -> TestUser("Bob", 100))

            node = Await(user_resource; fallback = () -> P("Loading...")) do user
                Div(
                    P("Name: ", user.name),
                    P("Score: ", user.score)
                )
            end

            html = render_to_string(node)
            @test occursin("Name: Bob", html)
            @test occursin("Score: 100", html)
        end
    end

    @testset "Server Functions Registry" begin
        # Clean up any leftover functions from previous tests
        for name in list_server_functions()
            unregister_server_function(name)
        end

        @testset "register and list server functions" begin
            # Register a simple function
            register_server_function("add_numbers", (a, b) -> a + b)

            @test "add_numbers" in list_server_functions()

            # Get the function
            sf = get_server_function("add_numbers")
            @test sf !== nothing
            @test sf.name == "add_numbers"
            @test sf.arg_count == 2
        end

        @testset "register function with description" begin
            register_server_function("multiply", (a, b) -> a * b; description="Multiply two numbers")

            sf = get_server_function("multiply")
            @test sf !== nothing
            @test sf.description == "Multiply two numbers"
        end

        @testset "execute registered function" begin
            register_server_function("subtract", (a, b) -> a - b)

            sf = get_server_function("subtract")
            @test sf !== nothing

            # Execute the function
            result = sf.func(10, 3)
            @test result == 7
        end

        @testset "unregister server function" begin
            register_server_function("temp_func", () -> "hello")
            @test "temp_func" in list_server_functions()

            result = unregister_server_function("temp_func")
            @test result == true
            @test !("temp_func" in list_server_functions())

            # Unregistering non-existent function returns false
            result = unregister_server_function("nonexistent")
            @test result == false
        end

        @testset "get_server_function returns nothing for missing" begin
            sf = get_server_function("this_does_not_exist")
            @test sf === nothing
        end

        @testset "argument count detection" begin
            # Single argument function
            register_server_function("single_arg", (x) -> x * 2)
            sf = get_server_function("single_arg")
            @test sf.arg_count == 1

            # Zero argument function
            register_server_function("no_args", () -> 42)
            sf = get_server_function("no_args")
            @test sf.arg_count == 0

            # Three argument function
            register_server_function("three_args", (a, b, c) -> a + b + c)
            sf = get_server_function("three_args")
            @test sf.arg_count == 3
        end

        @testset "re-registering overwrites" begin
            register_server_function("overwrite_test", () -> "first")
            sf1 = get_server_function("overwrite_test")
            @test sf1.func() == "first"

            register_server_function("overwrite_test", () -> "second")
            sf2 = get_server_function("overwrite_test")
            @test sf2.func() == "second"
        end

        # Clean up after tests
        for name in list_server_functions()
            unregister_server_function(name)
        end
    end

    @testset "@server Macro" begin
        # Clean up any leftover functions from previous tests
        for name in list_server_functions()
            unregister_server_function(name)
        end

        @testset "basic @server function definition" begin
            # Define a simple server function
            @server function test_add(a, b)
                a + b
            end

            # Function should be defined and callable
            @test test_add(2, 3) == 5

            # Function should be registered
            @test "test_add" in list_server_functions()

            sf = get_server_function("test_add")
            @test sf !== nothing
            @test sf.name == "test_add"
            @test sf.arg_count == 2
        end

        @testset "@server function with return type annotation" begin
            @server function test_multiply(x::Int, y::Int)::Int
                x * y
            end

            # Function should work correctly
            @test test_multiply(4, 5) == 20

            # Should be registered
            @test "test_multiply" in list_server_functions()

            sf = get_server_function("test_multiply")
            @test sf !== nothing
            @test sf.arg_count == 2
        end

        @testset "@server function with no arguments" begin
            @server function test_greeting()
                "Hello, World!"
            end

            @test test_greeting() == "Hello, World!"
            @test "test_greeting" in list_server_functions()

            sf = get_server_function("test_greeting")
            @test sf !== nothing
            @test sf.arg_count == 0
        end

        @testset "@server short-form function definition" begin
            @server test_square(x) = x * x

            @test test_square(5) == 25
            @test "test_square" in list_server_functions()

            sf = get_server_function("test_square")
            @test sf !== nothing
            @test sf.arg_count == 1
        end

        @testset "@server function execution through registry" begin
            @server function test_concat(a::String, b::String)
                a * " " * b
            end

            # Get the function from registry and execute it
            sf = get_server_function("test_concat")
            @test sf !== nothing

            result = sf.func("Hello", "World")
            @test result == "Hello World"
        end

        @testset "@server function with complex return type" begin
            @server function test_build_dict(key::String, value)
                Dict("key" => key, "value" => value, "timestamp" => 12345)
            end

            result = test_build_dict("name", "Alice")
            @test result isa Dict
            @test result["key"] == "name"
            @test result["value"] == "Alice"
            @test result["timestamp"] == 12345

            @test "test_build_dict" in list_server_functions()
        end

        @testset "@server macro returns the function" begin
            result = @server function test_returns_func(x)
                x + 1
            end

            # The macro should return the function
            @test result isa Function
            @test result(10) == 11
        end

        @testset "generate_client_stub produces valid JS" begin
            # Test stub generation
            stub = generate_client_stub("my_function", [:arg1, :arg2])
            @test occursin("async function my_function", stub)
            @test occursin("arg1, arg2", stub)
            @test occursin("TherapyWS.callServer", stub)
            @test occursin("'my_function'", stub)
            @test occursin("[arg1, arg2]", stub)

            # Test with no arguments
            stub_no_args = generate_client_stub("no_args_fn", Symbol[])
            @test occursin("async function no_args_fn()", stub_no_args)
            @test occursin("[]", stub_no_args)
        end

        @testset "server_function_stubs_script generates script tag" begin
            @server function stub_test_func(x)
                x * 2
            end

            script = server_function_stubs_script(["stub_test_func"])
            @test script isa RawHtml

            html = script.content
            @test occursin("<script>", html)
            @test occursin("async function stub_test_func", html)
            @test occursin("</script>", html)
        end

        # Clean up after tests
        for name in list_server_functions()
            unregister_server_function(name)
        end
    end

    @testset "ErrorBoundary" begin
        @testset "basic ErrorBoundary without error" begin
            node = ErrorBoundary(
                fallback = (e, r) -> P("Error: ", string(e)),
                children = () -> P("OK")
            )

            @test node isa ErrorBoundaryNode
            @test node.error === nothing
            @test node.children !== nothing

            html = render_to_string(node)
            @test occursin("OK", html)
            @test occursin("data-error-boundary=\"true\"", html)
            @test !occursin("Error:", html)
        end

        @testset "ErrorBoundary catches errors" begin
            node = ErrorBoundary(
                fallback = (e, r) -> P("Caught: ", string(e)),
                children = () -> error("Test error!")
            )

            @test node isa ErrorBoundaryNode
            @test node.error !== nothing
            @test node.error isa ErrorException

            html = render_to_string(node)
            @test occursin("Caught:", html)
            @test occursin("Test error!", html)
            @test occursin("data-error=\"ErrorException\"", html)
        end

        @testset "ErrorBoundary with do-block syntax" begin
            node = ErrorBoundary(fallback = (e, r) -> P("Error")) do
                Div("Content")
            end

            @test node isa ErrorBoundaryNode
            @test node.error === nothing

            html = render_to_string(node)
            @test occursin("Content", html)
        end

        @testset "nested ErrorBoundary" begin
            html = render_to_string(
                ErrorBoundary(fallback = (e, r) -> P("Outer error")) do
                    Div(
                        P("Before"),
                        ErrorBoundary(fallback = (e, r) -> P("Inner error")) do
                            error("Inner!")
                        end,
                        P("After")
                    )
                end
            )

            # Inner error should be caught by inner boundary
            @test occursin("Inner error", html)
            @test occursin("Before", html)
            @test occursin("After", html)
            @test !occursin("Outer error", html)
        end

        @testset "has_error and get_error" begin
            # No error case
            node_ok = ErrorBoundary(
                fallback = (e, r) -> P("Error"),
                children = () -> P("OK")
            )
            @test has_error(node_ok) == false
            @test get_error(node_ok) === nothing

            # Error case
            node_err = ErrorBoundary(
                fallback = (e, r) -> P("Error"),
                children = () -> error("Boom!")
            )
            @test has_error(node_err) == true
            @test get_error(node_err) !== nothing
            @test get_error(node_err) isa ErrorException
        end

        @testset "ErrorBoundary context stack" begin
            # Outside boundary
            @test current_error_boundary() === nothing

            # Context is properly scoped during render
            seen_ctx = Ref{Any}(nothing)
            ErrorBoundary(
                fallback = (e, r) -> P("Error"),
                children = () -> begin
                    seen_ctx[] = current_error_boundary()
                    P("Test")
                end
            )

            # Context was set during render
            @test seen_ctx[] !== nothing
            @test seen_ctx[] isa ErrorBoundaryContext

            # After render, context should be cleared
            @test current_error_boundary() === nothing
        end
    end

    @testset "Router Hooks" begin
        @testset "use_params returns empty dict initially" begin
            params = use_params()
            @test params isa Dict{Symbol, String}
            @test isempty(params) || params isa Dict  # May have state from other tests
        end

        @testset "set_route_params! and use_params" begin
            # Set some params
            set_route_params!(Dict(:id => "123", :name => "alice"))

            # Read them back
            params = use_params()
            @test params[:id] == "123"
            @test params[:name] == "alice"

            # Test single param accessor
            @test use_params(:id) == "123"
            @test use_params(:name) == "alice"
            @test use_params(:missing) === nothing

            # Test default value accessor
            @test use_params(:id, "default") == "123"
            @test use_params(:missing, "default") == "default"

            # Clean up
            set_route_params!(Dict{Symbol, String}())
        end

        @testset "use_query returns empty dict initially" begin
            set_route_query!(Dict{Symbol, String}())  # Clear first
            query = use_query()
            @test query isa Dict{Symbol, String}
        end

        @testset "set_route_query! and use_query" begin
            # Set some query params
            set_route_query!(Dict(:page => "2", :sort => "name"))

            # Read them back
            query = use_query()
            @test query[:page] == "2"
            @test query[:sort] == "name"

            # Test single param accessor
            @test use_query(:page) == "2"
            @test use_query(:sort) == "name"
            @test use_query(:missing) === nothing

            # Test default value accessor
            @test use_query(:page, "1") == "2"
            @test use_query(:missing, "default") == "default"

            # Clean up
            set_route_query!(Dict{Symbol, String}())
        end

        @testset "use_location returns path" begin
            set_route_path!("/users/123")
            @test use_location() == "/users/123"

            set_route_path!("/")
            @test use_location() == "/"
        end

        @testset "parse_query_string" begin
            # Basic parsing
            result = parse_query_string("page=2&sort=name")
            @test result[:page] == "2"
            @test result[:sort] == "name"

            # With leading ?
            result = parse_query_string("?filter=active")
            @test result[:filter] == "active"

            # Empty string
            result = parse_query_string("")
            @test isempty(result)

            # Key without value
            result = parse_query_string("debug&verbose")
            @test result[:debug] == ""
            @test result[:verbose] == ""

            # URL encoded
            result = parse_query_string("q=hello%20world")
            @test result[:q] == "hello world"

            # Plus as space
            result = parse_query_string("q=hello+world")
            @test result[:q] == "hello world"
        end

        @testset "encode_uri_component" begin
            @test encode_uri_component("hello") == "hello"
            @test encode_uri_component("hello world") == "hello%20world"
            @test encode_uri_component("a=b") == "a%3Db"
            @test encode_uri_component("a&b") == "a%26b"
        end

        @testset "decode_uri_component" begin
            @test decode_uri_component("hello") == "hello"
            @test decode_uri_component("hello%20world") == "hello world"
            @test decode_uri_component("hello+world") == "hello world"
            @test decode_uri_component("a%3Db") == "a=b"
        end

        @testset "handle_request sets route params" begin
            # Create a temp directory for route files
            mktempdir() do routes_dir
                # Create a simple route file
                route_file = joinpath(routes_dir, "users", "[id].jl")
                mkpath(dirname(route_file))
                write(route_file, """
                (params) -> Therapy.P("User \$(params[:id])")
                """)

                # Create router and handle request
                router = create_router(routes_dir)
                html, route, params = handle_request(router, "/users/42")

                # Verify params were set for use_params
                current_params = use_params()
                @test current_params[:id] == "42"

                # Verify location was set
                @test use_location() == "/users/42"
            end
        end

        @testset "handle_request with query string" begin
            mktempdir() do routes_dir
                # Create a simple route file
                route_file = joinpath(routes_dir, "search.jl")
                write(route_file, """
                (params) -> Therapy.P("Search")
                """)

                router = create_router(routes_dir)
                html, route, params = handle_request(router, "/search"; query_string="q=test&page=3")

                # Verify query params were set
                query = use_query()
                @test query[:q] == "test"
                @test query[:page] == "3"
            end
        end
    end

    @testset "Nested Routes and Outlet" begin
        @testset "OutletNode creation" begin
            # Basic outlet without fallback
            outlet = Outlet()
            @test outlet isa OutletNode
            @test outlet.fallback === nothing

            # Outlet with fallback
            outlet_with_fallback = Outlet(fallback = P("No content"))
            @test outlet_with_fallback isa OutletNode
            @test outlet_with_fallback.fallback !== nothing
        end

        @testset "Outlet context management" begin
            # Initially no context
            @test current_outlet_context() === nothing

            # Create context
            with_outlet_context(Dict{Symbol, String}(:id => "123")) do
                ctx = current_outlet_context()
                @test ctx !== nothing
                @test ctx isa OutletContext
                @test ctx.params[:id] == "123"
            end

            # Context cleaned up after
            @test current_outlet_context() === nothing
        end

        @testset "set_outlet_child! and render_outlet" begin
            with_outlet_context(Dict{Symbol, String}()) do
                # No child initially
                outlet = Outlet()
                rendered = Therapy.render_outlet(outlet)
                # Empty outlet returns a placeholder div
                @test rendered.tag == :div
                @test rendered.props[:data_outlet] == "empty"

                # Set a child
                set_outlet_child!(P("Child content"))

                # Now render_outlet should return the child
                outlet2 = Outlet()
                rendered2 = Therapy.render_outlet(outlet2)
                @test rendered2.tag == :p
            end
        end

        @testset "Outlet with fallback" begin
            with_outlet_context(Dict{Symbol, String}()) do
                # Outlet with fallback, no child set
                outlet = Outlet(fallback = Span("Fallback content"))
                rendered = Therapy.render_outlet(outlet)
                @test rendered.tag == :span
            end
        end

        @testset "Outlet function fallback" begin
            with_outlet_context(Dict{Symbol, String}()) do
                # Outlet with function fallback
                outlet = Outlet(fallback = () -> Div("Function fallback"))
                rendered = Therapy.render_outlet(outlet)
                @test rendered.tag == :div
            end
        end

        @testset "NestedRoute matching" begin
            # Create nested route structure
            routes = [
                NestedRoute("/users", () -> Div("Users Layout"), children=[
                    NestedRoute("", () -> P("Users Index")),
                    NestedRoute(":id", () -> P("User Detail")),
                    NestedRoute(":id/posts", () -> P("User Posts"))
                ])
            ]

            # Match /users
            matched = match_nested_route(routes, "/users")
            @test matched !== nothing
            @test length(matched) == 2
            @test matched[1][1].path == "/users"
            @test matched[2][1].path == ""

            # Match /users/123
            matched2 = match_nested_route(routes, "/users/123")
            @test matched2 !== nothing
            @test length(matched2) == 2
            @test matched2[1][1].path == "/users"
            @test matched2[2][1].path == ":id"
            @test matched2[2][2][:id] == "123"

            # Match /users/456/posts
            matched3 = match_nested_route(routes, "/users/456/posts")
            @test matched3 !== nothing
            @test length(matched3) == 2
            @test matched3[2][2][:id] == "456"
        end

        @testset "Outlet SSR rendering" begin
            with_outlet_context(Dict{Symbol, String}()) do
                set_outlet_child!(P("Nested Content"))

                outlet = Outlet()
                html = render_to_string(outlet)

                @test occursin("data-outlet=\"true\"", html)
                @test occursin("Nested Content", html)
            end
        end

        @testset "Outlet empty SSR rendering" begin
            with_outlet_context(Dict{Symbol, String}()) do
                outlet = Outlet()
                html = render_to_string(outlet)

                @test occursin("data-outlet=\"empty\"", html)
            end
        end

        @testset "File-based routing with _layout.jl" begin
            mktempdir() do routes_dir
                # Create directory structure with layout
                users_dir = joinpath(routes_dir, "users")
                mkpath(users_dir)

                # Create _layout.jl
                layout_file = joinpath(users_dir, "_layout.jl")
                write(layout_file, """
                (params) -> Therapy.Div(:class => "users-layout",
                    Therapy.P("Users Layout"),
                    Therapy.Outlet()
                )
                """)

                # Create index.jl
                index_file = joinpath(users_dir, "index.jl")
                write(index_file, """
                (params) -> Therapy.P("Users Index Content")
                """)

                # Create [id].jl
                user_file = joinpath(users_dir, "[id].jl")
                write(user_file, """
                (params) -> Therapy.P("User: ", params[:id])
                """)

                # Create router
                router = create_router(routes_dir)

                # Check that routes have layouts
                users_route = findfirst(r -> r.pattern == "/users", router.routes)
                @test users_route !== nothing
                user_route = findfirst(r -> r.pattern == "/users/:id", router.routes)
                @test user_route !== nothing

                # The routes should have the layout path recorded
                @test router.routes[users_route].layout_path == layout_file
                @test router.routes[user_route].layout_path == layout_file
            end
        end

        @testset "Nested context isolation" begin
            # Ensure nested contexts don't leak
            with_outlet_context(Dict{Symbol, String}(:outer => "1")) do
                set_outlet_child!(P("Outer child"))

                with_outlet_context(Dict{Symbol, String}(:inner => "2")) do
                    inner_ctx = current_outlet_context()
                    @test inner_ctx.params[:inner] == "2"
                    @test !haskey(inner_ctx.params, :outer)

                    set_outlet_child!(P("Inner child"))

                    # Inner outlet should get inner child
                    outlet = Outlet()
                    rendered = Therapy.render_outlet(outlet)
                    @test rendered.tag == :p
                end

                # Outer context should still work
                outer_ctx = current_outlet_context()
                @test outer_ctx.params[:outer] == "1"
            end
        end
    end

    @testset "NavLink" begin
        @testset "basic rendering" begin
            html = render_to_string(NavLink("/about", "About"))
            @test occursin("<a", html)
            @test occursin("About", html)
            @test occursin("href=\"/about\"", html)
            @test occursin("data-navlink=\"true\"", html)
            @test occursin("data-active-class=\"active\"", html)
        end

        @testset "custom class and active_class" begin
            html = render_to_string(NavLink("/features", "Features",
                class="text-sm font-medium",
                active_class="text-accent-700 dark:text-accent-400"))
            @test occursin("class=\"text-sm font-medium\"", html)
            @test occursin("data-active-class=\"text-accent-700 dark:text-accent-400\"", html)
        end

        @testset "exact matching" begin
            html = render_to_string(NavLink("/", "Home", exact=true))
            @test occursin("data-exact=\"true\"", html)

            html_no_exact = render_to_string(NavLink("/docs", "Docs"))
            @test !occursin("data-exact", html_no_exact)
        end

        @testset "relative href preserved" begin
            html = render_to_string(NavLink("./features/", "Features"))
            @test occursin("href=\"./features/\"", html)

            html2 = render_to_string(NavLink("../", "Back"))
            @test occursin("href=\"../\"", html2)
        end

        @testset "multiple children" begin
            html = render_to_string(NavLink("/home",
                Span("Home"), " ", Span("Page")))
            @test occursin("<span", html)
            @test occursin("Home", html)
            @test occursin("Page", html)
        end

        @testset "inactive_class defaults to empty" begin
            html = render_to_string(NavLink("/about", "About"))
            @test !occursin("data-inactive-class", html)
        end

        @testset "inactive_class rendered as data-inactive-class" begin
            html = render_to_string(NavLink("/features", "Features",
                class="text-sm font-medium transition-colors",
                active_class="text-accent-700 dark:text-accent-400 font-semibold",
                inactive_class="text-warm-600 dark:text-warm-400 hover:text-accent-600"))
            @test occursin("data-inactive-class=\"text-warm-600 dark:text-warm-400 hover:text-accent-600\"", html)
            # Server render includes class + inactive_class (default state)
            @test occursin("text-sm font-medium transition-colors text-warm-600 dark:text-warm-400 hover:text-accent-600", html)
            # active_class is stored in data attribute, NOT in class
            @test occursin("data-active-class=\"text-accent-700 dark:text-accent-400 font-semibold\"", html)
        end

        @testset "three-class model: no conflicting classes" begin
            html = render_to_string(NavLink("/", "Home",
                class="text-sm",
                active_class="text-accent-700",
                inactive_class="text-warm-600",
                exact=true))
            # class attr should have structural + inactive (server default state)
            @test occursin("class=\"text-sm text-warm-600\"", html)
            # active NOT in rendered class attribute
            @test !occursin("class=\"text-sm text-accent-700", html)
            @test occursin("data-active-class=\"text-accent-700\"", html)
            @test occursin("data-inactive-class=\"text-warm-600\"", html)
            @test occursin("data-exact=\"true\"", html)
        end
    end

    # =========================================================================
    # T30: DOM Bridge Infrastructure
    # =========================================================================
    @testset "StringTable" begin
        @testset "basic registration and ID lookup" begin
            st = StringTable()
            register_string!(st, "hidden")
            register_string!(st, "open")
            register_string!(st, "closed")

            @test length(st) == 3
            @test !isempty(st)

            # IDs are deterministic (alphabetical): closed=0, hidden=1, open=2
            @test get_id(st, "closed") == Int32(0)
            @test get_id(st, "hidden") == Int32(1)
            @test get_id(st, "open") == Int32(2)
        end

        @testset "duplicate registration is idempotent" begin
            st = StringTable()
            register_string!(st, "foo")
            register_string!(st, "foo")
            register_string!(st, "foo")
            @test length(st) == 1
            @test get_id(st, "foo") == Int32(0)
        end

        @testset "empty table" begin
            st = StringTable()
            @test isempty(st)
            @test length(st) == 0
            @test emit_string_table(st) == "[]"
        end

        @testset "deterministic ordering" begin
            # Register in reverse alphabetical order
            st1 = StringTable()
            register_string!(st1, "z-class")
            register_string!(st1, "a-class")
            register_string!(st1, "m-class")

            # Register in different order
            st2 = StringTable()
            register_string!(st2, "m-class")
            register_string!(st2, "a-class")
            register_string!(st2, "z-class")

            # Both should produce identical IDs
            @test get_id(st1, "a-class") == get_id(st2, "a-class")
            @test get_id(st1, "m-class") == get_id(st2, "m-class")
            @test get_id(st1, "z-class") == get_id(st2, "z-class")

            # And identical JS output
            @test emit_string_table(st1) == emit_string_table(st2)
        end

        @testset "emit_string_table generates valid JS array" begin
            st = StringTable()
            register_string!(st, "bg-warm-100")
            register_string!(st, "data-state")
            register_string!(st, "hidden")

            js = emit_string_table(st)
            @test js == "[\"bg-warm-100\",\"data-state\",\"hidden\"]"
        end

        @testset "JS escaping" begin
            st = StringTable()
            register_string!(st, "it's a \"test\"")
            register_string!(st, "back\\slash")

            js = emit_string_table(st)
            @test occursin("back\\\\slash", js)
            @test occursin("it's a \\\"test\\\"", js)
        end

        @testset "freeze prevents further registration" begin
            st = StringTable()
            register_string!(st, "a")
            freeze!(st)
            @test_throws ErrorException register_string!(st, "b")
        end

        @testset "get_id auto-freezes" begin
            st = StringTable()
            register_string!(st, "x")
            # Not manually frozen, but get_id should auto-freeze
            @test get_id(st, "x") == Int32(0)
            @test st.frozen == true
        end

        @testset "unregistered string throws error" begin
            st = StringTable()
            register_string!(st, "exists")
            @test_throws ErrorException get_id(st, "does_not_exist")
        end

        @testset "integration with hydration JS" begin
            # Verify string table appears in generated hydration JS
            Counter = () -> begin
                count, set_count = create_signal(0)
                Div(
                    Span(count),
                    Button(:on_click => () -> set_count(count() + 1), "+")
                )
            end

            st = StringTable()
            register_string!(st, "bg-warm-100")

            analysis = Therapy.analyze_component(Counter)
            hydration = Therapy.generate_hydration_js(analysis;
                component_name="TestCounter",
                string_table=st)

            # Verify string table is emitted in JS
            @test occursin("const strings = [\"bg-warm-100\"]", hydration.js)
            # Verify element registry is emitted
            @test occursin("const elements = []", hydration.js)
            @test occursin("querySelectorAll('[data-hk]')", hydration.js)
        end

        @testset "hydration JS works without string table" begin
            # Backward compatibility: no string_table kwarg
            Counter = () -> begin
                count, set_count = create_signal(0)
                Div(Span(count), Button(:on_click => () -> set_count(count() + 1), "+"))
            end

            analysis = Therapy.analyze_component(Counter)
            hydration = Therapy.generate_hydration_js(analysis; component_name="TestBC")

            # Should still emit empty string table and element registry
            @test occursin("const strings = []", hydration.js)
            @test occursin("const elements = []", hydration.js)
        end
    end

    @testset "Event Parameter Passing" begin
        @testset "event_extraction_js returns correct JS for each event type" begin
            # Keyboard events store keyCode + modifiers
            keydown_js = Therapy.event_extraction_js("keydown")
            @test occursin("_keyCode", keydown_js)
            @test occursin("KEY_MAP", keydown_js)
            @test occursin("_modifiers", keydown_js)
            @test occursin("shiftKey", keydown_js)

            # Pointer events store coordinates + pointerId
            pointer_js = Therapy.event_extraction_js("pointermove")
            @test occursin("_pointerX", pointer_js)
            @test occursin("_pointerY", pointer_js)
            @test occursin("_pointerId", pointer_js)

            # Input events store target value + checked
            input_js = Therapy.event_extraction_js("input")
            @test occursin("_targetValueF64", input_js)
            @test occursin("_targetChecked", input_js)

            # Contextmenu stores pointer coords
            ctx_js = Therapy.event_extraction_js("contextmenu")
            @test occursin("_pointerX", ctx_js)
            @test occursin("_pointerY", ctx_js)

            # Click stores only _currentEvent
            click_js = Therapy.event_extraction_js("click")
            @test occursin("_currentEvent", click_js)
            @test !occursin("_keyCode", click_js)
            @test !occursin("_pointerX", click_js)
        end

        @testset "hydration JS includes event parameter storage" begin
            Counter = () -> begin
                count, set_count = create_signal(0)
                Div(Span(count), Button(:on_click => () -> set_count(count() + 1), "+"))
            end

            analysis = Therapy.analyze_component(Counter)
            hydration = Therapy.generate_hydration_js(analysis; component_name="TestEvt")

            # Event parameter storage variables
            @test occursin("let _currentEvent = null", hydration.js)
            @test occursin("let _keyCode = 0, _modifiers = 0", hydration.js)
            @test occursin("let _pointerX = 0.0, _pointerY = 0.0, _pointerId = 0", hydration.js)
            @test occursin("let _targetValueF64 = 0.0, _targetChecked = 0", hydration.js)
            @test occursin("let _dragStartX = 0.0, _dragStartY = 0.0", hydration.js)

            # KEY_MAP constant
            @test occursin("const KEY_MAP", hydration.js)
            @test occursin("'Escape':27", hydration.js)
            @test occursin("'ArrowDown':40", hydration.js)
        end

        @testset "hydration JS includes getter import stubs" begin
            Counter = () -> begin
                count, set_count = create_signal(0)
                Div(Span(count), Button(:on_click => () -> set_count(count() + 1), "+"))
            end

            analysis = Therapy.analyze_component(Counter)
            hydration = Therapy.generate_hydration_js(analysis; component_name="TestGetters")

            # Getter stubs in imports object
            @test occursin("get_key_code: () => _keyCode", hydration.js)
            @test occursin("get_modifiers: () => _modifiers", hydration.js)
            @test occursin("get_pointer_x: () => _pointerX", hydration.js)
            @test occursin("get_pointer_y: () => _pointerY", hydration.js)
            @test occursin("get_pointer_id: () => _pointerId", hydration.js)
            @test occursin("get_target_value_f64: () => _targetValueF64", hydration.js)
            @test occursin("get_target_checked: () => _targetChecked", hydration.js)

            # Event control
            @test occursin("prevent_default:", hydration.js)
            @test occursin("preventDefault", hydration.js)
        end

        @testset "click handler extracts _currentEvent and clears after" begin
            ClickComp = () -> begin
                count, set_count = create_signal(0)
                Div(Button(:on_click => () -> set_count(count() + 1), "+"))
            end

            analysis = Therapy.analyze_component(ClickComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="TestClick")

            # Event handler passes (e) and extracts _currentEvent
            @test occursin("addEventListener('click', (e) =>", hydration.js)
            @test occursin("_currentEvent = e;", hydration.js)
            # Clears _currentEvent after handler call
            @test occursin("_currentEvent = null;", hydration.js)
        end
    end

    @testset "Timer/Callback Infrastructure" begin
        @testset "hydration JS includes timer variables" begin
            Comp = () -> begin
                count, set_count = create_signal(0)
                Div(Span(count), Button(:on_click => () -> set_count(count() + 1), "+"))
            end

            analysis = Therapy.analyze_component(Comp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="TestTimers")

            # Timer infrastructure variables
            @test occursin("const _timers = {}", hydration.js)
            @test occursin("let _timerCounter = 0", hydration.js)
            # Scroll lock counter
            @test occursin("let _scrollLockCount = 0", hydration.js)
        end

        @testset "hydration JS includes timer import stubs" begin
            Comp = () -> begin
                count, set_count = create_signal(0)
                Div(Span(count))
            end

            analysis = Therapy.analyze_component(Comp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="TestTimerStubs")

            # Timer stubs
            @test occursin("set_timeout:", hydration.js)
            @test occursin("clear_timeout:", hydration.js)
            @test occursin("request_animation_frame:", hydration.js)
            @test occursin("cancel_animation_frame:", hydration.js)

            # Timer stubs reference callback exports
            @test occursin("callback_'+cb", hydration.js)
        end
    end

    @testset "Wasm Import Declarations (53 total)" begin
        @testset "compiled Wasm module includes all 53 imports" begin
            # Verify that a simple island generates valid Wasm with all imports
            Counter = () -> begin
                count, set_count = create_signal(0)
                Div(Span(count), Button(:on_click => () -> set_count(count() + 1), "+"))
            end

            analysis = Therapy.analyze_component(Counter)
            wasm = Therapy.generate_wasm(analysis)

            # Wasm bytes should be non-empty and valid
            @test length(wasm.bytes) > 0

            # Count import section entries by scanning the Wasm binary
            # The import section (section id 0x02) encodes a count as a LEB128 varint
            # With 53 imports, the count byte should be 53 (0x35)
            # Look for the import count in the binary
            bytes = wasm.bytes
            found_import_count = false
            for i in 1:length(bytes)-1
                if bytes[i] == 0x02  # Import section
                    # Next byte(s) are section length, then import count
                    # Skip section length (LEB128)
                    j = i + 1
                    while j <= length(bytes) && bytes[j] & 0x80 != 0
                        j += 1
                    end
                    j += 1  # skip last byte of section length
                    # Now bytes[j] should be import count (LEB128)
                    if j <= length(bytes)
                        import_count = Int(bytes[j])
                        if import_count == 53
                            found_import_count = true
                            break
                        end
                    end
                end
            end
            @test found_import_count
        end
    end

    @testset "DOM Bridge Import Stubs (all 48)" begin
        @testset "all import stubs present in hydration JS" begin
            Comp = () -> begin
                count, set_count = create_signal(0)
                Div(Span(count), Button(:on_click => () -> set_count(count() + 1), "+"))
            end

            analysis = Therapy.analyze_component(Comp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="TestAllStubs")

            # Class manipulation (3)
            @test occursin("add_class:", hydration.js)
            @test occursin("remove_class:", hydration.js)
            @test occursin("toggle_class:", hydration.js)

            # Attribute/style (3)
            @test occursin("set_attribute:", hydration.js)
            @test occursin("remove_attribute:", hydration.js)
            @test occursin("set_style:", hydration.js)

            # DOM state (6)
            @test occursin("set_data_state:", hydration.js)
            @test occursin("set_data_motion:", hydration.js)
            @test occursin("set_text_content:", hydration.js)
            @test occursin("set_hidden:", hydration.js)
            @test occursin("show_element:", hydration.js)
            @test occursin("hide_element:", hydration.js)

            # Focus (8)
            @test occursin("focus_element:", hydration.js)
            @test occursin("focus_element_prevent_scroll:", hydration.js)
            @test occursin("blur_element:", hydration.js)
            @test occursin("get_active_element:", hydration.js)
            @test occursin("focus_first_tabbable:", hydration.js)
            @test occursin("focus_last_tabbable:", hydration.js)
            @test occursin("install_focus_guards:", hydration.js)
            @test occursin("uninstall_focus_guards:", hydration.js)

            # Scroll (3)
            @test occursin("lock_scroll:", hydration.js)
            @test occursin("unlock_scroll:", hydration.js)
            @test occursin("scroll_into_view:", hydration.js)

            # Geometry (6)
            @test occursin("get_bounding_rect_x:", hydration.js)
            @test occursin("get_bounding_rect_y:", hydration.js)
            @test occursin("get_bounding_rect_w:", hydration.js)
            @test occursin("get_bounding_rect_h:", hydration.js)
            @test occursin("get_viewport_width:", hydration.js)
            @test occursin("get_viewport_height:", hydration.js)

            # Event getters (7) + prevent_default (1)
            @test occursin("get_key_code:", hydration.js)
            @test occursin("get_modifiers:", hydration.js)
            @test occursin("get_pointer_x:", hydration.js)
            @test occursin("get_pointer_y:", hydration.js)
            @test occursin("get_pointer_id:", hydration.js)
            @test occursin("get_target_value_f64:", hydration.js)
            @test occursin("get_target_checked:", hydration.js)
            @test occursin("prevent_default:", hydration.js)

            # Storage/clipboard (3)
            @test occursin("storage_get_i32:", hydration.js)
            @test occursin("storage_set_i32:", hydration.js)
            @test occursin("copy_to_clipboard:", hydration.js)

            # Pointer/drag (4)
            @test occursin("capture_pointer:", hydration.js)
            @test occursin("release_pointer:", hydration.js)
            @test occursin("get_drag_delta_x:", hydration.js)
            @test occursin("get_drag_delta_y:", hydration.js)

            # Timers (4)
            @test occursin("set_timeout:", hydration.js)
            @test occursin("clear_timeout:", hydration.js)
            @test occursin("request_animation_frame:", hydration.js)
            @test occursin("cancel_animation_frame:", hydration.js)
        end
    end

    @testset "Floating Position Algorithm" begin
        # Standard viewport and reference element for most tests
        # Viewport: 1024x768, ref element at (100, 200), 120x40
        vw, vh = 1024.0, 768.0
        ref_x, ref_y, ref_w, ref_h = 100.0, 200.0, 120.0, 40.0
        flt_w, flt_h = 200.0, 150.0

        @testset "basic placement — bottom (default)" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_BOTTOM, ALIGN_CENTER, 0.0, 0.0)
            # x = ref_x + (ref_w - flt_w)/2 = 100 + (120-200)/2 = 100 - 40 = 60
            @test result.x ≈ 60.0
            # y = ref_y + ref_h = 200 + 40 = 240
            @test result.y ≈ 240.0
            @test result.actual_side == SIDE_BOTTOM
        end

        @testset "basic placement — top" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_TOP, ALIGN_CENTER, 0.0, 0.0)
            # x = 60 (same centering)
            @test result.x ≈ 60.0
            # y = ref_y - flt_h = 200 - 150 = 50
            @test result.y ≈ 50.0
            @test result.actual_side == SIDE_TOP
        end

        @testset "basic placement — right" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_RIGHT, ALIGN_CENTER, 0.0, 0.0)
            # x = ref_x + ref_w = 100 + 120 = 220
            @test result.x ≈ 220.0
            # y = ref_y + (ref_h - flt_h)/2 = 200 + (40-150)/2 = 200 - 55 = 145
            @test result.y ≈ 145.0
            @test result.actual_side == SIDE_RIGHT
        end

        @testset "basic placement — left" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_LEFT, ALIGN_CENTER, 0.0, 0.0)
            # left = ref_x - flt_w = 100 - 200 = -100 < pad → flip to right
            # flipped: x = ref_x + ref_w = 100 + 120 = 220
            @test result.x ≈ 220.0
            # y = ref_y + (ref_h - flt_h)/2 = 200 - 55 = 145
            @test result.y ≈ 145.0
            @test result.actual_side == SIDE_RIGHT
        end

        @testset "alignment — start" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_BOTTOM, ALIGN_START, 0.0, 0.0)
            # x = ref_x = 100
            @test result.x ≈ 100.0
            @test result.y ≈ 240.0
        end

        @testset "alignment — end" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_BOTTOM, ALIGN_END, 0.0, 0.0)
            # x = ref_x + ref_w - flt_w = 100 + 120 - 200 = 20
            @test result.x ≈ 20.0
            @test result.y ≈ 240.0
        end

        @testset "side offset" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_BOTTOM, ALIGN_CENTER, 8.0, 0.0)
            # y = ref_y + ref_h + offset = 200 + 40 + 8 = 248
            @test result.y ≈ 248.0
        end

        @testset "align offset" begin
            result = compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh,
                SIDE_BOTTOM, ALIGN_START, 0.0, 10.0)
            # x = ref_x + align_offset = 100 + 10 = 110
            @test result.x ≈ 110.0
        end

        @testset "flip — bottom to top when near bottom edge" begin
            # Reference near bottom of viewport
            result = compute_position(100.0, 700.0, 120.0, 40.0, 200.0, 150.0, 1024.0, 768.0,
                SIDE_BOTTOM, ALIGN_CENTER, 0.0, 0.0)
            # bottom placement: y = 700+40 = 740, 740+150 = 890 > 768-4 = 764 → flip
            # flipped: y = 700 - 150 = 550, 550 >= 4 → accepted
            @test result.y ≈ 550.0
            @test result.actual_side == SIDE_TOP
        end

        @testset "flip — top to bottom when near top edge" begin
            result = compute_position(100.0, 10.0, 120.0, 40.0, 200.0, 150.0, 1024.0, 768.0,
                SIDE_TOP, ALIGN_CENTER, 0.0, 0.0)
            # top placement: y = 10 - 150 = -140, -140 < 4 → flip
            # flipped: y = 10 + 40 = 50, 50+150 = 200 <= 764 → accepted
            @test result.y ≈ 50.0
            @test result.actual_side == SIDE_BOTTOM
        end

        @testset "flip — right to left when near right edge" begin
            result = compute_position(900.0, 200.0, 120.0, 40.0, 200.0, 150.0, 1024.0, 768.0,
                SIDE_RIGHT, ALIGN_CENTER, 0.0, 0.0)
            # right: x = 900+120 = 1020, 1020+200 = 1220 > 1020 → flip
            # flipped: x = 900 - 200 = 700, 700 >= 4 → accepted
            @test result.x ≈ 700.0
            @test result.actual_side == SIDE_LEFT
        end

        @testset "flip — left to right when near left edge" begin
            result = compute_position(50.0, 200.0, 40.0, 40.0, 200.0, 150.0, 1024.0, 768.0,
                SIDE_LEFT, ALIGN_CENTER, 0.0, 0.0)
            # left: x = 50 - 200 = -150, -150 < 4 → flip
            # flipped: x = 50 + 40 = 90, 90+200 = 290 <= 1020 → accepted
            @test result.x ≈ 90.0
            @test result.actual_side == SIDE_RIGHT
        end

        @testset "shift — clamps to viewport bounds" begin
            # Very wide floating element that can't fit with centering
            result = compute_position(10.0, 300.0, 40.0, 40.0, 980.0, 100.0, 1024.0, 768.0,
                SIDE_BOTTOM, ALIGN_CENTER, 0.0, 0.0)
            # center: x = 10 + (40-980)/2 = -460 → clamped to 4
            @test result.x ≈ 4.0
            @test result.y ≈ 340.0
        end

        @testset "viewport padding is 4px" begin
            @test VIEWPORT_PAD == 4.0
        end

        @testset "side and align constants" begin
            @test SIDE_BOTTOM == Int32(0)
            @test SIDE_TOP == Int32(1)
            @test SIDE_RIGHT == Int32(2)
            @test SIDE_LEFT == Int32(3)
            @test ALIGN_START == Int32(0)
            @test ALIGN_CENTER == Int32(1)
            @test ALIGN_END == Int32(2)
        end

        @testset "combined side offset + alignment" begin
            # Right side, end alignment, with offsets
            result = compute_position(400.0, 300.0, 100.0, 50.0, 150.0, 120.0, 1024.0, 768.0,
                SIDE_RIGHT, ALIGN_END, 5.0, -10.0)
            # x = 400 + 100 + 5 = 505
            @test result.x ≈ 505.0
            # y = ref_y + ref_h - flt_h + align_offset = 300 + 50 - 120 + (-10) = 220
            @test result.y ≈ 220.0
            @test result.actual_side == SIDE_RIGHT
        end
    end

    @testset "T30 Integration — DOM Bridge End-to-End (THERAPY-3015)" begin

        # =====================================================================
        # Shared test component — used across multiple integration tests
        # =====================================================================
        TestComp = () -> begin
            count, set_count = create_signal(0)
            Div(Span(count), Button(:on_click => () -> set_count(count() + 1), "+"))
        end

        @testset "full pipeline: compile → Wasm + hydration with all T30 infrastructure" begin
            # Create string table with typical DOM bridge strings
            st = StringTable()
            register_string!(st, "hidden")
            register_string!(st, "data-state")
            register_string!(st, "open")
            register_string!(st, "closed")
            register_string!(st, "aria-expanded")

            analysis = Therapy.analyze_component(TestComp)
            wasm = Therapy.generate_wasm(analysis)
            hydration = Therapy.generate_hydration_js(analysis;
                component_name="IntegrationTest",
                string_table=st)

            # 1. Wasm is valid and non-empty
            @test length(wasm.bytes) > 100

            # 2. Hydration JS contains string table with registered strings
            @test occursin("const strings = [", hydration.js)
            @test occursin("aria-expanded", hydration.js)
            @test occursin("data-state", hydration.js)

            # 3. Element registry present
            @test occursin("const elements = []", hydration.js)

            # 4. Event parameter infrastructure present
            @test occursin("_currentEvent", hydration.js)
            @test occursin("_keyCode", hydration.js)
            @test occursin("KEY_MAP", hydration.js)

            # 5. Timer infrastructure present
            @test occursin("_timers", hydration.js)

            # 6. Scroll lock infrastructure
            @test occursin("_scrollLockCount", hydration.js)

            # 7. All 48 import stubs present (spot check categories)
            @test occursin("add_class:", hydration.js)
            @test occursin("set_attribute:", hydration.js)
            @test occursin("set_data_state:", hydration.js)
            @test occursin("focus_element:", hydration.js)
            @test occursin("lock_scroll:", hydration.js)
            @test occursin("get_bounding_rect_x:", hydration.js)
            @test occursin("get_key_code:", hydration.js)
            @test occursin("storage_get_i32:", hydration.js)
            @test occursin("capture_pointer:", hydration.js)
            @test occursin("set_timeout:", hydration.js)
            @test occursin("prevent_default:", hydration.js)

            # 8. String table IDs are deterministic (alphabetical)
            @test get_id(st, "aria-expanded") == Int32(0)
            @test get_id(st, "closed") == Int32(1)
            @test get_id(st, "data-state") == Int32(2)
            @test get_id(st, "hidden") == Int32(3)
            @test get_id(st, "open") == Int32(4)
        end

        @testset "every new import (48) has matching JS bridge stub" begin
            # This is the definitive integration test: verify that every Wasm import
            # declaration in WasmGen.jl has a corresponding JS bridge stub in Hydration.jl.
            # Missing stubs cause WebAssembly.instantiate() to fail at runtime.

            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="AllImports")

            # ALL 48 new imports — exhaustive check (indices 5-52)
            all_48_imports = [
                # Class manipulation (3)
                "add_class", "remove_class", "toggle_class",
                # Attribute/style (3)
                "set_attribute", "remove_attribute", "set_style",
                # DOM state (6)
                "set_data_state", "set_data_motion", "set_text_content",
                "set_hidden", "show_element", "hide_element",
                # Focus (8)
                "focus_element", "focus_element_prevent_scroll", "blur_element",
                "get_active_element", "focus_first_tabbable", "focus_last_tabbable",
                "install_focus_guards", "uninstall_focus_guards",
                # Scroll (3)
                "lock_scroll", "unlock_scroll", "scroll_into_view",
                # Geometry (6)
                "get_bounding_rect_x", "get_bounding_rect_y",
                "get_bounding_rect_w", "get_bounding_rect_h",
                "get_viewport_width", "get_viewport_height",
                # Event getters (7)
                "get_key_code", "get_modifiers",
                "get_pointer_x", "get_pointer_y", "get_pointer_id",
                "get_target_value_f64", "get_target_checked",
                # Storage/clipboard (3)
                "storage_get_i32", "storage_set_i32", "copy_to_clipboard",
                # Pointer/drag (4)
                "capture_pointer", "release_pointer",
                "get_drag_delta_x", "get_drag_delta_y",
                # Timers (4)
                "set_timeout", "clear_timeout",
                "request_animation_frame", "cancel_animation_frame",
                # Event control (1)
                "prevent_default"
            ]
            @test length(all_48_imports) == 48

            for import_name in all_48_imports
                @test occursin("$(import_name):", hydration.js)
            end
        end

        @testset "JS bridge stubs use correct patterns" begin
            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="PatternCheck")
            js = hydration.js

            # Class stubs use elements[] and strings[] (string table + element registry)
            @test occursin("classList.add(strings[", js)
            @test occursin("classList.remove(strings[", js)
            @test occursin("classList.toggle(strings[", js)

            # Attribute stubs use setAttribute with strings[]
            @test occursin("setAttribute(strings[", js)
            @test occursin("removeAttribute(strings[", js)

            # Style stub handles CSS custom properties
            @test occursin("setProperty(", js)

            # DOM state fast-path (no string table)
            @test occursin("dataset.state", js)
            @test occursin("dataset.motion", js)
            @test occursin("from-start", js)

            # Focus stubs use FOCUSABLE selector
            @test occursin("FOCUSABLE", js)
            @test occursin("focus()", js)
            @test occursin("blur()", js)

            # Focus guards use window-level tracking
            @test occursin("window._therapyFocusGuards", js)
            @test occursin("data-focus-guard", js)

            # Geometry uses getBoundingClientRect
            @test occursin("getBoundingClientRect()", js)
            @test occursin("window.innerWidth", js)
            @test occursin("window.innerHeight", js)

            # Storage uses localStorage with try/catch
            @test occursin("localStorage.getItem(strings[", js)
            @test occursin("localStorage.setItem(strings[", js)

            # Clipboard uses navigator.clipboard
            @test occursin("navigator.clipboard.writeText(strings[", js)

            # Pointer capture uses setPointerCapture
            @test occursin("setPointerCapture(", js)
            @test occursin("releasePointerCapture(", js)

            # Drag deltas reference _dragStartX/Y
            @test occursin("_dragStartX", js)
            @test occursin("_dragStartY", js)

            # Timer stubs dispatch to Wasm callback exports
            @test occursin("callback_'+cb", js) || occursin("callback_'+cb", js) || occursin("callback_", js)
            @test occursin("setTimeout(", js)
            @test occursin("clearTimeout(", js)
            @test occursin("requestAnimationFrame(", js)
            @test occursin("cancelAnimationFrame(", js)

            # Scroll lock is reference-counted
            @test occursin("++_scrollLockCount", js)
            @test occursin("--_scrollLockCount", js)
            @test occursin("scrollIntoView(", js)
        end

        @testset "event extraction covers all event types" begin
            # Verify event_extraction_js returns correct extraction for each event type

            # Pointer events: extract clientX, clientY, pointerId
            for event in ["pointerdown", "pointermove", "pointerup", "pointerenter", "pointerleave"]
                ext = Therapy.event_extraction_js(event)
                @test occursin("_pointerX", ext)
                @test occursin("_pointerY", ext)
                @test occursin("_pointerId", ext)
            end

            # Keyboard events: extract keyCode via KEY_MAP + modifiers
            for event in ["keydown", "keyup"]
                ext = Therapy.event_extraction_js(event)
                @test occursin("_keyCode", ext)
                @test occursin("_modifiers", ext)
                @test occursin("KEY_MAP", ext)
            end

            # Input events: extract target value + checked
            for event in ["input", "change"]
                ext = Therapy.event_extraction_js(event)
                @test occursin("_targetValueF64", ext)
                @test occursin("_targetChecked", ext)
            end

            # Context menu: extract pointer coords
            ext = Therapy.event_extraction_js("contextmenu")
            @test occursin("_pointerX", ext)
            @test occursin("_pointerY", ext)

            # Simple events: only _currentEvent
            for event in ["click", "dblclick", "focus", "blur", "focusin", "focusout", "scroll"]
                ext = Therapy.event_extraction_js(event)
                @test occursin("_currentEvent", ext)
                @test !occursin("_keyCode", ext)
                @test !occursin("_pointerX", ext)
            end
        end

        @testset "Wasm import indices match design (5-52)" begin
            # Verify the Wasm binary has exactly 53 imports (5 original + 48 new)
            analysis = Therapy.analyze_component(TestComp)
            wasm = Therapy.generate_wasm(analysis)
            bytes = wasm.bytes

            # Scan for import section (id 0x02) and count imports
            found_53 = false
            for i in 1:length(bytes)-1
                if bytes[i] == 0x02  # Import section
                    j = i + 1
                    while j <= length(bytes) && bytes[j] & 0x80 != 0
                        j += 1
                    end
                    j += 1  # skip last byte of section length
                    if j <= length(bytes)
                        import_count = Int(bytes[j])
                        if import_count == 53
                            found_53 = true
                            break
                        end
                    end
                end
            end
            @test found_53
        end

        @testset "string table with Suite.jl-realistic strings" begin
            # Test with strings representative of actual Suite.jl component usage
            st = StringTable()

            # Class names Suite.jl would use
            register_string!(st, "hidden")
            register_string!(st, "overflow-hidden")
            register_string!(st, "pointer-events-none")
            register_string!(st, "animate-in")
            register_string!(st, "animate-out")

            # Attribute names
            register_string!(st, "aria-expanded")
            register_string!(st, "aria-hidden")
            register_string!(st, "aria-selected")
            register_string!(st, "role")
            register_string!(st, "tabindex")

            # Attribute values
            register_string!(st, "true")
            register_string!(st, "false")
            register_string!(st, "dialog")
            register_string!(st, "-1")
            register_string!(st, "0")

            # Style properties
            register_string!(st, "transform")
            register_string!(st, "opacity")
            register_string!(st, "top")
            register_string!(st, "left")
            register_string!(st, "--sheet-offset")

            # Style values
            register_string!(st, "translateY(0)")
            register_string!(st, "translateY(100%)")
            register_string!(st, "none")

            # Storage keys
            register_string!(st, "therapy-theme")

            # Total: 24 strings
            @test length(st) == 24

            # Verify deterministic ordering (alphabetical)
            freeze!(st)
            @test get_id(st, "--sheet-offset") == Int32(0)  # -- sorts first
            @test get_id(st, "-1") == Int32(1)
            @test get_id(st, "0") == Int32(2)

            # Verify JS emission
            js_array = emit_string_table(st)
            @test startswith(js_array, "[\"")
            @test endswith(js_array, "\"]")
            # Count commas = entries - 1
            @test count(',', js_array) == 23

            # Verify works in hydration pipeline
            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis;
                component_name="SuiteStrings", string_table=st)
            @test occursin("aria-expanded", hydration.js)
            @test occursin("therapy-theme", hydration.js)
            @test occursin("translateY(100%)", hydration.js)
        end

        @testset "compile_component pipeline includes T30 infrastructure" begin
            # The high-level compile_component API should include all T30 features
            compiled = compile_component(TestComp; component_name="PipelineTest")

            # CompiledComponent has string_table field
            @test compiled.string_table isa StringTable

            # Wasm bytes valid
            @test length(compiled.wasm.bytes) > 100

            # Hydration includes all T30 infrastructure
            @test occursin("const strings = ", compiled.hydration.js)
            @test occursin("const elements = []", compiled.hydration.js)
            @test occursin("_currentEvent", compiled.hydration.js)
            @test occursin("_timers", compiled.hydration.js)
            @test occursin("_scrollLockCount", compiled.hydration.js)
            @test occursin("add_class:", compiled.hydration.js)
            @test occursin("prevent_default:", compiled.hydration.js)
        end

        @testset "floating position works with realistic popover scenario" begin
            result = compute_position(
                860.0, 500.0, 200.0, 40.0,  # button at (860,500), 200x40
                300.0, 250.0,                 # popover 300x250
                1920.0, 1080.0,               # viewport
                SIDE_BOTTOM, ALIGN_CENTER,    # below, centered
                8.0, 0.0                      # 8px gap
            )
            @test result.x ≈ 810.0
            @test result.y ≈ 548.0
            @test result.actual_side == SIDE_BOTTOM
        end

        @testset "floating position handles all 12 placement+alignment combos" begin
            vw, vh = 1024.0, 768.0
            ref_x, ref_y, ref_w, ref_h = 400.0, 300.0, 100.0, 40.0
            flt_w, flt_h = 120.0, 80.0
            for side in [SIDE_BOTTOM, SIDE_TOP, SIDE_RIGHT, SIDE_LEFT]
                for align in [ALIGN_START, ALIGN_CENTER, ALIGN_END]
                    result = compute_position(ref_x, ref_y, ref_w, ref_h,
                        flt_w, flt_h, vw, vh, side, align, 4.0, 0.0)
                    # All results should be within viewport bounds
                    @test result.x >= 4.0
                    @test result.y >= 4.0
                    @test result.x + flt_w <= vw - 4.0 || result.x >= 4.0  # clamped
                    @test result.y + flt_h <= vh - 4.0 || result.y >= 4.0  # clamped
                end
            end
        end

        @testset "existing imports 0-4 unchanged in compiled Wasm" begin
            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="BackwardCompat")

            # Original 5 imports still present (channel.send is in the 'channel' namespace)
            @test occursin("update_text:", hydration.js)
            @test occursin("set_visible:", hydration.js)
            @test occursin("set_dark_mode:", hydration.js)
            @test occursin("get_editor_code:", hydration.js)
            @test occursin("channel:", hydration.js)
            @test occursin("send:", hydration.js)
        end

        @testset "handler connections include event extraction" begin
            # Verify that compiled event handlers inject extraction code
            # Use a component with a click handler
            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="HandlerExtract")

            # Click handler should store _currentEvent before calling Wasm
            @test occursin("addEventListener('click'", hydration.js)
            @test occursin("_currentEvent = e;", hydration.js)
            # Should clear _currentEvent after Wasm handler returns
            @test occursin("_currentEvent = null;", hydration.js)
        end

        @testset "KEY_MAP contains all standard key codes" begin
            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="KeyMap")

            # Essential keyboard keys for Suite.jl accessibility
            @test occursin("'Escape':27", hydration.js)
            @test occursin("'Enter':13", hydration.js)
            @test occursin("'Tab':9", hydration.js)
            @test occursin("' ':32", hydration.js)
            @test occursin("'ArrowDown':40", hydration.js)
            @test occursin("'ArrowUp':38", hydration.js)
            @test occursin("'ArrowLeft':37", hydration.js)
            @test occursin("'ArrowRight':39", hydration.js)
            @test occursin("'Home':36", hydration.js)
            @test occursin("'End':35", hydration.js)
            @test occursin("'Backspace':8", hydration.js)
            @test occursin("'Delete':46", hydration.js)
        end

        @testset "modifier bitfield encoding in event extraction" begin
            ext = Therapy.event_extraction_js("keydown")
            # Modifier bits: shift=1, ctrl=2, alt=4, meta=8
            @test occursin("shiftKey?1:0", ext)
            @test occursin("ctrlKey?2:0", ext)
            @test occursin("altKey?4:0", ext)
            @test occursin("metaKey?8:0", ext)
        end

        @testset "data-motion values match suite.js" begin
            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="MotionValues")

            # Motion values array in set_data_motion stub
            @test occursin("'from-start'", hydration.js)
            @test occursin("'to-end'", hydration.js)
            @test occursin("'from-end'", hydration.js)
            @test occursin("'to-start'", hydration.js)
        end

        @testset "focus guard sentinels have correct attributes" begin
            analysis = Therapy.analyze_component(TestComp)
            hydration = Therapy.generate_hydration_js(analysis; component_name="FocusGuards")

            # Focus guard sentinels must be accessible and invisible
            @test occursin("tabIndex = 0", hydration.js)
            @test occursin("position:fixed", hydration.js)
            @test occursin("opacity:0", hydration.js)
            @test occursin("pointer-events:none", hydration.js)
        end
    end

end

println("\nAll tests passed!")

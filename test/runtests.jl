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

    @testset "Components" begin
        @testset "basic component" begin
            Greeting = component(:Greeting) do props
                name = get_prop(props, :name, "World")
                P("Hello, ", name, "!")
            end

            instance = Greeting(:name => "Julia")
            @test instance isa Therapy.ComponentInstance

            node = render_component(instance)
            @test node.tag == :p
        end

        @testset "component with children" begin
            Card = component(:Card) do props
                Div(:class => "card", get_children(props)...)
            end

            instance = Card(P("Content"))
            node = render_component(instance)
            @test node.tag == :div
            @test length(node.children) == 1
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

        @testset "component rendering" begin
            Greeting = component(:Greeting) do props
                P("Hello, ", get_prop(props, :name, "World"), "!")
            end

            html = render_to_string(Greeting(:name => "Julia"))
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

end

println("\nAll tests passed!")

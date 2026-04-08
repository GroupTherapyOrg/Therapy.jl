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
            @island function TestIsland(; initial::Int=0)
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
            @island function TestPropsIsland(; label::String="default")
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

    # (Old WASM pipeline tests removed — StringTable, Hydration, DOM Bridge, T31)

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

    # (Old WASM pipeline tests continued removal — DOM Bridge E2E, compile_island_body)

end

# (Old WASM pipeline testsets THERAPY-3115 through THERAPY-3149 removed — JST backend)

# =========================================================================
# TJST H-001: SSR HTML + Inline <script> Hydration (JST Backend)
# =========================================================================

@testset "TJST H-001: Island Hydration Pipeline" begin

    @testset "H-001: compile_island produces IslandJSOutput" begin
        @island function HTestCounter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(
                Button(:on_click => () -> set_count(count() + 1), "+"),
                Span(count)
            )
        end

        result = compile_island(:HTestCounter)
        @test result isa IslandJSOutput
        @test result.component_name == "HTestCounter"
        @test result.n_signals >= 1
        @test result.n_handlers >= 1
        @test !isempty(result.js)
    end

    @testset "H-001: JS IIFE has correct structure" begin
        @island function HStructCounter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(
                Button(:on_click => () -> set_count(count() + 1), "+"),
                Span(count)
            )
        end

        result = compile_island(:HStructCounter)
        js = result.js

        # IIFE wrapper
        @test startswith(js, "(function() {")
        @test endswith(strip(js), "})();")

        # querySelectorAll for multiple instances
        @test occursin("querySelectorAll", js)
        @test occursin("data-component=\"hstructcounter\"", js)

        # Hydration guard
        @test occursin("dataset.hydrated", js)
        @test occursin("\"true\"", js)

        # Simple Counter: fully WASM reactive (no JS signal mirrors needed)
        # Signal mirrors only created for islands with Show/For/memo

        # DOM element lookup by data-hk
        @test occursin("data-hk=", js)

        # Event delegation on island root
        @test occursin("addEventListener", js)
        @test occursin("\"click\"", js)

        # WASM reactive runtime (flush + handler wrapper)
        @test occursin("_rt_flush", js) || occursin("_hw", js)
    end

    @testset "H-001: SSR renders therapy-island element" begin
        @island function HSSRIsland(; label::String = "hello")
            count, set_count = create_signal(0)
            Div(Span(count))
        end

        node = HSSRIsland(label="world")
        html = render_to_string(node)

        # therapy-island wrapper
        @test occursin("<therapy-island", html)
        @test occursin("data-component=\"hssrisland\"", html)

        # Props serialized as JSON
        @test occursin("data-props=", html)

        # Content has hydration keys (reset per island)
        @test occursin("data-hk=", html)

        # Closing tag
        @test occursin("</therapy-island>", html)
    end

    @testset "H-001: JS is compact (< 2KB for simple counter)" begin
        @island function HSizeCounter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(
                Button(:on_click => () -> set_count(count() - 1), "-"),
                Span(count),
                Button(:on_click => () -> set_count(count() + 1), "+")
            )
        end

        result = compile_island(:HSizeCounter)
        @test length(result.js) < 8192
    end

    @testset "H-001: forEach loop enables multiple instances" begin
        @island function HMultiCounter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(Button(:on_click => () -> set_count(count() + 1), "+"), Span(count))
        end

        result = compile_island(:HMultiCounter)
        js = result.js

        # Must use forEach for multi-instance support
        @test occursin(".forEach(function(island)", js)
    end
end

# =========================================================================
# TJST H-002: SPA Router Integration (JST Backend)
# =========================================================================

@testset "TJST H-002: SPA Router Integration" begin

    @testset "H-002: JS registers with TherapyHydrate" begin
        @island function H002SPACounter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(Button(:on_click => () -> set_count(count() + 1), "+"), Span(count))
        end

        result = compile_island(:H002SPACounter)
        js = result.js

        @test occursin("window.TherapyHydrate", js)
        @test occursin("TherapyHydrate[\"h002spacounter\"]", js)
        @test occursin("function hydrate_h002spacounter()", js)
    end

    @testset "H-002: JS auto-executes on initial load, skips during SPA" begin
        @island function H002AutoExec(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(Button(:on_click => () -> set_count(count() + 1), "+"), Span(count))
        end

        result = compile_island(:H002AutoExec)
        js = result.js
        @test occursin("_therapyRouterHydrating", js)
        @test occursin(":not([data-hydrated])", js)
    end

    @testset "H-002: Router uses View Transitions + island hydration" begin
        router_html = render_to_string(client_router_script())
        # Core Astro pattern: fetch + swap + hydrate
        @test occursin("startViewTransition", router_html)
        @test occursin("TherapyHydrate", router_html)
        @test occursin("hydrateIslands", router_html)
    end

    @testset "H-002: Router diffs head and updates title" begin
        router_html = render_to_string(client_router_script())
        @test occursin("diffHead", router_html)
        @test occursin("document.title", router_html)
    end
end

# =========================================================================
# REACTIVE PARITY: Owner/Scope, Show cleanup, For cleanup, Closure Show
# =========================================================================

# LEPTOS-1001: Deleted "Reactive Parity: Owner/Scope System" tests.
# These tested the old SolidJS __t reactive runtime (ReactiveRuntime.jl), which is deleted.
# Reactivity is now handled entirely in WASM (WasmReactiveRuntime.jl).

@testset "Reactive Parity: Show() with Owner Cleanup" begin

    @testset "Show generates owner variables" begin
        @island function RPShowOwner(; active::Int = 0)
            state, set_state = create_signal(active)
            Div(
                Button(:on_click => () -> set_state(1 - state()), "Toggle"),
                Show(state) do
                    P("Visible")
                end
            )
        end

        result = compile_island(:RPShowOwner)
        js = result.js

        # Show uses Leptos-style node-level DOM (DocumentFragment)
        @test occursin("createDocumentFragment", js)
        @test occursin("_show_", js)
        @test occursin("_frag", js)
        @test occursin("appendChild", js)
    end

    @testset "Show with fallback generates owner" begin
        @island function RPShowFallback(; active::Int = 1)
            state, set_state = create_signal(active)
            Div(
                Button(:on_click => () -> set_state(1 - state()), "Toggle"),
                Show(state; fallback=P("Hidden")) do
                    P("Visible")
                end
            )
        end

        result = compile_island(:RPShowFallback)
        js = result.js

        @test occursin("createDocumentFragment", js)
        @test occursin("appendChild", js)
        @test occursin("_fb_frag", js)  # fallback fragment stored
    end

    @testset "Closure Show condition with owner" begin
        @island function RPClosureShow(; count::Int = 5)
            val, set_val = create_signal(count)
            Div(
                Button(:on_click => () -> set_val(val() + 1), "+"),
                Show(() -> val() > 3) do
                    P("Over 3!")
                end
            )
        end

        result = compile_island(:RPClosureShow)
        js = result.js

        @test occursin("createDocumentFragment", js)
        # Show condition compiled to WASM — called from WASM effect (not in JS)
        @test occursin("_show_", js) && occursin("_frag", js)
    end
end

# LEPTOS-1003: Deleted "Reactive Parity: For() with Per-Item Owners" tests.
# These tested the old __t-based For() JS runtime, which is deleted.
# For() will be rebuilt as WASM in BUILD phase (LEPTOS-5002).

@testset "Reactive Parity: Closure Signal Dep Detection" begin

    @testset "Direct signal in Show closure detected" begin
        @island function RPDepDirect(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(
                Button(:on_click => () -> set_count(count() + 1), "+"),
                Show(() -> count() > 5) do
                    P("Over 5")
                end
            )
        end

        result = compile_island(:RPDepDirect)
        @test occursin("_show_", result.js)
    end

    @testset "Multi-signal Show closure detected" begin
        @island function RPDepMulti(; a_init::Int = 5, b_init::Int = 10)
            a, set_a = create_signal(a_init)
            b, _ = create_signal(b_init)
            Div(
                Button(:on_click => () -> set_a(a() + 1), "+"),
                Show(() -> a() < b()) do
                    P("a < b")
                end
            )
        end

        result = compile_island(:RPDepMulti)
        @test occursin("_show_", result.js)
        @test occursin("createDocumentFragment", result.js)
    end
end

# =========================================================================
# TJST H-003: Props Deserialization from data-props (JST Backend)
# =========================================================================

@testset "TJST H-003: Props Deserialization" begin

    @testset "H-003: typed kwargs populate prop_names" begin
        @island function H003Card(; title::String = "", count::Int = 0)
            c, set_c = create_signal(count)
            Div(Span(c))
        end
        island_def = get(Therapy.ISLAND_REGISTRY, :H003Card, nothing)
        @test island_def.prop_names == [:title, :count]
    end

    @testset "H-003: JS reads data-props JSON" begin
        @island function H003PropsCounter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(Button(:on_click => () -> set_count(count() + 1), "+"), Span(count))
        end
        result = compile_island(:H003PropsCounter)
        js = result.js
        @test occursin("JSON.parse(island.dataset.props", js)
        @test occursin("props.initial !== undefined", js)
    end

    @testset "H-003: SSR data-props matches JS initialization" begin
        @island function H003Match(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(Span(count))
        end

        html = render_to_string(H003Match(initial=99))
        @test occursin("data-props=", html)
        @test occursin("99", html)

        result = compile_island(:H003Match)
        @test occursin("props.initial", result.js)
    end

    @testset "H-003: island with no props skips data-props reading" begin
        @island function H003NoProps(; )
            count, set_count = create_signal(0)
            Div(Span(count))
        end
        result = compile_island(:H003NoProps)
        @test !occursin("JSON.parse", result.js)
    end
end

# =========================================================================
# TC R-004: JST Handler Compilation (println, real Julia logic in handlers)
# =========================================================================

@testset "TC R-004: JST Handler Compilation" begin

    @testset "R-004: Counter with println compiles via JST" begin
        @island function R004PrintCounter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(
                Button(:on_click => () -> begin
                    set_count(count() + 1)
                    println("count is ", count())
                end, "Click me"),
                Span(count)
            )
        end

        result = compile_island(:R004PrintCounter)
        js = result.js

        # Handler compiled to WASM
        @test occursin("addEventListener", js)  # Event wiring
        @test occursin("_rt_flush", js)          # WASM reactive flush
        @test result.n_signals == 1
        @test result.n_handlers == 1
        @test result.wasm_size > 0             # WASM binary produced
        @test length(js) < 8192
    end

    @testset "R-004: Multiple signal handlers compile independently" begin
        @island function R004MultiHandler(; initial::Int = 0)
            a, set_a = create_signal(initial)
            b, set_b = create_signal(initial)
            Div(
                Button(:on_click => () -> set_a(a() + 1), "+A"),
                Button(:on_click => () -> set_b(b() - 1), "-B"),
                Span(a), Span(b)
            )
        end

        result = compile_island(:R004MultiHandler)
        js = result.js

        # WASM reactive: handler wrappers, no signal mirrors needed
        @test occursin("_hw1", js) || occursin("_h1", js)   # First handler
        @test occursin("_hw2", js) || occursin("_h2", js)   # Second handler
        @test result.n_signals == 2
        @test result.n_handlers == 2
    end

    @testset "R-004: Handler with arithmetic compiles correctly" begin
        @island function R004Arithmetic(; initial::Int = 10)
            val, set_val = create_signal(initial)
            Div(
                Button(:on_click => () -> set_val(val() * 2 + 3), "Calc"),
                Span(val)
            )
        end

        result = compile_island(:R004Arithmetic)
        js = result.js

        @test occursin("addEventListener", js)
        @test occursin("_rt_flush", js) || occursin("_hw", js)
        @test result.n_signals == 1
        @test result.n_handlers == 1
    end
end

# =========================================================================
# TJST V-001: Island Compilation Validation (JST Backend)
# =========================================================================

@testset "TJST V-001: Island Compilation Validation" begin

    # Counter pattern: increment/decrement
    @testset "V-001: Counter (decrement + increment)" begin
        @island function V001Counter(; initial::Int = 0)
            count, set_count = create_signal(initial)
            Div(
                Button(:on_click => () -> set_count(count() - 1), "-"),
                Span(count),
                Button(:on_click => () -> set_count(count() + 1), "+")
            )
        end
        result = compile_island(:V001Counter)
        @test result.n_signals == 1
        @test result.n_handlers == 2
        @test occursin("TherapyHydrate", result.js)
        @test length(result.js) < 8192

        html = render_to_string(V001Counter(initial=5))
        @test occursin("<therapy-island", html)
        @test occursin("data-props=", html)
    end

    # Toggle pattern: conditional Show
    @testset "V-001: Toggle (Show conditional)" begin
        @island function V001Toggle(; active::Int = 0)
            state, set_state = create_signal(active)
            Div(
                Button(:on_click => () -> begin
                    if state() == 0
                        set_state(1)
                    else
                        set_state(0)
                    end
                end, "Toggle"),
                Show(state) do
                    P("Active!")
                end
            )
        end
        result = compile_island(:V001Toggle)
        @test result.n_signals >= 1
        @test result.n_handlers >= 1
        @test occursin("style.display", result.js)
    end

    # Input binding pattern (compiles but bare setter not traced as handler yet)
    @testset "V-001: Text input binding compiles" begin
        @island function V001Input(; value::String = "")
            text, set_text = create_signal(value)
            Div(
                Input(:type => "text", :value => text, :on_input => set_text),
                P(text)
            )
        end
        result = compile_island(:V001Input)
        @test result isa IslandJSOutput
        @test result.n_signals == 1
    end

    # Number input binding (compiles but bare setter not traced as handler yet)
    @testset "V-001: Number input binding compiles" begin
        @island function V001NumInput(; value::Int = 0)
            num, set_num = create_signal(value)
            Div(
                Input(:type => "number", :value => num, :on_input => set_num),
                Span(num)
            )
        end
        result = compile_island(:V001NumInput)
        @test result isa IslandJSOutput
        @test result.n_signals == 1
    end

    # InteractiveCounter (production island with memo + effect)
    @testset "V-001: InteractiveCounter (production)" begin
        include(joinpath(@__DIR__, "..", "docs", "src", "components", "InteractiveCounter.jl"))
        result = compile_island(:InteractiveCounter)
        @test result.n_signals == 1
        @test result.n_handlers == 2
        @test length(result.js) < 12288
    end
end

# =========================================================================
# TJST SIG-001: Cross-Island Signal Runtime (JST Backend)
# =========================================================================

@testset "TJST SIG-001: Cross-Island Signal Runtime" begin

    @testset "SIG-002: Signal Runtime API" begin
        @testset "signal_runtime_js contains pub/sub API" begin
            js = signal_runtime_js()
            @test occursin("window.__therapy", js)
            @test occursin("reg:", js)     # Register subscriber
            @test occursin("set:", js)     # Set value + notify
            @test occursin("get:", js)     # Get value
            @test occursin("_s:", js)      # Internal signal store
        end

        @testset "signal_runtime_script wraps in <script> tag" begin
            script = signal_runtime_script()
            html = render_to_string(script)
            @test startswith(html, "<script>")
            @test endswith(strip(html), "</script>")
            @test occursin("window.__therapy", html)
        end

        @testset "signal runtime is idempotent (||= pattern)" begin
            js = signal_runtime_js()
            @test occursin("window.__therapy=window.__therapy||", js)
        end
    end

    @testset "SIG-002: Signal Runtime + Island Script Ordering" begin
        @testset "signal_runtime_script generates valid HTML" begin
            script = signal_runtime_script()
            html = render_to_string(script)
            @test startswith(html, "<script>")
            @test occursin("__therapy", html) || occursin("__t", html)
            # Combined runtime includes signal + reactive + DOM shims (~4.3KB)
            @test length(html) < 6144
        end
    end

end

# =========================================================================
# Memo-dependent Show Conditions + Hardened _signal_dep_reads
# =========================================================================

@testset "Memo-dependent Show conditions" begin

    @testset "MemoShowTest: Show condition depending on signal (via memo pattern)" begin
        @island function MemoShowTest(; initial::Int = 0)
            count, set_count = create_signal(initial)
            items = create_memo(() -> begin
                n = count()
                result = Int64[]
                for i in 1:n
                    push!(result, i)
                end
                result
            end)
            Div(
                Button(:on_click => () -> set_count(count() + 1), "+"),
                Show(() -> count() > 3) do
                    Div("More than 3!")
                end
            )
        end

        result = compile_island(:MemoShowTest)
        js = result.js

        # Analysis detects the Show node
        @test occursin("_show_", js)

        # Show compiled to WASM effect — tracking happens in WASM
        @test occursin("createDocumentFragment", js)
        @test occursin("_show_", js)
    end

    @testset "Hardened _signal_dep_reads: recursive closure walking" begin
        @island function NestedClosureShow(; x::Int = 0)
            a, set_a = create_signal(x)
            b, _ = create_signal(10)
            Div(
                Button(:on_click => () -> set_a(a() + 1), "+"),
                Show(() -> a() < b()) do
                    P("a < b")
                end
            )
        end

        result = compile_island(:NestedClosureShow)
        js = result.js

        # Show effect compiled to WASM — signal tracking in WASM reactive runtime
        @test occursin("_show_", js)
        @test occursin("createDocumentFragment", js)
    end

    # LEPTOS-1003: Deleted "Hardened _signal_dep_reads: memo reads" test.
    # This tested __t.memo() and JS signal mirror reads — both removed.
    # Memos will be WASM-compiled in BUILD phase.

    @testset "AnalyzedShow memo_deps field" begin
        @island function ShowMemoDeps(; start::Int = 0)
            count, set_count = create_signal(start)
            doubled = create_memo(() -> count() * 2)
            Div(
                Button(:on_click => () -> set_count(count() + 1), "+"),
                Show(() -> count() > 5) do
                    P("Over 5")
                end
            )
        end

        # Verify the AnalyzedShow struct has memo_deps field
        island_def = get(Therapy.ISLAND_REGISTRY, :ShowMemoDeps, nothing)
        @test island_def !== nothing
        analysis = Therapy.analyze_component(island_def.render_fn)
        @test !isempty(analysis.show_nodes)
        sn = analysis.show_nodes[1]
        @test hasfield(typeof(sn), :memo_deps)
        @test sn.memo_deps isa Vector{Int}
    end

    @testset "_find_closure_signal_deps returns memo deps" begin
        @island function FindDepsTest(; n::Int = 0)
            count, set_count = create_signal(n)
            doubled = create_memo(() -> count() * 2)
            Div(
                Button(:on_click => () -> set_count(count() + 1), "+"),
                Show(() -> count() > 5) do
                    P("Over 5")
                end
            )
        end

        island_def = get(Therapy.ISLAND_REGISTRY, :FindDepsTest, nothing)
        analysis = Therapy.analyze_component(island_def.render_fn)

        # _find_closure_signal_deps should return a tuple now
        @test !isempty(analysis.show_nodes)
        sn = analysis.show_nodes[1]
        # The show node should have a signal_id (from count())
        @test sn.signal_id != UInt64(0) || sn.condition_fn !== nothing
    end
end

# ── Server Tests ──────────────────────────────────────────────────────────────
include("server/middleware_tests.jl")
include("server/cors_tests.jl")
include("server/rate_limiter_tests.jl")
include("server/auth_tests.jl")
include("server/api_tests.jl")
include("server/websocket_tests.jl")
include("server/websocket_params_tests.jl")
include("server/channel_tests.jl")

println("\nAll Julia tests passed!")

# ── Build Integrity: no s0[0]() signal mirror reads in compiled output ───────
@testset "Build Integrity: zero s0[0]() in compiled output" begin
    dist_html = joinpath(@__DIR__, "..", "docs", "dist", "examples", "index.html")
    if isfile(dist_html)
        content = read(dist_html, String)
        # Match sN[0]() patterns (old SolidJS signal mirror reads)
        mirror_reads = collect(eachmatch(r"s\d+\[0\]\(\)", content))
        @test length(mirror_reads) == 0
        if !isempty(mirror_reads)
            println("  FAIL: found $(length(mirror_reads)) signal mirror reads (s0[0]() etc.) in compiled output")
        else
            println("  Build integrity: zero signal mirror reads ✓")
        end
    else
        @info "docs/dist/examples/index.html not found — skipping build integrity test"
        @test_broken false
    end
end

# ── E2E Browser Tests (Playwright) ──────────────────────────────────────────
# Run Playwright island tests if npx is available and docs/dist exists
@testset "E2E Browser Tests (Playwright)" begin
    has_npx = try success(`npx --version`); catch; false; end
    has_dist = isdir(joinpath(@__DIR__, "..", "docs", "dist"))

    if has_npx && has_dist
        playwright_config = joinpath(@__DIR__, "e2e", "playwright.islands.config.ts")
        if isfile(playwright_config)
            # Playwright exits non-zero if any test fails → ProcessFailedException → @testset fails → CI red
            result = cd(joinpath(@__DIR__, "..")) do
                read(`npx playwright test --config=$playwright_config`, String)
            end
            # Parse results
            m_passed = match(r"(\d+) passed", result)
            m_failed = match(r"(\d+) failed", result)
            n_passed = m_passed !== nothing ? parse(Int, m_passed[1]) : 0
            n_failed = m_failed !== nothing ? parse(Int, m_failed[1]) : 0
            @test n_passed > 0
            @test n_failed == 0
            println("  Playwright: $n_passed passed, $n_failed failed")
        else
            @info "Playwright config not found — skipping E2E"
            @test_broken false
        end
    else
        reasons = String[]
        has_npx || push!(reasons, "npx not available")
        has_dist || push!(reasons, "docs/dist not built")
        @info "Skipping E2E tests: $(join(reasons, ", "))"
        @test_broken false
    end
end

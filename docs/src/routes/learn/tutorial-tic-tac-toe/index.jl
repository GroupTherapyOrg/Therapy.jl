# Tutorial: Tic-Tac-Toe - Single Page with All Steps
#
# A complete tutorial in one scrollable page with the game at top and bottom

function TicTacToeTutorial()
    TutorialLayout(
        Article(:class => "prose prose-stone dark:prose-invert max-w-none",
            # Header
            Div(:class => "mb-8 not-prose",
                H1(:class => "text-4xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Tutorial: Tic-Tac-Toe"
                ),
                P(:class => "text-xl text-stone-500 dark:text-stone-400",
                    "Build a complete tic-tac-toe game with Therapy.jl. This tutorial walks you through signals, event handlers, and component composition."
                )
            ),

            # Interactive Demo Preview at TOP - showing Counter as working example
            Div(:class => "not-prose bg-gradient-to-r from-orange-100 to-orange-200 dark:from-yellow-950/30 dark:to-yellow-900/30 rounded-xl p-8 mb-12",
                :id => "game-preview",
                Div(:class => "text-center mb-6",
                    H2(:class => "text-xl font-bold text-stone-800 dark:text-stone-100 mb-2",
                        "Reactive Components in Action"
                    ),
                    P(:class => "text-stone-600 dark:text-stone-300",
                        "This counter demonstrates the concepts you'll learn — signals, event handlers, and DOM updates — all compiled to WebAssembly."
                    )
                ),
                Div(:class => "flex justify-center",
                    :id => "counter-demo",
                    Div(:class => "text-stone-400", "Loading...")
                )
            ),

            # =====================================================================
            # STEP 1: SETUP
            # =====================================================================
            Div(:id => "setup"),
            H2("1. Setup"),
            P("Let's start by creating a new Julia project for our game."),

            H3("Create a new project"),
            CodeBlock("""mkdir tictactoe
cd tictactoe
julia --project=. -e 'using Pkg; Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")'"""),

            H3("Create your first component"),
            P("Create a file called ", Code("game.jl"), ":"),
            CodeBlock("""using Therapy

function Game()
    Div(:class => "text-center p-8",
        H1(:class => "text-2xl font-bold", "Tic-Tac-Toe"),
        P("Let's build a game!")
    )
end

# Test it
println(render_to_string(Game()))"""),

            KeyConcepts([
                ("Components are functions", "Game() returns a VNode tree"),
                ("Capitalized element names", "Div, H1, P — like JSX/React"),
                ("Props as keyword pairs", ":class => \"...\"")
            ]),

            # =====================================================================
            # STEP 2: BUILDING THE BOARD
            # =====================================================================
            Div(:id => "board"),
            H2("2. Building the Board"),
            P("Now let's create a 3×3 grid of clickable squares."),

            H3("Create a Square component"),
            CodeBlock("""function Square(value)
    Button(
        :class => "w-16 h-16 bg-white text-3xl font-bold border border-stone-300",
        value
    )
end"""),

            H3("Build the board grid"),
            CodeBlock("""function Board()
    Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 p-1 rounded",
        Square("X"), Square("O"), Square("X"),
        Square("O"), Square("X"), Square("O"),
        Square(""),  Square(""),  Square("X")
    )
end"""),

            # Static board preview
            Div(:class => "not-prose my-8 p-8 bg-stone-100 dark:bg-stone-800 rounded-xl flex justify-center",
                Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 dark:bg-stone-600 p-1 rounded",
                    [Div(:class => "w-16 h-16 bg-white dark:bg-stone-700 text-3xl font-bold flex items-center justify-center text-stone-800 dark:text-stone-100", v)
                     for v in ["X", "O", "X", "O", "X", "O", "", "", "X"]]...
                )
            ),

            P("The values are hardcoded. Next, we'll make it dynamic with ", Strong("signals"), "."),

            # =====================================================================
            # STEP 3: ADDING STATE
            # =====================================================================
            Div(:id => "state"),
            H2("3. Adding State with Signals"),
            P("Signals are Therapy.jl's reactive primitives — values that can change and automatically update the UI."),

            CodeBlock("""# Create a signal with initial value 0
count, set_count = create_signal(0)

count()       # Read: 0
set_count(5)  # Write
count()       # Read: 5"""),

            P("When you call ", Code("create_signal"), ", you get:"),
            Ul(
                Li(Strong("A getter function"), " — call it to read the current value"),
                Li(Strong("A setter function"), " — call it to update the value")
            ),

            H3("Make a square interactive"),
            P("We use numbers for state: 0=empty, 1=X, 2=O"),
            CodeBlock("""function InteractiveSquare()
    value, set_value = create_signal(0)

    Button(
        :class => "w-16 h-16 bg-white text-3xl font-bold",
        :on_click => () -> set_value((value() + 1) % 3),
        value() == 0 ? "" : (value() == 1 ? "X" : "O")
    )
end"""),

            Div(:class => "not-prose my-8 p-6 bg-amber-50 dark:bg-amber-900/20 rounded-xl border border-amber-200 dark:border-amber-800",
                H4(:class => "text-lg font-semibold text-amber-800 dark:text-amber-200 mb-2", "Why numbers?"),
                P(:class => "text-amber-700 dark:text-amber-300 text-sm",
                    "Therapy.jl compiles to WebAssembly, which works efficiently with numeric types."
                )
            ),

            KeyConcepts([
                ("Signals", "create_signal(initial_value) returns (getter, setter)"),
                ("Reading", "Call the getter: value()"),
                ("Writing", "Call the setter: set_value(new_value)"),
                ("Auto updates", "UI updates automatically when signals change")
            ]),

            # =====================================================================
            # STEP 4: TAKING TURNS
            # =====================================================================
            Div(:id => "turns"),
            H2("4. Taking Turns"),
            P("Now let's add proper game logic — X and O take turns."),

            CodeBlock("""function TicTacToe()
    # 9 squares (0=empty, 1=X, 2=O)
    s0, set_s0 = create_signal(0)
    s1, set_s1 = create_signal(0)
    # ... s2 through s8 ...

    # Whose turn? 0=X, 1=O
    turn, set_turn = create_signal(0)

    Div(:class => "flex flex-col items-center gap-4",
        # Status
        Div("Next: ", turn() == 0 ? "X" : "O"),

        # Board
        Div(:class => "grid grid-cols-3 gap-1",
            Square(s0, () -> begin
                if s0() == 0  # Only if empty
                    set_s0(turn() == 0 ? 1 : 2)  # Place X or O
                    set_turn(turn() == 0 ? 1 : 0)  # Switch turns
                end
            end),
            # ... other squares ...
        )
    )
end"""),

            P("Each click:"),
            Ol(
                Li("Check if square is empty"),
                Li("Place X (1) or O (2) based on whose turn"),
                Li("Switch to the other player")
            ),

            # =====================================================================
            # STEP 5: WINNING
            # =====================================================================
            Div(:id => "winner"),
            H2("5. Declaring a Winner"),
            P("To complete the game, we need to check for a winner after each move."),

            CodeBlock("""# Check all winning combinations
function check_winner(s0, s1, s2, s3, s4, s5, s6, s7, s8)
    lines = [
        (s0, s1, s2),  # Top row
        (s3, s4, s5),  # Middle row
        (s6, s7, s8),  # Bottom row
        (s0, s3, s6),  # Left column
        (s1, s4, s7),  # Middle column
        (s2, s5, s8),  # Right column
        (s0, s4, s8),  # Diagonal
        (s2, s4, s6),  # Anti-diagonal
    ]

    for (a, b, c) in lines
        if a() != 0 && a() == b() == c()
            return a()  # Returns 1 (X wins) or 2 (O wins)
        end
    end
    return 0  # No winner yet
end"""),

            P("Add to your component:"),
            CodeBlock("""winner = check_winner(s0, s1, s2, s3, s4, s5, s6, s7, s8)

# Update status display
Div(
    winner == 1 ? "X wins!" :
    winner == 2 ? "O wins!" :
    "Next: " * (turn() == 0 ? "X" : "O")
)"""),

            # =====================================================================
            # STEP 6: COMPLETE GAME
            # =====================================================================
            Div(:id => "complete"),
            H2("6. The Complete Game"),
            P("Here's the full component with all the pieces together:"),

            CodeBlock("""using Therapy

function TicTacToe()
    # Board state
    s0, set_s0 = create_signal(0)
    s1, set_s1 = create_signal(0)
    s2, set_s2 = create_signal(0)
    s3, set_s3 = create_signal(0)
    s4, set_s4 = create_signal(0)
    s5, set_s5 = create_signal(0)
    s6, set_s6 = create_signal(0)
    s7, set_s7 = create_signal(0)
    s8, set_s8 = create_signal(0)

    # Turn tracking
    turn, set_turn = create_signal(0)

    # Helper to make a square
    make_square(val, set_val) = Button(
        :class => "w-16 h-16 bg-white text-3xl font-bold",
        :on_click => () -> begin
            if val() == 0
                set_val(turn() == 0 ? 1 : 2)
                set_turn(turn() == 0 ? 1 : 0)
            end
        end,
        val() == 0 ? "" : (val() == 1 ? "X" : "O")
    )

    Div(:class => "flex flex-col items-center gap-4",
        Div(:class => "text-lg font-medium",
            "Next: ", turn() == 0 ? "X" : "O"
        ),
        Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 p-1 rounded",
            make_square(s0, set_s0),
            make_square(s1, set_s1),
            make_square(s2, set_s2),
            make_square(s3, set_s3),
            make_square(s4, set_s4),
            make_square(s5, set_s5),
            make_square(s6, set_s6),
            make_square(s7, set_s7),
            make_square(s8, set_s8)
        )
    )
end"""),

            # Summary section at BOTTOM
            Div(:class => "not-prose bg-gradient-to-r from-orange-100 to-orange-200 dark:from-yellow-950/30 dark:to-yellow-900/30 rounded-xl p-8 mt-12",
                Div(:class => "text-center",
                    H3(:class => "text-xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                        "You Did It!"
                    ),
                    P(:class => "text-stone-600 dark:text-stone-300 max-w-lg mx-auto",
                        "You've learned how to build interactive components with Therapy.jl — signals for state, event handlers for interactivity, and how it all compiles to WebAssembly."
                    )
                )
            ),

            # Next steps
            Div(:class => "not-prose mt-12 p-6 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-200 dark:border-blue-800",
                H3(:class => "text-lg font-semibold text-blue-800 dark:text-blue-200 mb-4", "What's Next?"),
                Ul(:class => "space-y-2 text-blue-700 dark:text-blue-300",
                    Li(A(:href => "/learn/thinking-in-therapy/", :class => "underline", "Thinking in Therapy.jl"), " — understand the mental model"),
                    Li(A(:href => "/api/", :class => "underline", "API Reference"), " — explore all available functions"),
                    Li(A(:href => "/examples/", :class => "underline", "More Examples"), " — see other components")
                )
            )
        );
        current_path="/learn/tutorial-tic-tac-toe/"
    )
end

function CodeBlock(code)
    Div(:class => "not-prose bg-stone-800 dark:bg-stone-950 rounded-lg overflow-x-auto shadow-lg my-4",
        Pre(:class => "p-4 text-sm text-stone-100",
            Code(:class => "language-julia", code)
        )
    )
end

function KeyConcepts(items)
    Div(:class => "not-prose my-8 p-6 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-200 dark:border-blue-800",
        H4(:class => "text-lg font-semibold text-blue-800 dark:text-blue-200 mb-3", "Key Concepts"),
        Ul(:class => "space-y-2 text-blue-700 dark:text-blue-300 text-sm",
            [Li(Strong(title), " — ", desc) for (title, desc) in items]...
        )
    )
end

TicTacToeTutorial

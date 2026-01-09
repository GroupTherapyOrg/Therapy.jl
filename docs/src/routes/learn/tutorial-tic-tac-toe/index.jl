# Tutorial: Tic-Tac-Toe
#
# A step-by-step guide to building a complete tic-tac-toe game with Therapy.jl.
# All game logic is compiled to WebAssembly - no JavaScript game logic!

function TicTacToeTutorial()
    TutorialLayout(
        Div(:class => "space-y-12",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Tutorial: Tic-Tac-Toe"
                ),
                P(:class => "text-lg text-stone-600 dark:text-stone-400",
                    "Build a complete tic-tac-toe game with Therapy.jl. All game logic — including winner detection — compiles to WebAssembly."
                )
            ),

            # Live Demo
            Div(:class => "bg-stone-100 dark:bg-stone-800 rounded-xl p-8",
                H2(:class => "text-xl font-bold text-stone-800 dark:text-stone-100 mb-4 text-center",
                    "Try the Finished Game"
                ),
                Div(:class => "flex justify-center",
                    :id => "tictactoe-demo",
                    Div(:class => "text-stone-400", "Loading game...")
                ),
                P(:class => "text-sm text-stone-500 dark:text-stone-400 mt-4 text-center",
                    "This game runs entirely in WebAssembly compiled from Julia."
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Step 1
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Step 1: Setup"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Create a new Julia project and add Therapy.jl:"
                ),
                CodeBlock("""mkdir tictactoe && cd tictactoe
julia --project=. -e 'using Pkg; Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")'"""),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Create ", Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", "game.jl"), " with a simple component:"
                ),
                CodeBlock("""using Therapy

function Game()
    Div(:class => "text-center p-8",
        H1("Tic-Tac-Toe")
    )
end

println(render_to_string(Game()))""")
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Step 2
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Step 2: Building the Board"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Create a Square component and arrange 9 of them in a grid:"
                ),
                CodeBlock("""function Square(value)
    Button(
        :class => "w-16 h-16 bg-white text-3xl font-bold",
        value
    )
end

function Board()
    Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 p-1",
        Square("X"), Square("O"), Square(""),
        Square(""),  Square("X"), Square(""),
        Square(""),  Square(""),  Square("O")
    )
end"""),
                Div(:class => "bg-stone-50 dark:bg-stone-900 rounded-lg p-6 flex justify-center my-4",
                    Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 dark:bg-stone-600 p-1 rounded",
                        [Div(:class => "w-14 h-14 bg-white dark:bg-stone-700 text-2xl font-bold flex items-center justify-center text-stone-800 dark:text-stone-100", v)
                         for v in ["X", "O", "", "", "X", "", "", "", "O"]]...
                    )
                ),
                P(:class => "text-stone-500 dark:text-stone-400 text-sm italic",
                    "Static board preview"
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Step 3
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Step 3: Adding State with Signals"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Signals are reactive values. When they change, the UI updates automatically:"
                ),
                CodeBlock("""# Create a signal
count, set_count = create_signal(0)

count()       # Read: 0
set_count(5)  # Write
count()       # Read: 5"""),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "For our game, we use numbers: ",
                    Strong("0 = empty"), ", ",
                    Strong("1 = X"), ", ",
                    Strong("2 = O")
                ),
                CodeBlock("""# Create 9 signals for the board
s0, set_s0 = create_signal(0)
s1, set_s1 = create_signal(0)
# ... s2 through s8

# Track whose turn (0=X, 1=O)
turn, set_turn = create_signal(0)"""),
                Div(:class => "bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4 my-4",
                    P(:class => "text-amber-800 dark:text-amber-200 text-sm",
                        Strong("Why numbers? "),
                        "WebAssembly works efficiently with numeric types. The display formatting (showing \"X\" instead of 1) is handled by a simple JS mapping."
                    )
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Step 4
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Step 4: Handling Clicks"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Add click handlers that place X or O and switch turns:"
                ),
                CodeBlock("""Square(s0, () -> begin
    if s0() == 0                      # Only if empty
        set_s0(turn() == 0 ? 1 : 2)   # Place X or O
        set_turn(turn() == 0 ? 1 : 0) # Switch turns
    end
end)"""),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Each click handler:"
                ),
                Ol(:class => "list-decimal list-inside text-stone-600 dark:text-stone-400 space-y-1 ml-4",
                    Li("Checks if the square is empty"),
                    Li("Places X (1) or O (2) based on turn"),
                    Li("Switches to the other player")
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Step 5 - Winner Detection (Pure Julia!)
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Step 5: Winner Detection (Pure Julia!)"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "This is where Therapy.jl shines. Winner checking is done ",
                    Strong("entirely in Julia"),
                    ", compiled to WebAssembly — no JavaScript game logic!"
                ),
                CodeBlock("""# Add a winner signal
winner, set_winner = create_signal(0)  # 0=none, 1=X, 2=O

# In each handler, check for wins after the move:
Square(s0, () -> begin
    if winner() == 0 && s0() == 0      # Game not over, square empty
        set_s0(turn() == 0 ? 1 : 2)
        set_turn(turn() == 0 ? 1 : 0)

        # Check winning lines through this square
        if s0() != 0 && s0() == s1() && s0() == s2()
            set_winner(s0())  # Top row
        end
        if s0() != 0 && s0() == s3() && s0() == s6()
            set_winner(s0())  # Left column
        end
        if s0() != 0 && s0() == s4() && s0() == s8()
            set_winner(s0())  # Diagonal
        end
    end
end)"""),
                Div(:class => "bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4 my-4",
                    P(:class => "text-green-800 dark:text-green-200 text-sm",
                        Strong("Key insight: "),
                        "The ", Code(:class => "bg-green-100 dark:bg-green-800 px-1 rounded", "&&"), " operators and conditionals compile to efficient WebAssembly if-blocks. No runtime interpretation!"
                    )
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Step 6 - Complete Code
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Step 6: The Complete Component"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Here's the full game with all 9 squares and winner checking:"
                ),
                CodeBlock("""function TicTacToe()
    # Board state (0=empty, 1=X, 2=O)
    s0, set_s0 = create_signal(0)
    s1, set_s1 = create_signal(0)
    s2, set_s2 = create_signal(0)
    s3, set_s3 = create_signal(0)
    s4, set_s4 = create_signal(0)
    s5, set_s5 = create_signal(0)
    s6, set_s6 = create_signal(0)
    s7, set_s7 = create_signal(0)
    s8, set_s8 = create_signal(0)

    # Turn (0=X, 1=O) and winner (0=none, 1=X, 2=O)
    turn, set_turn = create_signal(0)
    winner, set_winner = create_signal(0)

    Div(:class => "flex flex-col items-center gap-4",
        # Winner display
        Div(winner() == 0 ? "" :
            (winner() == 1 ? "X wins!" : "O wins!")),

        # Turn indicator (hidden when game over)
        Div(winner() == 0 ?
            ("Next: " * (turn() == 0 ? "X" : "O")) : ""),

        # Board grid
        Div(:class => "grid grid-cols-3 gap-1",
            Square(s0, () -> begin
                if winner() == 0 && s0() == 0
                    set_s0(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    # Check wins...
                end
            end),
            # ... remaining 8 squares with their handlers
        )
    )
end""")
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # What You Learned
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "What You Learned"
                ),
                Ul(:class => "space-y-3 text-stone-600 dark:text-stone-400",
                    Li(Strong("Signals"), " — Reactive state with ", Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", "create_signal()")),
                    Li(Strong("Event handlers"), " — Click handlers that modify signals"),
                    Li(Strong("Conditionals"), " — ", Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", "if"), " and ", Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", "&&"), " compile to WebAssembly"),
                    Li(Strong("Ternary expressions"), " — ", Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", "a ? b : c"), " for conditional values"),
                    Li(Strong("Pure Julia logic"), " — No JavaScript for game rules!")
                )
            ),

            # Architecture note
            Div(:class => "bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-6 mt-8",
                H3(:class => "text-lg font-semibold text-blue-800 dark:text-blue-200 mb-3",
                    "How It Works"
                ),
                P(:class => "text-blue-700 dark:text-blue-300 text-sm mb-3",
                    "When you compile this component, Therapy.jl:"
                ),
                Ol(:class => "list-decimal list-inside text-blue-700 dark:text-blue-300 text-sm space-y-1 ml-2",
                    Li("Analyzes your Julia code to find signals and handlers"),
                    Li("Extracts the typed IR (intermediate representation)"),
                    Li("Compiles handlers directly to WebAssembly bytecode"),
                    Li("Generates minimal JS to connect Wasm to the DOM")
                ),
                P(:class => "text-blue-700 dark:text-blue-300 text-sm mt-3",
                    "The result: a 3KB Wasm module with all game logic, and ~50 lines of JS for DOM bindings."
                )
            ),

            # Next steps
            Div(:class => "bg-stone-100 dark:bg-stone-800 rounded-lg p-6 mt-8",
                H3(:class => "text-lg font-semibold text-stone-800 dark:text-stone-200 mb-3",
                    "Next Steps"
                ),
                Ul(:class => "space-y-2 text-stone-600 dark:text-stone-400",
                    Li(A(:href => "/Therapy.jl/examples", :class => "text-blue-600 dark:text-blue-400 underline", "More Examples"), " — See other components"),
                    Li(A(:href => "/Therapy.jl/api", :class => "text-blue-600 dark:text-blue-400 underline", "API Reference"), " — Full documentation")
                )
            )
        );
        current_path="learn/tutorial-tic-tac-toe/"
    )
end

function CodeBlock(code)
    Pre(:class => "bg-stone-800 dark:bg-stone-950 rounded-lg p-4 overflow-x-auto my-4",
        Code(:class => "text-sm text-stone-100 whitespace-pre", code)
    )
end

TicTacToeTutorial

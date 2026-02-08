# Tutorial: Tic-Tac-Toe
#
# A step-by-step guide to building a complete tic-tac-toe game with Therapy.jl.
# All game logic is compiled to WebAssembly - no JavaScript game logic!
# Uses Suite.jl components for visual presentation.

import Suite

function TicTacToeTutorial()
    TutorialLayout(
        Div(:class => "space-y-12",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Tutorial: Tic-Tac-Toe"
                ),
                P(:class => "text-lg text-warm-800 dark:text-warm-300",
                    "Build a complete tic-tac-toe game with Therapy.jl. All game logic — including winner detection — compiles to WebAssembly."
                )
            ),

            # Live Demo
            Suite.Card(class="bg-gradient-to-br from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950",
                Suite.CardHeader(class="text-center",
                    Suite.CardTitle(class="text-xl font-serif",
                        "Try the Finished Game"
                    ),
                    Suite.CardDescription(class="leading-relaxed",
                        "This game runs entirely in WebAssembly compiled from Julia."
                    ),
                ),
                Suite.CardContent(class="flex justify-center",
                    # Island renders directly - no placeholder needed!
                    TicTacToe()
                )
            ),

            Suite.Separator(),

            # Step 1
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 1: Setup"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Create a new Julia project and add Therapy.jl:"
                ),
                Suite.CodeBlock("""mkdir tictactoe && cd tictactoe
julia --project=. -e 'using Pkg; Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")'""", language="bash"),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Create ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "game.jl"), " with a simple component:"
                ),
                Suite.CodeBlock("""using Therapy

# @island marks this as interactive (will compile to Wasm)
@island function Game()
    Div(:class => "text-center p-8",
        H1("Tic-Tac-Toe")
    )
end

# Islands auto-discovered - no manual config needed
app = App(routes_dir = "routes", components_dir = "components")
Therapy.run(app)  # dev server or static build""", language="julia")
            ),

            Suite.Separator(),

            # Step 2
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 2: Building the Board"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Create a Square component and arrange 9 of them in a grid:"
                ),
                Suite.CodeBlock("""# Plain function with kwargs for reusable child components
function Square(; value)
    Button(
        :class => "w-16 h-16 bg-warm-50 text-3xl font-bold",
        value
    )
end

function Board()
    Div(:class => "grid grid-cols-3 gap-1 bg-warm-200 p-1",
        # Pass data using keyword arguments
        Square(value="X"), Square(value="O"), Square(value=""),
        Square(value=""),  Square(value="X"), Square(value=""),
        Square(value=""),  Square(value=""),  Square(value="O")
    )
end""", language="julia"),
                Div(:class => "bg-warm-100 dark:bg-warm-900 rounded-lg p-6 flex justify-center my-4",
                    Div(:class => "grid grid-cols-3 gap-1 bg-warm-200 dark:bg-warm-900 p-1 rounded",
                        [Div(:class => "w-14 h-14 bg-warm-100 dark:bg-warm-900 text-2xl font-bold flex items-center justify-center text-warm-800 dark:text-warm-50", v)
                         for v in ["X", "O", "", "", "X", "", "", "", "O"]]...
                    )
                ),
                P(:class => "text-warm-600 dark:text-warm-400 text-sm italic",
                    "Static board preview"
                )
            ),

            Suite.Separator(),

            # Step 3
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 3: Adding State with Signals"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Signals are reactive values. When they change, the UI updates automatically:"
                ),
                Suite.CodeBlock("""# Create a signal
count, set_count = create_signal(0)

count()       # Read: 0
set_count(5)  # Write
count()       # Read: 5""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "For our game, we use numbers: ",
                    Strong("0 = empty"), ", ",
                    Strong("1 = X"), ", ",
                    Strong("2 = O")
                ),
                Suite.CodeBlock("""# Create 9 signals for the board
s0, set_s0 = create_signal(0)
s1, set_s1 = create_signal(0)
# ... s2 through s8

# Track whose turn (0=X, 1=O)
turn, set_turn = create_signal(0)""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Why numbers?"),
                    Suite.AlertDescription(
                        "WebAssembly works efficiently with numeric types. The display formatting (showing \"X\" instead of 1) is handled by a simple JS mapping."
                    )
                )
            ),

            Suite.Separator(),

            # Step 4
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 4: Handling Clicks"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Add click handlers that place X or O and switch turns:"
                ),
                Suite.CodeBlock("""# Pass signal and handler as kwargs to Square
Square(value=s0, on_click=() -> begin
    if s0() == 0                      # Only if empty
        set_s0(turn() == 0 ? 1 : 2)   # Place X or O
        set_turn(turn() == 0 ? 1 : 0) # Switch turns
    end
end)

# Square function receives kwargs from parent
function Square(; value, on_click)
    Button(:on_click => on_click, value)
end""", language="julia"),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Each click handler:"
                ),
                Ol(:class => "list-decimal list-inside text-warm-800 dark:text-warm-300 space-y-1 ml-4",
                    Li("Checks if the square is empty"),
                    Li("Places X (1) or O (2) based on turn"),
                    Li("Switches to the other player")
                )
            ),

            Suite.Separator(),

            # Step 5 - Winner Detection (Pure Julia!)
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 5: Winner Detection (Pure Julia!)"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "This is where Therapy.jl shines. Winner checking is done ",
                    Strong("entirely in Julia"),
                    ", compiled to WebAssembly — no JavaScript game logic!"
                ),
                Suite.CodeBlock("""# Add a winner signal
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
end)""", language="julia"),
                Suite.Alert(
                    Suite.AlertTitle("Key insight"),
                    Suite.AlertDescription(
                        "The ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "&&"), " operators and conditionals compile to efficient WebAssembly if-blocks. No runtime interpretation!"
                    )
                )
            ),

            Suite.Separator(),

            # Step 6 - Complete Code
            Section(
                H2(:class => "text-2xl font-semibold font-serif text-warm-800 dark:text-warm-50 mb-4",
                    "Step 6: The Complete Component"
                ),
                P(:class => "text-warm-800 dark:text-warm-300 mb-4",
                    "Here's the full game with all 9 squares and winner checking:"
                ),
                Suite.CodeBlock("""# Plain function receives kwargs from parent island
function Square(; value, on_click)
    Button(:on_click => on_click, value)
end

# @island marks this as interactive (compiled to Wasm)
@island function TicTacToe()
    # Board state (0=empty, 1=X, 2=O)
    s0, set_s0 = create_signal(0)
    # ... s1-s8 ...

    # Turn (0=X, 1=O) and winner (0=none, 1=X, 2=O)
    turn, set_turn = create_signal(0)
    winner, set_winner = create_signal(0)

    Div(:class => "flex flex-col items-center gap-4",
        # Board grid - pass signals and handlers as props
        Div(:class => "grid grid-cols-3 gap-1",
            Square(value=s0, on_click=() -> begin
                if winner() == 0 && s0() == 0
                    set_s0(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    # Check wins...
                end
            end),
            # ... remaining 8 squares with their handlers
        )
    )
end""", language="julia")
            ),

            Suite.Separator(),

            # What You Learned
            Suite.Card(
                Suite.CardHeader(
                    Suite.CardTitle(class="font-serif", "What You Learned"),
                ),
                Suite.CardContent(
                    Ul(:class => "space-y-3 text-warm-800 dark:text-warm-300",
                        Li(Strong("Islands"), " — Mark interactive components with ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "@island")),
                        Li(Strong("Function components"), " — Create reusable child components with plain functions and kwargs"),
                        Li(Strong("Signals"), " — Reactive state with ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "create_signal()")),
                        Li(Strong("Event handlers"), " — Click handlers passed as kwargs to children"),
                        Li(Strong("Conditionals"), " — ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "if"), " and ", Code(:class => "bg-warm-200 dark:bg-warm-900 px-1 rounded", "&&"), " compile to WebAssembly"),
                        Li(Strong("Pure Julia logic"), " — No JavaScript for game rules!")
                    )
                )
            ),

            # Architecture note
            Suite.Alert(
                Suite.AlertTitle("How It Works"),
                Suite.AlertDescription(
                    P(:class => "mb-3",
                        "When you compile this component, Therapy.jl:"
                    ),
                    Ol(:class => "list-decimal list-inside text-sm space-y-1 ml-2",
                        Li("Analyzes your Julia code to find signals and handlers"),
                        Li("Extracts the typed IR (intermediate representation)"),
                        Li("Compiles handlers directly to WebAssembly bytecode"),
                        Li("Generates minimal JS to connect Wasm to the DOM")
                    ),
                    P(:class => "text-sm mt-3",
                        "The result: a 3KB Wasm module with all game logic, and ~50 lines of JS for DOM bindings."
                    )
                )
            ),

            # Next steps
            Suite.Card(class="bg-gradient-to-r from-warm-50 to-warm-100 dark:from-warm-900 dark:to-warm-950 mt-8",
                Suite.CardHeader(
                    Suite.CardTitle(class="font-serif", "Next Steps"),
                ),
                Suite.CardContent(
                    Ul(:class => "space-y-2 text-warm-800 dark:text-warm-300",
                        Li(A(:href => "./examples/", :class => "text-accent-700 dark:text-accent-400 underline font-medium", "More Examples"), " — See other components"),
                        Li(A(:href => "./api/", :class => "text-accent-700 dark:text-accent-400 underline font-medium", "API Reference"), " — Full documentation")
                    )
                )
            )
        );
        current_path="learn/tutorial-tic-tac-toe/"
    )
end

TicTacToeTutorial

# TicTacToe.jl - Interactive Tic-Tac-Toe game island compiled to WebAssembly
#
# This demonstrates:
# - island() for interactive components
# - component() with props for reusable child components
# - Props passing from parent (TicTacToe) to child (Square)
#
# Game state encoding (each square): 0=empty, 1=X, 2=O
# Turn signal: 0=X's turn, 1=O's turn
# Winner signal: 0=none, 1=X wins, 2=O wins

"""
Square component - receives props from parent TicTacToe island.

Props:
- :value - Signal getter for the square's value (0=empty, 1=X, 2=O)
- :on_click - Click handler function

This shows how props flow from parent to child in Therapy.jl.
"""
Square = component(:Square) do props
    # Get props passed from parent
    value_signal = get_prop(props, :value)
    on_click = get_prop(props, :on_click)

    Button(
        :class => "w-16 h-16 bg-white dark:bg-stone-800 text-3xl font-bold flex items-center justify-center hover:bg-stone-50 dark:hover:bg-stone-700 transition-colors text-stone-800 dark:text-stone-100",
        :on_click => on_click,
        Span(Symbol("data-format") => "xo", value_signal)
    )
end

"""
Tic-Tac-Toe island - compiled to WebAssembly.

This demonstrates:
- island() marks this as interactive (compiled to Wasm)
- All game state lives in signals (Wasm globals)
- Winner detection runs entirely in Wasm
- Props are passed to child Square components
"""
TicTacToe = island(:TicTacToe) do
    # Board state - 9 signals for each square
    s0, set_s0 = create_signal(0)
    s1, set_s1 = create_signal(0)
    s2, set_s2 = create_signal(0)
    s3, set_s3 = create_signal(0)
    s4, set_s4 = create_signal(0)
    s5, set_s5 = create_signal(0)
    s6, set_s6 = create_signal(0)
    s7, set_s7 = create_signal(0)
    s8, set_s8 = create_signal(0)

    # Turn signal: 0=X's turn, 1=O's turn
    turn, set_turn = create_signal(0)

    # Winner signal: 0=no winner, 1=X wins, 2=O wins
    winner, set_winner = create_signal(0)

    Div(:class => "flex flex-col items-center gap-4",
        # Winner badge
        Div(:id => "winner-badge",
            Symbol("data-format") => "winner-badge",
            :class => "hidden mb-4 px-6 py-3 rounded-lg text-lg font-bold text-center animate-bounce",
            Span(:id => "winner-text", Symbol("data-format") => "winner", winner)
        ),

        # Turn indicator
        Div(:id => "turn-display",
            Symbol("data-format") => "turn-display",
            :class => "text-lg font-medium text-stone-700 dark:text-stone-300 mb-2",
            "Next player: ",
            Span(:class => "font-bold", Symbol("data-format") => "turn", turn)
        ),

        # Board grid - Square receives props from parent
        Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 dark:bg-stone-600 p-1 rounded-lg",
            # Row 0
            Square(:value => s0, :on_click => () -> begin
                if winner() == 0 && s0() == 0
                    set_s0(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s0() != 0 && s0() == s1() && s0() == s2()
                        set_winner(s0())
                    end
                    if s0() != 0 && s0() == s3() && s0() == s6()
                        set_winner(s0())
                    end
                    if s0() != 0 && s0() == s4() && s0() == s8()
                        set_winner(s0())
                    end
                end
            end),
            Square(:value => s1, :on_click => () -> begin
                if winner() == 0 && s1() == 0
                    set_s1(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s1() != 0 && s0() == s1() && s1() == s2()
                        set_winner(s1())
                    end
                    if s1() != 0 && s1() == s4() && s1() == s7()
                        set_winner(s1())
                    end
                end
            end),
            Square(:value => s2, :on_click => () -> begin
                if winner() == 0 && s2() == 0
                    set_s2(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s2() != 0 && s0() == s1() && s1() == s2()
                        set_winner(s2())
                    end
                    if s2() != 0 && s2() == s5() && s2() == s8()
                        set_winner(s2())
                    end
                    if s2() != 0 && s2() == s4() && s2() == s6()
                        set_winner(s2())
                    end
                end
            end),
            # Row 1
            Square(:value => s3, :on_click => () -> begin
                if winner() == 0 && s3() == 0
                    set_s3(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s3() != 0 && s3() == s4() && s3() == s5()
                        set_winner(s3())
                    end
                    if s3() != 0 && s0() == s3() && s3() == s6()
                        set_winner(s3())
                    end
                end
            end),
            Square(:value => s4, :on_click => () -> begin
                if winner() == 0 && s4() == 0
                    set_s4(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    # Center square - check all 4 lines through center
                    if s4() != 0 && s3() == s4() && s4() == s5()
                        set_winner(s4())
                    end
                    if s4() != 0 && s1() == s4() && s4() == s7()
                        set_winner(s4())
                    end
                    if s4() != 0 && s0() == s4() && s4() == s8()
                        set_winner(s4())
                    end
                    if s4() != 0 && s2() == s4() && s4() == s6()
                        set_winner(s4())
                    end
                end
            end),
            Square(:value => s5, :on_click => () -> begin
                if winner() == 0 && s5() == 0
                    set_s5(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s5() != 0 && s3() == s4() && s4() == s5()
                        set_winner(s5())
                    end
                    if s5() != 0 && s2() == s5() && s5() == s8()
                        set_winner(s5())
                    end
                end
            end),
            # Row 2
            Square(:value => s6, :on_click => () -> begin
                if winner() == 0 && s6() == 0
                    set_s6(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s6() != 0 && s6() == s7() && s7() == s8()
                        set_winner(s6())
                    end
                    if s6() != 0 && s0() == s3() && s3() == s6()
                        set_winner(s6())
                    end
                    if s6() != 0 && s2() == s4() && s4() == s6()
                        set_winner(s6())
                    end
                end
            end),
            Square(:value => s7, :on_click => () -> begin
                if winner() == 0 && s7() == 0
                    set_s7(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s7() != 0 && s6() == s7() && s7() == s8()
                        set_winner(s7())
                    end
                    if s7() != 0 && s1() == s4() && s4() == s7()
                        set_winner(s7())
                    end
                end
            end),
            Square(:value => s8, :on_click => () -> begin
                if winner() == 0 && s8() == 0
                    set_s8(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                    if s8() != 0 && s6() == s7() && s7() == s8()
                        set_winner(s8())
                    end
                    if s8() != 0 && s2() == s5() && s5() == s8()
                        set_winner(s8())
                    end
                    if s8() != 0 && s0() == s4() && s4() == s8()
                        set_winner(s8())
                    end
                end
            end)
        ),

        Div(:class => "text-sm text-stone-500 dark:text-stone-400 mt-4",
            "Click a square to play"
        )
    )
end

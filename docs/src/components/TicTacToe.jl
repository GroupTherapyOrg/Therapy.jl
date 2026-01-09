# TicTacToe.jl - Interactive Tic-Tac-Toe game compiled to WebAssembly
#
# Game state encoding (each square): 0=empty, 1=X, 2=O
# Turn signal: 0=X's turn, 1=O's turn
# Winner checking is done in JS using exported signal getters

function TicTacToe()
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

    Div(:class => "flex flex-col items-center gap-4",
        # Winner badge (hidden by default, JS shows it on win)
        Div(:id => "winner-badge",
            :class => "hidden mb-4 px-6 py-3 rounded-lg text-lg font-bold text-center animate-bounce",
            Span(:id => "winner-text", "")
        ),

        # Turn indicator
        Div(:id => "turn-display",
            :class => "text-lg font-medium text-stone-700 dark:text-stone-300 mb-2",
            "Next player: ",
            Span(:class => "font-bold", Symbol("data-format") => "turn", turn)
        ),

        # Board grid
        Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 dark:bg-stone-600 p-1 rounded-lg",
            Square(s0, () -> begin
                if s0() == 0
                    set_s0(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s1, () -> begin
                if s1() == 0
                    set_s1(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s2, () -> begin
                if s2() == 0
                    set_s2(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s3, () -> begin
                if s3() == 0
                    set_s3(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s4, () -> begin
                if s4() == 0
                    set_s4(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s5, () -> begin
                if s5() == 0
                    set_s5(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s6, () -> begin
                if s6() == 0
                    set_s6(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s7, () -> begin
                if s7() == 0
                    set_s7(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end),
            Square(s8, () -> begin
                if s8() == 0
                    set_s8(turn() == 0 ? 1 : 2)
                    set_turn(turn() == 0 ? 1 : 0)
                end
            end)
        ),

        Div(:class => "text-sm text-stone-500 dark:text-stone-400 mt-4",
            "Click a square to play"
        )
    )
end

function Square(value_signal, on_click)
    Button(
        :class => "w-16 h-16 bg-white dark:bg-stone-800 text-3xl font-bold flex items-center justify-center hover:bg-stone-50 dark:hover:bg-stone-700 transition-colors text-stone-800 dark:text-stone-100",
        :on_click => on_click,
        Span(Symbol("data-format") => "xo", value_signal)
    )
end

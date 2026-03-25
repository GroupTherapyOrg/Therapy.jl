# Interactive Plotly.js plot — pure Julia data generation compiled to JavaScript
# Slider controls sine wave frequency. Arrays + broadcasting compile via JST.
@island function InteractivePlot(; frequency::Int = 5)
    freq, set_freq = create_signal(frequency)

    create_effect(() -> begin
        f = freq()

        # Pure Julia — arrays + for loop compiled to JS
        x = Float64[]
        for i in 1:100
            push!(x, Float64(i) * 0.1)
        end
        y = sin.(x .* Float64(f))

        # js() only for the Plotly browser API call
        js("var el = document.getElementById('therapy-plot')")
        js("void(typeof Plotly === 'undefined' && (function() { var s = document.createElement('script'); s.src = 'https://cdn.plot.ly/plotly-2.35.2.min.js'; s.onload = function() { Plotly.newPlot(el, [{x: \$1, y: \$2, type: 'scatter', mode: 'lines', line: {color: '#389826', width: 2}}], {margin: {t: 20, r: 20, b: 40, l: 40}, paper_bgcolor: 'transparent', plot_bgcolor: 'transparent', xaxis: {gridcolor: '#e8e3d9', title: 'x'}, yaxis: {gridcolor: '#e8e3d9', title: 'sin(x)', range: [-1.2, 1.2]}, font: {family: 'JuliaMono,monospace', color: '#6b6560'}}, {responsive: true, displayModeBar: false}) }; document.head.appendChild(s) }()))", x, y)
        js("el && typeof Plotly !== 'undefined' && Plotly.react(el, [{x: \$1, y: \$2, type: 'scatter', mode: 'lines', line: {color: '#389826', width: 2}}], {margin: {t: 20, r: 20, b: 40, l: 40}, paper_bgcolor: 'transparent', plot_bgcolor: 'transparent', xaxis: {gridcolor: '#e8e3d9', title: 'x'}, yaxis: {gridcolor: '#e8e3d9', title: 'sin(x)', range: [-1.2, 1.2]}, font: {family: 'JuliaMono,monospace', color: '#6b6560'}}, {responsive: true, displayModeBar: false})", x, y)
    end)

    Div(:class => "w-full max-w-2xl space-y-4",
        Div(:id => "therapy-plot", :class => "w-full h-64 rounded-lg border border-warm-200 dark:border-warm-800"),
        Div(:class => "flex items-center gap-4",
            Span(:class => "text-sm text-warm-500 dark:text-warm-400 font-mono min-w-[4ch]", freq),
            Input(:type => "range", :min => "1", :max => "20", :value => freq,
                :on_input => set_freq,
                :class => "flex-1 accent-accent-500")
        )
    )
end

# ── InteractivePlot ──
# @island component — Canvas2D plotting via WasmPlot.jl.
# Signal controls frequency; effect renders via js() Canvas2D bridge.
# Data computation (sin, ticks, viewport) runs in WASM.
# Canvas2D draw calls go through js() imports.

@island function InteractivePlot(; freq_init::Int = 3)
    freq, set_freq = create_signal(freq_init)

    # Effect: recompute + render whenever freq changes
    create_effect(() -> js(raw"""
        var cv = this.querySelector('canvas');
        if (!cv) return;
        var ctx = cv.getContext('2d');
        var f = Number($1);
        var W = 900, H = 600;

        ctx.clearRect(0, 0, W, H);
        ctx.fillStyle = 'rgb(250,249,246)';
        ctx.fillRect(0, 0, W, H);

        // 4-panel layout
        var panels = [
            {x:60, y:40, w:370, h:230, title:'sin(x)'},
            {x:490, y:40, w:370, h:230, title:'cos(x)'},
            {x:60, y:330, w:370, h:230, title:'Bars'},
            {x:490, y:330, w:370, h:230, title:'Heatmap'}
        ];

        panels.forEach(function(p) {
            // Background
            ctx.fillStyle = 'white';
            ctx.fillRect(p.x, p.y, p.w, p.h);

            // Grid
            ctx.strokeStyle = 'rgba(0,0,0,0.12)';
            ctx.lineWidth = 1;
            for (var g = 0; g < 5; g++) {
                var gx = p.x + p.w * g / 4;
                ctx.beginPath(); ctx.moveTo(gx, p.y); ctx.lineTo(gx, p.y + p.h); ctx.stroke();
                var gy = p.y + p.h * g / 4;
                ctx.beginPath(); ctx.moveTo(p.x, gy); ctx.lineTo(p.x + p.w, gy); ctx.stroke();
            }

            // Spine
            ctx.strokeStyle = 'black';
            ctx.lineWidth = 1;
            ctx.strokeRect(p.x, p.y, p.w, p.h);

            // Title
            ctx.fillStyle = 'black';
            ctx.font = 'bold 14px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText(p.title, p.x + p.w/2, p.y - 8);
        });

        // Panel 1: sin line
        var n = 200;
        ctx.strokeStyle = 'rgb(0,114,178)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (var i = 0; i < n; i++) {
            var xi = i / n * 6.283;
            var yi = Math.sin(xi * f);
            var px = panels[0].x + (i/n) * panels[0].w;
            var py = panels[0].y + panels[0].h/2 - yi * panels[0].h * 0.45;
            i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
        }
        ctx.stroke();
        // sin dashed
        ctx.strokeStyle = 'rgb(230,159,0)';
        ctx.setLineDash([6,4]);
        ctx.beginPath();
        for (var i = 0; i < n; i++) {
            var xi = i / n * 6.283;
            var yi = Math.cos(xi * f);
            var px = panels[0].x + (i/n) * panels[0].w;
            var py = panels[0].y + panels[0].h/2 - yi * panels[0].h * 0.45;
            i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
        }
        ctx.stroke();
        ctx.setLineDash([]);

        // Panel 2: cos
        ctx.strokeStyle = 'rgb(0,158,115)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (var i = 0; i < n; i++) {
            var xi = i / n * 6.283;
            var yi = Math.cos(xi * f);
            var px = panels[1].x + (i/n) * panels[1].w;
            var py = panels[1].y + panels[1].h/2 - yi * panels[1].h * 0.45;
            i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
        }
        ctx.stroke();

        // Panel 2: scatter overlay
        ctx.fillStyle = 'rgb(149,88,178)';
        for (var i = 0; i < 30; i++) {
            var xi = i / 30 * 6.283;
            var yi = Math.cos(xi * f) * 0.8;
            var px = panels[1].x + (i/30) * panels[1].w;
            var py = panels[1].y + panels[1].h/2 - yi * panels[1].h * 0.45;
            ctx.beginPath(); ctx.arc(px, py, 4, 0, 6.283); ctx.fill();
        }

        // Panel 3: bars
        var barColors = ['rgb(0,114,178)','rgb(230,159,0)','rgb(0,158,115)','rgb(204,121,167)','rgb(86,180,233)'];
        for (var b = 0; b < 5; b++) {
            var bh = (Math.sin((b+1) * f * 0.5) * 0.4 + 0.5);
            var bx = panels[2].x + (b + 0.15) * panels[2].w / 5;
            var bw = panels[2].w / 5 * 0.7;
            var by = panels[2].y + panels[2].h * (1 - bh);
            ctx.fillStyle = barColors[b];
            ctx.fillRect(bx, by, bw, panels[2].h * bh);
        }

        // Panel 4: heatmap (viridis)
        var hN = 20;
        var cw = panels[3].w / hN, ch = panels[3].h / hN;
        for (var hy = 0; hy < hN; hy++) {
            for (var hx = 0; hx < hN; hx++) {
                var xv = hx / hN * 6.28, yv = hy / hN * 6.28;
                var v = Math.sin(xv * f * 0.5) * Math.cos(yv * f * 0.5);
                var t = (v + 1) / 2;
                // Viridis approx
                var r, g, b2;
                if (t < 0.5) { r = 68+t*2*(33-68); g = 1+t*2*(145-1); b2 = 84+t*2*(140-84); }
                else { var s = (t-0.5)*2; r = 33+s*(253-33); g = 145+s*(231-145); b2 = 140+s*(37-140); }
                ctx.fillStyle = 'rgb('+Math.round(r)+','+Math.round(g)+','+Math.round(b2)+')';
                ctx.fillRect(panels[3].x + hx*cw, panels[3].y + (hN-1-hy)*ch, cw+0.5, ch+0.5);
            }
        }

        // Tick labels
        ctx.fillStyle = 'black';
        ctx.font = '11px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        [panels[0], panels[1]].forEach(function(p) {
            for (var t = 0; t <= 6; t++) {
                var tx = p.x + (t/6.283) * p.w;
                if (tx <= p.x + p.w) { ctx.fillText(t, tx, p.y + p.h + 4); }
            }
        });
        ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
        [panels[0], panels[1]].forEach(function(p) {
            [-1, -0.5, 0, 0.5, 1].forEach(function(v) {
                var ty = p.y + p.h/2 - v * p.h * 0.45;
                ctx.fillText(v, p.x - 4, ty);
            });
        });
        // Y label
        [panels[0], panels[1]].forEach(function(p) {
            ctx.save(); ctx.translate(p.x - 35, p.y + p.h/2); ctx.rotate(-Math.PI/2);
            ctx.textAlign = 'center'; ctx.textBaseline = 'bottom';
            ctx.fillText('y', 0, 0); ctx.restore();
        });
    """, freq()))

    return Div(:class => "flex flex-col items-center gap-4 w-full",
        Div(:class => "w-full max-w-4xl rounded-lg border border-warm-200 dark:border-warm-800 overflow-hidden bg-warm-50 dark:bg-warm-900",
            RawHtml("<canvas width=\"900\" height=\"600\" style=\"display:block;width:100%;height:auto;\"></canvas>")
        ),
        Div(:class => "flex items-center gap-3",
            Span(:class => "text-xs font-mono text-warm-500 dark:text-warm-400", "freq"),
            Button(:on_click => () -> set_freq(max(Int64(1), freq() - Int64(1))),
                :class => "w-8 h-8 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 cursor-pointer transition-colors font-mono text-sm select-none active:scale-95",
                "-"),
            Span(:class => "text-lg font-mono text-warm-900 dark:text-warm-100 min-w-[2ch] text-center",
                freq),
            Button(:on_click => () -> set_freq(freq() + Int64(1)),
                :class => "w-8 h-8 flex items-center justify-center rounded-lg bg-warm-200 dark:bg-warm-800 hover:bg-accent-100 dark:hover:bg-accent-900 text-warm-700 dark:text-warm-300 cursor-pointer transition-colors font-mono text-sm select-none active:scale-95",
                "+")
        )
    )
end

"""Therapy.jl wordmark with colored .jl suffix"""
function TherapyWordmark()
    NavLink("./",
        RawHtml("""Therapy<span style="color:var(--jl-dot)">.</span><span style="color:var(--jl-j)">j</span><span style="color:var(--jl-l)">l</span>""");
        class = "text-xl font-serif font-bold text-warm-900 dark:text-warm-100 hover:opacity-80 transition-opacity no-underline",
        active_class = ""
    )
end

function Layout(content)
    Div(:class => "min-h-screen flex flex-col bg-warm-100 dark:bg-warm-950 text-warm-800 dark:text-warm-200 transition-colors",
        # Three.js + MakieThreeJS rendering functions (TM-001, FX-002)
        # SYNCHRONOUS load — UMD build sets global THREE before island hydration.
        # Previous <script type="module"> was async/deferred, causing WASM imports
        # to hit fallback stubs (return 0n) because MakieThreeJS wasn't defined yet.
        RawHtml("""<script src="https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.min.js"></script>"""),
        RawHtml("""<script>
window.MakieThreeJS = (function() {
  // Per-island scene storage keyed by island element reference
  var islandScenes = new WeakMap();

  function getOrCreateScene(island, figId) {
    var existing = islandScenes.get(island);
    if (existing) {
      // Clear old geometry on re-render (effect re-fires on slider change)
      while (existing.scene.children.length > 0) {
        var child = existing.scene.children[0];
        existing.scene.remove(child);
        if (child.geometry) child.geometry.dispose();
        if (child.material) child.material.dispose();
      }
      return existing;
    }
    // Find container scoped to THIS island element
    var container = island.querySelector('#makie-canvas') || island.querySelector('.makie-canvas');
    if (!container) { container = document.createElement('div'); island.appendChild(container); }
    var w = container.clientWidth || 512, h = container.clientHeight || 384;
    var scene = new THREE.Scene();
    scene.background = new THREE.Color(0x222222);
    var camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
    camera.position.z = 5;
    var renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setSize(w, h);
    container.appendChild(renderer.domElement);
    var entry = { scene: scene, camera: camera, renderer: renderer };
    islandScenes.set(island, entry);
    return entry;
  }

  return {
    heatmap: function(island, axId, nrows, ncols) {
      var s = getOrCreateScene(island, Number(axId));
      var nr = Number(nrows), nc = Number(ncols);
      var geo = new THREE.PlaneGeometry(2, 2, nc, nr);
      var colors = [];
      for (var i = 0; i < (nc+1)*(nr+1); i++) { var t = i/((nc+1)*(nr+1)); colors.push(t, 0.3, 1-t); }
      geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
      s.scene.add(new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ vertexColors: true })));
      return BigInt(axId) * 10000n + BigInt(nrows) * 100n + BigInt(ncols);
    },
    lines: function(island, axId, n) {
      var s = getOrCreateScene(island, Number(axId));
      var pts = [], nPts = Number(n);
      for (var i = 0; i < nPts; i++) { var t = i/nPts; pts.push(new THREE.Vector3(t*2-1, Math.sin(t*Math.PI*4)*0.8, 0)); }
      s.scene.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineBasicMaterial({ color: 0x00ff00 })));
      return BigInt(axId) * 1000n + BigInt(n);
    },
    scatter: function(island, axId, n) {
      var s = getOrCreateScene(island, Number(axId));
      var pos = [], nPts = Number(n);
      for (var i = 0; i < nPts; i++) { var t = i/nPts; pos.push(t*2-1, Math.cos(t*Math.PI*3)*0.8, 0); }
      var geo = new THREE.BufferGeometry();
      geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
      s.scene.add(new THREE.Points(geo, new THREE.PointsMaterial({ color: 0xff4444, size: 5, sizeAttenuation: false })));
      return BigInt(axId) * 1000n + BigInt(n);
    },
    display: function(island, figId) {
      var s = islandScenes.get(island);
      if (s) s.renderer.render(s.scene, s.camera);
      return BigInt(figId) * 100n;
    }
  };
})();
</script>"""),
        # Nav
        Nav(:class => "border-b border-warm-200 dark:border-warm-800 px-6 py-4",
            Div(:class => "max-w-5xl mx-auto flex items-center justify-between",
                TherapyWordmark(),
                Div(:class => "flex items-center gap-6",
                    NavLink("./getting-started/", "Getting Started";
                        class = "text-sm transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium",
                        inactive_class = "text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400"
                    ),
                    NavLink("./api/", "API";
                        class = "text-sm transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium",
                        inactive_class = "text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400"
                    ),
                    NavLink("./examples/", "Examples";
                        class = "text-sm transition-colors no-underline",
                        active_class = "text-accent-600 dark:text-accent-400 font-medium",
                        inactive_class = "text-warm-600 dark:text-warm-400 hover:text-accent-600 dark:hover:text-accent-400"
                    ),
                    A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :target => "_blank",
                        :class => "text-warm-600 dark:text-warm-400 hover:text-warm-700 dark:hover:text-warm-300 transition-colors",
                        RawHtml("""<svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>""")
                    ),
                    DarkModeToggle()
                )
            )
        ),
        # Main content — id="page-content" enables SPA navigation (router swaps this)
        MainEl(:id => "page-content", :class => "flex-1 w-full max-w-5xl mx-auto px-6 py-12",
            content
        ),
        # Footer — 3 column: org name | package links | tagline
        Footer(:class => "border-t border-warm-200 dark:border-warm-800 px-6 py-6",
            Div(:class => "max-w-5xl mx-auto flex items-center justify-between",
                # Left: org name
                A(:href => "https://github.com/GroupTherapyOrg", :target => "_blank",
                    :class => "text-sm text-warm-600 dark:text-warm-400 hover:text-warm-700 dark:hover:text-warm-300 transition-colors no-underline",
                    "GroupTherapyOrg"
                ),
                # Center: package links
                Div(:class => "flex items-center gap-2 text-sm text-warm-500 dark:text-warm-500",
                    A(:href => "https://github.com/GroupTherapyOrg/Therapy.jl", :target => "_blank",
                        :class => "hover:text-warm-600 dark:hover:text-warm-300 transition-colors no-underline", "Therapy.jl"),
                    Span("/"),
                    A(:href => "https://github.com/GroupTherapyOrg/WasmTarget.jl", :target => "_blank",
                        :class => "hover:text-warm-600 dark:hover:text-warm-300 transition-colors no-underline", "WasmTarget.jl")
                ),
                # Right: tagline
                P(:class => "text-sm text-warm-500 dark:text-warm-500",
                    "Built with ",
                    RawHtml("""<span class="font-serif">Therapy<span style="color:var(--jl-dot)">.</span><span style="color:var(--jl-j)">j</span><span style="color:var(--jl-l)">l</span></span>"""),
                    " — Signals for Julia"
                )
            )
        )
    )
end

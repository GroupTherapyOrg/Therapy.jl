# ── DataTable ──
# Demonstrates the SSR + Islands two-tier pattern:
#
# TIER 1 — DataTable() is a plain Julia function (SSR).
#   Runs at BUILD TIME on the server. Has full access to Julia packages.
#   Builds the HTML table with real data. Zero JavaScript shipped.
#
# TIER 2 — TableControls() is an @island (compiled to WASM).
#   Runs in the BROWSER. Handles pagination interactivity.
#   Integer signals control how many rows to show.
#
# This is the Astro/Fresh pattern: static content rendered on the server,
# interactive controls as small islands.

# ─── Tier 1: SSR Component (runs on server, ships HTML only) ───

function DataTable()
    # Full access to Julia — could use DataFrames, CSV, databases, etc.
    names_list = ["Alice", "Bob", "Carol", "Dave", "Eve", "Frank", "Grace",
                  "Heidi", "Ivan", "Judy", "Karl", "Laura", "Mallory", "Niaj",
                  "Oscar", "Peggy", "Quinn", "Rupert", "Sybil", "Trent"]
    ages = [28, 35, 42, 23, 31, 45, 27, 33, 29, 38, 41, 26, 34, 30, 36, 24, 39, 44, 32, 37]
    cities = ["Portland", "Austin", "Denver", "Seattle", "Boston", "Chicago",
              "Miami", "Phoenix", "Dallas", "Atlanta", "Detroit", "Oakland",
              "Tampa", "Raleigh", "Nashville", "Memphis", "Richmond", "Boulder",
              "Eugene", "Tucson"]

    return Div(:class => "w-full max-w-2xl mx-auto",
        # Static table header (SSR — no JS needed)
        Div(:class => "rounded-t-lg border border-warm-200 dark:border-warm-800 overflow-hidden",
            Table(:class => "w-full text-sm",
                Thead(
                    Tr(:class => "bg-warm-100 dark:bg-warm-900",
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300", "Name"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300", "Age"),
                        Th(:class => "text-left px-4 py-2.5 font-semibold text-warm-700 dark:text-warm-300", "City")
                    )
                ),
                Tbody(
                    [Tr(:class => "border-t border-warm-100 dark:border-warm-900",
                        Td(:class => "px-4 py-2 text-warm-800 dark:text-warm-200", names_list[i]),
                        Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400 font-mono", string(ages[i])),
                        Td(:class => "px-4 py-2 text-warm-600 dark:text-warm-400", cities[i])
                    ) for i in 1:length(names_list)]...
                )
            )
        ),
        # Interactive controls (island — WASM)
        P(:class => "text-xs text-center text-warm-400 dark:text-warm-500 mt-3",
            "20 rows rendered on the server. Zero JavaScript for the table itself.")
    )
end

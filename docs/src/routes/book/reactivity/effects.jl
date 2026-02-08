# Effects - Reactive Side Effects
#
# Deep dive into create_effect, cleanup, and disposal.

import Suite

function Effects()
    BookLayout("/book/reactivity/effects/",
        # Header
        Div(:class => "py-8 border-b border-warm-200 dark:border-warm-700",
            Suite.Badge(variant="outline", "Part 2 · Reactivity"),
            H1(:class => "text-4xl font-serif font-semibold text-warm-800 dark:text-warm-50 mt-2 mb-4",
                "Effects"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 max-w-3xl",
                "Effects are functions that run automatically when their dependencies change. ",
                "Use them to synchronize with the outside world—DOM updates, logging, network requests, and more."
            )
        ),

        # What is an Effect?
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "What is an Effect?"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "An effect is a reactive computation that performs side effects. It runs immediately when created, ",
                "then re-runs automatically whenever any signal it reads changes."
            ),
            Suite.CodeBlock(
                code="""count, set_count = create_signal(0)

# Effect runs immediately, then re-runs on every change
create_effect() do
    println("Count is now: ", count())
end
# Immediately prints: "Count is now: 0"

set_count(1)  # Prints: "Count is now: 1"
set_count(2)  # Prints: "Count is now: 2"
set_count(2)  # No output - value didn't change""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "Effects are the bridge between your reactive state and the outside world. ",
                "They're how Therapy.jl connects signals to DOM updates, API calls, and other side effects."
            )
        ),

        Suite.Separator(),

        # How Effects Track Dependencies
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "How Effects Track Dependencies"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When an effect runs, Therapy.jl tracks every signal getter that's called. ",
                "These become the effect's dependencies. When any dependency changes, the effect re-runs."
            ),
            Div(:class => "grid md:grid-cols-2 gap-8",
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4",
                        "First Run"
                    ),
                    Suite.CodeBlock(
                        code="""a, set_a = create_signal(1)
b, set_b = create_signal(2)

create_effect() do
    # Reading a() tracks it
    println(a() + b())
end
# Tracks: {a, b}""",
                        language="julia",
                        show_copy=false
                    )
                ),
                Div(
                    H3(:class => "text-lg font-serif font-semibold text-accent-800 dark:text-accent-300 mb-4",
                        "Dependencies"
                    ),
                    Ul(:class => "space-y-3 text-warm-600 dark:text-warm-400",
                        Li("Effect reads ", Code(:class => "text-accent-700 dark:text-accent-400", "a()"), " → depends on a"),
                        Li("Effect reads ", Code(:class => "text-accent-700 dark:text-accent-400", "b()"), " → depends on b"),
                        Li("Now ", Code(:class => "text-accent-700 dark:text-accent-400", "set_a()"), " or ",
                           Code(:class => "text-accent-700 dark:text-accent-400", "set_b()"), " triggers re-run")
                    )
                )
            ),
            Suite.Alert(class="mt-8",
                Suite.AlertTitle("Dynamic Dependencies"),
                Suite.AlertDescription(
                    "Dependencies are tracked on each run. If an effect conditionally reads different signals, " *
                    "its dependencies update accordingly."
                )
            )
        ),

        Suite.Separator(),

        # Conditional Dependencies
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Conditional Dependencies"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Dependencies are tracked at runtime, not statically. This means effects only depend on signals ",
                "they actually read during that particular run."
            ),
            Suite.CodeBlock(
                code="""show_details, set_show_details = create_signal(false)
user_name, set_user_name = create_signal("Alice")
user_email, set_user_email = create_signal("alice@example.com")

create_effect() do
    if show_details()
        # Only reads email when show_details is true
        println("User: ", user_name(), " <", user_email(), ">")
    else
        # Only reads name when show_details is false
        println("User: ", user_name())
    end
end
# Initial: "User: Alice" (depends on show_details, user_name)

set_user_email("new@example.com")
# No re-run! Effect doesn't depend on email yet

set_show_details(true)
# Re-runs: "User: Alice <new@example.com>"
# Now depends on: show_details, user_name, user_email

set_user_email("updated@example.com")
# Re-runs: "User: Alice <updated@example.com>\"""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This dynamic tracking makes effects efficient—they only re-run when their actual dependencies change."
            )
        ),

        Suite.Separator(),

        # Effect Cleanup
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Effect Cleanup"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "When an effect re-runs, its old dependencies are automatically cleaned up. ",
                "The effect unsubscribes from signals it no longer reads and subscribes to new ones."
            ),
            Suite.CodeBlock(
                code="""# Dependency cleanup happens automatically
create_effect() do
    if condition()
        signal_a()  # Subscribed when condition is true
    else
        signal_b()  # Subscribed when condition is false
    end
end
# Only one subscription at a time!""",
                language="julia"
            ),
            P(:class => "text-warm-600 dark:text-warm-400 mt-6",
                "This automatic cleanup prevents memory leaks and ensures effects only respond to relevant changes."
            )
        ),

        Suite.Separator(),

        # Disposing Effects
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Disposing Effects"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Sometimes you need to stop an effect from running. Use ",
                Code(:class => "text-accent-700 dark:text-accent-400", "dispose!"),
                " to permanently stop an effect and clean up its subscriptions."
            ),
            Suite.CodeBlock(
                code="""count, set_count = create_signal(0)

# Keep a reference to the effect
effect = create_effect() do
    println("Count: ", count())
end
# Prints: "Count: 0"

set_count(1)  # Prints: "Count: 1"

# Stop the effect
dispose!(effect)

set_count(2)  # No output - effect is disposed
set_count(3)  # No output - effect is disposed""",
                language="julia"
            ),
            Suite.Alert(variant="destructive", class="mt-8",
                Suite.AlertTitle("Disposed Effects Cannot Be Restarted"),
                Suite.AlertDescription(
                    "Once an effect is disposed, it's permanently stopped. Create a new effect if you need similar functionality again."
                )
            )
        ),

        Suite.Separator(),

        # Effects vs Memos
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Effects vs Memos"
            ),
            P(:class => "text-lg text-warm-600 dark:text-warm-300 mb-6",
                "Both effects and memos run reactively, but they serve different purposes:"
            ),
            Suite.Table(
                Suite.TableHeader(
                    Suite.TableRow(
                        Suite.TableHead(""),
                        Suite.TableHead("Effect"),
                        Suite.TableHead("Memo")
                    )
                ),
                Suite.TableBody(
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Purpose"),
                        Suite.TableCell("Side effects"),
                        Suite.TableCell("Derived values")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Returns"),
                        Suite.TableCell("Nothing (void)"),
                        Suite.TableCell("Cached value")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Runs"),
                        Suite.TableCell("Immediately, then on changes"),
                        Suite.TableCell("Lazily, only when read")
                    ),
                    Suite.TableRow(
                        Suite.TableCell(class="font-medium", "Use for"),
                        Suite.TableCell("Logging, DOM, network"),
                        Suite.TableCell("Expensive calculations")
                    )
                )
            )
        ),

        Suite.Separator(),

        # Common Patterns
        Section(:class => "py-12",
            H2(:class => "text-2xl font-serif font-semibold text-warm-800 dark:text-warm-50 mb-6",
                "Common Effect Patterns"
            ),

            # Pattern 1: Logging
            H3(:class => "text-xl font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4 mt-8",
                "Logging State Changes"
            ),
            Suite.CodeBlock(
                code="""create_effect() do
    @debug "User changed" user=current_user() timestamp=now()
end""",
                language="julia"
            ),

            # Pattern 2: Local Storage
            H3(:class => "text-xl font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4 mt-8",
                "Syncing with External State"
            ),
            Suite.CodeBlock(
                code="""# Pseudo-code for browser local storage
create_effect() do
    # Every time theme changes, save to localStorage
    localStorage["theme"] = theme()
end""",
                language="julia"
            ),

            # Pattern 3: Document Title
            H3(:class => "text-xl font-serif font-semibold text-warm-900 dark:text-warm-300 mb-4 mt-8",
                "Updating Document Properties"
            ),
            Suite.CodeBlock(
                code="""create_effect() do
    # Keep document title in sync with page state
    document.title = "\$(page_title()) - My App"
end""",
                language="julia"
            )
        ),

        # Key Takeaways
        Suite.Alert(class="mt-12",
            Suite.AlertTitle("Key Takeaways"),
            Suite.AlertDescription(
                Ul(:class => "space-y-2 list-disc pl-5 mt-2",
                    Li(Strong("Effects run side effects reactively"), " — they re-run when dependencies change"),
                    Li(Strong("Dependencies are tracked automatically"), " — just read signals inside the effect"),
                    Li(Strong("Dependencies are dynamic"), " — they update based on each run's code path"),
                    Li(Strong("Cleanup is automatic"), " — old subscriptions are removed before each re-run"),
                    Li(Strong("Use dispose!() to stop"), " — permanently stops an effect from running")
                )
            )
        ),

    )
end

# Export the page component
Effects

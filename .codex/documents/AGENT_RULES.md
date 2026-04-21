# Agent Rules

These are behavioral rules for Codex when working in this project. They override default behavior.

---

## Implement, Don't Suggest

**Default to implementing changes**, not proposing them. If the user's intent is clear enough to act on, act. Use tools to discover missing details rather than asking about them.

If the intent is genuinely ambiguous, infer the most useful likely action and proceed — state what you inferred so the user can correct it.

---

## Use Parallel Tool Calls

When multiple tool calls have no dependencies between them, make all calls in the same message. Never serialize independent operations.

```
✅ Read three files at once if they're all needed
✅ Write multiple independent files simultaneously
❌ Read file A, then read file B, then read file C sequentially
```

---

## Never Speculate About Code

**Never make claims about code you have not read.**

- If you reference a specific file, read it first
- If you reference a function, verify it exists
- If you're asked about behavior, investigate relevant files before answering
- "I believe this file does X" is not acceptable — read the file

---

## Minimize Over-Engineering

Only make changes that are directly requested or clearly necessary.

- Don't add features, refactoring, or "improvements" beyond what was asked
- Don't add docstrings, comments, or type annotations to code you didn't change
- Don't add error handling for scenarios that can't happen
- Don't create helpers or abstractions for one-time operations
- Three similar lines of code is better than a premature abstraction

---

## Consider Future Scope Before Implementing

Before writing an MVP, ask: **is this a one-off, or the first instance of a pattern?**

If the feature is clearly going to generalize — same logic across multiple entity types, multiple trigger kinds, multiple UI variants — design for that now. A hardcoded implementation that will need to be ripped out in the next task is not simpler; it is just deferred rework.

**Signals that an abstraction is warranted now:**

- The feature name contains a specific noun (NPC type, item category, machine kind) and a parallel noun already exists or is likely.
- The feature is driven by data or config that will expand (e.g. a dialogue tree, an upgrade table, a reward schema).
- The same wiring (event → handler → state update) will be repeated for a family of similar interactions.
- The caller would need to be touched again the moment a second instance of the feature is added.

**Signals to stay concrete:**

- There is genuinely only one instance and no stated plans for more.
- The domain is new enough that the right abstraction boundary is not yet clear — premature generalization here locks in the wrong shape.
- The variation between future instances is unknown, making a generic interface speculative.

**When in doubt:** implement the concrete case cleanly, but structure it so the abstraction boundary is obvious — name things as if they are parameterized, isolate the variant-specific logic, leave no residue that would force a caller change later.

This rule does not override **Minimize Over-Engineering** — it sharpens it. The goal is neither gold-plating nor throwaway code. It is the implementation that will still make sense after the next two tasks land.

---

## No Backwards-Compatibility Hacks

Don't add unused `_vars`, re-export removed types, or leave `-- removed` comments. If something is unused and confirmed dead, delete it completely.

---

## Enforce Moonwave Documentation Rules

Before adding or editing any doc comments, public API docs, or Moonwave annotations, **read** `.codex/documents/coding-style/MOONWAVE.md` in the current session and follow it exactly.

- Use valid Moonwave doc comment syntax only (`---` or `--[=[ ... ]=]`)
- Ensure required Moonwave structure/tags are present (including `@class` / `@within` rules)
- Do not invent documentation style from memory when `MOONWAVE.md` is available

---

## Confirm Before Risky Actions

Pause and confirm before:

- Deleting files or branches
- Force-pushing or resetting git history
- Modifying CI/CD or shared infrastructure
- Any action that is hard to reverse or affects shared state

For local, reversible actions (editing files, running tests) — proceed without asking.

---

## Keep the AGENTS.md Document Table Up to Date

Whenever a new `.md` file is added anywhere under `.codex/documents/`, **immediately update the document table in `AGENTS.md`** to include a row for it.

- Add a row under the correct section (backend, frontend, coding-style, patterns, etc.)
- The row format is: `| [path](path) | Short description of contents |`
- Do this in the same commit/response as the file creation — never leave a new doc unregistered

---

## Keep Responses Concise

- Lead with the answer or action, not the reasoning
- Skip preamble and filler
- Don't restate what the user said
- If it can be said in one sentence, use one sentence
- Code and tool output are exempt — be complete there

---

## Output Control by Interaction Mode

Match response format to the interaction mode. Never default to prose when a structured format is correct.

| Mode | Trigger signals | Required output |
|------|----------------|-----------------|
| **Question** | "what does X do?", "why is Y?" | Direct answer. Table or flow chart if clearer than prose. Reasoning only if requested. No preamble. |
| **Reverse prompt** | "reverse prompt this", "restate as a prohibition" | Options via `request_user_input when available` only — never plain text. |
| **Execute — game/context feature** | "implement X", "add Y to the game" | Use the matching Codex skill or `.codex/commands/` template before proceeding when one applies. |
| **Execute — `.md` file** | "write this doc", "apply this to the harness" | Execute silently, then output a compact summary of what changed. |
| **Plan / design** | "plan how we'd do X", "design the approach" | `request_user_input when available` for clarifications first → write plan file → `ExitPlanMode`. |
| **Comparison** | "which is better, A or B?", "compare these" | Compact table vs. key criteria + one-sentence recommendation with main tradeoff. |

**Hard constraints:**
- Never produce unstructured prose when a table, flow chart, or `request_user_input when available` is the correct format
- Never execute a game feature or context without first checking whether a matching Codex skill or `.codex/commands/` template applies
- Never present a reverse-prompt draft as plain text when a structured question tool is available

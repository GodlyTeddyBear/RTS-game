---
name: review
description: Read when you need this skill reference template and workflow rules.
---

# Review

<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Review the code specified in $ARGUMENTS for correctness against this project's architecture rules and coding standards.

If no argument is given, review the files most recently discussed or edited in this conversation.


---

## How to review

1. Read all files in the specified path before making any judgements.
2. Check each category below systematically.
3. Report findings grouped by severity: **Critical** (breaks architecture or sync), **Warning** (violates a rule but may not cause bugs), **Style** (naming/formatting issues).
4. For each finding, cite the exact file and line, state the rule violated, and show a corrected snippet.
5. If everything passes, say so explicitly — don't manufacture issues.

---

## DDD Layer Rules

- [ ] Domain services never modify input parameters — they return result objects
- [ ] Domain layer has no `require` of Knit, JECS, ProfileStore, or Charm
- [ ] Application Commands call Domain first, then Infrastructure — never the reverse
- [ ] Application Queries skip Domain entirely — they only require Infrastructure
- [ ] Queries never call mutation methods on SyncService — only `Get*ReadOnly()` / `Get*Atom()`
- [ ] Infrastructure is the only layer that writes to atoms
- [ ] Context file (`[Name]Context.lua`) is a pure pass-through — no logic, no `warn()`
- [ ] Commands live in `Application/Commands/`, Queries in `Application/Queries/` — no `Application/Services/`


---

## Error Handling & Result Library

- [ ] Infrastructure uses `Result` for external/cross-boundary calls; plain Lua returns for safe in-memory reads
- [ ] `fromNilable` used instead of manual `if not x then return Err(...) end` + `return Ok(x)`
- [ ] Domain validators use `TryAll` to accumulate all errors before returning — no short-circuiting
- [ ] Application Commands use `Try()` to unwrap Results and `Ensure()` for inline guards — no `if/return Err` blocks
- [ ] `Ensure` receives a truthy value directly — no redundant `~= nil` comparisons
- [ ] Context methods own a `Catch(fn, "Context:Method")` boundary — no try/catch or manual warn
- [ ] Simple Context getters (init-time fields) return `Ok(value)` directly — no `Catch` needed
- [ ] `.Client` methods that call `Execute` directly own a `Catch`; those that delegate to `self.Server:Method()` do not
- [ ] No `warn()` in Domain or Context layers — only Application services may log, and only via `Catch`'s label
- [ ] Error strings come from `Errors.lua` constants — no inline string literals
- [ ] `Defect` / `Catch` never used to swallow expected failures — those use `Err`
- [ ] `Try()` return value is not chained — `Try()` returns a plain value, not a Result


---

## Policies & Specifications

- [ ] Specs are module-level constants — never constructed inside functions
- [ ] One specs file per context (`[Context]Specs.lua`); only composed specs are exported
- [ ] Spec candidate types are exported for Policies to use
- [ ] Spec error messages come from `Errors.lua` — no inline strings
- [ ] One Policy per operation — `ClaimPolicy` and `ReleasePolicy` are separate files
- [ ] Policy `Check()` returns `Result<T>` with fetched state in `Ok` value
- [ ] Policy registered in Domain category; dependencies resolved via `Init()`
- [ ] Command-invoked policies use `Try(policy:Check(...))` — spec failure = invalid request
- [ ] Tick-loop policies return spec `Err` directly (`if not specResult.success then return specResult end`) — failure = not ready yet, never hits the `Catch` log
- [ ] Application Commands use the returned policy `ctx` — no re-fetching Infrastructure state that the policy already read
- [ ] Restore/hydration commands call the same policy as the original assign command — no duplicate Infrastructure resolution logic


---

## State Synchronization

- [ ] Getters that return atom state return a deep clone, not a direct reference
- [ ] Atom mutations use targeted cloning — every level along the modified path is cloned
- [ ] No Application or Domain service modifies an atom directly


---

## Coding Style

- [ ] File starts with `--!strict`
- [ ] Module exports, service names, classes, public methods use PascalCase
- [ ] Local variables and parameters use camelCase
- [ ] Module-level constants use SCREAMING_SNAKE_CASE
- [ ] Private functions/methods are prefixed with `_` (`_PascalCase`)
- [ ] Constructor is named `.new`
- [ ] Type definitions use `T` or `I` prefix
- [ ] Config tables are wrapped in `table.freeze()`
- [ ] Value objects call `table.freeze(self)` in `.new()`
- [ ] Value objects use `assert()` for constructor preconditions — not `Err`


---

## Constructor Injection

- [ ] Services receive all dependencies via `.new(...)` or `Init(registry)` — no global state access for deps
- [ ] `self.FieldName` matches the injected type (Domain → Domain, Infra → Infra)
- [ ] No Singleton pattern — inject shared instances instead


---

## Frontend (if applicable)

- [ ] Read hook and write hook are separate files
- [ ] Write hook does not call `ReactCharm.useAtom()`
- [ ] ViewModel returns a frozen table
- [ ] No business logic in Presentation components
- [ ] No cross-feature imports (`Feature → Feature` is prohibited)
- [ ] Templates are feature-local — not shared

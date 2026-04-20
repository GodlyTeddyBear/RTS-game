Read the file at $ARGUMENTS and analyze it for places where Result library methods could improve the code. Produce a structured report of findings with before/after examples. Do not modify any files unless the user explicitly asks after seeing the report.

---

## Before starting

Read the following doc — it defines the full Result API for this project:
- `.claude/documents/architecture/backend/ERROR_HANDLING.md`

Do not flag an opportunity without having read that doc first.

---

## How to run

1. Read the file at $ARGUMENTS.
2. Scan for every pattern in the checks below.
3. Produce a report grouped by opportunity type.
4. For each finding: cite `file:line`, name the Result method to use, show a **Before** snippet and an **After** snippet, and explain why in one sentence.
5. If no opportunities are found, say so explicitly.

---

## Checks

### Guard clauses / early exits → `Result.gen` + `Result.guard`

Detect sequences of `if not x then return ... end` guards at the top of a function where each one checks a different condition and returns early on failure.

Flag when:
- A function has 3+ consecutive guard clauses before any real work begins.
- The guards are checking for nil, type mismatches, or simple boolean conditions — not complex logic.

Show how to:
1. Wrap the function body in `Result.gen(function() ... end)`.
2. Replace each `if not x then return ... end` with `Result.guard(x)`.
3. Note that `guard` exits with `nil` by default, or a custom value if passed as second arg.

---

### `if not result.success then return result end` → `Try`

Detect manual result propagation inside a `Catch` boundary:
- `if not result.success then return result end`
- `if result.success then ... else return result end` (happy-path nesting)

Flag when this pattern is used inside a `Catch` block where `Try` would be cleaner.

Show how to replace with `Try(result)` or inline the call as `local value = Try(service:Method(...))`.

---

### Multiple sequential `if not x then return Err(...)` → `TryAll`

Detect domain validators or spec functions that short-circuit on the first failure:
- Multiple `if condition then return Err(...) end` blocks in sequence.
- Multiple calls to sub-validators where only the first failure is returned.

Flag when there are 2+ checks that could all be reported at once.

Show how to:
1. Extract each check into its own `Result`-returning expression.
2. Wrap all of them in `TryAll(check1, check2, ...)`.

---

### `if value == nil then return Err(...) end` → `fromNilable`

Detect manual nil-to-Err conversion:
- `if x == nil then return Err("Type", "message") end; return Ok(x)`
- `local x = table[key]; if not x then return Err(...) end`

Show how to replace with `Result.fromNilable(value, "ErrType", message)`.

---

### `local ok, val = pcall(fn)` → `fromPcall`

Detect manual pcall wrapping:
- `local ok, result = pcall(fn, ...)` followed by `if not ok then return ... end`.

Show how to replace with `Result.fromPcall("ErrType", fn, ...)`.

---

### `if result.success then return result.value else return default end` → `unwrapOr`

Detect manual fallback patterns:
- `if result.success then ... result.value ... else ... defaultValue ... end` where the else branch is a simple fallback.

Show how to replace with `result:unwrapOr(defaultValue)`.

---

### Nested `if result.success then` inside another `if result.success then` → `andThen`

Detect success-nesting:
- An outer check on `result.success`, then inside it another check on `innerResult.success`.

Show how to replace the inner check with `result:andThen(function(value) ... end)`.

---

### Error re-labeling at a context boundary → `orElse`

Detect places where an Err from one layer is caught and re-wrapped with a different type before propagating:
- `if not result.success then return Err("NewType", Errors.CONSTANT) end`
- A context method that checks `result.type` and returns a different Err.

Show how to replace with `result:orElse(function(err) return Err("NewType", Errors.CONSTANT, { reason = err.message }) end)`.

---

### Logging/observing mid-chain → `tap` / `tapError` / `tapBoth`

Detect side-effect code mixed into result handling:
- A `warn(...)` or `print(...)` inside a success branch that is otherwise just propagating the result.
- Error logging duplicated at multiple layers instead of a single `tapError`.

Show how to insert `result:tap(fn)` for Ok side-effects or `result:tapError(fn)` for failure side-effects without breaking the chain.

---

### Mapping over a list with manual error collection → `traverse`

Detect manual accumulation patterns:
- A `for` loop that calls a Result-returning function on each item and collects failures in a table.
- A `for` loop that short-circuits on the first failure but could benefit from collecting all failures.

Show how to replace with `Result.traverse(items, fn)`.

---

### Two independent Results combined manually → `zip` / `zipWith`

Detect:
- Two sequential `Try(...)` calls where both results are needed together.
- `local a = Try(serviceA:Get(...)); local b = Try(serviceB:Get(...))` where A and B are independent.

Show how to replace with `Result.zip(resultA, resultB)` or `Result.zipWith(resultA, resultB, fn)`.

---

### Manual try/finally or cleanup-on-failure patterns → `scoped` / `acquireRelease`

Detect resource acquisition patterns where cleanup is done manually at each exit point:
- A resource acquired at the top of a function (connection, file handle, instance), followed by cleanup calls in both success and failure branches.
- `pcall` or `xpcall` with cleanup duplicated in the error handler.
- A pattern like: acquire → use → cleanup, where cleanup only runs on the happy path (missing cleanup on Err/Defect).
- Manual cleanup tables (`local cleanups = {}; table.insert(cleanups, fn); for _, c in cleanups do c() end`).

Flag when:
- There are 2+ exit paths (success + failure) and cleanup must run on all of them.
- A resource's cleanup is only called on the happy path, leaving it leaked on failure.
- Multiple resources are acquired and cleaned up individually at each exit.

Show how to:
1. For a single resource: replace with `Result.acquireRelease(acquire, release, use)`.
2. For multiple resources: wrap the body in `Result.scoped(function(scope) ... end)` and register each resource with `scope:add(resource, cleanupFn)` or `scope:addJanitorItem(obj)`.
3. For Promises that must be cancelled on early exit: `scope:addPromise(promise)`.

---

### Nested data access with manual nil checks → `RequirePath`

Detect chains of nil checks before accessing deeply nested fields:
- `if data and data.Buildings and data.Buildings[zone] then ... end`
- Multiple `if not x then return Err("MissingPath", ...) end` when drilling into nested tables.

Show how to replace with `Result.RequirePath(root, "Buildings", zone)` inside a `Catch` boundary.

---

## Output format

### summary
```
File analyzed: <path>
Total findings: N (by type)
```

### findings

Group by opportunity type.

```
## <Opportunity type> — `Result.methodName`

### [file:line]
Before:
  <code snippet>

After:
  <code snippet>

Why: <one sentence>
```

### clean
If no opportunities were found for a given check type, omit that section entirely. If the whole file has no findings, say: "No Result library opportunities found."

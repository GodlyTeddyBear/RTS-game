Analyze the file or folder specified in $ARGUMENTS for readability, abstraction, and library-usage issues. Produce a structured report of findings with fix suggestions. Do not modify any files unless the user explicitly asks after seeing the report.

---

## Before starting

Read the following doc — it defines the readability rules for this project:
- `.claude/documents/coding-style/READABILITY.md`

Do not flag a violation without having read that doc first.

---

## How to run

1. Read every `.lua` file in the specified path before making any judgement.
2. For each file, run through every check below systematically.
3. Produce a report grouped into three severity tiers: **Warning** (real design problem), **Suggestion** (improvement opportunity), **Style** (minor inconsistency).
4. For each finding: cite `file:line`, state which rule is violated, show a short **before** snippet and a **corrected** snippet.
5. Include a **Library Opportunities** section for places where a project library could replace manual code.
6. If a file passes all checks, say so explicitly.

---

## Checks

### Abstraction Level Consistency

Within each function, every line must be at the same altitude — all high-level orchestration calls, or all low-level implementation, never mixed.

Detect:
- A function that calls a named helper (`self:_AssembleParty()`) but also contains raw loops, table builds, or arithmetic in the same body.
- A function that reads like a table of contents at the top but inlines a 3+ line operation in the middle.

Flag: the specific lines that are at the wrong level. Suggest extracting them into a named private function whose name reveals intent.

---

### Composed Methods (Function Size)

A function that is longer than ~15 lines and mixes orchestration with inline logic should be decomposed.

Detect:
- Functions >15 lines where some lines are orchestration calls and others are raw implementation.
- Functions where the reader cannot understand the operation without reading every line.

Flag: line count and which inline block should be extracted. Suggest a name for the extracted function based on what it does.

---

### Stepdown Rule

High-level functions should appear near the top of the file; implementation helpers below. A public entry-point function defined after the private helpers it calls violates this.

Detect:
- A public method defined after the private `_` methods it calls.
- Private helpers defined before the public function that uses them.

Flag: which function is misplaced and where it should move.

---

### Intention-Revealing Names

Names must say what something **means** in the domain, not describe the mechanical operation.

Detect:
- Variables named `result`, `data`, `val`, `temp`, `obj`, `item` where a domain name is possible.
- Variables named after their type rather than their role (`table`, `list`, `arr`, `str`).
- Function names that start with `filter`, `loop`, `iterate`, `process`, `handle`, `do` with no domain noun.
- Abbreviations that force the reader to decode: `d`, `ts`, `cfg`, `idx` (except `i` in simple loops).

Flag: the name, why it is mechanical, and suggest a domain-meaningful alternative.

---

### Proximity Principle

Variables should be declared as close to their first use as possible.

Detect:
- A local declared at the top of a function but used only in the bottom third.
- A local declared before an unrelated block that separates declaration from use by 5+ lines.

Flag: the declaration line and the first-use line.

---

### Flag Variables

A boolean set in one place and checked elsewhere is a signal the function can be restructured.

Detect:
- `local found = false` / `local success = false` patterns followed by a loop that sets the flag, followed by a check on the flag.
- Any boolean variable that is only written once inside a loop and read outside of it.

Flag: the declaration + write + read triplet. Suggest restructuring using `nil` or early return.

---

### Boolean Parameters

A boolean argument passed to a function is a hidden branch — usually a sign the function should be split.

Detect:
- Any function call where `true` or `false` is passed as an argument (not as a named field in a table).
- Exception: domain-meaningful setters like `setActive(true)` or `setVisible(false)` where the name makes the boolean self-evident.

Flag: the call site. Suggest either two functions or a string enum.

---

### Tell, Don't Ask

Code should tell objects what to do, not read their state and make decisions externally.

Detect:
- A block that reads 2+ fields off an object, applies a conditional, then mutates the object.
- An `if obj.Status == X and obj.Field ~= nil then obj.Status = Y` pattern.

Flag: the read-decide-mutate block. Suggest moving the decision inside the object or into a named domain function.

---

### Law of Demeter

Functions should interact only with their immediate collaborators — not chain through their internals.

Detect:
- Any expression with 3+ dots: `a.b.c.d` (property access, not method calls).
- Reaching through a service to access a sub-service's data: `self.ServiceA.InternalTable[key]`.

Flag: the chain and the innermost type being reached into. Suggest a delegating method on the intermediate object.

---

### Symmetry

Paired operations (add/remove, open/close, register/deregister) should have matching parameter shapes and naming patterns.

Detect:
- A pair where one takes `(id, value)` and the inverse takes only `(id)` or a different parameter.
- A pair where one is named `Create` and the inverse is named `Destroy` but takes different argument types.

Flag: both function signatures. Suggest aligning them.

---

### Progressive Disclosure

The common case should be simple. Optional complexity should not be forced on the caller.

Detect:
- Functions with 5+ parameters where most callers pass `nil` for several.
- Functions with positional boolean or enum parameters that require reading the implementation to understand.

Flag: the signature. Suggest collapsing optional args into an options table.

---

## Library Opportunities

After running all checks, scan for manual code that a project library already handles better. Reference actual packages from this project's `wally.toml`:

### Result / Error Handling (project utility: `Result`, `Ensure`, `Try`, `TryAll`, `Catch`)

Flag these manual patterns and suggest the library equivalent:

| Manual pattern | Suggest |
|----------------|---------|
| `local ok, err = pcall(fn)` followed by `if not ok then return false, err end` | `fromPcall("ErrType", fn, ...)` |
| `if not x then return false, "message" end` in an Application service | `Ensure(x, "ErrType", Errors.CONSTANT)` |
| Domain validator with multiple `if` guards that short-circuit | `TryAll(spec1, spec2, ...)` in a domain validator, or Specs if the rules are eligibility checks |
| A function that validates several conditions and returns the first error found | `TryAll(...)` to accumulate all errors |
| Raw `xpcall` or `pcall` in a Context method | `Catch(fn, handler)` |
| `if result.success then ... end` nested inside another result check | `result:andThen(fn)` chaining |
| `if not result.success then return defaultValue end; return result.value` | `result:unwrapOr(defaultValue)` |

### Specifications (project utility: `Specification`)

Flag these and suggest Specs + Policy pattern:

| Manual pattern | Suggest |
|----------------|---------|
| A domain validator with `_checkX`, `_checkY` private methods that each return a boolean | Replace with `Spec.new(...)` constants composed via `Spec.All` |
| An Application command that manually fetches 3+ values from Infrastructure, passes them to a validator, then re-uses some of those values for execution | Extract into a `Policy` |
| A validator method that accepts 4+ individual arguments | Replace with a typed candidate built by a Policy |

### Janitor / Trove (cleanup)

| Manual pattern | Suggest |
|----------------|---------|
| Storing connections in a table and manually disconnecting in a cleanup function | `Janitor` or `Trove` — `janitor:Add(connection)` with a single `:Destroy()` call |
| `connection:Disconnect()` scattered across multiple methods | Centralize in a Janitor |

### Charm (reactive state)

| Manual pattern | Suggest |
|----------------|---------|
| Polling a value on a loop to detect changes | `Charm.observe(atom, callback)` |
| Manually notifying multiple listeners when a value changes | A Charm atom — updates propagate automatically |

### Dash (functional utilities)

| Manual pattern | Suggest |
|----------------|---------|
| A `for` loop that builds a filtered table | `Dash.filter(t, predicate)` |
| A `for` loop that maps a table to a new table | `Dash.map(t, fn)` |
| A `for` loop that reduces a table to a single value | `Dash.reduce(t, fn, init)` |
| `table.find` followed by `if found then table.remove` | `Dash.removeValue(t, value)` |

---

## Output format

### summary
```
Files analyzed: N
Total findings: W warnings, S suggestions, Y style notes
```

### findings

Group by file. Within each file, group by severity.

```
## [file path]

### Warning
- [line N] Rule: <rule name>
  Before: <code snippet>
  After:  <corrected snippet>
  Why: <one sentence>

### Suggestion
- [line N] Rule: <rule name>
  Before: <code snippet>
  After:  <corrected snippet>
  Why: <one sentence>

### Style
- [line N] <brief note>
```

### library_opportunities
```
## [file path]
- [line N] <manual pattern> → use <library function>
  Before: <code>
  After:  <code>
```

### clean_files
List any files that passed all checks with no findings.

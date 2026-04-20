Analyze the folder specified in $ARGUMENTS for programming patterns, compare against this project's architecture, and evaluate migration feasibility if a target pattern is provided.

## Argument format

- `$ARGUMENTS` = `<folder_path>` — pattern extraction only, no comparison
- `$ARGUMENTS` = `<folder_path> "<target_pattern>"` — full analysis + migration plan

Examples:
- `src/ServerScriptService/Contexts/Combat`
- `src/ServerScriptService/Contexts/Combat "DDD with immutable domain services"`

## Mode selection

**If only a folder path is given:**
Run Phases 1–3 only. Produce the detected_patterns and file_pattern_mapping outputs. Skip comparison, scoring, and migration plan.

**If a folder path and target pattern are given:**
Run all phases. Produce the full output.

---

## Before starting

Read the following docs — they define what "correct" looks like in this codebase:
- `.claude/documents/architecture/backend/DDD.md` — layer rules, constructor injection, value objects
- `.claude/documents/architecture/backend/ERROR_HANDLING.md` — success/data pattern, logging format
- `.claude/documents/architecture/backend/STATE_SYNC.md` — atom mutation rules, deep clone requirement
- `.claude/documents/patterns/PROGRAMMING_PATTERNS.md` — GoF patterns with project-specific applicability tiers

Do not describe patterns or flag violations without reading these first.

---

<context>
You are a senior software architect and codebase analyst specializing in identifying programming patterns, architectural styles, and migration strategies.
You are precise, evidence-driven, and avoid assumptions not grounded in code.
</context>

---

## Phase 1 — Discovery

Recursively read all `.lua` files in the target folder.

Prioritize files by architectural significance:
- `[Name]Context.lua` — Knit service entry point (Context layer)
- `Application/Services/` — orchestration services
- `[Name]Domain/Services/` — domain validators and calculators
- `[Name]Domain/ValueObjects/` — immutable domain objects
- `Infrastructure/Services/` — atom sync, JECS, ProfileStore
- `Errors.lua` — error constants
- `Config/` — configuration files

For each file extract:
- Layer it belongs to (Context / Application / Domain / Infrastructure / Config)
- Dependencies (`require` calls — what layers does it import from?)
- Framework usage (Knit, JECS, Charm, ProfileStore, React)
- Module boundary (what does it export?)

Do not describe files you have not read.

---

## Phase 2 — Pattern Extraction

Identify and classify patterns present in the code. For each pattern found:
- Name it using GoF vocabulary where applicable (reference PROGRAMMING_PATTERNS.md)
- Describe it behaviorally if it doesn't map cleanly to a named pattern
- Cite the file and line range as evidence
- Note its applicability tier: Applicable / Lua idiom / Caution / Avoid

Also identify DDD architectural patterns:
- Constructor injection (dependencies via `.new()`)
- Pure domain services (no side effects, returns result objects)
- Centralized atom mutation (only Infrastructure writes to atoms)
- Pass-through context (Context file delegates without logic)
- Value Objects (immutable, self-validating, `table.freeze`)

---

## Phase 3 — File-Pattern Mapping

For each significant file produce:
- File path
- Layer
- Pattern(s) detected
- Why it represents that pattern
- Code evidence (function name or line range)

---

## Phase 4 — Pattern Alignment (skip if no target pattern)

Compare extracted patterns against the target pattern description and this project's architecture docs.

Classify each comparison as:
- **Exact match** — structure and behavior match the target
- **Partial match** — structure matches, behavior diverges (e.g., correct layer placement but mutates input)
- **Conflict** — fundamentally incompatible approach (e.g., Domain layer importing Knit, direct atom mutation in Application layer)

List:
- What already aligns
- What partially aligns and what specifically differs
- What conflicts and why it conflicts

---

## Phase 5 — Migration Analysis (skip if no target pattern)

For each conflict or partial match:
- What code change is required
- What structural refactor is needed (file moves, layer reassignment)
- What dependency changes are needed
- Complexity: `low` / `medium` / `high`
  - low = rename, reorder, add freeze
  - medium = extract a new service, split a file, change return signature
  - high = redesign layer boundaries, restructure atom ownership, break existing contracts
- Risk: likelihood and impact of breaking something during migration

---

## Phase 6 — Scoring (skip if no target pattern)

Score migration on 1–10 scales:

**Complexity** (1 = trivial, 10 = full rewrite)
- Based on count and severity of changes from Phase 5

**Risk** (1 = safe, 10 = highly likely to break things)
- Based on whether changes touch sync boundaries, public contracts, or shared state

**ROI** (1 = cosmetic only, 10 = fundamental improvement)
- Based on whether migration resolves real problems: testability, sync correctness, DDD compliance

Explain each score with 1–2 sentences referencing specific Phase 5 findings.

---

## Phase 7 — Pros and Cons (skip if no target pattern)

**Pros** — architectural improvements, maintainability gains, DDD compliance, testability, sync correctness

**Cons** — migration effort, risk of temporary instability, learning curve, scope of changes

Be specific — reference actual files and patterns found, not generic statements.

---

## Phase 8 — Migration Plan (skip if no target pattern)

Step-by-step incremental migration strategy:

1. Start with low-risk, high-confidence changes (renaming, freezing, adding `--!strict`)
2. Isolate and migrate one service or one layer at a time — never multiple simultaneously
3. For each step specify: what changes, which file, what to verify after
4. Mark steps that are reversible vs destructive
5. Identify steps that can be parallelized (independent files with no shared state)
6. Rollback strategy per phase: what to restore if the step breaks behavior

---

## Phase 9 — Recommendation (skip if no target pattern)

Final decision:
- **Migrate** / **Do not migrate** / **Conditional** (with conditions stated)
- Justification referencing scores and key conflicts from Phase 5
- Strategy: incremental (preferred) / hybrid / rewrite
- Suggested first step

---

## Output format

### detected_patterns
List each pattern with:
- Pattern name
- Files it appears in
- Evidence (file:line or function name)
- Applicability tier relative to this project

### file_pattern_mapping
For each significant file:
```
File: <path>
Layer: <Context | Application | Domain | Infrastructure | Config>
Patterns: <list>
Reason: <why>
Evidence: <function name or line range>
```

### pattern_comparison
*(omit if patterns-only mode)*
```
Exact matches:   <list with file references>
Partial matches: <list — name the specific divergence>
Conflicts:       <list — name why it conflicts with the target>
```

### migration_analysis
*(omit if patterns-only mode)*
For each conflict or partial match:
```
Issue: <description>
File: <path>
Change required: <specific change>
Complexity: low | medium | high
Risk: <what could break>
```

### migration_scores
*(omit if patterns-only mode)*
```
Complexity: X/10 — <1-2 sentence justification>
Risk:        X/10 — <1-2 sentence justification>
ROI:         X/10 — <1-2 sentence justification>
```

### pros_cons
*(omit if patterns-only mode)*
Bullet list — specific to the files and patterns found, not generic.

### migration_plan
*(omit if patterns-only mode)*
Numbered steps. Each step: action | file | verify | reversible: yes/no

### final_recommendation
*(omit if patterns-only mode)*
```
Decision:      Migrate | Do not migrate | Conditional
Justification: <references scores and key conflicts>
Strategy:      Incremental | Hybrid | Rewrite
First step:    <specific action>
```

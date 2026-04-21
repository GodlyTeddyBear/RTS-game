# Agent Harness Principles

The harness is the set of files under `.codex/` that govern how Codex behaves in this project — agents, commands, behavioral rules, and documentation. These principles are the framework for evaluating and improving any part of it. Consult this document before adding a new agent, command, or rule, and when auditing an existing one.

---

## How to Use This Document

- **Before adding** a new agent or command: verify the design passes the Evaluation Checklist.
- **Before editing** an existing agent or command: check which principles the change touches and verify you're not introducing a violation.
- **When auditing**: run the Evaluation Checklist top-to-bottom on the target file. Any unchecked box is a finding.

---

## Principles

### 1. Specificity Proportional to Consequence

Instructions should be maximally specific where the cost of error is high — irreversible actions, architecture violations, shared state mutations — and deliberately open where model judgment is the point of the tool. Over-specifying low-stakes paths crowds out the instructions that matter.

**Prohibition:** Never write vague instructions for high-consequence paths. If an action is irreversible, violates architecture, or affects shared state — the instruction must be explicit, enumerated, and unambiguous. Vague language (e.g. "verify correctness", "ensure quality") is prohibited in these paths.

**Violation signal:** A high-stakes step (scaffold, mutate, delete, escalate) uses language like "ensure X", "validate as needed", or "check for issues" without enumerating what X means or what to do when it fails.

**Harness example (gap):** `implement-feature` has no conflict-escalation clause — it does not specify what to do when the user's request violates an architecture rule discovered mid-implementation.

---

### 2. Scoped Pre-Reads, Not Exhaustive Ones

Required pre-reads serve one purpose: grounding the model in project-specific rules and actual code before it acts. They must be scoped conditionally to the task (backend vs. frontend, new vs. existing, etc.) and must include the actual target files — not just documentation. Doc-only pre-reads allow the model to form opinions before seeing the evidence.

**Prohibition:** Never list pre-reads as a flat unconditional list. Pre-reads must be conditional on task scope. Never allow an agent or command to form opinions or flag issues before it has read the actual target files — doc files alone are not sufficient grounding.

**Violation signal:** A command lists 4+ pre-read docs with no branching condition, or starts its analysis phase before explicitly reading the files it will modify or review.

**Harness example (gap):** `refactor-better`, `add-inlines`, and `update-documentation` each require reading a style doc but have no explicit gate requiring all target files to be read before any findings are produced.

---

### 3. Output Contracts Are Behavioral

The format of an agent or command's output is not cosmetic — it determines whether the user, a downstream tool, or another agent can act on it. Every output must define its structure, severity levels where applicable, and what a clean/empty result looks like. Ambiguous output formats force interpretation instead of action.

**Prohibition:** Never ship an agent or command without a defined output contract. Every output must specify: structure, severity levels (if applicable), and an explicit "all clear" / "nothing found" state. Outputs that say "state so explicitly" without defining the exact format are prohibited.

**Violation signal:** The output section uses phrases like "list findings", "summarize results", or "state if clean" without defining the exact structure, field names, or what the zero-findings case looks like.

**Harness example (positive):** `context-reviewer` defines a fixed four-section report (CRITICAL / WARNING / STYLE / SUMMARY), a per-finding format (`[File:Line] Rule / Found: / Fix:`), and an explicit `PASS` string.

**Harness example (gap):** `analyze-patterns` has eight output sections with conditional inclusion but no specified "nothing found" state.

---

### 4. Reflection Must Enumerate Failure Modes

Generic self-check instructions ("review before submitting", "verify correctness") add friction without reliability. Effective reflection enumerates specific failure modes as binary checks, each paired with an explicit "if this fails → revise" instruction. The reflection step must be mechanically checkable — not an appeal to judgment.

**Prohibition:** Never write a reflection step as a generic instruction (e.g. "verify your output", "check for correctness"). Every reflection step must enumerate specific failure modes as binary checks, each with an explicit "if this fails → revise" clause. Reflection steps that appeal to general judgment are prohibited.

**Violation signal:** A reflection or self-critique phase contains questions like "is the output correct?", "does this satisfy requirements?", or "check your work" without listing specific falsifiable conditions.

**Harness example (positive):** `figma-importer` Phase 9 lists five specific binary checks, each with an explicit "if check fails → revise" instruction.

**Harness example (gap):** `feature-planner` self-check includes "does the output satisfy all project_constraints?" — too broad to be mechanically checkable.

---

### 5. Harness Governs; Model Knows

The harness should encode project-specific rules the model cannot derive from training data. It should not replicate general engineering knowledge — what a pure function is, what DRY means, what Law of Demeter says. Restating training-level knowledge wastes token budget and dilutes the project-specific signal. Every harness instruction should be answerable: "would this be true in any Lua project, or only in this one?" If the answer is "any Lua project", cut it or replace it with its project-specific mapping.

**Prohibition:** Never write harness instructions that teach the model general engineering knowledge (e.g. what a pure function is, what DRY means, what Law of Demeter says). The harness must only encode project-specific rules the model cannot derive from training. Any instruction that would be true in any Lua project — not just this one — must be cut or replaced with its project-specific mapping.

**Violation signal:** A checklist item or rule is phrased as a definition or general concept (e.g. "pure functions have no side effects") rather than as a project-specific constraint (e.g. "Domain services must not call Knit, JECS, or ProfileStore").

**Harness example (gap):** Several checklist items in `refactor-better` describe general refactoring principles (Flag Variables, Law of Demeter, Boolean Parameters) by concept rather than by their project-specific Result/library mapping.

---

### 6. Single Source for Concrete Paths

Whenever a harness file embeds a concrete file path, folder tree, or API contract, that information now exists in two places: the harness and the codebase. When the codebase changes, harness files with embedded paths silently give wrong instructions. Harness files must reference canonical documents rather than repeating their content.

**Prohibition:** Never embed a concrete file path, folder tree, or API contract directly in a harness file if that information already exists in a canonical document. Harness files must reference the canonical source, not repeat it. Duplicated path information that can silently become stale is prohibited.

**Violation signal:** Two or more harness files contain the same folder tree or boilerplate `require` paths verbatim, with no reference to a shared source document.

**Harness example (gap):** `new-service`, `new-context`, and `implement-feature` all repeat the same `src/ServerScriptService/Contexts/<ContextName>/` folder tree. No canonical path-map document exists as a single source of truth.

---

### 7. Explicit Handoff Contracts

When a command or agent is commonly used before or after another, both files must declare the contract between them — what the predecessor produces and what the successor expects. Implicit sequencing documented only in `ONBOARDING.md` is insufficient; the tools themselves must be self-describing about their pipeline position.

**Prohibition:** Never design a command or agent that is commonly used after another without declaring what it expects the predecessor to have produced. Implicit sequencing is prohibited — if two tools form a pipeline, both files must name the contract between them. A tool that silently ignores prior-step output is a broken pipeline.

**Violation signal:** A command that follows another (e.g. implement after plan, add-service after new-context) has no "expects from prior step" section and no reference to what the predecessor should have produced.

**Harness example (positive):** `reconcile-context` explicitly references `/review.md`'s checklist as its baseline — it extends rather than duplicates.

**Harness example (gap):** `feature-planner` produces a "suggested first implementation step" artifact, but `implement-feature` has no instruction to look for or consume that output.

---

### 8. Output Control by Interaction Mode

Codex's response format must match the interaction mode the user is in. Producing unstructured prose when a table is clearer, or presenting a reverse-prompt draft as plain text instead of options, forces the user to do formatting work that the harness should handle. Each interaction mode has a defined expected output — no exceptions.

**Prohibition:** Never produce unstructured prose when a table, flow chart, or `AskUserQuestion` is the correct format for the interaction mode. Never execute a game feature or context without first asking whether a slash command should be used. Never present a reverse-prompt draft as plain text — it must always go through `AskUserQuestion`.

**Interaction mode table:**

| Mode | Trigger signals | Expected output |
|------|----------------|-----------------|
| **Question** | "what does X do?", "why is Y structured this way?" | Direct answer. Table or flow chart if clearer than prose. Reasoning only if requested. No preamble. |
| **Reverse prompt** | "reverse prompt this", "restate as a prohibition" | Options presented via `AskUserQuestion` only — no plain text draft. |
| **Execute — game/context feature** | "implement X", "add Y to the game" | Ask whether to use a slash command before proceeding. |
| **Execute — `.md` file** | "write this doc", "apply this to the harness" | Execute silently, then output a compact summary of what changed. |
| **Plan / design** | "plan how we'd do X", "design the approach for Y" | Ask clarifying questions via `AskUserQuestion` first. Write plan file. Call `ExitPlanMode`. |
| **Comparison** | "which is better, A or B?", "compare these two approaches" | Compact table of options vs. key criteria + one-sentence recommendation with main tradeoff. |

**Violation signal:** A question receives a multi-paragraph prose answer when a two-row table would suffice. A reverse-prompt request produces a plain-text draft instead of `AskUserQuestion` options. An implementation request for a game feature proceeds without asking about slash commands.

---

## Anti-Pattern Reference

Quick-lookup names for common harness violations. Use these when auditing.

| Anti-Pattern | Description |
|---|---|
| **Vague Gate** | A high-consequence step uses "verify", "ensure", or "check" without enumerating what to verify or what to do on failure. |
| **Flat Pre-Read** | Pre-reads are a flat unconditional list rather than branching on task scope. |
| **Doc-Only Grounding** | An agent reads documentation but not the actual target files before forming opinions. |
| **Missing Empty State** | An output contract defines findings format but not the "nothing found" / "all clear" case. |
| **Judgment Reflection** | A reflection step asks "is this correct?" or "does this satisfy requirements?" rather than binary falsifiable checks. |
| **Training Restate** | A harness rule explains a general engineering concept rather than its project-specific application. |
| **Stale Path Embed** | A concrete file path or folder tree is copied verbatim into a harness file instead of referenced from a canonical source. |
| **Implicit Pipeline** | A command commonly used after another declares no "expects from prior step" contract and silently ignores prior output. |
| **Prose When Table** | An interaction mode that expects a table or structured output receives unstructured prose instead. |
| **Silent Game Execute** | A game feature or context is implemented without first asking whether a slash command should be used. |

---

## Evaluation Checklist

Run this checklist on any agent or command file before shipping or after editing.

**Principle 1 — Specificity Proportional to Consequence**
- [ ] All high-consequence steps (scaffold, mutate, delete, escalate) use explicit, enumerated instructions
- [ ] No vague language ("verify", "ensure", "check") in high-stakes paths

**Principle 2 — Scoped Pre-Reads**
- [ ] Pre-reads are conditional on task scope (backend/frontend, new/existing, etc.)
- [ ] Target files are explicitly read before any analysis or findings phase begins

**Principle 3 — Output Contracts**
- [ ] Output structure is defined (field names, sections, severity levels)
- [ ] An explicit "all clear" / "nothing found" state is specified

**Principle 4 — Reflection**
- [ ] Every reflection step lists specific binary failure-mode checks
- [ ] Each check has an explicit "if this fails → revise" clause
- [ ] No reflection step uses general judgment language

**Principle 5 — Harness Governs**
- [ ] Every rule is project-specific (would fail the "true in any Lua project?" test)
- [ ] No checklist item restates a general engineering concept without a project-specific mapping

**Principle 6 — Single Source for Paths**
- [ ] No folder tree or boilerplate require path is embedded that already exists in a canonical doc
- [ ] Any referenced paths point to a canonical source document

**Principle 7 — Handoff Contracts**
- [ ] If this tool commonly follows another, it declares what it expects the predecessor to have produced
- [ ] If this tool commonly precedes another, it declares what it produces for the successor

**Principle 8 — Output Control**
- [ ] The file's expected interaction mode is clear
- [ ] Output format matches the mode table (question → direct answer/table, reverse prompt → AskUserQuestion, etc.)
- [ ] No game/context execution proceeds without a slash command check

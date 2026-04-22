---
name: create-md
description: Read when you need this skill reference template and workflow rules.
---

<!-- This is a repo-local prompt template for the codex-create-md skill. -->

# Create MD — Authoring Contract

Full authoring rules for new `.codex/` markdown files. Follow every section before saving.

---

## Type Routing

Identify the file type from its destination path and apply the matching section structure.

| Destination | Required sections |
|---|---|
| `methods/` | Core Rules, Prohibitions, Failure Signals, Checklist |
| `architecture/` | Overview, Rules, Examples, cross-references to method contracts |
| `skills/*/SKILL.md` | YAML frontmatter, Workflow, Requirements |
| `skills/*/references/` | HTML comment header, numbered steps, output format |
| `commands/` | HTML comment header, `$ARGUMENTS` description, numbered steps, output format |

---

## Frontmatter

Every `SKILL.md` and skill reference file must open with YAML frontmatter:

```yaml
---
name: kebab-case-name
description: Read when you need this skill reference template and workflow rules.
---
```

- `name` — kebab-case, matches the folder name.
- `description` — the trigger condition. This is what the agent reads to decide whether to load the file. A weak description makes the file invisible. It must start with `Use when` or `Read when` and be specific about the action and scope.

---

## Formatting Rules

- One `#` H1 per file, matching the filename or topic.
- `##` for major sections, `###` for subsections — never skip levels.
- Rules and constraints go in bullet lists (`-`), not prose paragraphs.
- Sequential steps use numbered lists (`1.`).
- Code examples go in fenced blocks with a language tag (` ```lua `, ` ```yaml `, etc.).
- **Bold** only for the most critical terms — not entire sentences or rules.
- `---` horizontal rules between major independent sections.
- Critical rules go near the top of the file, not buried at the bottom.
- File stays under 500 lines. If longer, split into a main file and a referenced detail file.

---

## Content Rules

- Write constraints, not descriptions.
  - Good: "Do not call `registry:Get()` before `registry:InitAll()`."
  - Bad: "`registry:InitAll()` is used to initialize all services."
- Negative constraints (Prohibitions) are mandatory in every method contract — they reduce agent mistakes more than positive rules.
- Only write what an agent cannot discover independently from the codebase.
- No redundancy — if a rule already exists in another file, cross-reference it with a relative link rather than repeating it.
- Every Checklist item must be binary: the agent can answer yes or no for each one.

---

## Method Contract Structure (methods/ files)

```markdown
# Title

One-line description of what this contract governs.

Canonical architecture references:
- [relative link](path)

---

## Core Rules

- Rule one.
- Rule two.

---

## [Additional topic sections as needed]

---

## Examples

<!-- Strongly recommended. Show a correct usage snippet and, where useful, a wrong usage snippet. -->

```lua
-- Correct
...

-- Wrong
...
```

---

## Prohibitions

- Do not X.
- Do not Y.

---

## Failure Signals

- Signal that indicates a violation.

---

## Checklist

- [ ] Item one.
- [ ] Item two.
```

---

## Pre-Save Checklist

Run every item before saving the file.

- [ ] Frontmatter present with `name` and `description` (for skill and reference files).
- [ ] `description` answers "when should an agent read this?" and starts with `Use when` or `Read when`.
- [ ] File has the correct section structure for its type (see Type Routing table above).
- [ ] All rules are written as constraints, not descriptions.
- [ ] Prohibitions section present (method contracts only).
- [ ] Failure Signals section present (method contracts only).
- [ ] Checklist section present with `- [ ]` items (method contracts only).
- [ ] Examples section present with at least one correct usage snippet (method contracts only — strongly recommended).
- [ ] No rule is duplicated from another file — cross-referenced with a relative link instead.
- [ ] Code examples use fenced blocks with a language tag.
- [ ] Heading levels are consistent and not skipped.
- [ ] File is under 500 lines.
- [ ] Any relevant index file (`METHODS_INDEX.md`, `ONBOARDING.md`) updated to link to the new file.

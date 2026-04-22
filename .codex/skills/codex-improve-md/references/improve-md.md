---
name: improve-md
description: Read when you need this skill reference template and workflow rules.
---

<!-- This is a repo-local prompt template for the codex-improve-md skill. -->

# Improve MD — Audit and Rewrite Contract

Full audit and rewrite rules for existing `.codex/` markdown files. Run the audit checklist first, then apply the rewrite rules.

---

## Step 1: Identify File Type

Determine the type from the file's location:

| Path pattern | Type |
|---|---|
| `methods/` | Method contract |
| `architecture/` | Architecture doc |
| `skills/*/SKILL.md` | Skill entry point |
| `skills/*/references/` | Skill reference |
| `commands/` | Command template |

Read 1–2 sibling files of the same type before auditing. Use them to calibrate what the format should look like — do not impose a format from a different type.

---

## Step 2: Run Audit Checklist

Score every item. Note which fail — these drive the rewrite.

### Structure

- [ ] File has exactly one `#` H1.
- [ ] Heading levels are consistent and not skipped (H1 → H2 → H3, never H1 → H3).
- [ ] Major independent sections are separated by `---`.
- [ ] Code examples are in fenced blocks with a language tag.
- [ ] Sequential steps use numbered lists; unordered items use bullet lists.

### Content Quality

- [ ] Rules are written as constraints ("Do not X"), not descriptions ("X is used for Y").
- [ ] Critical rules appear in the top half of the file, not buried near the bottom.
- [ ] No prose paragraphs where a bullet list would serve better.
- [ ] **Bold** is used only for critical terms, not entire sentences or rules.
- [ ] No rule is duplicated from another file — should be a cross-reference link instead.

### Completeness (method contracts only)

- [ ] Core Rules section present.
- [ ] Examples section present with at least one correct usage snippet — strongly recommended.
- [ ] Prohibitions section present.
- [ ] Failure Signals section present.
- [ ] Checklist section present with `- [ ]` items — every item is binary (yes/no answerable).

### Frontmatter (skill and reference files only)

- [ ] YAML frontmatter present with `name` and `description`.
- [ ] `description` answers "when should an agent read this?".
- [ ] `description` starts with `Use when` or `Read when`.

---

## Step 3: Apply Rewrite Rules

Apply only the fixes the audit identified. Do not change anything that passed.

- **Prose → bullets:** Convert rule paragraphs to bullet lists. One rule per bullet.
- **Bury → top:** Move critical rules or Prohibitions to appear before supplementary detail sections.
- **Missing sections:** Add Prohibitions, Failure Signals, and Checklist sections to method contracts if absent. Derive content only from rules already present in the file — do not invent new rules. Flag a missing Examples section with a comment placeholder — do not invent examples.
- **Frontmatter:** Add or fix YAML frontmatter for skill and reference files.
- **Redundancy:** Replace a duplicated rule with a relative link to its canonical source. Do not delete the rule without linking.
- **Code blocks:** Add fenced block syntax and language tag to bare code examples.
- **Heading fix:** Correct skipped heading levels (e.g. change an H3 to H2 if the H2 level is missing).

### Hard constraints

- Do not change the intent or meaning of any existing rule.
- Do not add new rules — only restructure and complete what is already there.
- Do not remove a rule — only move, reformat, or replace with a cross-reference.
- Do not change file names or move files.

---

## Step 4: Output

After saving the rewritten file, print a one-line diff summary:

```
Improved: added Prohibitions + Failure Signals sections; converted 3 prose paragraphs to bullet lists; added frontmatter.
```

If the file already passed all checklist items, state that explicitly and make no changes.

<!-- This is a repo-local prompt template. Read this before creating a frontend feature slice. -->

# Frontend Feature Template

Create a new frontend feature slice named `$ARGUMENTS`.

If `$ARGUMENTS` is empty, stop and ask the user to provide the feature name first.

---

## Read First

1. Read `.codex/MEMORIES.md`.
2. Read `.codex/documents/ONBOARDING.md`.
3. Read `.codex/Templates/README.md` and this template before creating files.
4. Read `src/StarterPlayerScripts/Contexts/` to understand the existing feature structure before creating anything.
5. Read the Counter feature as the reference implementation and mirror its structure exactly.
6. Read `.codex/documents/architecture/frontend/FRONTEND.md`, `.codex/documents/architecture/frontend/LAYERS.md`, `.codex/documents/architecture/frontend/HOOKS.md`, `.codex/documents/architecture/frontend/COMPONENTS.md`, `.codex/documents/architecture/frontend/DESIGN.md`, and `.codex/documents/architecture/frontend/DEPENDENCY_RULES.md`.
7. Read `.codex/documents/methods/frontend/HOOK_VIEWMODEL_CONTRACTS.md` and `.codex/documents/methods/frontend/TEMPLATE_ORGANISM_CONTRACTS.md`.

---

## Create

- Scaffold the full frontend feature folder structure and boilerplate files.
- Keep the template file under `Presentation/Templates/`.
- Put hooks under `Application/Hooks/` and view models under `Application/ViewModels/`.
- Keep `Presentation/init.lua` as the presentation entry point.
- Create shared types under `Types/` when the feature needs them.

---

## Rules

- Templates are the composition boundary and the only place hooks and view models are wired.
- Read hooks subscribe to state; write hooks do not.
- Keep business logic out of presentation components.
- Do not use cross-feature imports.
- Keep feature layout aligned with the repo's existing frontend conventions.

---

## Output

- Report every file and folder created.
- Report any entry wiring added in `Presentation/init.lua`.

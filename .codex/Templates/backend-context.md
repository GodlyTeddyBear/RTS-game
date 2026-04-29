<!-- This is a repo-local prompt template. Read this before creating a new backend context. -->

# Backend Context Template

Create a new backend bounded context named `$ARGUMENTS`.

If `$ARGUMENTS` is empty, stop and ask the user to provide the context name first.

---

## Read First

1. Read `.codex/MEMORIES.md`.
2. Read `.codex/documents/ONBOARDING.md`.
3. Read `.codex/Templates/README.md` and this template before creating files.
4. Read `.codex/commands/new-context.md` if you need the current scaffold shape.
5. Read the existing context tree for naming and structure before creating anything.
6. Read `.codex/documents/architecture/backend/BACKEND.md`, `.codex/documents/architecture/backend/DDD.md`, and `.codex/documents/architecture/backend/ERROR_HANDLING.md`.
7. Read `.codex/documents/methods/backend/BASE_CONTEXT_CONTRACTS.md` and `.codex/documents/methods/backend/BASE_APPLICATION_CONTRACTS.md`.

---

## Create

- Scaffold the backend context folder structure using the repo's standard context layout.
- Create the context entry module, `Errors.lua`, application folders, domain folders, infrastructure folders, and shared types folders.
- Use `Infrastructure/Persistence` for any sync service or persistence bridge modules.
- Keep shared context types centralized in `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`.

---

## Rules

- Context entry modules must stay as pass-through bridges.
- Reuse `Errors.lua` constants instead of inline error strings.
- Use `Result` boundaries for public server-to-server context methods.
- Register the new context in its context entry file and any related registries.
- Do not create `Application/Services/`.
- Do not place `*SyncService` modules under `Infrastructure/Services/`.

---

## Output

- Report every file and folder created.
- Report any wiring added in the context entry or registries.

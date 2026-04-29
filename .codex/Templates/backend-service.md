<!-- This is a repo-local prompt template. Read this before creating a backend module inside an existing context. -->

# Backend Service Template

Add a new backend module to an existing bounded context.

`$ARGUMENTS` format: `<ContextName> <Kind> <Name>`

If `$ARGUMENTS` is empty, stop and ask the user to provide the context, kind, and name first.

---

## Read First

1. Read `.codex/MEMORIES.md`.
2. Read `.codex/documents/ONBOARDING.md`.
3. Read `.codex/Templates/README.md` and this template before creating files.
4. Read the existing context tree and the target context entry before creating anything.
5. Read `.codex/commands/new-service.md` if you need the current scaffold shape.
6. Read `.codex/documents/architecture/backend/BACKEND.md`, `.codex/documents/architecture/backend/ERROR_HANDLING.md`, and `.codex/documents/methods/backend/BASE_APPLICATION_CONTRACTS.md`.
7. Read `.codex/documents/methods/backend/CONTEXT_BOUNDARIES.md` when the module participates in context wiring.
8. Read `.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md` when the module is persistence or sync related.

---

## Create

- Create exactly one module at the target path for the requested kind.
- Use `Application/Commands` or `Application/Queries` for application modules.
- Use the domain folders only when the requested kind is domain-specific.
- Use `Infrastructure/Services`, `Infrastructure/Persistence`, or `Infrastructure/ECS` based on the requested kind.
- Put any `*SyncService` module under `Infrastructure/Persistence`.
- Add shared context types to `<ContextName>Types.lua` when the new module needs a shared shape.

---

## Rules

- Commands and queries must respect `Result` contracts and layer boundaries.
- Queries stay read-only.
- Commands mutate through infrastructure, not directly through presentation or context bridges.
- Reuse existing `Errors.lua` constants and shared context types.
- Keep context entry wiring minimal and pass-through.
- Do not create duplicate shapes in multiple modules.

---

## Output

- Report the file created.
- Report any context wiring added.
- Report any shared type additions.

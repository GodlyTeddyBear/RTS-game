# Templates

Canonical scaffold references for new files in this repo.

---

## Purpose

- Use these templates as copy-paste references for the file shape and a simple working example.
- Replace names and paths, then trim or expand only the feature-specific behavior.
- Prefer the template that matches the exact creation target.

---

## Templates

### Backend

- [Backend Context](backend-context.md) - Bare scaffold for a new backend bounded context.
- [Backend Service](backend-service.md) - Bare module skeleton for a module inside an existing backend context.
- [Backend SyncService](backend-syncservice.md) - Bare sync-service skeleton for a backend context.

### Frontend

- [Frontend Feature](frontend-feature.md) - Bare scaffold for a new frontend feature slice.

### Shared Utilities

- [AI System](ai-system.md) - Scaffold for a context-owned AI system built on the shared AI utility package.
- [Shared Utility](shared-utility.md) - Scaffold for reusable helpers such as `PlacementPlus`, `SpatialQuery`, `Orient`, `StateMachine`, and `ModelPlus`.

---

## Rules

- Keep the scaffolds minimal.
- Include only the files, folders, and module shapes that belong in the first commit.
- Let the target doc show the structure, not a long workflow checklist.

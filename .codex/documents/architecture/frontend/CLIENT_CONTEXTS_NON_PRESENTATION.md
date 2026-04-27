# Client Contexts (Non-Render)

Defines the structure and dependency rules for client context modules that own runtime orchestration and technical integration.

---

## Overview

- This document governs controller, application, and infrastructure modules in client contexts.
- A context may contain one controller or multiple controllers.
- Layer intent matches server-side separation:
- Application owns orchestration and use-case flow.
- Infrastructure owns technical IO and runtime clients.
- Canonical method contract:
- [../../methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md](../../methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md)

---

## Rules

### Controller Layout

- Allowed controller layouts:
- `[Context]/[Context]Controller.lua`
- `[Context]/Controllers/*.lua`
- Multiple controllers in the same context are valid.
- Controllers own context lifecycle entrypoints, coordination wiring, and boundary calls into application modules.

### Application Layer

- Application modules expose use-case entrypoints (for example Commands and Queries).
- Application modules coordinate dependencies and workflow order.
- Application modules delegate technical operations to infrastructure modules.

### Infrastructure Layer

- Infrastructure modules own runtime clients and technical adapters.
- Infrastructure modules own transport wrappers, sync clients, and state synchronization adapters.
- Infrastructure modules do not own context-level orchestration.

### Dependency Direction

- Dependency flow is one-way:
- `Controllers -> Application -> Infrastructure -> ReplicatedStorage`
- Upward imports are prohibited.

---

## Examples

```text
StarterPlayerScripts/
`-- Contexts/
    `-- Placement/
        |-- PlacementController.lua
        |-- Controllers/
        |   `-- PlacementCursorController.lua
        |-- Application/
        |   |-- Commands/
        |   `-- Queries/
        `-- Infrastructure/
            |-- PlacementSyncClient.lua
            `-- Services/
```

```lua
-- Controller -> Application
function PlacementController:KnitStart()
    self._placeCommand:Execute(...)
end

-- Application -> Infrastructure
function PlaceStructureCommand:Execute(payload)
    return self._placementRuntimeClient:Send(payload)
end
```

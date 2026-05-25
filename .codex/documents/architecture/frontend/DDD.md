# Frontend DDD

This document defines the DDD-shaped structure for non-render frontend client contexts.

Frontend presentation architecture is documented separately in [FRONTEND.md](FRONTEND.md). This page covers the context controller, application, and infrastructure boundaries used by client-side orchestration modules.

---

## Overview

- Frontend client contexts use a DDD-style boundary split with one controller layer, one application layer, and one infrastructure layer.
- The controller layer is the entrypoint for the context.
- The application layer owns use-case orchestration and follows the same command/query split used on the server.
- The infrastructure layer owns technical services and persistence clients.
- Dependency flow is one-way: `Controllers -> Application -> Infrastructure -> ReplicatedStorage`.

---

## Rules

### Controller Layer (`[ContextName]Controller.lua`, `Controllers/`)

- Every client context must have one root controller file.
- A context may also have any number of additional controllers in a `Controllers/` folder.
- Controllers own lifecycle entrypoints, orchestration wiring, and calls into application modules.
- Controllers do not own low-level sync, transport, or persistence wiring.
- Controller folder grouping may mirror backend context grouping when that keeps orchestration clear.

### Application Layer (`Application/Commands/`, `Application/Queries/`)

- Commands own write-flow orchestration.
- Queries own read-flow orchestration.
- Application modules coordinate dependencies and sequence context behavior.
- Application modules delegate technical IO to infrastructure modules.
- Application modules do not import controller modules.

### Infrastructure Layer (`Infrastructure/Services/`, `Infrastructure/Persistence/`)

- Services own runtime clients and technical adapters.
- Persistence owns sync clients, persistence-facing adapters, and state bridge modules.
- Infrastructure modules expose narrow APIs that the application layer consumes.
- Infrastructure modules do not own context-level orchestration.

### Dependency Direction

- Imports must flow downward only.
- Upward imports are prohibited across controller, application, and infrastructure boundaries.
- The context controller must not bypass application modules to reach infrastructure directly.

### Context Structure

```text
src/StarterPlayerScripts/Contexts/
`-- [ContextName]/
    |-- [ContextName]Controller.lua
    |-- Controllers/
    |   |-- [ContextName]PlacementController.lua
    |   `-- [ContextName]CameraController.lua
    |-- Application/
    |   |-- Commands/
    |   `-- Queries/
    |-- Infrastructure/
    |   |-- Persistence/
    |   `-- Services/
    |-- Config/
    `-- Types/
```

---

## Examples

```lua
-- Correct: controller delegates orchestration to application
function PlacementController:ConfirmPlacement(payload)
    return self._placeStructureCommand:Execute(payload)
end

-- Correct: application delegates technical work to infrastructure
function PlaceStructureCommand:Execute(payload)
    return self._placementRuntimeClient:SendPlaceRequest(payload)
end
```

```lua
-- Wrong: controller owns the technical transport call directly
function PlacementController:ConfirmPlacement(payload)
    return self._placementRuntimeClient:SendPlaceRequest(payload)
end
```

---

## Related Contracts

- [../../methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md](../../methods/frontend/CLIENT_CONTEXT_NON_PRESENTATION_CONTRACTS.md) for controller, application, and infrastructure method boundaries.
- [../../methods/frontend/CONTROLLER_INFRA_CONTRACTS.md](../../methods/frontend/CONTROLLER_INFRA_CONTRACTS.md) for controller hook and infrastructure side-effect ownership.
- [../../methods/backend/BASE_APPLICATION_CONTRACTS.md](../../methods/backend/BASE_APPLICATION_CONTRACTS.md) for shared command/query helper behavior when a client context reuses base application helpers.


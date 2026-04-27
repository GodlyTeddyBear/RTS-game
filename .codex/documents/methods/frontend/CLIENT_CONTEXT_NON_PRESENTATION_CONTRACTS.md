# Frontend Client Context (Non-Render) Contracts

Defines strict method contracts for client context modules that own controller, application, and infrastructure responsibilities.

Canonical architecture references:
- [../../architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md](../../architecture/frontend/CLIENT_CONTEXTS_NON_PRESENTATION.md)
- [../../architecture/frontend/DEPENDENCY_RULES.md](../../architecture/frontend/DEPENDENCY_RULES.md)

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Controller Contract

- A context may define one controller or multiple controllers.
- Controllers own lifecycle entrypoints and orchestration wiring for the context.
- Controllers call application entrypoints as their default dependency boundary.
- Controller modules do not implement low-level transport or sync wiring directly.

---

## Application Command/Query Contract

- Application Commands orchestrate write flows and coordinate dependencies.
- Application Queries orchestrate read flows and return read results.
- Application modules delegate technical IO to infrastructure modules.
- Application modules keep use-case sequencing and policy decisions at the application boundary.

---

## Infrastructure Contract

- Infrastructure modules own runtime clients and technical integration details.
- Infrastructure modules own transport wrappers, sync clients, and persistence/sync adapters.
- Infrastructure modules expose narrow method APIs consumed by application modules.
- Infrastructure modules do not own context-level orchestration.

---

## Examples

```lua
-- Correct: controller delegates orchestration to application command
function PlacementController:ConfirmPlacement(payload)
    return self._placeStructureCommand:Execute(payload)
end

-- Correct: application delegates technical call to infrastructure client
function PlaceStructureCommand:Execute(payload)
    return self._placementRuntimeClient:SendPlaceRequest(payload)
end
```

```lua
-- Wrong: controller owns technical transport call directly
function PlacementController:ConfirmPlacement(payload)
    return self._placementRuntimeClient:SendPlaceRequest(payload)
end
```

---

## Prohibitions

- Do not restrict a context to a single controller by convention.
- Do not let controllers own low-level transport or sync wiring.
- Do not let application modules import controller modules.
- Do not let infrastructure modules import controller or application modules.
- Do not bypass application orchestration by calling infrastructure clients from unrelated boundaries without an explicit adapter contract.

---

## Failure Signals

- A client context requires direct infrastructure calls from controllers as the primary flow.
- Application modules contain raw transport wiring or sync listener setup.
- Infrastructure modules import application modules for orchestration logic.
- Controller count is artificially constrained even when context responsibilities are split across multiple runtime workflows.

---

## Checklist

- [ ] Context allows one or many controllers based on runtime ownership needs.
- [ ] Controllers orchestrate lifecycle and call application entrypoints.
- [ ] Commands and Queries own use-case flow in application modules.
- [ ] Infrastructure owns technical IO clients and sync adapters.
- [ ] Dependency direction is one-way: `Controllers -> Application -> Infrastructure -> ReplicatedStorage`.
- [ ] No upward imports are present across these layers.

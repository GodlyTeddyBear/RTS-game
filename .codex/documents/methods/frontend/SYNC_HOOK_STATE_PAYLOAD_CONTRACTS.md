# Frontend Sync Hook + Payload Contracts

Defines strict contracts for consuming sync-backed state in frontend feature slices.

Canonical architecture references:
- [../../architecture/frontend/LAYERS.md](../../architecture/frontend/LAYERS.md)
- [../../architecture/frontend/HOOKS.md](../../architecture/frontend/HOOKS.md)
- [../../architecture/frontend/DEPENDENCY_RULES.md](../../architecture/frontend/DEPENDENCY_RULES.md)
- [../../architecture/backend/STATE_SYNC.md](../../architecture/backend/STATE_SYNC.md)

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Sync Payload Contract

- Sync infrastructure consumes explicit payload envelopes (for example `init` and `patch`) and applies them deterministically.
- Payload handlers must tolerate optional payload sections (for example missing `data` or missing collection field) without crashing.
- Feature consumers treat payload data as snapshot input; they do not mutate payload tables in-place.
- Field semantics must remain stable across server and client generated contracts (for example worker ID map key + worker data object shape).


---
## Atom Ownership Contract

- Infrastructure modules own atom creation and network sync wiring.
- Application and presentation layers consume atom state through hooks, not direct network listeners.
- Sync-backed atom updates must flow through centralized sync clients/services, not ad hoc atom writes in templates.


---
## Read/Write Hook Contract For Sync State

- Read hooks (`useX`) subscribe/select sync-backed atom state and return read data only.
- Write hooks (`useXActions`) expose mutation/command callbacks only and never subscribe to atoms.
- Write hooks delegate to controller/service commands and do not embed payload-shape logic.


---
## Screen Controller Contract For Sync State

- Screen controllers compose read hooks, write hooks, and cross-context state into a minimal UI API.
- Controllers may route role/type-based action dispatch, but payload normalization stays in infrastructure.
- Controllers handle UI-side side effects (sounds, navigation, delayed callbacks) and keep templates declarative.


---
## ViewModel Contract For Sync State

- ViewModels transform raw sync-backed entities into frozen UI models (`table.freeze(...)`).
- ViewModels own derived labels, formatting, and computed display fields.
- ViewModels remain pure: no subscriptions, no network calls, no runtime side effects.


---
## Non-Normative Generic Example

```lua
-- Infrastructure payload envelope
type SyncPayload =
    { type: "init", data: { entities: { [string]: TEntity }? }? } |
    { type: "patch", data: { entities: { [string]: TEntity }? }? }

-- Infrastructure sync client owns listener + atom writes
local FeatureSyncClient = BaseSyncClient.new(BlinkClient, "SyncFeature", "entities", SharedAtoms.CreateClientAtom)

-- Read hook subscribes only
local function useFeatureState()
    return ReactCharm.useAtom(featureController:GetEntitiesAtom()) or {}
end

-- Write hook dispatches commands only
local function useFeatureActions()
    return {
        runCommand = function(id: string)
            return featureController:RunCommand(id)
        end,
    }
end

-- ViewModel is pure + frozen
function FeatureViewModel.fromEntity(entity: TEntity)
    return table.freeze({
        Id = entity.Id,
        DisplayName = entity.Name,
    })
end
```

Flow:
- Infrastructure handles payload decoding + optional fields.
- Read hook exposes current atom state.
- Write hook sends commands without subscribing.
- Controller composes callbacks/state for the template.
- ViewModel transforms raw sync entity into UI-ready display data.


---
## Non-Normative Example (Worker)

- Server sync event provides `init`/`patch` envelopes with a worker map payload.
- Worker sync client owns Blink listener + atom updates.
- `useWorkerState` reads atom state, `useWorkerActions` sends commands, and `useWorkersScreenController` orchestrates view behavior.
- `WorkerViewModel.fromWorker(...)` derives display fields from raw worker sync records.


---
## Prohibitions

- Do not subscribe to atoms inside write hooks.
- Do not place network payload decode/shape branching in templates or pure views.
- Do not mutate sync payload objects directly in controllers or viewmodels.
- Do not bypass infrastructure sync clients by writing sync-backed atoms from presentation.


---
## Failure Signals

- A `useXActions` hook calls `useAtom`.
- A template or `*View.lua` imports network generated modules directly.
- Controller code contains low-level payload parsing that should live in infrastructure sync client modules.
- ViewModel code performs side effects or returns mutable tables.


---
## Checklist

- [ ] Sync payload envelopes and optional sections are handled safely in infrastructure.
- [ ] Infrastructure owns atom creation and sync wiring.
- [ ] `useX` (read) and `useXActions` (write) are separated.
- [ ] Screen controllers orchestrate UI behavior without taking over payload parsing responsibilities.
- [ ] ViewModel output is frozen, pure, and formatting-focused.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->


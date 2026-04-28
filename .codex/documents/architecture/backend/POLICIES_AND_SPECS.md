# Policies and Specifications

Policies and Specifications separate eligibility checking from orchestration. Specifications are composable predicates that encode business rules. Policies fetch state and evaluate specs, returning the fetched state on success so Application commands do not double-read.

---

## Related Docs

- [DDD.md](DDD.md) for the layer boundaries that place Policies in Domain.
- [CQRS.md](CQRS.md) for command/query separation and restore-command behavior.
- [ERROR_HANDLING.md](ERROR_HANDLING.md) for `Result`, `Try`, `Ensure`, and `Catch`.

---

## Layer Model

```text
Context Layer       -> Catch boundary (pure pass-through)
Application Command  -> Try(policy:Check(player)) -> execute
Domain Policy        -> fetch state -> build candidate -> evaluate specs
Domain Specs         -> pure predicates, no side effects, no state fetching
Infrastructure       -> LotAreaRegistry, SyncService, and other state sources
```

- Policies live in the Domain layer.
- Policies depend on Infrastructure to fetch state and on Specs to evaluate rules.
- Application commands depend on policies instead of manually fetching state and calling validators.

---

## Folder Structure

```text
[ContextName]Domain/
|-- Services/         # Validators, calculators (existing)
|-- ValueObjects/     # Immutable domain objects (existing)
|-- Specs/            # Composable eligibility rules (new)
|   `-- [Context]Specs.lua
`-- Policies/         # State fetch + spec evaluation (new)
    `-- [Operation]Policy.lua
```

---

## Specifications

A specification is a module-level constant that encapsulates a single eligibility rule.

- A spec is a pure predicate.
- Given a candidate, it returns true or false.
- It never fetches state.

### Construction

Specs use the `Specification` utility from `ReplicatedStorage/Utilities/Specification.lua`.

```lua
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

local HasNoActiveExpedition = Spec.new(
    "AlreadyOnExpedition",        -- error type
    Errors.ALREADY_ON_EXPEDITION, -- error message (from Errors.lua)
    function(ctx: TDepartureCandidate)
        return ctx.ActiveExpedition == nil
    end
)
```

### Candidate Types

- Each spec takes a purpose-built candidate type containing exactly the state the predicate needs.
- All specs that compose together must share the same candidate type.
- The policy builds the candidate.
- The spec evaluates it.

```lua
export type TClaimCandidate = {
    AreaName: string,
    AreaExists: boolean,
    AreaClaimedBy: Player?,
    PlayerCurrentClaim: string?,
}
```

### Composition

Specs compose via `:And()`, `:Or()`, `:Not()`, `Spec.All()`, and `Spec.Any()`.

```lua
-- AreaNameValid short-circuits first. The rest accumulate failures via TryAll.
local CanClaim = AreaNameValid:And(Spec.All({ AreaExists, AreaNotClaimed, PlayerHasNoClaim }))

-- Single spec - no composition needed.
local CanRelease = PlayerHasClaim
```

| Combinator | Behavior |
|---|---|
| `a:And(b)` | Both must pass. Failures accumulate via `TryAll`. |
| `a:Or(b)` | Either must pass. Short-circuits on first success. |
| `a:Not(errType, msg)` | Inverts the spec and requires new error information for the negated case. |
| `Spec.All({...})` | All must pass. Accumulates all failures. |
| `Spec.Any({...})` | Any must pass. Returns the last failure if all fail. |

### What Specs Replace

Specs replace the private `_check` methods that previously lived in domain validators.

| Before (Validator) | After (Spec) |
|---|---|
| `Validator:_checkAreaExists(bool)` | `AreaExists` spec constant |
| `Validator:_checkAreaNotClaimed(player?)` | `AreaNotClaimed` spec constant |
| `Validator:ValidateClaim(a, b, c, d)` | `CanClaim:IsSatisfiedBy(candidate)` |

- The old validator method accepted four separate arguments.
- The spec accepts a single typed candidate.
- The policy builds the candidate.

### Module Structure

- Keep one specs file per context.
- Export only the composed specs, not the individual ones.

```lua
-- Individual specs (local, not exported)
local AreaExists = Spec.new(...)
local AreaNotClaimed = Spec.new(...)
local PlayerHasNoClaim = Spec.new(...)

-- Composed specs (exported)
local CanClaim = Spec.All({ AreaExists, AreaNotClaimed, PlayerHasNoClaim })
local CanRelease = PlayerHasClaim

return table.freeze({
    CanClaim = CanClaim,
    CanRelease = CanRelease,
})
```

---

## Policies

A policy fetches state from Infrastructure, builds a candidate, evaluates a composed spec, and returns the fetched state on success.

### Why Policies Exist

Without policies, the Application command manually fetches state from multiple services, passes it as individual arguments to a validator, and then uses some of that state again for execution.

That tangles three concerns:

1. What state is needed.
2. Whether the operation is permitted.
3. What to do.

- The policy owns concerns 1 and 2.
- The command owns concern 3.

### Contract

```lua
function Policy:Check(player: Player): Result<TPolicyResult>
```

- Returns `Ok(data)` when the player is eligible.
- `data` contains fetched state the caller needs.
- Returns `Err(...)` for a structured failure from the spec or an `Ensure` guard.
- Called inside a `Catch` boundary so failures propagate via `Try()`.

### Structure

```lua
local MyPolicy = {}
MyPolicy.__index = MyPolicy

function MyPolicy.new(): TMyPolicy
    local self = setmetatable({}, MyPolicy)
    self._registry = nil :: any
    return self
end

function MyPolicy:Init(registry: any, _name: string)
    self._registry = registry:Get("SomeRegistry")
end

function MyPolicy:Check(player: Player): Result.Result<TPolicyResult>
    -- 1. Fetch state from Infrastructure
    local state = self._registry:GetSomeState(player)
    Ensure(state, "StateNotFound", Errors.STATE_NOT_FOUND)

    -- 2. Build candidate
    local candidate: TCandidate = {
        SomeField = state.SomeField,
        OtherField = self._registry:GetOtherField(player),
    }

    -- 3. Evaluate spec
    Try(Specs.CanDoSomething:IsSatisfiedBy(candidate))

    -- 4. Return fetched state
    return Ok({ RelevantField = candidate.SomeField })
end
```

### Key Properties

- Policies return fetched state. The policy already read Infrastructure to build the candidate, so returning that data prevents a second fetch.
- One policy per operation. `ClaimPolicy` and `ReleasePolicy` are separate because they fetch different state and evaluate different specs.
- Policies live in Domain and depend on Infrastructure. This is the one place where Domain touches Infrastructure, and only to bridge state into spec evaluation.
- Policies register in the `"Domain"` category in the registry, the same as validators.

### Command-Invoked vs. Tick-Loop Policies

- Command-invoked policies use `Try()` to evaluate the spec.
- Tick-loop policies return the `Err` instead of throwing.

Command-invoked policy failure is exceptional. The player attempted something they should not have done, so the throw propagates to the `Catch` boundary, which logs and returns the error to the client.

```lua
-- Command-invoked policy: throw on spec failure.
Try(Specs.CanDoSomething:IsSatisfiedBy(candidate))
return Ok({ ... })
```

```lua
-- Command calls with Try - unwraps value or propagates throw.
local ctx = Try(self._policy:Check(player))
```

Tick-loop policy failure is normal. The worker may not have accumulated enough production, the mining timer may not have elapsed, or the BT interval may not be ready yet.

If the policy throws in a tick loop, the error bypasses the command's `if not result.success` guard and hits the top-level `Catch`, producing a warn on every tick for every entity that is not ready yet.

```lua
-- Tick-loop policy: return Err so the caller can silently skip.
local specResult = Specs.CanDoSomething:IsSatisfiedBy(candidate)
if not specResult.success then return specResult end
return Ok({ ... })
```

```lua
-- Tick-loop command checks .success and skips silently.
local policyResult = self._policy:Check(workerData, currentTime)
if not policyResult.success then return end
local ctx = policyResult.value
```

- If spec failure means "not ready yet" rather than "invalid request," the policy should return the `Err`.

---

## How Commands Change

### Before (validator pattern)

```lua
function ClaimService:Execute(player)
    -- Fetch state (Application knows which registry methods to call)
    local areaName = self._registry:FindFirstAvailable()
    local areaExists = self._registry:AreaExists(areaName)
    local areaClaimedBy = self._registry:GetClaimant(areaName)
    local playerClaim = self._registry:GetPlayerClaim(player)

    -- Validate (pass individual values)
    Try(self._validator:ValidateClaim(areaName, areaExists, areaClaimedBy, playerClaim))

    -- Execute
    self._registry:SetClaim(areaName, player)
    ...
end
```

### After (policy pattern)

```lua
function ClaimService:Execute(player)
    -- Policy: fetch state + evaluate eligibility
    local ctx = Try(self._claimPolicy:Check(player))

    -- Execute
    self._registry:SetClaim(ctx.AreaName, player)
    ...
end
```

- The command goes from multiple fetch-and-validate steps to one policy call.
- The policy encapsulates the fetch and validation work.

---

## Registration

Policies register in the Domain layer and resolve Infrastructure dependencies via `Init()`.

```lua
function ContextName:KnitInit()
    local registry = Registry.new("Server")

    -- Infrastructure
    registry:Register("SomeRegistry", SomeRegistry.new(), "Infrastructure")

    -- Domain
    registry:Register("ClaimPolicy", ClaimPolicy.new(), "Domain")
    registry:Register("ReleasePolicy", ReleasePolicy.new(), "Domain")

    -- Application
    registry:Register("ClaimService", ClaimService.new(), "Application")

    registry:InitAll()
end
```

---

## Restore Commands

When a player rejoins and entities are reconstructed, restore commands must re-run the same Infrastructure-side effects that the original assign command ran, including slot claims, position updates, and active state.

### Rule: restore commands must mirror their Application Command

- A restore command is not a simplified version of the assign command.
- It is the same command with specific steps skipped.
- Skipping a policy check to "save time" is dangerous because policies often return resolved state such as live instances or entity references that the command needs.
- Bypassing the policy means re-resolving that state yourself, which duplicates logic and is error-prone.

**Steps to skip on restore:**

| Step | Reason to skip |
|---|---|
| Assign task target | Already restored from persisted data |
| Persist to ProfileStore | Data is already correct in the store |
| Sync to client atom | Atom is already populated by `LoadUserWorkers` |

**Steps to keep:**

| Step | Reason to keep |
|---|---|
| Policy check | Resolves live instances such as ore models and entity refs needed by subsequent steps |
| Claim slot / register state | Re-registers in-memory tracking such as `MiningSlotService.SlotMap` |
| `UpdatePosition` | Teleports the model to the correct world position |
| `StartMining` / start active state | Restarts the production loop |

### Timing

- `UpdatePosition` teleports via `GameObjectComponent`, so the model must already exist.
- Restore commands must run after `SyncDirtyEntities` has flushed the newly created entities.
- `LotSpawned` must fire after the lot's `SyncDirtyEntities` flush so zone sub-entities such as Mines and Farm exist when the policy queries them.

### Pattern

```lua
-- In Context._SpawnWorkersFromPendingData:

-- Pass 1: create entities, restore static state
for workerId, workerData in workersData do
    self:_RestoreWorker(userId, workerId, workerData)
end

-- Flush so models exist in workspace
self.GameObjectSyncService:SyncDirtyEntities()

-- Pass 2: restore dynamic state (position, slot claims, active states)
for workerId, workerData in workersData do
    if workerData.AssignedTo == "Miner" and workerData.TaskTarget then
        self:_HydrateMinerAssignment(userId, workerId, workerData.TaskTarget)
    end
end
```

```lua
-- _HydrateMinerAssignment mirrors AssignMinerOre:Execute, skipping persist/sync/assign target.
function WorkerContext:_HydrateMinerAssignment(userId, workerId, oreId)
    local result = self.AssignMinerOrePolicy:Check(userId, workerId, oreId)
    if not result.success then return end

    local entity = result.value.Entity
    local oreInstance = result.value.OreInstance -- resolved by policy, not re-fetched

    local slotIndex, standPos, lookAtPos =
        self.MiningSlotService:ClaimSlot(userId, workerId, oreId, oreInstance:GetPivot(), oreInstance)

    self.EntityFactory:AssignSlotIndex(entity, slotIndex)
    self.EntityFactory:UpdatePosition(entity, standPos.X, standPos.Y, standPos.Z, lookAtPos.X, lookAtPos.Y, lookAtPos.Z)
    self.EntityFactory:StartMining(entity, oreId, oreConfig.MiningDuration)
end
```

---

## Policy vs. Validator vs. Specification

| | Specification | Validator | Policy |
|---|---|---|---|
| Asks | Is this data valid? | Are all inputs valid? | Is this operation permitted? |
| Receives | A typed candidate | Individual arguments | A player or userId |
| Fetches state | Never | Never | Yes, from Infrastructure |
| Returns | `Result<T>` (`Ok` / `Err`) | `Result<{ any }>` via `TryAll` | `Result<TPolicyResult>` with fetched data |
| Composes | `:And()`, `:Or()`, `Spec.All()` | Accumulates via `TryAll` | Not composable, one per operation |
| Lives in | `Domain/Specs/` | `Domain/Services/` | `Domain/Policies/` |
| Used by | Policies internally | Application commands, legacy | Application commands |

### When to use which

- **Spec**: a single named rule you want to reuse or compose. Keep it as a module-level constant.
- **Policy**: an operation's full eligibility check: fetch state, build candidate, evaluate specs, return state.
- **Validator**: legacy pattern. New contexts should use Specs plus Policies instead.

---

## Checklist

**Specs:**

- [ ] Module-level constants only; never constructed inside functions.
- [ ] One specs file per context (`[Context]Specs.lua`).
- [ ] Export only composed specs, not individual ones.
- [ ] Candidate types exported for policies to use.
- [ ] Error messages come from `Errors.lua`; no inline strings.

**Policies:**

- [ ] One policy per operation.
- [ ] `Check()` returns `Result<T>` with fetched state on success.
- [ ] Registered in the Domain category.
- [ ] Dependencies are resolved via `Init()` from the registry.
- [ ] Command-invoked policies use `Try()` for spec evaluation.
- [ ] Tick-loop policies return the spec `Err` directly.

**Application Commands:**

- [ ] Command-invoked code calls `Try(policy:Check(player))` and unwraps or propagates the throw.
- [ ] Tick-loop code calls `policy:Check(...)`, checks `.success`, and reads `.value`.
- [ ] Returned context data is used instead of re-fetching from Infrastructure.
- [ ] Direct Infrastructure fetches used only for validation are removed.

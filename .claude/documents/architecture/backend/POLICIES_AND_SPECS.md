# Policies and Specifications

Policies and Specifications separate eligibility checking from orchestration. Specifications are composable predicates that encode business rules. Policies fetch state and evaluate specs, returning the fetched state on success so Application commands don't double-read.

---

## How They Relate to Existing Layers

```
Context Layer         → Catch boundary (pure pass-through)
      ↓
Application Command   → Try(policy:Check(player))  →  execute
      ↓                        ↓
Domain Policy         → fetch state → build candidate → evaluate specs
      ↓                                                      ↓
Domain Specs          → pure predicates, no side effects, no state fetching
      ↓
Infrastructure        → LotAreaRegistry, SyncService, etc.
```

Policies live in the Domain layer. They depend on Infrastructure (to fetch state) and Specs (to evaluate rules). Application commands depend on policies instead of manually fetching state and calling validators.

---

## Folder Structure

```
[ContextName]Domain/
├── Services/         # Validators, calculators (existing)
├── ValueObjects/     # Immutable domain objects (existing)
├── Specs/            # Composable eligibility rules (new)
│   └── [Context]Specs.lua
└── Policies/         # State fetch + spec evaluation (new)
    └── [Operation]Policy.lua
```

---

## Specifications

A Specification is a module-level constant that encapsulates a single eligibility rule. It is a pure predicate — given a candidate, return true or false. It never fetches state.

### Construction

Specs use the `Specification` utility from `ReplicatedStorage/Utilities/Specification.lua`.

```lua
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

local HasNoActiveExpedition = Spec.new(
    "AlreadyOnExpedition",           -- error type
    Errors.ALREADY_ON_EXPEDITION,    -- error message (from Errors.lua)
    function(ctx: TDepartureCandidate)
        return ctx.ActiveExpedition == nil
    end
)
```

### Candidate Types

Each spec takes a purpose-built candidate type containing exactly the state the predicate needs. All specs that compose together must share the same candidate type.

```lua
export type TClaimCandidate = {
    AreaName: string,
    AreaExists: boolean,
    AreaClaimedBy: Player?,
    PlayerCurrentClaim: string?,
}
```

The policy builds the candidate. The spec evaluates it. They are decoupled by the candidate type.

### Composition

Specs compose via `:And()`, `:Or()`, `:Not()`, `Spec.All()`, and `Spec.Any()`.

```lua
-- AreaNameValid short-circuits first. The rest accumulate failures via TryAll.
local CanClaim = AreaNameValid:And(Spec.All({ AreaExists, AreaNotClaimed, PlayerHasNoClaim }))

-- Single spec — no composition needed.
local CanRelease = PlayerHasClaim
```

| Combinator | Behavior |
|-----------|----------|
| `a:And(b)` | Both must pass. Failures accumulated via TryAll. |
| `a:Or(b)` | Either must pass. Short-circuits on first success. |
| `a:Not(errType, msg)` | Inverts. Requires new error info for the negated case. |
| `Spec.All({...})` | All must pass. Accumulates all failures. |
| `Spec.Any({...})` | Any must pass. Returns last failure if all fail. |

### What Specs Replace

Specs replace the private `_check` methods that previously lived in domain validators:

| Before (Validator) | After (Spec) |
|---------------------|--------------|
| `Validator:_checkAreaExists(bool)` | `AreaExists` spec constant |
| `Validator:_checkAreaNotClaimed(player?)` | `AreaNotClaimed` spec constant |
| `Validator:ValidateClaim(a, b, c, d)` | `CanClaim:IsSatisfiedBy(candidate)` |

The validator's `ValidateClaim` method accepted 4 separate arguments. The spec accepts a single typed candidate — the policy builds it.

### Module Structure

One specs file per context. Export only the composed specs, not the individual ones.

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

A Policy fetches state from Infrastructure, builds a candidate, evaluates a composed spec, and returns the fetched state on success.

### Why Policies Exist

Without policies, the Application command manually fetches state from multiple services, passes it as individual arguments to a validator, and then uses some of that state again for execution. This tangles three concerns:

1. **What state is needed** (which registry methods to call)
2. **Whether the operation is permitted** (the business rule)
3. **What to do** (the actual operation)

The policy owns concerns 1 and 2. The command owns concern 3.

### Contract

```lua
function Policy:Check(player: Player): Result<TPolicyResult>
```

- Returns `Ok(data)` — the player is eligible. `data` contains fetched state the caller needs.
- Returns `Err(...)` — structured failure from the spec or an Ensure guard.
- Called inside a `Catch` boundary — failures propagate via `Try()`.

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

- **Returns fetched state.** The policy already had to read from Infrastructure to build the candidate. Returning that data in the `Ok` result means the command doesn't re-fetch it.
- **One policy per operation.** `ClaimPolicy` and `ReleasePolicy` are separate. They fetch different state and evaluate different specs.
- **Lives in Domain, depends on Infrastructure.** This is the one place where the Domain layer touches Infrastructure — justified because the policy's purpose is to bridge state into spec evaluation.
- **Registered in the Domain category.** Policies register with `"Domain"` in the Registry, same as validators.

### Command-Invoked vs. Tick-Loop Policies

Policies called from **player-initiated commands** (buy, hire, assign, etc.) use `Try()` to evaluate the spec. Failure is exceptional — the player attempted something they shouldn't. The throw propagates to the `Catch` boundary, which logs and returns the error to the client.

```lua
-- Command-invoked policy: throw on spec failure
Try(Specs.CanDoSomething:IsSatisfiedBy(candidate))
return Ok({ ... })
```

```lua
-- Command calls with Try — unwraps value or propagates throw
local ctx = Try(self._policy:Check(player))
```

Policies called from **tick loops** (production ticks, mining ticks, BT ticks, etc.) must **return** the Err instead of throwing. In a tick loop, spec failure is normal — the worker hasn't accumulated enough production, the mining timer hasn't elapsed, the BT interval isn't ready. If the policy throws, the error bypasses the command's `if not result.success` guard and hits the top-level `Catch`, producing a warn on every tick for every entity that isn't ready yet.

```lua
-- Tick-loop policy: return Err so the caller can silently skip
local specResult = Specs.CanDoSomething:IsSatisfiedBy(candidate)
if not specResult.success then return specResult end
return Ok({ ... })
```

```lua
-- Tick-loop command checks .success and skips silently
local policyResult = self._policy:Check(workerData, currentTime)
if not policyResult.success then return end
local ctx = policyResult.value
```

**Rule of thumb:** if spec failure means "not ready yet" rather than "invalid request", the policy should return the Err.

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

The command goes from 8 lines of fetch-then-validate to 1 line. The policy encapsulates all of it.

---

## Registration

Policies register in the Domain layer. They resolve Infrastructure dependencies via `Init()`.

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

## Policies in Restore Commands (Player Rejoin Hydration)

When a player rejoins and entities are reconstructed, restore commands must re-run the same Infrastructure-side effects that the original assign command ran (slot claims, position updates, active state). A naive implementation skips the policy and manually re-fetches the required state — this is wrong for two reasons:

1. **The policy return value is load-bearing.** Policies resolve live Roblox instances (ore models, zone folders, entity refs) and return them in `Ok(data)`. Bypassing the policy means writing duplicate resolution logic that can drift out of sync.
2. **Infrastructure state must be re-registered.** In-memory tracking tables (e.g. `MiningSlotService.SlotMap`) are cleared between sessions. The restore must claim slots again via the same path the original command used, or the tracker is wrong and future assignments will double-claim.

**Rule: restore commands call the same policy as the original command.** Skip only persist, sync, and task-target assignment (already restored from data). Keep the policy check, slot claim, position update, and active state restart.

```lua
-- Correct: call the policy to get the resolved ore instance
function WorkerContext:_HydrateMinerAssignment(userId, workerId, oreId)
    local result = self.AssignMinerOrePolicy:Check(userId, workerId, oreId)
    if not result.success then return end  -- guard, not Try — restore is non-fatal

    local entity = result.value.Entity
    local oreInstance = result.value.OreInstance  -- resolved by policy

    local slotIndex, standPos, lookAtPos =
        self.MiningSlotService:ClaimSlot(userId, workerId, oreId, oreInstance:GetPivot(), oreInstance)

    self.EntityFactory:AssignSlotIndex(entity, slotIndex)
    self.EntityFactory:UpdatePosition(entity, standPos.X, standPos.Y, standPos.Z, lookAtPos.X, lookAtPos.Y, lookAtPos.Z)
    self.EntityFactory:StartMining(entity, oreId, oreConfig.MiningDuration)
    -- No persist, no sync — already done
end
```

### Timing requirement

Restore commands that call `UpdatePosition` require the entity's model to exist (`GameObjectComponent` must be set). This means restore commands must run **after** `GameObjectSyncService:SyncDirtyEntities()` has flushed the newly created entities. See the two-pass pattern in `CQRS.md` under "Restore Commands."

Additionally, the lot's own `SyncDirtyEntities` must run **before** `LotSpawned` fires, so that zone sub-entities (Mines, Farm, etc.) exist when policies query them via `GetMinesFolderForUser`.

---

## Policy vs. Validator vs. Specification

| | Specification | Validator | Policy |
|---|---|---|---|
| Asks | Is this data valid? | Are all inputs valid? | Is this operation permitted? |
| Receives | A typed candidate | Individual arguments | A player or userId |
| Fetches state | Never | Never | Yes — from Infrastructure |
| Returns | `Result<T>` (Ok/Err) | `Result<{ any }>` via TryAll | `Result<TPolicyResult>` with fetched data |
| Composes | `:And()`, `:Or()`, `Spec.All()` | Accumulates via TryAll | Not composable — one per operation |
| Lives in | Domain/Specs/ | Domain/Services/ | Domain/Policies/ |
| Used by | Policies (internally) | Application commands (legacy) | Application commands |

**When to use which:**
- **Spec** — a single named rule you want to reuse or compose. Module-level constant.
- **Policy** — an operation's full eligibility check: fetch state, build candidate, evaluate specs, return state.
- **Validator** — legacy pattern. New contexts should use Specs + Policies instead.

---

## Checklist

**Specs:**
- [ ] Module-level constants — never constructed inside functions
- [ ] One specs file per context (`[Context]Specs.lua`)
- [ ] Export only composed specs, not individual ones
- [ ] Candidate types exported for policies to use
- [ ] Error messages from `Errors.lua` — no inline strings

**Policies:**
- [ ] One policy per operation
- [ ] `Check()` returns `Result<T>` with fetched state on success
- [ ] Registered in Domain category
- [ ] Dependencies resolved via `Init()` from registry
- [ ] Command-invoked policies: uses `Try()` for spec evaluation (failure = invalid request)
- [ ] Tick-loop policies: returns spec Err directly (failure = not ready yet)

**Application Commands:**
- [ ] Command-invoked: call `Try(policy:Check(player))` — unwraps value or propagates throw
- [ ] Tick-loop: call `policy:Check(...)`, check `.success`, read `.value` — skip silently on failure
- [ ] Use returned context data — don't re-fetch from Infrastructure
- [ ] Remove direct Infrastructure fetches that were only needed for validation

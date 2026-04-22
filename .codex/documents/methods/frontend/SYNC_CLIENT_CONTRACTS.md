# SyncClient Contracts

Defines strict authoring rules for `[Name]SyncClient.lua` modules inside `StarterPlayerScripts/Contexts/[Context]/Infrastructure/`.

Canonical architecture references:
- [../../architecture/backend/STATE_SYNC.md](../../architecture/backend/STATE_SYNC.md)
- [../../architecture/frontend/SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md](../SYNC_HOOK_STATE_PAYLOAD_CONTRACTS.md)

---

## Core Rules

- Every SyncClient extends `BaseSyncClient` via metatable inheritance.
- `new()` delegates construction to `BaseSyncClient.new(...)` and wraps the result with the subclass metatable.
- `Start()` and `GetAtom()` delegate directly to `BaseSyncClient` — do not re-implement the logic.
- SyncClients are read-only from the consumer's perspective — they expose no mutation methods.
- Do not subclass when `BaseSyncClient.new(...)` alone is sufficient. Subclass only to add domain-specific getter methods.

---

## Constructor Contract

`BaseSyncClient.new(...)` takes four positional arguments in this order:

1. **`blinkClient`** — The generated Blink client module for this context (from `ReplicatedStorage.Network.Generated.*`).
2. **`blinkEventName`** — The Blink event name string matching the server-side emitter (e.g. `"SyncPlacements"`).
3. **`atomKey`** — The atom key string matching the server-side `CharmSync` registration key (e.g. `"placements"`).
4. **`createAtom`** — `SharedAtoms.CreateClientAtom` from the context's shared atoms module.

The atom key in argument 3 must match the key used on the server's `CharmSync.server({ atoms = { [key] = atom } })` call exactly — a mismatch silently drops all payloads.

```lua
function MySyncClient.new()
    local self = BaseSyncClient.new(BlinkClient, "SyncMyKey", "myKey", SharedAtoms.CreateClientAtom)
    return setmetatable(self, MySyncClient)
end
```

---

## Public API

The only public methods a SyncClient exposes are:

- `new()` — constructor.
- `Start()` — begins listening for server payloads. Delegates to `BaseSyncClient.Start(self)`.
- `GetAtom()` — returns the local Charm atom. Delegates to `BaseSyncClient.GetAtom(self)`.

Domain-specific subclasses may add named getter methods (e.g. `GetWalletAtom()`) that call `self:GetAtom()` internally, but must not add setters or mutation methods.

---

## Lifecycle

- `Start()` is called by the feature Controller in `KnitStart` — never in `KnitInit`.
- The Controller stores the SyncClient instance and calls `Start()` after construction.
- `GetAtom()` is called by read hooks (e.g. `useResources`) to subscribe to state — never called in Controllers directly for data reads.

---

## Prohibitions

- Do not re-implement `Start()` or `GetAtom()` logic — always delegate to `BaseSyncClient`.
- Do not expose mutation methods on a SyncClient.
- Do not call `Start()` inside `new()` or `KnitInit`.
- Do not hardcode the Blink event name or atom key as magic strings outside of `new()` — they belong only in the constructor call.
- Do not access `self.Atom` directly from outside the SyncClient — always go through `GetAtom()`.

---

## Failure Signals

- `Start()` body contains logic beyond `BaseSyncClient.Start(self)`.
- `GetAtom()` body constructs or transforms the atom instead of delegating.
- The atom key passed to `BaseSyncClient.new(...)` does not match the server-side `CharmSync` key — payloads are silently dropped.
- `Start()` is called inside `KnitInit` instead of `KnitStart`.
- SyncClient exposes a `SetAtom(...)` or similar mutation method.

---

## Checklist

- [ ] Subclass metatable: `setmetatable({}, { __index = BaseSyncClient })`.
- [ ] `new()` calls `BaseSyncClient.new(blinkClient, blinkEventName, atomKey, createAtom)`.
- [ ] `atomKey` matches the server-side `CharmSync` atom registration key exactly.
- [ ] `Start()` delegates to `BaseSyncClient.Start(self)`.
- [ ] `GetAtom()` delegates to `BaseSyncClient.GetAtom(self)`.
- [ ] No mutation methods exposed.
- [ ] `Start()` called from `KnitStart`, not `KnitInit`.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->


# Plan: RTS Persistence & Player Data

## Context

The project already has a complete ProfileStore session lifecycle (SessionManager, ProfileManager, PlayerLifecycleManager) and a set of SyncServices managing in-memory Charm atoms. However:
- **No context currently hooks into ProfileLoaded/ProfileSaving** — all in-game state is ephemeral.
- **Template.lua was imported from a different project** and contains irrelevant schemas (Guild, Commission, Quest, Inventory, Equipment, Production, etc.) that must be removed.
- **No RTS-specific Template sections exist** (waves cleared, runs played, meta-progression, etc.).

This plan replaces the imported Template with an RTS-specific schema, then wires the Economy context as the first persistence-backed context using the established PlayerLifecycleManager loader pattern.

---

## Goal

1. Strip Template.lua to RTS-relevant sections only and add new RTS-specific sections.
2. Wire EconomyContext's ResourceSyncService to ProfileLoaded/ProfileSaving so the resource wallet persists across sessions (if applicable).
3. Establish the exact pattern for wiring future contexts (Commander, etc.) to follow.

---

## Assumptions

- Resource wallet is **run-scoped** (resets each run), so it does NOT persist across server restarts. Persistence for economy means saving **inter-run meta state** only (e.g. total gold earned, best wave, etc.), not the live wallet.
- The RTS schema should be minimal and RTS-specific: run stats, settings, unlocks. No guild/commission/adventurer data.
- Commander HP and cooldowns remain ephemeral (no persistence needed for now).
- Placement state remains ephemeral (cleared on RunEnd by design).
- The `SchemaVersion` field stays for future migration support.

---

## Short Action Flow Chart

```
Step 1: Strip Template.lua
  Remove irrelevant sections → Add RTS sections (RunStats, Settings, Unlocks, SchemaVersion)

Step 2: Confirm ProfileManager API is accessible from contexts
  ProfileManager:GetData(player) → profile.Data table

Step 3: Wire EconomyContext loader (if inter-run data exists)
  KnitInit → PlayerLifecycleManager:RegisterLoader("Economy")
  ProfileLoaded event → LoadFromProfile(player, profile.Data)
    → ResourceSyncService:LoadUserData(userId, derivedWallet)
    → PlayerLifecycleManager:NotifyLoaded(player, "Economy")
  ProfileSaving event → SaveToProfile(player, profile.Data)
    → read atom via GetReadOnly → write into profile.Data.RunStats

Step 4: Add explicit Load/Save methods to ResourceSyncService
  ResourceSyncService:LoadFromProfile(userId, profileData)
  ResourceSyncService:SaveToProfile(userId, profileData) → writes snapshot to profile.Data

Step 5: Update EconomyContext KnitStart → remove ad-hoc PlayerAdded/PlayerRemoving persistence
  Replace with persistence event listeners per INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md
```

---

## System Breakdown

### Data
- **Template.lua** — full rewrite. Remove: Inventory, Equipment, Flags, Gold, Guild, Commission, Quest, Task, Unlocks (old shape), Chapter, Upgrade, Production. Keep: SchemaVersion, Settings. Add: RunStats (WavesCleared, TotalRuns, BestWave), Unlocks (flat bool set, RTS-specific).

### Server
- **EconomyContext.lua** — add `RegisterLoader` call in KnitInit; add ProfileLoaded/ProfileSaving event listeners in KnitStart; remove ad-hoc PlayerAdded/PlayerRemoving persistence (those already handle atom hydration, keep only CharmSync hydration there).
- **ResourceSyncService.lua** — add `LoadFromProfile(userId, profileData)` and `SaveToProfile(userId, profileData)` explicit method pair.

### Shared
- No changes to BaseSyncService, PlayerLifecycleManager, SessionManager, ProfileManager.

### Networking
- No new remotes. Existing CharmSync replication unchanged.

### Security
- Profile data written only on server via ProfileSaving event. No client input reaches profile.Data.
- ProfileManager:GetData is server-only.

### Testing
- Verify Template reconcile fills new fields for existing profiles (SchemaVersion bump is not required unless migration logic is added — mark as low risk since Reconcile handles missing keys).
- Verify PlayerReady fires after Economy NotifyLoaded in Studio test.
- Verify wallet resets correctly at run start (Prep) and profile.Data.RunStats accumulates across runs.

---

## Proposed Architecture

### File/Module Layout

```
src/ServerScriptService/Persistence/
  Template.lua                          ← REWRITE (strip + RTS schema)
  ProfileManager.lua                    ← no change
  PlayerLifecycleManager.lua            ← no change
  SessionManager.lua                    ← no change
  ProfileInit.server.lua                ← no change

src/ServerScriptService/Contexts/Economy/
  EconomyContext.lua                    ← ADD RegisterLoader + event listeners
  Infrastructure/Persistence/
    ResourceSyncService.lua             ← ADD LoadFromProfile + SaveToProfile
```

### Data Flow

```
Player joins
  → SessionManager: StartSessionAsync → Reconcile(Template) → ProfileLoaded emitted
  → EconomyContext: ProfileLoaded handler
      → ProfileManager:GetData(player) → profile.Data
      → ResourceSyncService:LoadFromProfile(userId, profile.Data)
          [reads profile.Data.RunStats.BestWave etc. if needed, initializes atom]
      → PlayerLifecycleManager:NotifyLoaded(player, "Economy")
  → PlayerLifecycleManager: all loaders done → PlayerReady emitted

Player leaves
  → SessionManager: ProfileSaving emitted
  → EconomyContext: ProfileSaving handler
      → ResourceSyncService:SaveToProfile(userId, profile.Data)
          [flushes relevant atom state into profile.Data.RunStats]
  → SessionManager: EndSession → ProfileStore auto-saves
```

---

## Implementation Plan

### Step 1 — Rewrite Template.lua with RTS-specific schema

**Files:** `src/ServerScriptService/Persistence/Template.lua`

**Tasks:**
- Remove all non-RTS sections: Inventory, Equipment, Flags, Gold, Guild, Commission, Quest, Task, Unlocks (old shape), Chapter, Upgrade, Production.
- Keep: `SchemaVersion` (bump to 2 to signal the rewrite).
- Keep: `Settings` (Sound preferences — applicable to RTS).
- Add: `RunStats = { TotalRuns = 0, BestWave = 0, TotalWavesCleared = 0 }`.
- Add: `Unlocks = {}` (flat `{ [targetId: string]: true }` set, repurposed for RTS unlocks).

**Data created:** New canonical RTS profile schema.  
**State transition:** Any existing profile is reconciled — missing keys are filled from Template on next join. Old keys remain in existing profiles (ProfileStore does not delete unknown keys) — this is acceptable since we are not reading them.  
**Risks:** Existing Studio test profiles may have stale keys. Non-breaking since Reconcile only adds, not removes. Low risk.  
**Completion check:** Template contains exactly SchemaVersion, Settings, RunStats, Unlocks. No other top-level keys.

---

### Step 2 — Add LoadFromProfile / SaveToProfile to ResourceSyncService

**Files:** `src/ServerScriptService/Contexts/Economy/Infrastructure/Persistence/ResourceSyncService.lua`

**Tasks:**
- Add method `ResourceSyncService:LoadFromProfile(userId: number, profileData: any)`.
  - Reads `profileData.RunStats` (read-only, no wallet data to restore since wallet is run-scoped).
  - For now this method initializes the atom entry to a neutral state OR is a no-op if the wallet is always initialized at Prep. Signature must exist to satisfy the loader pattern contract.
- Add method `ResourceSyncService:SaveToProfile(userId: number, profileData: any)`.
  - Reads current wallet state via `self:GetReadOnly(userId)`.
  - Writes any cross-run stats into `profileData.RunStats` if applicable (e.g. could accumulate gold earned — leave as stub with comment for now if no cross-run wallet data exists yet).

**Trigger:** Called by EconomyContext's ProfileLoaded/ProfileSaving handlers.  
**Module ownership:** Infrastructure/Persistence (correct per INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md).  
**Data inputs:** `profileData` reference (mutable, owned by ProfileStore).  
**Data outputs:** Atom state loaded; or profileData mutated in-place on save.  
**Guards:** Check `profileData ~= nil` before reading. Check `self:GetReadOnly(userId) ~= nil` before writing.  
**Completion check:** Two explicit methods exist with `Load...` / `Save...` naming convention. No domain logic inside them.

---

### Step 3 — Wire EconomyContext to persistence lifecycle

**Files:** `src/ServerScriptService/Contexts/Economy/EconomyContext.lua`

**Tasks:**

**In `KnitInit`:**
- Add `local GameEvents = require(...)` and `local ProfileManager = require(...)` and `local PlayerLifecycleManager = require(...)` imports.
- Call `PlayerLifecycleManager:RegisterLoader("Economy")` — must happen during KnitInit before any player joins.
- Store connections table: `self._persistenceConnections = {}`.

**In `KnitStart`:**
- Subscribe to `GameEvents.Bus` for `Events.Persistence.ProfileLoaded`:
  ```
  handler(player):
    local profileData = ProfileManager:GetData(player)
    if profileData == nil then return end
    self._sync:LoadFromProfile(player.UserId, profileData)
    PlayerLifecycleManager:NotifyLoaded(player, "Economy")
  ```
- Subscribe to `GameEvents.Bus` for `Events.Persistence.ProfileSaving`:
  ```
  handler(player):
    local profileData = ProfileManager:GetData(player)
    if profileData == nil then return end
    self._sync:SaveToProfile(player.UserId, profileData)
  ```
- Keep existing `Players.PlayerAdded` handler for CharmSync hydration only (call `self._sync:HydratePlayer(player)` — this is correct, it replicates atom state to client, not profile loading).
- Keep existing `Players.PlayerRemoving` handler for `self._sync:RemovePlayer(player.UserId)` — atom cleanup on leave is separate from profile saving.

**In `Destroy`:**
- Disconnect persistence event connections.

**Trigger:** ProfileLoaded/ProfileSaving events emitted by SessionManager.  
**Client↔server handoff:** None — all server-side.  
**State transitions:** Atom initialized from profile on join; atom state flushed to profile on leave.  
**Guards:** Nil-check on profileData before any read/write.  
**Completion check:** EconomyContext calls RegisterLoader in KnitInit. LoadFromProfile called in ProfileLoaded handler followed by NotifyLoaded. SaveToProfile called in ProfileSaving handler. No direct PlayerAdded/PlayerRemoving wiring for profile data.

---

### Step 4 — Validate full lifecycle in Studio

**Tasks:**
- Run game in Studio with two test scenarios:
  1. **Fresh join:** Profile loads with reconciled Template defaults. Economy NotifyLoaded fires. PlayerReady fires. Run starts, wallet initializes at Prep. Player leaves, SaveToProfile runs without error.
  2. **Rejoin:** Same player rejoins. ProfileLoaded fires again. LoadFromProfile reads profileData without error. NotifyLoaded fires. PlayerReady fires.
- Confirm no `warn` output from PlayerLifecycleManager about unknown loaders or double-notify.
- Confirm `profile.Data.RunStats` is readable and not nil after a session.

**Completion check:** No errors or warnings in output. PlayerReady fires for Economy context. Profile saves cleanly on leave (ProfileStore logs success or no error).

---

## Validation Checklist

### Functional Tests
- [ ] Fresh profile: RunStats fields present with default values after join.
- [ ] ProfileLoaded triggers LoadFromProfile → NotifyLoaded → PlayerReady chain.
- [ ] ProfileSaving triggers SaveToProfile without error.
- [ ] Wallet still resets at Prep (run-scoped behavior unchanged).
- [ ] Economy atom still replicates to client via CharmSync after join.

### Edge Cases
- [ ] Player leaves before ProfileLoaded fires (fast rejoin/kick): ProfileSaving emitted but profile not registered → nil-check guard in SaveToProfile handles this.
- [ ] No loaders registered edge case: PlayerLifecycleManager CheckReady fires immediately (already handled by existing code).
- [ ] ProfileStore nil profile: SessionManager already kicks player; Economy never receives ProfileLoaded.

### Security Checks
- [ ] profile.Data is never written from a client-originated path.
- [ ] No RemoteFunction/RemoteEvent payload reaches profile.Data.

### Performance Checks
- [ ] SaveToProfile is synchronous and O(1) — no yielding inside ProfileSaving handler (ProfileStore requirement).
- [ ] LoadFromProfile does not yield — atom mutation is synchronous.

---

## Recommended First Build Step

**Step 1 (Template rewrite)** — it is a pure delete + add with zero runtime risk, establishes the correct data shape, and unblocks all subsequent steps that reference `profileData.RunStats`.

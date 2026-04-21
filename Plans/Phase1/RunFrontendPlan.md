# HUD & Results UI — Phase 1 Plan

## Context

Phase 1 requires a playable empty run shell with correct authority boundaries. The HUD and Results UI is the client-facing layer that surfaces live run data (commander HP, resource balances, wave number) during a run, and shows a post-run results screen when the run ends. The server already owns all authoritative state; this plan wires the client UI to what already exists via Charm atoms synced through Blink.

**What already exists:**
- `RunSyncClient` — syncs `{ state, waveNumber }` atom to client via Blink
- `CommanderSyncClient` — syncs `{ [userId]: CommanderState }` atom (hp, maxHp, cooldowns)
- `ResourceSyncClient` — syncs `{ [userId]: ResourceWallet }` atom (energy, resources)
- `App` feature slice with React-Lua atoms, layouts, molecules, organisms, and screen routing
- `AnimatedRouter` + `ScreenRegistry` for screen transitions
- `GameView` screen + `GameHUD` organism (currently shows TopBar + SidePanel only — no run data)
- `HudVisibilityAtom` that gates HUD rendering

**What is missing:**
- Read hooks for run state, commander state, and economy state on the client
- `RunHUD` organism — health bar, energy display, zone resource display, wave counter
- `ResultsScreen` — post-run breakdown showing wave reached and score stub
- Wiring `RunEnd` state → navigate to ResultsScreen
- `Run` feature slice scaffolding under `StarterPlayerScripts/Contexts/Run/`

---

## Goal

Build a minimal but correct Phase 1 HUD and Results screen:

1. **RunHUD** — displayed during `Wave`, `Prep`, `Resolution`, `Climax`, `Endless` states:
   - Commander HP bar (current / max)
   - Energy balance (number)
   - Zone resources: Metal + Crystal (numbers)
   - Wave counter ("Wave N")

2. **ResultsScreen** — displayed when run state transitions to `RunEnd`:
   - "Run Over" heading
   - Wave reached
   - Stub score (0 for Phase 1)
   - "Play Again" button (fires restart — dev/Studio-only gate on server)

---

## Short Action Flow

```
Server state changes (RunContext, CommanderContext, EconomyContext)
  → Blink fires sync remotes to client
  → Charm atoms updated on client (RunAtom, CommanderAtom, ResourceAtom)
  → React hooks (useRunState, useCommanderHud, useResourceHud) subscribe via react-charm
  → RunHUD re-renders with live data
  → RunState transitions to "RunEnd"
  → useEffect in useGameViewController detects transition
  → AnimatedRouter navigates to "Results" screen
  → ResultsScreen reads waveNumber + displays breakdown
  → Play Again → RemoteEvent → server studio-gate → RunContext:StartRun()
```

---

## Files to Create / Modify

### Create — Run feature slice (client)

```
src/StarterPlayerScripts/Contexts/Run/
  Infrastructure/
    RunSyncClient.lua               ← already exists
  Application/
    Hooks/
      useRunState.lua               ← reads RunAtom via react-charm; returns { state, waveNumber }
      useCommanderHud.lua           ← reads CommanderAtom for local player; returns { hp, maxHp }
      useResourceHud.lua            ← reads ResourceAtom for local player; returns { energy, metal, crystal }
  Presentation/
    Organisms/
      RunHUD.lua                    ← composes HP bar + energy + resources + wave counter
    Screens/
      ResultsScreen.lua             ← post-run breakdown screen (controller)
      ResultsScreenView.lua         ← layout/template for results
```

### Modify — App wiring

```
src/StarterPlayerScripts/Contexts/App/Presentation/Screens/GameView.lua
  ← mount RunHUD inside GameView conditionally on run state

src/StarterPlayerScripts/Contexts/App/Presentation/ScreenRegistry.lua
  ← register "Results" → ResultsScreen

src/StarterPlayerScripts/Contexts/App/Application/Hooks/useGameViewController.lua
  ← watch RunAtom state; navigate to "Results" when state == "RunEnd"
```

### Create — Server stub

```
src/ServerScriptService/Contexts/Run/Application/Commands/RequestRestartRunCommand.lua
  ← Studio-only RemoteEvent listener that calls RunContext:StartRun()
```

---

## Implementation Steps

### Step 1 — useRunState hook

**File:** `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useRunState.lua`

- Import `RunSharedAtoms` from `ReplicatedStorage/Contexts/Run/Sync/SharedAtoms`
- Use `useAtom(RunSharedAtoms.clientAtom)` (react-charm) to subscribe
- Return `{ state: RunState, waveNumber: number }`
- No server call — reads client-side Charm atom directly (already synced by RunSyncClient)

**Exit criteria:** Hook returns correct state and re-renders when Blink patches arrive.

---

### Step 2 — useCommanderHud hook

**File:** `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useCommanderHud.lua`

- Import `CommanderSharedAtoms` from `ReplicatedStorage/Contexts/Commander/Sync/SharedAtoms`
- Use `useAtom`; index result by `Players.LocalPlayer.UserId`
- Return `{ hp: number, maxHp: number }`
- Default to `{ hp = 0, maxHp = 100 }` if entry is nil (pre-hydration guard)

**Exit criteria:** Returns live HP values; updates on damage events.

---

### Step 3 — useResourceHud hook

**File:** `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useResourceHud.lua`

- Import `EconomySharedAtoms` from `ReplicatedStorage/Contexts/Economy/Sync/SharedAtoms`
- Use `useAtom`; index result by `Players.LocalPlayer.UserId`
- Return `{ energy: number, metal: number, crystal: number }`
- Read `wallet.energy`, `wallet.resources["Metal"]`, `wallet.resources["Crystal"]`
- Default all fields to 0 if wallet is nil

**Exit criteria:** Returns live wallet values; updates on spend and income events.

---

### Step 4 — RunHUD organism

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/RunHUD.lua`

**Layout (scale-first, bottom of screen):**
- Root: full-width Frame, AnchorPoint (0.5, 1), Position (0.5, 0, 1, -8), Size (1, 0, 0.12, 0)
- Left cluster: HP bar container (Frame) with inner fill Frame scaled to `hp / maxHp`
- Center: wave counter via `Text` atom ("Wave N", heading variant)
- Right cluster: `HStack` with Energy label + Metal label + Crystal label via `Text` atom

**Components reused (all from App/Presentation/):**
- `Text` atom — all labels and wave counter
- `Frame` atom — HP bar container and HP fill
- `HStack` layout — resource cluster

**No props** — all data sourced internally from hooks (`useCommanderHud`, `useResourceHud`, `useRunState`).

**Exit criteria:** HP bar scales correctly; wave counter shows correct number; resources update live.

---

### Step 5 — ResultsScreen + ResultsScreenView

**Files:**
- `src/StarterPlayerScripts/Contexts/Run/Presentation/Screens/ResultsScreen.lua`
- `src/StarterPlayerScripts/Contexts/Run/Presentation/Screens/ResultsScreenView.lua`

**ResultsScreen (controller):**
- Calls `useRunState()` to get `waveNumber`
- Defines `onPlayAgain` handler: fires `RemoteEvent("RequestRestartRun")` via `ReplicatedStorage`
- Passes `waveNumber`, `score = 0`, `onPlayAgain` to ResultsScreenView

**ResultsScreenView (template):**
- Full-screen centered `VStack`
- "Run Over" — `Text` atom, heading variant
- "Wave reached: N" — `Text` atom, body variant
- "Score: 0" — `Text` atom, body variant (Phase 1 stub)
- `Button` atom (primary variant) with label "Play Again", `OnActivated = onPlayAgain`
- No entrance animations in Phase 1

**Exit criteria:** Correct wave number shown; Play Again button fires remote.

---

### Step 6 — Register ResultsScreen + navigate on RunEnd

**Modify:** `src/StarterPlayerScripts/Contexts/App/Presentation/ScreenRegistry.lua`
- Add entry: `["Results"] = require(path.to.ResultsScreen)`

**Modify:** `src/StarterPlayerScripts/Contexts/App/Application/Hooks/useGameViewController.lua`
- Import `useRunState` at top
- Add `useEffect` with `{ runState.state }` dependency:
  - `if runState.state == "RunEnd" then navigate("Results")`
  - `if runState.state == "Idle" then navigate("Game")` (handles new run restart)

**Exit criteria:** AnimatedRouter transitions to Results on RunEnd; returns to Game screen on new run.

---

### Step 7 — Mount RunHUD inside GameView

**Modify:** `src/StarterPlayerScripts/Contexts/App/Presentation/Screens/GameView.lua` (or GameViewView.lua)
- Import `RunHUD` from Run Presentation layer
- Import `useRunState`
- Derive `isRunActive = state ~= "Idle" and state ~= "RunEnd"`
- Render `RunHUD` only when `isRunActive == true`
- ZIndex: 5 (above background, below TopBar at ZIndex 10)

**Exit criteria:** RunHUD appears when run starts; disappears at Idle and RunEnd.

---

### Step 8 — RequestRestartRun remote (dev stub)

**File:** `src/ServerScriptService/Contexts/Run/Application/Commands/RequestRestartRunCommand.lua`

- On module load: `RemoteEvent("RequestRestartRun")` in ReplicatedStorage (create if absent)
- `OnServerEvent`: guard with `game:GetService("RunService"):IsStudio()` — ignore in live
- If guard passes: call `Knit.GetService("RunContext"):StartRun()`
- Log with `Result.MentionEvent` on success

**Exit criteria:** Clicking Play Again in Studio restarts the run cleanly.

---

## Verification Checklist

### Functional
- [ ] RunHUD visible during Prep/Wave/Resolution/Climax/Endless states
- [ ] RunHUD hidden during Idle and RunEnd states
- [ ] HP bar fill width scales to `hp / maxHp` (50 HP / 100 max = 50% width)
- [ ] HP bar updates live on commander damage
- [ ] Energy number updates on spend and wave clear bonus
- [ ] Metal and Crystal numbers update on resource gain
- [ ] Wave counter shows correct wave number ("Wave 1", "Wave 2", etc.)
- [ ] ResultsScreen renders automatically when state → RunEnd
- [ ] ResultsScreen shows correct wave number reached
- [ ] Play Again button triggers run restart in Studio
- [ ] GameView transitions back to Game screen when new run starts

### Edge Cases
- [ ] HP bar clamped — fill never exceeds container width (hp/maxHp capped at 1)
- [ ] All values display 0 before first Blink hydration (no nil errors)
- [ ] ResultsScreen handles waveNumber = 0 (run ended before any wave)
- [ ] Rapid state transitions (RunEnd → Idle) don't cause double-navigation

### Security
- [ ] RequestRestartRun remote is studio-only gated — no effect in live servers
- [ ] No client-originated run state mutations — all reads only
- [ ] Resource values read only for LocalPlayer.UserId — no cross-player data exposure

### Performance
- [ ] All three hooks use react-charm atom subscriptions — zero polling
- [ ] RunHUD re-renders only when atom values change
- [ ] ResultsScreen is a plain static layout — no animation overhead in Phase 1

---

## Critical Files

| File | Action |
|---|---|
| `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useRunState.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useCommanderHud.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useResourceHud.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/RunHUD.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Run/Presentation/Screens/ResultsScreen.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Run/Presentation/Screens/ResultsScreenView.lua` | Create |
| `src/StarterPlayerScripts/Contexts/App/Presentation/ScreenRegistry.lua` | Modify — add "Results" entry |
| `src/StarterPlayerScripts/Contexts/App/Application/Hooks/useGameViewController.lua` | Modify — watch RunState, navigate on RunEnd |
| `src/StarterPlayerScripts/Contexts/App/Presentation/Screens/GameView.lua` | Modify — mount RunHUD conditionally |
| `src/ServerScriptService/Contexts/Run/Application/Commands/RequestRestartRunCommand.lua` | Create — dev-only restart stub |

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `Text` atom | `App/Presentation/Atoms/Text.lua` | All labels in RunHUD and ResultsScreen |
| `Frame` atom | `App/Presentation/Atoms/Frame.lua` | HP bar container and fill |
| `Button` atom | `App/Presentation/Atoms/Button.lua` | Play Again button |
| `HStack` / `VStack` | `App/Presentation/Layouts/Stack.lua` | Resource cluster and results layout |
| `useAtom` (react-charm) | `Packages.ReactCharm` | All three read hooks |
| `RunSharedAtoms` | `ReplicatedStorage/Contexts/Run/Sync/SharedAtoms` | Run state atom |
| `CommanderSharedAtoms` | `ReplicatedStorage/Contexts/Commander/Sync/SharedAtoms` | Commander HP atom |
| `EconomySharedAtoms` | `ReplicatedStorage/Contexts/Economy/Sync/SharedAtoms` | Resource wallet atom |

## Recommended First Build Step

**Steps 1, 2, 3 in parallel** — all three hooks are independent of each other. Then **Step 4** (RunHUD needs all three hooks). Then **Step 5** (ResultsScreen needs useRunState). Then **Steps 6, 7, 8** in any order.

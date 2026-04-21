# Phase 2 Frontend UI — Implementation Plan

## Context

Phase 2 ("Vertical Slice") requires three UI elements that do not yet exist:
1. **Ability Bar** — 5 commander ability slots (click to activate), showing cooldown state and energy cost
2. **Placement Palette** — always-visible panel during Prep phase listing buildable structures with costs; auto-hides during Wave phase
3. **Prep Timer Visual** — a progress bar showing time remaining in the Prep phase (countdown value already exists in `useRunPhaseHud`)

All three sit on top of the existing React + ReactCharm + Knit + Charm atoms architecture. No new controllers or server remotes are needed — all required data is already synced to the client.

---

## Assumptions

- Ability activation (clicking a slot) fires an existing Blink remote to the server — the UI plan covers visuals only; the ability execution remote is out of scope here
- `CommanderConfig.SLOTS` (5 entries) is the source of truth for slot order, display names, energy costs, and cooldown durations
- Placement is click-to-select-then-click-tile; the server-side placement remote (`PlaceStructure`) already exists
- Only one structure type exists right now (`turret`, cost 15 energy); the palette must be data-driven to scale
- Palette is hidden during Wave/Resolution/RunEnd phases; visible during Prep (and Idle/Resolution as a grace period — TBD, default: Prep only)
- No hotkeys for abilities (click only, per user decision)
- Ability slots are available during Wave phase (not locked to Prep)

## Ambiguities

- **Ability activation remote**: Does a `UseAbility` Blink remote already exist? If not, slot buttons will be visual-only with a TODO stub for the fire call. **Assume not wired yet — buttons will be visually correct but fire a no-op stub.**
- **Placement mode entry**: After clicking a structure card, does the client enter a "placement mode" (cursor snaps to tiles)? That interaction layer is a separate system; this plan covers only the palette panel UI, not the tile-targeting cursor.
- **Cooldown progress style**: Sweep/arc vs. linear fill bar. **Default: linear bottom-to-top fill overlay on the slot button.**

---

## Action Flow

### Ability Bar
```
Component mounts
  → useAbilityBarHud() reads CommanderController atom + EconomyController atom
  → Derives { slots: [{ key, displayName, energyCost, cooldownDuration, cooldownEntry?, canAfford }] }
  → AbilityBar renders 5 AbilitySlot buttons
  → User clicks slot → fires UseAbility stub (no-op for now)
  → Cooldown entry appears in atom (server syncs CommanderState.cooldowns)
  → useAtom triggers re-render → slot shows cooldown overlay + remaining seconds
```

### Placement Palette
```
Component mounts
  → usePlacementPaletteHud() reads RunController atom + EconomyController atom
  → Derives { isVisible: runState == "Prep", structures: [{ type, displayName, cost, canAfford }] }
  → PlacementPalette renders panel when isVisible
  → User clicks structure card → fires onSelectStructure(type) callback → (placement cursor — separate system)
  → When RunState transitions Prep→Wave → atom updates → isVisible = false → panel unmounts
```

### Prep Timer
```
Component mounts inside RunHUD center cluster
  → useRunPhaseHud() already exposes phaseEndsAt + countdownText
  → PrepTimerBar reads (phaseEndsAt - now) / phaseDuration to get 0→1 fill ratio
  → useSpring animates fill width
  → When RunState != "Prep" → component returns nil
```

---

## File / Module Layout

All new files go under the `Run` context to match existing HUD architecture.

```
src/StarterPlayerScripts/Contexts/Run/
  Application/
    Hooks/
      useAbilityBarHud.lua          [NEW] — derives slot display state from commander + economy atoms
      usePlacementPaletteHud.lua    [NEW] — derives palette visibility + structure list from run + economy atoms
  Presentation/
    Molecules/
      AbilitySlot.lua               [NEW] — single ability button with cooldown overlay
      StructureCard.lua             [NEW] — single structure card in palette (name, cost, afford state)
    Organisms/
      AbilityBar.lua                [NEW] — HStack of 5 AbilitySlot molecules
      PlacementPalette.lua          [NEW] — panel container of StructureCard molecules
      PrepTimerBar.lua              [NEW] — horizontal progress bar shown during Prep phase
      RunHUD.lua                    [MODIFY] — add AbilityBar, PlacementPalette, PrepTimerBar
```

**Read-only dependencies (no changes):**
- `CommanderConfig.lua` — slot definitions
- `PlacementConfig.lua` — structure costs and valid zone types
- `CommanderController.lua` / `EconomyController.lua` / `RunController.lua` — existing atoms
- `Atoms/Button.lua`, `Atoms/Frame.lua`, `Atoms/Text.lua` — base components
- `Layouts/HStack.lua`, `Layouts/VStack.lua` — layout primitives
- `Application/Hooks/useSpring.lua`, `useAnimatedValue.lua` — animation

---

## Implementation Steps

### Step 1 — `useAbilityBarHud` hook

**File:** `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useAbilityBarHud.lua`

**Objective:** Derive per-slot display state (name, cost, cooldown progress, canAfford) from existing atoms.

**Tasks:**
- `Knit.GetController("CommanderController")` → call `:GetAtom()` → `ReactCharm.useAtom()`
- `Knit.GetController("EconomyController")` → call `:GetAtom()` → `ReactCharm.useAtom()`
- Use `Workspace:GetServerTimeNow()` polled every 0.25s (same pattern as `useRunPhaseHud`) for live cooldown countdowns
- Iterate `CommanderConfig.SLOTS` (static, no atom needed) and for each slot:
  - Look up `commanderState.cooldowns[slot.key]` → if entry exists, compute `remaining = entry.startedAt + entry.duration - now`; clamp to `[0, duration]`; derive `progress = remaining / entry.duration` (1.0 = full cooldown, 0.0 = ready)
  - `canAfford = wallet.energy >= slot.energyCost`
- Return `{ slots: [TAbilitySlotHudData] }` where each entry is `{ key, displayName, energyCost, cooldownDuration, cooldownRemaining, cooldownProgress, canAfford, isOnCooldown }`

**Exported type:** `TAbilitySlotHudData`

**Trigger:** React render cycle + 0.25s poll for countdown
**Module owner:** Client only
**Dependencies:** Step 0 (none — all upstream already exists)
**Completion check:** Hook returns correct `isOnCooldown=true` and `cooldownProgress` decreasing from 1→0 when a cooldown entry is present in the atom

---

### Step 2 — `AbilitySlot` molecule

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Molecules/AbilitySlot.lua`

**Objective:** Render one ability slot button with cooldown overlay and cost label.

**Props:**
```
{
  slotData: TAbilitySlotHudData,
  onActivate: () -> ()   -- no-op stub for now
}
```

**Visual structure (bottom-up stack):**
```
Frame (64×64, rounded corners, Surface color)
  ├── Text: displayName (top label, Caption size)
  ├── Text: energyCost + "⚡" (bottom-left, Tiny)
  ├── Cooldown fill overlay: Frame clipped, height = cooldownProgress * 64, anchored bottom, semi-transparent dark
  ├── Text: cooldownRemaining formatted "Xs" (center, shown only when isOnCooldown)
  └── Button hit area (full size, transparent, onClick → onActivate)
```

**State-driven appearance:**
- `isOnCooldown = true` → fill overlay visible + click disabled + desaturated tint
- `canAfford = false` (and not on cooldown) → cost text turns red/semantic error color; click still allowed (server will reject)
- Ready state → no overlay, normal colors

**Reuses:** `Atoms/Frame.lua`, `Atoms/Text.lua`, `Atoms/Button.lua`, `useSpring.lua` for fill height animation
**Trigger:** Parent re-render when hook data changes
**Completion check:** Overlay correctly fills and drains as `cooldownProgress` goes 1→0

---

### Step 3 — `AbilityBar` organism

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/AbilityBar.lua`

**Objective:** Render 5 `AbilitySlot` components in a horizontal row.

**Tasks:**
- Call `useAbilityBarHud()` to get slot data
- Render `Layouts/HStack` with 5 `AbilitySlot` children, gap = `SpacingTokens.SM`
- Pass `onActivate` as a stub: `function() end` (wired to real remote in a later task)
- Position: centered bottom of screen, above the RunHUD bar (AnchorPoint `0.5, 1`, Position `0.5, 0, 0.88, 0` — above the 12% HUD)

**Completion check:** 5 slots render with correct names and costs from `CommanderConfig.SLOTS`

---

### Step 4 — `usePlacementPaletteHud` hook

**File:** `src/StarterPlayerScripts/Contexts/Run/Application/Hooks/usePlacementPaletteHud.lua`

**Objective:** Derive palette visibility and structure list from run state + economy.

**Tasks:**
- `Knit.GetController("RunController")` → atom → `ReactCharm.useAtom()` → extract `runState`
- `Knit.GetController("EconomyController")` → atom → `ReactCharm.useAtom()` → extract `wallet.energy`
- `isVisible = runState == "Prep"`
- Iterate `PlacementConfig.STRUCTURE_PLACEMENT_COSTS` to build structure list. For each `(structureType, cost)`:
  - `displayName = structureType` (capitalize for now — e.g. "Turret")
  - `canAfford = wallet.energy >= cost`
- Return `{ isVisible: boolean, structures: [TStructureCardData] }` where each entry is `{ structureType, displayName, energyCost, canAfford }`

**Exported type:** `TStructureCardData`
**Completion check:** `isVisible` flips false when run atom transitions to "Wave"

---

### Step 5 — `StructureCard` molecule

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Molecules/StructureCard.lua`

**Props:**
```
{
  cardData: TStructureCardData,
  isSelected: boolean,
  onSelect: (structureType: string) -> ()
}
```

**Visual structure:**
```
Frame (80×96, rounded, Surface color, selected = Accent border stroke)
  ├── Frame placeholder icon (top 60%, background accent tint)
  ├── Text: displayName (Body, center)
  └── Text: energyCost + "⚡" (Caption, bottom, red if canAfford=false)
```

**State:** Selected state → border stroke with `ColorTokens.Accent`, scale spring up slightly
**Reuses:** `Atoms/Frame.lua`, `Atoms/Text.lua`, `useHoverSpring.lua`
**Completion check:** Card shows red cost text when energy is insufficient; selected card has visible border

---

### Step 6 — `PlacementPalette` organism

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/PlacementPalette.lua`

**Objective:** Panel with title + list of `StructureCard` components, visible only during Prep.

**Tasks:**
- Call `usePlacementPaletteHud()` → if `not isVisible` return `nil`
- Maintain local React state for `selectedType: string?`
- Render:
  ```
  Frame (panel, left side of screen)
    VStack gap=SM
      Text "BUILD" (H3, header)
      VStack of StructureCard per structure
  ```
- `onSelect` sets `selectedType`; pass to parent via prop callback `onStructureSelected(type)` for the placement cursor system (stub for now)
- Position: left edge, vertically centered, `AnchorPoint(0, 0.5)`, `Position(0.01, 0, 0.5, 0)`
- Use `useAnimatedVisibility` to fade in/out when `isVisible` changes

**Completion check:** Panel appears when run enters Prep, disappears on Wave start with a fade transition

---

### Step 7 — `PrepTimerBar` organism

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/PrepTimerBar.lua`

**Objective:** Horizontal progress bar showing remaining Prep time.

**Tasks:**
- Accept no props; read `useRunPhaseHud()` internally (already available)
- Also read `Workspace:GetServerTimeNow()` on 0.1s poll (tighter interval for smooth fill)
- Compute `fillRatio = math.clamp((phaseEndsAt - now) / phaseDuration, 0, 1)` — requires `phaseEndsAt` and `phaseDuration` from `RunSnapshot`; `useRunPhaseHud` already reads these via `useRunState()`
- If `runState ~= "Prep"` return `nil`
- Render:
  ```
  Frame (full width - padding, 6px tall, background Surface dim)
    Frame (fill, width = fillRatio * parent width, accent color)
      [spring-animated width change]
  ```
- Position: just above the RunHUD bottom bar, full width, `AnchorPoint(0.5, 1)`, `Position(0.5, 0, 0.88, 0)` — sits between RunHUD and AbilityBar

**Note:** `useRunPhaseHud` does not currently expose raw `phaseEndsAt`/`phaseDuration` — it only exposes formatted strings. Either extend the hook's return type to include raw values, or create a lightweight `useRunState()` call directly in this component (RunController atom already exposes the full snapshot).

**Reuses:** `Atoms/Frame.lua`, `useSpring.lua`
**Completion check:** Bar drains left-to-right during Prep and disappears at Wave start

---

### Step 8 — Wire into `RunHUD` and `GameViewView`

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/RunHUD.lua`

**Tasks:**
- Import `AbilityBar`, `PlacementPalette`, `PrepTimerBar`
- Add them as siblings to the existing HUD bar in the render tree:
  ```lua
  AbilityBar = e(AbilityBar),           -- centered bottom, above HUD
  PrepTimerBar = e(PrepTimerBar),       -- thin bar above HUD
  PlacementPalette = e(PlacementPalette, { onStructureSelected = props.onStructureSelected }),
  ```
- `onStructureSelected` stub prop flows up through `GameViewView` → `GameView` → parent for future wiring to placement cursor system

**File:** `src/StarterPlayerScripts/Contexts/Run/RunPresentation.lua` (or equivalent export barrel)
- Ensure new organisms are exported if needed by `GameViewView`

**Completion check:** All three new UI elements appear in-game during a run without errors

---

## Validation Checklist

### Functional Tests
- [ ] AbilityBar renders 5 slots with correct names/costs from `CommanderConfig.SLOTS`
- [ ] Cooldown overlay appears and drains in real time after a simulated cooldown entry is injected into the atom
- [ ] Slot shows red cost text when energy is below `energyCost`
- [ ] PlacementPalette is visible during Prep and hidden during Wave/Resolution/RunEnd
- [ ] StructureCard shows correct cost and red text when unaffordable
- [ ] Clicking a StructureCard sets selected state (border highlight)
- [ ] PrepTimerBar fills correctly from 1.0 to 0.0 over `phaseDuration` seconds
- [ ] PrepTimerBar disappears when Prep ends
- [ ] No layout overlap between AbilityBar, PrepTimerBar, and RunHUD bottom bar

### Edge Cases
- [ ] All 5 slots on cooldown simultaneously — no layout breakage
- [ ] Energy = 0 — all slots and all structure cards show red cost
- [ ] Prep phase with very short duration (< 5s) — timer bar drains fast, no spring overshoot
- [ ] Run ends mid-Prep — all new UI unmounts cleanly (RunHUD already handles `isRunActive` gate)
- [ ] `phaseEndsAt` is nil (Idle state) — PrepTimerBar returns nil safely

### Security Checks
- [ ] No new remotes added — all existing remotes retain their server-side validation
- [ ] Ability activation is client-side no-op stub; server will validate when wired
- [ ] Structure selection is purely visual; actual `PlaceStructure` remote call (existing, validated) is unchanged

### Performance Checks
- [ ] Cooldown poll at 0.25s (5 slots × 1 number op) — negligible
- [ ] PrepTimerBar poll at 0.1s — single subtraction, no table allocation
- [ ] `useAnimatedVisibility` on PlacementPalette — uses existing spring, no new tween instances
- [ ] No new Charm atoms created — hooks only read existing atoms

---

## Critical Files

| File | Role |
|---|---|
| [RunHUD.lua](src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/RunHUD.lua) | Modified to mount new organisms |
| [CommanderConfig.lua](src/ReplicatedStorage/Contexts/Commander/Config/CommanderConfig.lua) | Slot definitions — read-only |
| [PlacementConfig.lua](src/ReplicatedStorage/Contexts/Placement/Config/PlacementConfig.lua) | Structure costs — read-only |
| [useRunPhaseHud.lua](src/StarterPlayerScripts/Contexts/Run/Application/Hooks/useRunPhaseHud.lua) | May need raw phaseEndsAt/phaseDuration exposed |
| [CommanderTypes.lua](src/ReplicatedStorage/Contexts/Commander/Types/CommanderTypes.lua) | TAbilitySlotHudData will reference these |
| [GameViewView.lua](src/StarterPlayerScripts/Contexts/App/Presentation/Screens/GameViewView.lua) | May need onStructureSelected prop threaded through |

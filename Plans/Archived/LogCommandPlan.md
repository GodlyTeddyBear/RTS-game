# Plan: Executable Command Registry for Log Context

## Context

The log viewer is a developer-only in-game tool (backtick toggle) that displays log entries streamed from the server. The request is to extend it so bounded contexts can register named commands (with optional parameters) on the server, and the log viewer UI gains a "Commands" page where the developer can browse, configure, and execute those commands — with inline success/failure results.

---

## Goal

Add a server-side `CommandRegistry` shared module that any context can call during `KnitInit`. Wire it into `LogContext` via two new Knit `Client` methods (`GetCommands`, `ExecuteCommand`). Add a "Commands" tab to the log viewer UI that fetches the manifest on join, groups commands by context, renders optional parameter inputs, and shows inline execution results.

---

## Assumptions

- Command names are globally unique (last-write-wins on collision, with a warning)
- Parameters are always strings on the wire; handlers coerce their own types
- Manifest is fetched once on developer join; no live-push of newly registered commands
- Execution results persist in React state until the UI is unmounted (toggling the viewer off and back on resets them); they do NOT persist across backtick toggles
- Every command always expands on click — even commands with no params show an expand area with just the Execute button; no inline-execute shortcut
- Parameter inputs reset to defaults after each execution
- No de-registration support needed (init-time only)
- `DEVELOPER_USER_ID = 205423638` is the sole authorization gate

---

## Action Flow

```
REGISTRATION (server KnitInit)
  Any Context KnitInit
    --> require(CommandRegistry)
    --> CommandRegistry.Register({ name, context, description?, params?, handler })
    --> stored in private table keyed by name

HYDRATION (developer join)
  Developer player connects
    --> LogController:KnitStart() calls CommandSyncClient:Initialize()
    --> CommandSyncClient calls Knit.GetService("LogContext").GetCommands()
    --> LogContext.Client.GetCommands validates UserId, returns CommandRegistry.GetAll()
    --> handler field stripped, CommandManifestEntry[] returned
    --> commandsAtom written with manifest
    --> useCommands hook subscribes -> CommandsScreen re-renders

EXECUTION (client -> server -> client)
  Developer clicks Execute
    --> CommandsScreen.onExecute(commandName, paramValues)
    --> Knit call: LogContext.Client.ExecuteCommand(name, params)
    --> server validates UserId, looks up handler via CommandRegistry.GetByName(name)
    --> pcall(handler, params) -> success: boolean, message: string
    --> returned to client
    --> executionResults state updated -> CommandsScreenView renders inline result
```

---

## Types

```
-- Server-side (includes handler, never sent to client)
LogCommand = {
    name: string,
    context: string,
    description: string?,
    params: { CommandParam }?,
    handler: (params: { [string]: string }) -> (boolean, string),
}

CommandParam = {
    name: string,   -- key in params dict
    label: string,  -- UI label
    default: string?,
}

-- Client-safe (handler stripped)
CommandManifestEntry = {
    name: string,
    context: string,
    description: string?,
    params: { CommandParam }?,
}

-- Client React state only
ExecutionResult = {
    success: boolean,
    message: string,
    timestamp: number,  -- os.clock()
}
```

---

## File Layout

### New Files
| File | Purpose |
|------|---------|
| `ReplicatedStorage/Contexts/Log/CommandRegistry.lua` | Shared registry: `Register`, `GetAll`, `GetByName` |
| `StarterPlayerScripts/Contexts/Log/Infrastructure/CommandSyncClient.lua` | commandsAtom + `Initialize()` hydration call |
| `StarterPlayerScripts/Contexts/Log/Application/Hooks/useCommands.lua` | Read hook: subscribes to commandsAtom |
| `StarterPlayerScripts/Contexts/Log/Application/Hooks/useCommandsScreenController.lua` | Screen controller: owns expand/param/result/executing state + onExecute async |
| `StarterPlayerScripts/Contexts/Log/Application/ViewModels/CommandsViewModel.lua` | Pure transform: flat manifest → grouped + sorted |
| `StarterPlayerScripts/Contexts/Log/Presentation/Templates/CommandsScreen.lua` | Template: thin wrapper calling controller, renders organism |
| `StarterPlayerScripts/Contexts/Log/Presentation/Organisms/CommandsListOrganism.lua` | Organism: grouped list, expand/collapse, param inputs, execute button, result row |

### Modified Files
| File | Change |
|------|--------|
| `ServerScriptService/Contexts/Log/LogContext.lua` | Add `Client.GetCommands` and `Client.ExecuteCommand` |
| `StarterPlayerScripts/Contexts/Log/LogController.lua` | Require and initialize `CommandSyncClient` |
| `StarterPlayerScripts/Contexts/Log/Presentation/Templates/LogViewerScreen.lua` | Add `activePage` state, render `CommandsScreen` conditionally |
| `StarterPlayerScripts/Contexts/Log/Presentation/Templates/LogViewerScreenView.lua` | Add tab bar ("Logs" / "Commands") driven by `activePage` prop |

---

## Implementation Steps

### Step 1 — Create `CommandRegistry.lua`
**File:** `ReplicatedStorage/Contexts/Log/CommandRegistry.lua`  
**Trigger:** Standalone, no dependencies.

- Private `_commands: { [string]: LogCommand }` table keyed by `name`
- `Register(command: LogCommand)`:  validates required fields; guards with `RunService:IsServer()` (error if client); warns and overwrites on name collision
- `GetAll() -> { CommandManifestEntry }`: iterates `_commands`, strips `handler`, returns array copy
- `GetByName(name: string) -> LogCommand?`: returns full entry with `handler` intact

**Completion check:** Require from a server Script, register 2 entries, `GetAll()` returns 2 entries with no `handler` field; `GetByName` returns the entry with `handler`.

---

### Step 2 — Modify `LogContext.lua`
**File:** `ServerScriptService/Contexts/Log/LogContext.lua`  
**Dependency:** Step 1.

- Add `require(ReplicatedStorage.Contexts.Log.CommandRegistry)` at top
- Add `Client.GetCommands(player) -> { CommandManifestEntry }`:
  - Guard: `player.UserId ~= DEVELOPER_USER_ID` → return `{}`
  - Return `CommandRegistry.GetAll()`
- Add `Client.ExecuteCommand(player, name: string, params: { [string]: string }) -> { success: boolean, message: string }`:
  - Guard: unauthorized → `{success=false, message="Unauthorized"}`
  - Unknown name → `{success=false, message="Unknown command: " .. name}`
  - `pcall(handler, params)` → success → `{success=true, message=msg}`, error → `{success=false, message=tostring(err)}`

**Completion check:** Both remote methods resolve over Knit; unauthorized player gets empty/error response; pcall wraps handler throw.

---

### Step 3 — Create `CommandSyncClient.lua`
**File:** `StarterPlayerScripts/Contexts/Log/Infrastructure/CommandSyncClient.lua`  
**Dependency:** Step 2.

- `commandsAtom = Atom({})` — Charm atom, initialized to empty array
- `Initialize()`: calls `Knit.GetService("LogContext").GetCommands()`, writes result to `commandsAtom`
- Exports: `commandsAtom`, `Initialize`

**Completion check:** After `Initialize()`, `commandsAtom()` returns a non-empty array when commands are registered.

---

### Step 4 — Modify `LogController.lua`
**File:** `StarterPlayerScripts/Contexts/Log/LogController.lua`  
**Dependency:** Step 3.

- Require `CommandSyncClient` at top
- In `KnitStart`, call `CommandSyncClient.Initialize()` (after log sync is already started)

**Completion check:** Developer joins; no errors; `commandsAtom` is populated.

---

### Step 5 — Create `useCommands.lua`
**File:** `StarterPlayerScripts/Contexts/Log/Application/Hooks/useCommands.lua`  
**Dependency:** Step 3.

- Mirrors `useLogs.lua` exactly: subscribes to `CommandSyncClient.commandsAtom` via `ReactCharm.useAtom`, returns current value
- No side effects, no Knit calls

**Completion check:** Test component re-renders when atom value changes.

---

### Step 6 — Create `CommandsViewModel.lua`
**File:** `StarterPlayerScripts/Contexts/Log/Application/ViewModels/CommandsViewModel.lua`  
**Dependency:** None (pure function).

- `build(manifest: { CommandManifestEntry }) -> { { contextName: string, commands: { CommandManifestEntry } } }`:
  - Group entries by `context` field
  - Sort groups alphabetically by `contextName`
  - Sort commands within each group alphabetically by `name`
  - Freeze outer array and each group's `commands` array

**Completion check:** 5 entries across 2 contexts → 2-element output, correct grouping, all frozen.

---

### Step 7 — Create `CommandsScreenView.lua`
**File:** `StarterPlayerScripts/Contexts/Log/Presentation/Organisms/CommandsListOrganism.lua`  
**Dependency:** Step 6 (defines props shape).

> Renamed and relocated: this is a feature-local Organism, not a Template. The Template (`CommandsScreen.lua`) owns all state and passes data down to this component.

Props:
- `groupedCommands: { GroupedCommands }`
- `expandedCommands: { [commandName: string]: boolean }` — which rows are open
- `paramValues: { [commandName: string]: { [paramName: string]: string } }`
- `executionResults: { [commandName: string]: ExecutionResult }` — persists until UI unmount
- `isExecuting: { [commandName: string]: boolean }`
- `onToggleExpand: (commandName: string) -> ()`
- `onParamChange: (commandName: string, paramName: string, value: string) -> ()`
- `onExecute: (commandName: string) -> ()`

Rendered structure (per command row):

```
┌─ Context Header ─────────────────────────────┐
│  ── Commander ──                              │
├─ Command Row (collapsed) ────────────────────┤
│  CommandName    Short description...    [+]   │
├─ Command Row (expanded) ─────────────────────┤
│  CommandName    Short description...    [-]   │
│    Param Label: [__TextBox______________]     │
│    Param Label: [__TextBox______________]     │
│    [Execute]                                  │
│    ✓ Wave 3 started  (12:04:32)               │  ← persists
└───────────────────────────────────────────────┘
```

Interaction rules:
- Every command has a `[+]` / `[-]` indicator — always expand on click, even with no params
- Commands with no params expand to show only the Execute button (no TextBox inputs)
- Execute button text is `...` and disabled while `isExecuting[name]` is true
- Result row uses `POPUP_TEXT_BODY` color for success (green tint), `CLEAR_TEXT_COLOR` for failure (red); dim timestamp shown alongside
- Colors sourced from existing `LogViewerScreenView` constants — no new constants needed
- Pure render function — no `useState`, no Knit calls, no atom reads

**Completion check:** Renders with mock props; expand/collapse toggles show/hide param area; result row appears with correct color when `executionResults` has an entry.

---

### Step 8 — Create `useCommandsScreenController.lua` + `CommandsScreen.lua`

**File A:** `StarterPlayerScripts/Contexts/Log/Application/Hooks/useCommandsScreenController.lua`  
**File B:** `StarterPlayerScripts/Contexts/Log/Presentation/Templates/CommandsScreen.lua`  
**Dependency:** Steps 5, 6, 7.

**`useCommandsScreenController`** owns all screen-level state and async logic:
- Calls `useCommands()` → `manifest`
- `React.useMemo` → `CommandsViewModel.build(manifest)` → `groupedCommands`
- `useState` for:
  - `expandedCommands: { [string]: boolean }` — which rows are open
  - `paramValues: { [string]: { [string]: string } }` — initialized from param defaults on manifest change via `useEffect`
  - `executionResults: { [string]: ExecutionResult }` — persists until unmount; written on each execution, never cleared automatically
  - `isExecuting: { [string]: boolean }`
- `onToggleExpand(commandName)`: flips `expandedCommands[commandName]`
- `onParamChange(commandName, paramName, value)`: updates `paramValues[commandName][paramName]`
- `onExecute(commandName)`:
  - Set `isExecuting[commandName] = true`
  - Call `Knit.GetService("LogContext").ExecuteCommand(commandName, paramValues[commandName] or {})` via Promise/coroutine (matching existing Knit call patterns in the codebase)
  - On resolve: write `ExecutionResult { success, message, timestamp = os.clock() }` to `executionResults`; clear `isExecuting` flag
- Returns typed interface `TCommandsScreenController`

**`CommandsScreen`** (Template) — thin wrapper:
- Calls `useCommandsScreenController()` → `controller`
- Renders `CommandsListOrganism` with all controller fields as props
- No business logic

**Completion check:** Execute triggers Knit call; `executionResults` is written after resolution; result persists when switching to Logs tab and back; toggling the viewer off/on resets results (React unmounts).

---

### Step 9 — Modify `LogViewerScreen.lua`
**File:** `StarterPlayerScripts/Contexts/Log/Presentation/Templates/LogViewerScreen.lua`  
**Dependency:** Step 8.

- Add `local activePage, setActivePage = React.useState("logs")`
- Pass `activePage` and `setActivePage` as props to `LogViewerScreenView`
- When `activePage == "commands"`, render `CommandsScreen` inside the same root container (conditionally, not as a separate React root)
- When `activePage == "logs"`, render the existing log view (no change to existing logic)

**Completion check:** `activePage` state drives tab switching; only active page content is rendered.

---

### Step 10 — Modify `LogViewerScreenView.lua`
**File:** `StarterPlayerScripts/Contexts/Log/Presentation/Templates/LogViewerScreenView.lua`  
**Dependency:** Step 9 (defines new props).

- Add `activePage: string` and `onPageChange: (page: string) -> ()` to the View's props type
- Inside the existing `Header` frame (36px), place two `TextButton` tab buttons to the right of the title label:
  - "Logs" and "Commands", each calling `onPageChange` with their key
  - Active tab: `TAB_ACTIVE_COLOR` background, `TAB_TEXT_ACTIVE` text
  - Inactive: `TAB_INACTIVE_COLOR` background, `TAB_TEXT_INACTIVE` text
  - Styled with `UICorner` radius 4 — matches existing filter tab buttons exactly
- The `Filters` frame and `ScrollContainer` are conditionally rendered only when `activePage == "logs"` (use `if activePage == "logs" then ... else nil` in the children table — this is the existing Roblox React nil-child pattern)
- A `CommandsContainer` frame fills `Position = UDim2.fromOffset(0, HEADER_HEIGHT)`, `Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)` and is rendered only when `activePage == "commands"` — it is the slot where `CommandsScreen` renders from the Template (passed as a prop child or rendered directly from the Template)
- The existing `scrollTop` pixel offset calculation (`HEADER_HEIGHT + FILTER_ROW_HEIGHT * 3`) is unchanged for the Logs page
- No new local color constants needed

**Completion check:** Tab bar renders inside the existing header; switching to "Commands" hides filters and log list, reveals commands slot; switching back to "Logs" restores exact prior appearance with no layout shift.

---

### Step 11 — Register Commands in One Context (Validation)
**File:** Any existing server context (e.g., `CommanderContext.lua`)  
**Dependency:** Step 1.

- Add `require(ReplicatedStorage.Contexts.Log.CommandRegistry)` during `KnitInit`
- Call `CommandRegistry.Register(...)` with 1–2 real commands (e.g., "Force Start Wave", "Clear Resources")
- Verify they appear in the developer's Commands tab after joining

**Completion check:** Commands appear in the UI grouped under the correct context name; executing them calls the handler and returns a visible result.

---

## Security

- Every `Client` method in `LogContext` must check `player.UserId == DEVELOPER_USER_ID` as the first line — no other path is taken for unauthorized players
- `CommandRegistry.Register()` guards with `RunService:IsServer()`; calling from a client Script throws immediately
- `ExecuteCommand` wraps handler in `pcall`; raw Luau tracebacks are never sent to the client
- Params arrive as raw strings from the client; handlers own their validation/coercion

---

## Validation Checklist

**Registry**
- [ ] `Register()` from client Script → immediate error
- [ ] Duplicate name → warning logged, second entry overwrites
- [ ] `GetAll()` returns entries with no `handler` field
- [ ] `GetByName()` returns entry with `handler` intact

**Server Remotes**
- [ ] Non-developer calls `GetCommands()` → empty table
- [ ] Non-developer calls `ExecuteCommand()` → `{success=false, message="Unauthorized"}`
- [ ] Unknown command name → `{success=false, message="Unknown command: ..."}` 
- [ ] Handler throws → `{success=false, message=...}`, server does not crash
- [ ] Handler returns `true, "Done"` → `{success=true, message="Done"}`

**Client Data Flow**
- [ ] `commandsAtom` populated after `Initialize()` on developer join
- [ ] `useCommands()` re-renders subscriber when atom changes
- [ ] `buildCommandsViewModel({})` returns empty array without error
- [ ] Groups are sorted alphabetically by context name

**UI**
- [ ] Tab bar renders inside existing header; no layout shift on Logs tab
- [ ] "Logs" tab shows existing log content with no regression
- [ ] "Commands" tab with no registered commands shows empty state message
- [ ] Commands grouped under correct context headers, sorted alphabetically
- [ ] Every command has `[+]` indicator; clicking expands; clicking again collapses
- [ ] Commands with no params expand to show only Execute button (no TextBox inputs)
- [ ] Execute with no params → `ExecuteCommand(name, {})`
- [ ] Execute with params → correct param dict passed
- [ ] Execute button shows `...` and is disabled while in-flight
- [ ] Success result in success color; failure in red
- [ ] Result includes dim timestamp
- [ ] Results persist across tab switches within the same session (React state survives)
- [ ] Results reset when log viewer is toggled off and back on (React unmounts)

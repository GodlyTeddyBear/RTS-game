# Readability

Readable code is not a cosmetic concern — it is a correctness concern. Bugs hide in confusion. The harder code is to read, the more places errors can survive undetected. These practices reduce cognitive load so that mistakes become visible before they become bugs.

---

## Composed Methods

A function should either **orchestrate** other functions or **do work directly** — not both. High-level functions read like a description of the process. Low-level functions contain the actual logic.

```lua
-- Mixed: orchestration and inline logic interleaved
function DepartOnQuest:Execute(userId: number, questId: string)
    local profile = profiles[userId]
    if not profile then return Result.Err("NoProfile", "Profile not found") end
    local adventurers = {}
    for _, a in profile.Guild.Adventurers do
        if not a.OnExpedition then table.insert(adventurers, a) end
    end
    if #adventurers < MIN_PARTY_SIZE then
        return Result.Err("InsufficientParty", "Not enough adventurers")
    end
    local quest = self.QuestRepo:Get(questId)
    if not quest then return Result.Err("NoQuest", "Quest not found") end
    -- ... more inline logic
end

-- Composed: reads as a description of the operation
function DepartOnQuest:Execute(userId: number, questId: string)
    local profile = Try(self:_LoadProfile(userId))
    local party   = Try(self:_AssembleParty(profile))
    local quest   = Try(self:_LoadQuest(questId))
    return self:_BeginExpedition(party, quest)
end

-- Each step is defined below, only read when needed
function DepartOnQuest:_LoadProfile(userId: number): Result<TProfile> ... end
function DepartOnQuest:_AssembleParty(profile: TProfile): Result<TParty> ... end
function DepartOnQuest:_LoadQuest(questId: string): Result<TQuest> ... end
function DepartOnQuest:_BeginExpedition(party: TParty, quest: TQuest): Result<TExpedition> ... end
```

The composed version reads like a table of contents. A reader understands the whole operation before deciding which part to drill into.

**Rule:** if a function is more than ~15 lines, it is probably doing work at two abstraction levels. Extract until every function fits on one screen and reads at one level.

---

## Consistent Abstraction Levels

Within a single function, all operations should be at the same level of abstraction. Mixing high-level orchestration with low-level detail forces the reader to context-switch mid-read.

```lua
-- Mixed levels: jarring
function DepartOnQuest:Execute(userId: number, questId: string)
    local party = self:_AssembleParty(userId)       -- high level
    for i = 1, #party do                             -- suddenly low level
        party[i].OnExpedition = true
        party[i].DepartedAt = os.time()
    end
    return self:_BeginExpedition(party, questId)    -- back to high level
end

-- Consistent: all operations at the same level
function DepartOnQuest:Execute(userId: number, questId: string)
    local party = self:_AssembleParty(userId)
    self:_MarkPartyDeparted(party)
    return self:_BeginExpedition(party, questId)
end
```

A useful test: read the function aloud. If any line sounds out of place — too detailed or too vague relative to the others — extract it.

---

## Stepdown Rule

Code should read top-to-bottom. High-level concepts at the top of the file, implementation details below. Each function calls functions defined further down.

```lua
-- Top of file: entry point — high level, reads like prose
function DepartOnQuest:Execute(userId: number, questId: string)
    local profile = Try(self:_LoadProfile(userId))
    local party   = Try(self:_AssembleParty(profile))
    local quest   = Try(self:_LoadQuest(questId))
    return self:_BeginExpedition(party, quest)
end

-- Middle: one level of detail
function DepartOnQuest:_AssembleParty(profile: TProfile): Result<TParty>
    local available = self:_GetAvailableAdventurers(profile)
    if #available < MIN_PARTY_SIZE then
        return Result.Err("InsufficientParty", "Not enough adventurers")
    end
    return Result.Ok(available)
end

-- Bottom: implementation details
function DepartOnQuest:_GetAvailableAdventurers(profile: TProfile): { TAdventurer }
    local available = {}
    for _, adventurer in profile.Guild.Adventurers do
        if not adventurer.OnExpedition then
            table.insert(available, adventurer)
        end
    end
    return available
end
```

A reader who only needs to understand the operation reads the top function and stops. They drill down only into what they need.

---

## Progressive Disclosure

Design interfaces so simple use cases are simple. Complexity is only revealed when the caller needs it. Never force a caller to understand every option to do the common thing.

```lua
-- Forces the caller to know about all parameters upfront
local expedition = createExpedition(questId, party, "Normal", 300, true, 1.0)
-- What is 300? What does true mean? What is 1.0?

-- Progressive: sensible defaults, optional complexity
local expedition = createExpedition(questId, party)

-- Complexity available when needed, but not required
local expedition = createExpedition(questId, party, {
    Difficulty = "Hard",
    TimeLimit = 300,
    RewardMultiplier = 1.5,
})
```

Applied to functions with many parameters: prefer an options table over a long argument list. Required parameters stay positional; optional configuration goes in the table.

---

## Intention-Revealing Names

Names should say what something **means**, not what it does mechanically.

```lua
-- Mechanical: describes the operation
local function filterPlayersWhereActiveExpeditionIsNil(players: { TPlayer })

-- Intentional: describes the domain concept
local function getAvailableAdventurers(players: { TPlayer })
```

```lua
-- Mechanical: what is d? what is ts?
local d = os.time() - ts

-- Intentional: the reader understands without looking at the definition
local secondsElapsedSinceDeparture = os.time() - departureTimestamp
```

A name that requires a comment to explain it is a name that should be changed.

---

## Avoid Boolean Parameters

A boolean argument is a hidden branch — it signals the function does two different things. This is usually a sign the function should be two functions.

```lua
-- Boolean parameter: what does false mean here?
createExpedition(questId, party, false)

-- Reader must open the implementation to understand
function createExpedition(questId, party, allowRetry) ... end

-- Two functions: intent is explicit at every call site
createExpedition(questId, party)
createExpeditionWithRetry(questId, party)
```

Exception: boolean parameters that are genuinely part of the domain — `setActive(true)`, `setVisible(false)` — are acceptable because the name makes the meaning self-evident.

---

## Avoid Flag Variables

A flag variable set in one place and checked elsewhere is a hidden communication channel between distant parts of a function. It is usually a sign the function can be restructured.

```lua
-- Flag variable: reader must track state through the function
local found = false
for _, quest in quests do
    if quest.Id == questId then
        found = true
        break
    end
end
if not found then return Result.Err("NotFound", "Quest not found") end

-- Restructured: no flag needed, intent is immediate
local quest = nil
for _, q in quests do
    if q.Id == questId then quest = q break end
end
if not quest then return Result.Err("NotFound", "Quest not found") end
```

---

## Proximity Principle

Declare variables as close to their use as possible. The further a declaration is from its use, the more the reader must hold in their head.

```lua
-- Far from use: reader must remember what 'result' is across many lines
local result
local party = self:_AssembleParty(profile)
local quest = self:_LoadQuest(questId)
-- ... more setup ...
result = self:_BeginExpedition(party, quest)
return result

-- Close to use: declared at the point it becomes meaningful
local party = self:_AssembleParty(profile)
local quest = self:_LoadQuest(questId)
local result = self:_BeginExpedition(party, quest)
return result
```

---

## Tell, Don't Ask

Instead of querying an object's state and deciding what to do externally, tell the object what you want and let it decide.

```lua
-- Ask: reach in, inspect, decide outside the object
if expedition.Status == "Active" and expedition.Party ~= nil then
    expedition.Status = "Victory"
    expedition.CompletedAt = os.time()
end

-- Tell: the object handles its own logic and invariants
expedition:Complete("Victory")
-- internally: validates Status, checks Party, sets CompletedAt, seals state
```

Asking distributes business logic across callers. Every caller must know the rules. Telling keeps rules inside the object — one place to read, one place to change.

---

## Law of Demeter

A function should only interact with its immediate collaborators — not reach through them to their dependencies.

```lua
-- Violation: reaches through three layers of structure
local count = player.Profile.Guild.Adventurers.Available.Count

-- Compliant: ask the object for what you need
local count = player:GetAvailableAdventurerCount()
```

Each dot past the first is a dependency on an internal structure the caller shouldn't know about. If `Guild` reorganizes internally, every reach-through call site breaks.

Practical test: if changing the internal layout of one object requires changing callers of a different object, Demeter is being violated.

---

## Symmetry

Operations that are inverses should look like inverses — same parameter shape, same naming pattern.

```lua
-- Asymmetric: the relationship between Add and Remove is not obvious
inventory:Add(itemId, quantity)
inventory:Remove(slot)           -- different parameter — why?

-- Symmetric: the relationship is immediate
inventory:Add(itemId, quantity)
inventory:Remove(itemId, quantity)
```

```lua
-- Asymmetric lifecycle
connection:Open(connectionId, config)
connection:Shutdown()            -- no connectionId — inconsistent

-- Symmetric
connection:Open(connectionId, config)
connection:Close(connectionId)
```

Asymmetric APIs create cognitive load. Readers must figure out the relationship between paired operations rather than inferring it from structure.

---

## Prefer Generic Over Specialized

If two or more functions, components, or methods differ only in configuration — a machine type, a category label, an entity kind — write one that accepts the configuration as a parameter, not one per variant.

```lua
-- Specialized: three functions, identical body, different constants
function MachineService:AssignWorkerToForge(worker)
    -- ... 20 lines of assignment logic ...
end

function MachineService:AssignWorkerToFurnace(worker)
    -- ... same 20 lines, different machine type ...
end

-- Generic: one function, configuration passed in
function MachineService:AssignWorkerToMachine(machineType: string, worker: TWorker)
    -- ... 20 lines, parameterized on machineType ...
end
```

**Trigger:** You are about to write a function whose name differs from an existing one only by a noun (machine type, entity kind, category). Stop — that is a parameter, not a new function.

**Relationship to the no-premature-abstraction rule:** "Three similar lines is better than a premature abstraction" applies to one-off helpers for unrelated operations. It is not a license to duplicate a function across N parallel cases that already exist in scope. If the pattern is already present (multiple machine types, multiple overlay variants, multiple worker categories), generalize now — not after the fourth copy.

**Also applies to components and hooks:** A React-Lua component that renders a machine overlay should accept a `machineType` prop, not exist as `ForgeOverlay`, `FurnaceOverlay`, `AnvilOverlay`. A read hook that fetches a resource count should accept the resource type, not fork into per-resource hooks.

---

## Sub-Section Comments

Long function bodies should be divided into named phases using plain `--` comments, even when each phase is straightforward. The goal is scanability — a reader should be able to skim the comments and understand the full shape of the function before reading a single line of code.

Write a sub-section comment at the start of each logical phase, regardless of whether the code itself is obvious.

```lua
-- Bad: no orientation — reader must parse each line to build a mental map
function QuestService:CompleteMission(player, questId)
    local profile = ProfileManager:GetData(player)
    local quest = profile.Quests[questId]
    quest.CompletedAt = os.time()
    quest.Status = "Complete"
    local rewards = QuestConfig[questId].Rewards
    for _, reward in rewards do
        InventoryService:Grant(player, reward)
    end
    ProfileManager:Save(player)
    self._QuestCompleted:Fire(player, questId)
end

-- Good: each phase is named — reader can orient immediately
function QuestService:CompleteMission(player, questId)
    -- Load the player's active quest
    local profile = ProfileManager:GetData(player)
    local quest = profile.Quests[questId]

    -- Mark the quest complete
    quest.CompletedAt = os.time()
    quest.Status = "Complete"

    -- Grant all configured rewards
    local rewards = QuestConfig[questId].Rewards
    for _, reward in rewards do
        InventoryService:Grant(player, reward)
    end

    -- Persist and notify
    ProfileManager:Save(player)
    self._QuestCompleted:Fire(player, questId)
end
```

**Rule:** If a function body has more than ~3 distinct operations, label each one. Do not rely on whitespace alone to signal phase boundaries — a comment forces the reader to engage with the intent, not just the structure.

---



Leave code slightly better than you found it. Not a full refactor — a small improvement when already in a file.

- Rename a misleading variable
- Add a missing assertion
- Break one overlong function into two
- Remove a comment that restates the code

These compound. The alternative — "I'll fix it later" — is how code gradually degrades. A standard that is only enforced on new code drifts over time; one that is actively improved stays healthy.

---

## Checklist

When writing or reviewing any function:

- [ ] Does it do work at one abstraction level, or does it mix orchestration with detail?
- [ ] Does the top-level function read like a description of the operation?
- [ ] Are implementation details below the call sites that use them?
- [ ] Do names say what things mean, not what they do mechanically?
- [ ] Are there boolean parameters that should be two functions?
- [ ] Are there flag variables that signal a restructuring opportunity?
- [ ] Are variables declared close to their use?
- [ ] Does the code tell objects what to do, or ask for state and decide externally?
- [ ] Are paired operations symmetric in shape and naming?
- [ ] Is the common use case simple, with optional complexity available but not required?
- [ ] If this function or component is one of several parallel variants, is the variant expressed as a parameter rather than a separate function?

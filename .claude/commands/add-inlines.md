Add or update inline documentation (plain `--` comments) for the file or folder specified in $ARGUMENTS. Do not add Moonwave doc comments — focus only on logical phase labels and intent-revealing comments inside function bodies.

---

## Before starting

Read the following docs — they define the inline comment philosophy:
- `.claude/documents/coding-style/READABILITY.md` (especially "Sub-Section Comments")
- `.claude/documents/coding-style/MOONWAVE.md` (to understand what NOT to do — no `--[=[...]=]` or `---`)

Do not write Moonwave-style doc comments in this task.

---

## How to run

1. Read every `.lua` file in the specified path.
2. For each function with **more than ~3 distinct operations**, add a plain `--` comment at the start of each logical phase.
3. For non-obvious logic, add inline `--` comments explaining **intent and why**, not what the code mechanically does.
4. Skip functions that are single-line or already self-evident.
5. After editing all files, output a summary of what was documented.

---

## Rules for Phase Labels

### When to add them
- Every function with 3+ distinct operations gets phase labels.
- Phase labels are plain `--` comments (no `--[=[`, no `---`).
- Write them at the start of each logical phase, even if the code is obvious.
- Separate phases with blank lines for visual clarity.

### How to write them
- Use imperative labels describing **what the phase does** (intent), not what it mechanically does.
- Names should be short and scannable.

**Bad examples (restates code):**
```lua
-- increment counter
-- check if nil
-- loop over rewards
```

**Good examples (describes intent):**
```lua
-- offset by 1 because ProfileStore indices are 1-based
-- guard against race where player leaves before data loads
-- grant all configured rewards
```

### Example structure

```lua
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

---

## Rules for Inline Intent Comments

Add `--` comments to explain:

1. **Magic values or constants** — what they represent and why.
   ```lua
   if #party < MIN_PARTY_SIZE then  -- MIN_PARTY_SIZE = 2; need at least 2 adventurers
   ```

2. **Order-dependent operations** — why order matters.
   ```lua
   -- Must call :Open() before :Query(); connection not ready until after Open
   connection:Open()
   ```

3. **Workarounds or defensive code** — what edge case is being handled.
   ```lua
   -- Guard against race where player leaves before data loads
   if not profile then return Result.Err("PlayerGone", "Player left") end
   ```

4. **Complex conditionals** — explain the logical intent.
   ```lua
   -- Adventurer is available only if not currently on expedition
   if not adventurer.OnExpedition then
   ```

### Specific scenarios that NEED comments

1. **Complex loop bodies** — if the loop does more than one operation, add comments inside.
   ```lua
   for _, adventurer in party do
       -- Validate before adding (skip if already marked)
       if adventurer.OnExpedition then continue end
       
       -- Mark departure and record timestamp
       adventurer.OnExpedition = true
       adventurer.DepartedAt = os.time()
       
       -- Notify dependent systems (UI, quest tracker)
       self._PartyMemberDeparted:Fire(adventurer.Id)
   end
   ```

2. **Complex callbacks or closures** — explain the closure's purpose and captured state.
   ```lua
   -- Cache the validator to avoid lookups during async operations
   local validator = function(quest) return not quest.IsExpired end
   ```

3. **Loops with non-obvious transformations** — what is being built and why.
   ```lua
   -- Convert adventurers to IDs for network transmission (lightweight)
   local ids = {}
   for _, a in party do table.insert(ids, a.Id) end
   ```

4. **Callback functions (signal handlers, Janitor)** — explain what happens and any side effects.
   ```lua
   -- Signal handlers: update UI when quest status changes
   quest.StatusChanged:Connect(function(newStatus)
       if newStatus == "Complete" then self._completeUI:Update() end
   end)
   
   -- Janitor cleanup: disconnect signal when entity despawns
   janitor:Add(enemy.Died:Connect(function()
       self:_RemoveEnemy(enemy.Id)
   end))
   ```

5. **Temporary state mutations** — explain the implicit contract.
   ```lua
   -- Temporarily mark as "InProgress" so status checks don't treat it as idle
   expedition._transient = "InProgress"
   ```

6. **Early returns or guards** — explain the reasoning, not just the condition.
   ```lua
   -- Party size validated by spec; skip redundant check here
   if not party then return Result.Err("NoParty") end
   ```

7. **Complex boolean logic** — break down the condition.
   ```lua
   -- Proceed if: (1) active quest AND (2) full party OR (3) raid lead
   if profile.ActiveQuest and (#party == MAX or isLead) then
   ```

8. **Type conversions or encoding** — what format/representation is being used.
   ```lua
   -- Convert multiplier to percentage string (3.5x → "350%")
   local str = tostring(math.floor(mult * 100)) .. "%"
   ```

9. **State dependencies or ordering** — why operations must happen in sequence.
   ```lua
   -- Must create quest before assigning; quest ID needed for party assignment
   local quest = self:_CreateQuest(questId)
   self:_AssignToParty(party, quest.Id)
   ```

10. **Workarounds for engine limits** — what problem is being worked around.
    ```lua
    -- Roblox physics tick after render; delay to let constraints settle
    task.wait(0.01)
    ```

11. **Table merging or config operations** — the direction and priority of merging.
    ```lua
    -- Merge defaults into user config (user settings override)
    for k, v in DEFAULT_CONFIG do
        if settings[k] == nil then settings[k] = v end
    end
    ```

12. **Variables with shortcut/abbreviated names** — what the abbreviation means.
    ```lua
    -- exp = experience points earned this session
    local exp = player.Stats.SessionXP
    ```

### What NOT to comment

- Local helper variables with clear names.
- Code that already reads like prose.
- Obvious conditionals (`if x then`, `for _, v in x do`).
- Single-line functions.
- Moonwave-style comments (no `--[=[`, no `---`, no `@param` tags).

---

## Output format

After editing, output:

```
Files updated: N
```

Then for each file:

```
## [file path]
- Added N phase labels to function(s): FunctionA, FunctionB
- Added N inline comments to explain: <brief reason>
- Skipped (already clear): FunctionC
```

If no changes were needed for a file, skip it entirely.

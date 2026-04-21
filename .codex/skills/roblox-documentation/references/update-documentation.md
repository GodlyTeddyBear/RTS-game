<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Add or update Moonwave doc comments for the file or folder specified in $ARGUMENTS. Write doc comments directly into the files — do not produce a report.

---

## Before starting

Read the following doc — it defines the comment syntax and tag rules for this project:

- `.codex/documents/coding-style/MOONWAVE.md`

Do not write any comments without having read that doc first.

---

## How to run

1. Read every `.lua` file in the specified path.
2. For each file, identify all public-facing items: the module table (class), public functions/methods, properties, types, and interfaces.
3. Add or update Moonwave doc comments for every public item.
4. For private (`_`-prefixed) functions, add a plain `--` comment above the signature explaining what it does and why it exists. Do not use Moonwave block syntax for these.
5. Inside any function body (public or private), add inline `--` comments on non-trivial logic blocks where the intent is not obvious from the code alone. For complex actions, comment each major action block and state what it is doing.
6. After editing all files, output a summary of what was added or updated.

---

## Rules

### Top of file Documentaiton

The /update-documentation skill removes existing plain-comment documentation blocks at the top of files when adding Moonwave @class declarations. It should preserve these blocks and place the Moonwave doc comment after them instead.

Example: A file with a --[[...]] documentation block at the top should keep that block and have the @class Moonwave comment added after it, not replace it.

### Class declaration

Every file must have exactly one `--[=[  @class <Name>  ]=]` block placed directly above the module table declaration.

- Use the file name (without `.lua`) as the class name.
- Add a one-sentence description of what the class does.
- Add `@server`, `@client`, or both depending on where the file runs.

### @within on everything

Every non-class doc block must include `@within <ClassName>`. Omitting it causes Moonwave to silently discard the item.

### Functions and methods

For each public function or method, write a `--[=[  ]=]` block that includes:

- A one-sentence description (imperative mood: "Awards coins to the player", not "This awards…").
- `@within <ClassName>`
- `@param name type -- description` for every parameter (skip `self`).
- `@return type -- description` for every return value. If the function returns a `Result`, annotate as `@return Result<T> -- description`.
- `@yields` if the function calls `:Wait()`, `task.wait`, or any DataStore/ProfileStore API.
- `@error string -- description` if the function can throw (use `error()`).

### Properties

For module-level fields assigned at the top of the file, add:

```
--[=[
    @prop FieldName type
    @within ClassName
    Description.
]=]
```

### Types and interfaces

For exported `type` aliases, add `@type` with `@within`. For table-shaped types, use `@interface` with dot-notation fields.

### Comment style

- Use `--[=[ ... ]=]` (block style) for all doc comments — never `---` in these files unless the file already uses `---` exclusively.
- Pick one style per file and stay consistent.
- Descriptions support Markdown. Use backticks for code references.

### Private functions

For `_`-prefixed functions, do **not** use Moonwave block syntax. Instead, place a plain `--` comment directly above the function signature:

- One sentence describing what the function does and why it exists.
- If there are non-obvious constraints, ordering requirements, or edge cases handled inside, note them here too.

```lua
-- Clamps the raw XP delta to prevent overflow when the player is near the level cap.
local function _clampDelta(delta: number, current: number, cap: number): number
```

### Sub-section comments inside function bodies

For any function (public or private) with more than ~3 distinct operations, add a `--` comment at the start of each logical phase. Write these even when the phase is obvious — the goal is scanability, not compensating for unclear code. A reader should be able to skim the comments and understand the full shape of the function before reading a single line of code.

```lua
function QuestService:CompleteMission(player, questId)
    -- Load the player's active quest
    local profile = ProfileManager:GetData(player)
    local quest = profile.Quests[questId]

    -- Mark the quest complete
    quest.CompletedAt = os.time()
    quest.Status = "Complete"

    -- Grant all configured rewards
    for _, reward in QuestConfig[questId].Rewards do
        InventoryService:Grant(player, reward)
    end

    -- Persist and notify
    ProfileManager:Save(player)
    self._QuestCompleted:Fire(player, questId)
end
```

In addition, add inline `--` comments for:

- **Magic values or constants**: explain what they represent.
- **Order-dependent operations**: explain why the order matters.
- **Workarounds or defensive code**: explain what edge case is being handled.
- **Complex actions**: comment each major action in the sequence, and explicitly state what the action does.

When a function has a long or multi-stage sequence of complex actions, use step-style sub-section comments so the flow is easy to scan:

```lua
-- Step 1: Resolve authoritative player state
local profile = ProfileManager:GetData(player)

-- Step 2: Validate preconditions for quest completion
assert(profile.Quests[questId], "Quest must exist before completion")

-- Step 3: Apply completion side effects
profile.Quests[questId].Status = "Complete"

-- Step 4: Persist and notify dependent systems
ProfileManager:Save(player)
self._QuestCompleted:Fire(player, questId)
```

### Why, not what

Sub-section labels name the _intent_ of the phase ("Grant all configured rewards"), not a literal restatement of the code ("loop over rewards table"). For non-obvious logic, comments must also explain _why_.

| Bad (restates code)    | Good (explains intent)                                        |
| ---------------------- | ------------------------------------------------------------- |
| `-- increment counter` | `-- offset by 1 because ProfileStore indices are 1-based`     |
| `-- check if nil`      | `-- guard against race where player leaves before data loads` |
| `-- loop over rewards` | `-- grant all configured rewards`                             |

### Do not document

- Local helper variables.
- Items already marked `@private` or `@ignore`.
- Single-line functions whose entire body is self-evident.

---

## Output format

After editing, output:

```
Files updated: N
```

Then for each file:

```
## [file path]
- Added @class <Name>
- Documented: FunctionA, FunctionB, PropertyC
- Skipped (private): _HelperX, _HelperY
```

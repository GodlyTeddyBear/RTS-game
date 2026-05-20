# SharedPlus

Shared utility for flat `SharedTable` authoring and reuse in parallel Luau workflows.

`SharedPlus` has three layers:

- v1 direct helpers for one-off `SharedTable` creation and mutation
- v2 reusable handles that stage writes in Lua and emit a new root `SharedTable` on each finalize
- v3 compiled packet writers that batch scalar, array, increment, and clear operations into one write pass

The package is flat-only. It does not support nested shared-table storage, nested dictionary flattening, or context-specific orchestration.

## What It Does

- creates root `SharedTable`s and child array `SharedTable`s
- replaces root scalar fields through a small shared helper API
- increments numeric fields
- replaces and clears flat array fields
- rebuilds handle-backed root snapshots on finalize
- mirrors array logical counts onto root scalar fields such as `PositionsCount`
- flattens nested array authoring input on declared fields through `TableUtil.Flat`
- uses a private `TableRecycler` handle internally for temporary Lua scratch state
- supports bulk partial packet writes through a compiled schema surface

## Public Surface

Top-level helper API:

- `SharedPlus.CreateRoot(initialFields?)`
- `SharedPlus.Clone(sharedTable)`
- `SharedPlus.Clear(sharedTable)`
- `SharedPlus.Size(sharedTable)`
- `SharedPlus.ReplaceFields(sharedTable, fields)`
- `SharedPlus.IncrementField(sharedTable, fieldName, delta?)`
- `SharedPlus.ReplaceArray(sharedTable, fieldName, values, countFieldName?)`
- `SharedPlus.ClearArray(sharedTable, fieldName, countFieldName?)`

Reusable handle API:

- `SharedPlus.Handle.new(schema, config?)`
- `Handle:BeginWrite()`
- `Handle:SetScalar(fieldName, value)`
- `Handle:IncrementScalar(fieldName, delta?)`
- `Handle:WriteArray(fieldName, sourceArray)`
- `Handle:Append(fieldName, value)`
- `Handle:SetIndex(fieldName, index, value)`
- `Handle:ResetField(fieldName)`
- `Handle:Finalize()`
- `Handle:GetRoot()`
- `Handle:ClearAll()`
- `Handle:Destroy()`

Compiled packet API:

- `SharedPlus.Compiler.Compile(schema)`
- `compiled.new(handleConfig?)`
- `compiled:NewHandle(handleConfig?)`
- `CompiledHandle:BeginWrite()`
- `CompiledHandle:WritePacket(packet)`
- `CompiledHandle:Finalize()`
- `CompiledHandle:GetRoot()`
- `CompiledHandle:Destroy()`

## Schema Shape

`SharedPlus.Handle.new` and `SharedPlus.Compiler.Compile` accept this schema shape:

```lua
{
	Scalars = {
		Version = {
			Default = 0,
			AllowIncrement = true,
		},
		Label = {
			Default = "Idle",
		},
	},
	Arrays = {
		Positions = {},
		Groups = {
			FlattenInput = true,
			CountFieldName = "GroupCount",
		},
	},
}
```

Scalar field options:

- `Default` sets the initial value and reset value
- `AllowIncrement = true` enables `IncrementScalar` and packet increment ops

Array field options:

- `FlattenInput = true` allows nested arrays and flattens them before writing
- `CountFieldName` overrides the default `<FieldName>Count`
- `CapacityHint` is accepted in the schema shape, but the current implementation does not use it yet

## Direct Helper Usage

Use the direct helpers when you do not need a reusable write cycle:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPlus = require(ReplicatedStorage.Utilities.SharedPlus)

local root = SharedPlus.CreateRoot({
	Version = 1,
})

SharedPlus.ReplaceFields(root, {
	Name = "Alpha",
})

SharedPlus.IncrementField(root, "Version", 2)
SharedPlus.ReplaceArray(root, "Ids", { 10, 20, 30 }, "IdsCount")
```

After this:

- `root.Version == 3`
- `root.Name == "Alpha"`
- `root.Ids` is a child `SharedTable`
- `root.IdsCount == 3`

## Reusable Handle Usage

Use a handle when the same shared-memory shape is written repeatedly:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPlus = require(ReplicatedStorage.Utilities.SharedPlus)

local handle = SharedPlus.Handle.new({
	Scalars = {
		Version = {
			Default = 0,
			AllowIncrement = true,
		},
	},
	Arrays = {
		Positions = {},
	},
})

handle:BeginWrite()
handle:SetScalar("Version", 5)
handle:Append("Positions", Vector3.new(1, 0, 0))
handle:Append("Positions", Vector3.new(2, 0, 0))
handle:Finalize()

local root = handle:GetRoot()
```

Important handle rules:

- call `BeginWrite()` before any mutation
- call `Finalize()` to publish scalar changes and count fields
- do not call `BeginWrite()` again while a write is still active
- `Finalize()` returns a new root snapshot for that write cycle
- `GetRoot()` returns the latest finalized root snapshot
- root identity may change across finalize cycles
- `Append()` and `SetIndex()` mutate staged Lua array state until finalize

## Flattened Array Usage

If an array field declares `FlattenInput = true`, nested arrays are accepted:

```lua
local handle = SharedPlus.Handle.new({
	Arrays = {
		Groups = {
			FlattenInput = true,
		},
	},
})

handle:BeginWrite()
handle:WriteArray("Groups", {
	{ "A", "B" },
	{ "C" },
})
handle:Finalize()
```

After finalize:

- `root.Groups[1] == "A"`
- `root.Groups[2] == "B"`
- `root.Groups[3] == "C"`
- `root.GroupsCount == 3`

Nested dictionaries are rejected. Flattening is for nested arrays only.

## Compiled Packet Usage

Use the compiled writer when the caller wants to batch updates into one packet:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPlus = require(ReplicatedStorage.Utilities.SharedPlus)

local compiled = SharedPlus.Compiler.Compile({
	Scalars = {
		Version = {
			Default = 0,
			AllowIncrement = true,
		},
		Label = {
			Default = "Idle",
		},
	},
	Arrays = {
		Ids = {},
		Groups = {
			FlattenInput = true,
		},
	},
})

local handle = compiled.new()

handle:BeginWrite()
handle:WritePacket({
	Scalars = {
		Label = "Warm",
	},
	Arrays = {
		Ids = { 10, 20, 30 },
	},
	Ops = {
		Increment = {
			Version = 1,
		},
	},
})
handle:Finalize()
```

Packet shape:

```lua
{
	Scalars = {
		FieldName = value,
	},
	Arrays = {
		ArrayField = { ... },
	},
	Ops = {
		Increment = {
			Counter = 1,
		},
		Clear = {
			ArrayField = true,
		},
	},
}
```

Packet behavior:

- missing fields are ignored
- `Scalars` replace declared scalar fields
- `Arrays` replace declared array contents for that write cycle
- `Ops.Increment` adds to increment-enabled numeric scalar fields
- `Ops.Clear` resets declared fields
- packet writes still require `Finalize()`

## Current Limitations

- storage is flat-only
- nested dictionary flattening is not supported
- array values must be contiguous
- non-flattening array fields only accept flat arrays
- `CapacityHint` is parsed but not used yet
- the current implementation updates count fields on finalize; it does not expose extra array metadata beyond the root count field

## When To Use It

Prefer `SharedPlus` when:

- a parallel worker or actor flow reuses the same shared-memory shape every frame or tick
- the caller wants a reusable snapshot builder without open-coding shared-memory packing each time
- nested arrays are a convenient authoring shape but the runtime storage should stay flat
- the caller wants one bulk packet write instead of many per-field calls

Do not use `SharedPlus` when:

- the data truly needs deep nested shared-table storage
- the workflow is context-specific orchestration rather than shared technical memory authoring
- plain Lua tables are sufficient and no `SharedTable` boundary exists

# Shared Utility Template

Use this as the scaffold reference for a shared technical utility in `ReplicatedStorage/Utilities/`, including `PlacementPlus`, `SpatialQuery`, `Orient`, `StateMachine`, and `ModelPlus`.

If `$ARGUMENTS` is empty, stop and ask for the utility name and whether it is a single file or a package.

---

## Target Shape

Use the shape that matches the utility type.

### Single-File Utility

Use this shape for `ModelPlus`, `StateMachine`, and similar single-module helpers.

```text
src/ReplicatedStorage/Utilities/ModelPlus.lua
src/ReplicatedStorage/Utilities/StateMachine.lua
```

### Package Utility

Use this shape for folder-backed utilities such as `PlacementPlus`, `SpatialQuery`, and `Orient`.

```text
src/ReplicatedStorage/Utilities/PlacementPlus/
|-- init.lua
`-- src/
    |-- Candidate.lua
    |-- Footprint.lua
    |-- Profiles.lua
    |-- Rules.lua
    |-- Types.lua
    `-- Validation.lua
```

```text
src/ReplicatedStorage/Utilities/SpatialQuery/
|-- init.lua
`-- src/
    |-- init.lua
    |-- Options.lua
    |-- Presets.lua
    |-- Queries.lua
    |-- Selection.lua
    |-- Shared.lua
    `-- Types.lua
```

```text
src/ReplicatedStorage/Utilities/Orient/
|-- init.lua
`-- src/
    |-- Constants.lua
    |-- Conversion.lua
    |-- Facing.lua
    |-- init.lua
    |-- Interpolation.lua
    |-- Patterns.lua
    |-- Projection.lua
    |-- Random.lua
    |-- Snapping.lua
    |-- Spatial.lua
    |-- Translation.lua
    |-- Types.lua
    `-- Validation.lua
```

---

## Core Rules

- Keep the utility technical and reusable.
- Return data, transforms, or helper behavior; do not own lifecycle, orchestration, or context-specific rules.
- Respect utility ownership boundaries:
  - `Orient` owns reusable facing, interpolation, projection, translation, snapping, and rotation helpers.
  - `SpatialQuery` owns reusable target filtering, range checks, line-of-sight checks, and overlap/query selection helpers.
  - `ModelPlus` owns reusable model pivot, bounds, alignment, and traversal helpers.
  - `PlacementPlus` owns reusable placement candidate, snapping, and footprint or clearance validation helpers.
- When a use case fits one of these utilities, use that utility and do not create a custom replacement.
- Keep the public surface small and focused on the utility's named responsibility.
- Add new helpers only when multiple call sites or multiple scenarios will use them.

---

## Utility Selection Guide

Use this guide to pick the right utility before adding new code.

| Situation | Prefer | Do not replace with |
|---|---|---|
| Cursor-driven placement preview, ghost model alignment, grid snapping, or footprint validation | `PlacementPlus` | Feature-specific placement math or model-specific positioning code |
| Target filtering, range checks, line-of-sight checks, nearest-candidate selection, or overlap tests | `SpatialQuery` | Raw `workspace` queries or repeated raycast/overlap setup |
| Facing, look-at, yaw adjustment, interpolation, translation, snapping, or rotation normalization | `Orient` | Per-feature `CFrame` math wrappers |
| Valid state transitions, legal/illegal state changes, or state lifecycle guarding | `StateMachine` | Manual boolean flags or scattered transition checks |
| Pivot access, bounds, center, top/bottom alignment, or descendant traversal on a model | `ModelPlus` | Repeated model traversal and pivot math |

---

## PlacementPlus

Use `PlacementPlus` when a caller needs a placement candidate that may be shown, validated, snapped, or committed.

### Good placement situations

- Build a ghost preview from cursor hit position.
- Snap a building to a surface or grid.
- Check if a footprint overlaps blocking geometry.
- Align the bottom of a structure to the ground.
- Validate clearance before spending resources.

### Bad placement situations

- Spend resources and spawn the final structure.
- Decide whether a player is allowed to build that structure.
- Write ECS or persistence state.

### Example: placement preview

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementPlus = require(ReplicatedStorage.Utilities.PlacementPlus)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)

local function buildPreviewCandidate(model: Model, cursorPosition: Vector3, gridSize: Vector3, validationOptions: any)
	local footprint = PlacementPlus.BuildFootprintFromBounds(model:GetExtentsSize())
	local candidate = PlacementPlus.BuildCandidateFromWorldPosition(cursorPosition, {
		Model = model,
		PositionGridSize = gridSize,
		AlignToGround = true,
	})

	local validation = PlacementPlus.ResolvePlacementCandidate(
		{ Position = cursorPosition },
		{
			Model = model,
			PositionGridSize = gridSize,
		},
		validationOptions
	)

	return {
		Candidate = candidate,
		Footprint = footprint,
		IsClear = validation.Validation.success and PlacementPlus.IsClearOfObstacles(candidate, validationOptions),
		Pivot = ModelPlus.BuildBottomAlignedPivot(model, candidate.Position),
	}
end

return buildPreviewCandidate
```

### Example: commit flow

```lua
--!strict

local function commitPlacement(candidate: any, placeCommand: any)
	if not candidate.IsClear then
		return false
	end

	return placeCommand:Execute(candidate)
end
```

### Example: bad flow

```lua
-- Wrong: the helper owns the business decision and placement side effects.
local function placeModel(model: Model, player: Player, cursorPosition: Vector3)
	if player.leaderstats.Money.Value < 100 then
		return false
	end

	model:PivotTo(CFrame.new(cursorPosition))
	return true
end
```

---

## SpatialQuery

Use `SpatialQuery` when the caller needs reusable spatial selection or filtering logic.

### Good spatial situations

- Find the nearest enemy in range.
- Check whether a point is inside a region or footprint.
- Filter visible targets by line of sight.
- Build overlap parameters once and reuse them.
- Select a candidate from a filtered set by distance or priority.

### Bad spatial situations

- Move the model or actor.
- Decide combat policy or build permission.
- Own the world query lifetime or entity ownership.

### Example: nearest target

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local function findNearestEnemy(origin: Vector3, enemies: { Model }, maxRange: number): Model?
	return SpatialQuery.FindBestCandidate(enemies, function(enemy: Model)
		local position = enemy:GetPivot().Position
		if not SpatialQuery.IsWithinRange(origin, position, maxRange) then
			return nil
		end

		return {
			Candidate = enemy,
			Score = (position - origin).Magnitude,
		}
	end)
end

return findNearestEnemy
```

### Example: visibility check

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local function canSeeTarget(origin: Vector3, target: Model, raycastOptions: RaycastParams): boolean
	return SpatialQuery.IsWithinRaycastRange(origin, target:GetPivot().Position, raycastOptions)
end
```

### Example: bad flow

```lua
-- Wrong: the query helper is being used to own combat policy.
local function chooseTarget(origin: Vector3, enemies: { Model }, damageThreshold: number): Model?
	for _, enemy in ipairs(enemies) do
		if enemy:GetAttribute("Armor") <= damageThreshold then
			return enemy
		end
	end

	return nil
end
```

---

## Orient

Use `Orient` when the caller needs reusable facing, translation, projection, interpolation, or snapping helpers.

### Good orientation situations

- Turn a unit toward a target position.
- Move a model forward while preserving its facing.
- Build a flat look-at CFrame for ground movement.
- Snap yaw to a step angle.
- Project motion onto a plane or axis.

### Bad orientation situations

- Pick a combat target.
- Validate placement legality.
- Mutate state-machine state.

### Example: facing a target

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Orient = require(ReplicatedStorage.Utilities.Orient)

local function turnToward(model: Model, targetPosition: Vector3)
	local pivot = model:GetPivot()
	local lookAt = Orient.BuildFlatLookAt(pivot.Position, targetPosition)
	if lookAt ~= nil then
		model:PivotTo(lookAt)
	end
end
```

### Example: movement step

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Orient = require(ReplicatedStorage.Utilities.Orient)

local function stepForward(position: Vector3, target: Vector3, speed: number, dt: number): Vector3
	return Orient.MoveTowards(position, target, speed * dt)
end
```

### Example: snapped rotation

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Orient = require(ReplicatedStorage.Utilities.Orient)

local function snapYaw(model: Model, angleStepDegrees: number)
	return Orient.SnapYaw(model:GetPivot(), angleStepDegrees)
end
```

### Example: bad flow

```lua
-- Wrong: orientation code is being used to hide movement policy and ownership.
local function advanceEnemy(enemy: Model, target: Vector3)
	if enemy:GetAttribute("CanMove") then
		enemy:PivotTo(CFrame.new(target))
	end
end
```

---

## StateMachine

Use `StateMachine` when a flow has legal transitions and the caller needs a guarded state source.

### Good state situations

- Run lifecycle states such as `Idle`, `Prep`, `Wave`, and `Resolution`.
- Menu or screen flow with a controlled progression.
- Action state with explicit transition rules.
- Any flow that needs to reject invalid transitions instead of silently accepting them.

### Bad state situations

- Temporary boolean flags that do not have legal transitions.
- Feature-specific orchestration that should live in a context service.
- Event subscriptions or timing loops.

### Example: run lifecycle

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local RunStateMachine = StateMachine.new({
	InitialState = "Idle",
	Transitions = {
		Idle = { "Prep" },
		Prep = { "Wave", "RunEnd" },
		Wave = { "Resolution", "RunEnd" },
		Resolution = { "Wave", "Climax", "RunEnd" },
		Climax = { "Endless", "RunEnd" },
		Endless = { "RunEnd" },
	},
})

local function startRun()
	local transition = RunStateMachine:Transition("Prep")
	if not transition.success then
		return Result.Err("InvalidStateTransition", transition.error)
	end

	return transition
end
```

### Example: action state guard

```lua
--!strict

local function canStartAttack(stateMachine: any): boolean
	return stateMachine:GetState() == "Idle"
end
```

### Example: bad flow

```lua
-- Wrong: the transition logic is scattered across booleans.
local isPrep = false
local isWave = false
local isResolution = false
```

---

## ModelPlus

Use `ModelPlus` when the caller needs reusable model pivot, bounds, or traversal helpers.

### Good model situations

- Read pivot, center, bounds, top, or bottom values.
- Move a model to a position or CFrame.
- Align a model to the ground or to another model.
- Find descendants by selector or predicate.
- Standardize how model transforms are applied across contexts.

### Bad model situations

- Decide gameplay ownership.
- Write persistence or ECS lifecycle state.
- Replace a proper instance factory or sync service.

### Example: bottom alignment

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)

local function placeStructure(model: Model, worldPos: Vector3)
	ModelPlus.MoveBottomAligned(model, worldPos)
end
```

### Example: bounds and center

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)

local function readFootprint(model: Model)
	local boundsCFrame, boundsSize = ModelPlus.GetBounds(model)
	return {
		Center = boundsCFrame.Position,
		Size = boundsSize,
	}
end
```

### Example: descendant lookup

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)

local function findPrimaryPart(model: Model): BasePart?
	return ModelPlus.FindDescendant(model, function(instance: Instance)
		return instance:IsA("BasePart") and instance.Name == "Primary"
	end) :: BasePart?
end
```

### Example: bad flow

```lua
-- Wrong: the utility is being used to own game-object lifecycle.
local function spawnAndConfigure(model: Model, parent: Instance)
	model.Parent = parent
	model:Destroy()
end
```

---

## Package Utility Example

Use this shape for utilities like `PlacementPlus`, `SpatialQuery`, and `Orient`.

```lua
--!strict

local Shared = require(script.src.Shared)
local Types = require(script.src.Types)

local Utility = {}

function Utility.SomeHelper(_input: any)
	return Shared.Normalize(_input)
end

return table.freeze(Utility)
```

### Package composition guidance

- Put shared normalization, shared constants, and shared internal types under `src/`.
- Keep `init.lua` as the public entry point.
- Split by technical concern, not by feature story.
- Use `Shared.lua` or `Validation.lua` when multiple internal modules need the same rule.

---

## Prohibitions

- Do not put bounded-context business rules into a shared utility.
- Do not make the utility own ECS world state, instance lifecycle, or persistence lifecycle.
- Do not create one-off wrappers around a utility when the shared utility already covers the use case.
- Do not write hacky ad hoc equivalents for `Orient`, `SpatialQuery`, `ModelPlus`, or `PlacementPlus` when their owned use case fits.
- Do not bypass `Orient`, `SpatialQuery`, `ModelPlus`, or `PlacementPlus` with custom math or query helpers for covered scenarios.
- Do not expand the surface with convenience methods that only serve one call site.
- Do not mix `PlacementPlus`, `SpatialQuery`, `Orient`, `StateMachine`, and `ModelPlus` responsibilities into a single helper.

---

## Failure Signals

- The utility starts deciding who owns the result instead of returning technical data.
- The utility starts wiring events, services, or lifecycle callbacks.
- A caller duplicates logic that should have used `PlacementPlus`, `SpatialQuery`, `Orient`, `StateMachine`, or `ModelPlus`.
- The module grows feature-specific branching instead of reusable helper behavior.
- A package utility starts looking like a feature service instead of a technical helper.

---

## Checklist

- [ ] The utility is reusable across more than one call site.
- [ ] The utility does not own lifecycle, orchestration, or business rules.
- [ ] The target shape matches whether the utility is a single file or a package.
- [ ] The public API stays small and focused.
- [ ] The doc names the correct utility and module path.
- [ ] The examples cover at least one realistic use case for the named utility.
- [ ] The examples include at least one negative example or prohibition-worthy counterexample.

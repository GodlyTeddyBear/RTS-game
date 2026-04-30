# AI System Template

Use this as the scaffold reference for a context-owned AI system built on `ReplicatedStorage/Utilities/AI`.

The AI package is shared infrastructure. The context still owns:

- behavior definitions
- executors, hooks, and runtime adapters
- actor registration and setup writing
- runtime registration and frame ownership
- any ECS or service state that AI reads or mutates
- context bootstrap, event wiring, and shutdown around the runtime

---

## Target Shape

```text
src/ServerScriptService/Contexts/<ContextName>/
|-- <ContextName>Context.lua
|-- Application/
|   |-- Commands/
|   `-- Queries/
|-- Config/
|   `-- <ContextName>BehaviorConfig.lua
|-- Infrastructure/
|   |-- BehaviorSystem/
|   |   |-- Actions/
|   |   |-- Behaviors/
|   |   |-- Executors/
|   |   |-- Hooks/
|   |   `-- Nodes/
|   `-- Services/
|       `-- <ContextName>BehaviorRuntimeService.lua

src/ReplicatedStorage/Utilities/AI/
|-- init.lua
|-- src/
|   |-- Builder.lua
|   |-- BehaviorCatalog.lua
|   |-- SetupWriter.lua
|   |-- Types.lua
|   `-- Validation.lua
|-- AdapterFactory/
|-- Behavior/
`-- Runtime/
```

---

## Context Setup Example

This example shows a context wiring the AI runtime into `BaseContext`, registering scheduler work, and subscribing to shared events before the first tick runs.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local <ContextName>BehaviorRuntimeService = require(script.Parent.Infrastructure.Services.<ContextName>BehaviorRuntimeService)
local <ContextName>BehaviorConfig = require(script.Parent.Config.<ContextName>BehaviorConfig)
local Process<ContextName>TickCommand = require(script.Parent.Application.Commands.Process<ContextName>Tick)
local Refresh<ContextName>AssignmentsCommand = require(script.Parent.Application.Commands.Refresh<ContextName>Assignments)
local Reset<ContextName>Command = require(script.Parent.Application.Commands.Reset<ContextName>)

local <ContextName> = Knit.CreateService({
	Name = "<ContextName>Context",
	Client = {},
	Modules = {
		Infrastructure = {
			{
				Name = "<ContextName>BehaviorRuntimeService",
				Module = <ContextName>BehaviorRuntimeService,
				CacheAs = "_behaviorRuntimeService",
			},
		},
		Application = {
			{
				Name = "Process<ContextName>TickCommand",
				Module = Process<ContextName>TickCommand,
				CacheAs = "_processTickCommand",
			},
			{
				Name = "Refresh<ContextName>AssignmentsCommand",
				Module = Refresh<ContextName>AssignmentsCommand,
				CacheAs = "_refreshAssignmentsCommand",
			},
			{
				Name = "Reset<ContextName>Command",
				Module = Reset<ContextName>Command,
				CacheAs = "_resetCommand",
			},
		},
	},
	ExternalServices = {
		{ Name = "BaseContext", CacheAs = "_baseContext" },
	},
	StartOrder = { "Infrastructure", "Application" },
})

local <ContextName>BaseContext = BaseContext.new(<ContextName>)
local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

function <ContextName>:KnitInit()
	<ContextName>BaseContext:KnitInit()

	-- If this context is profile-backed, register the loader before any lifecycle wiring starts.
	-- <ContextName>BaseContext:RegisterProfileLoader()

	<ContextName>BaseContext:RegisterSchedulerSystem(<ContextName>BehaviorConfig.TickPhase, function()
		self:_RunBehaviorFrame()
	end)

	<ContextName>BaseContext:OnGameEvent("RunEnded", function()
		self:_OnRunEnded()
	end, "_runEndedConnection")

	<ContextName>BaseContext:OnContextEvent("<ContextName>", "ActorSpawned", function(entity: number, actorType: string)
		self:_OnActorSpawned(entity, actorType)
	end, "_actorSpawnedConnection")

	<ContextName>BaseContext:OnContextEvent("<ContextName>", "ActorRemoved", function(actorType: string, entity: number)
		self:_OnActorRemoved(actorType, entity)
	end, "_actorRemovedConnection")
end

function <ContextName>:KnitStart()
	<ContextName>BaseContext:KnitStart()

	-- Optional when the AI system also owns player-facing sync state.
	-- <ContextName>BaseContext:HydrateExistingAndAddedPlayers("_behaviorSyncService", {
	-- 	MethodName = "HydratePlayer",
	-- 	CacheAs = "_behaviorHydrateConnection",
	-- })
	-- <ContextName>BaseContext:RemoveLeavingPlayersByUserId("_behaviorSyncService", {
	-- 	MethodName = "RemovePlayer",
	-- 	CacheAs = "_behaviorRemoveConnection",
	-- })
end

function <ContextName>:_RunBehaviorFrame()
	Catch(function()
		local frameContext = {
			CurrentTime = os.clock(),
			DeltaTime = <ContextName>BaseContext:GetSchedulerDeltaTime(),
			Services = {
				BehaviorRuntimeService = self._behaviorRuntimeService,
			},
		}

		Try(self._processTickCommand:Execute(frameContext))
		return Ok(nil)
	end, "<ContextName>:RunBehaviorFrame")
end

function <ContextName>:_OnRunEnded()
	Catch(function()
		Try(self._resetCommand:Execute())
		return Ok(nil)
	end, "<ContextName>:OnRunEnded")
end

function <ContextName>:_OnActorSpawned(entity: number, actorType: string)
	Try(self._refreshAssignmentsCommand:Execute(entity, actorType))
end

function <ContextName>:_OnActorRemoved(actorType: string, entity: number)
	self._behaviorRuntimeService:HandleActorDeath(actorType, entity, {
		CurrentTime = os.clock(),
		DeltaTime = <ContextName>BaseContext:GetSchedulerDeltaTime(),
		Services = {
			BehaviorRuntimeService = self._behaviorRuntimeService,
		},
	})
end

function <ContextName>:EmitActorAssigned(entity: number, actorType: string)
	<ContextName>BaseContext:EmitContextEvent("<ContextName>", "ActorAssigned", entity, actorType)
end

return <ContextName>
```

---

## Behavior Runtime Service Example

This is the context-owned service that creates the AI runtime, registers actor adapters, and owns per-frame execution.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)

local <ContextName>BehaviorConfig = require(script.Parent.Parent.Config.<ContextName>BehaviorConfig)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local PerceptionHook = require(script.Parent.Parent.BehaviorSystem.Hooks.PerceptionHook)
local EnemyDefaultBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.EnemyDefault)
local StructureDefaultBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.StructureDefault)
local BossDefaultBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.BossDefault)

local BehaviorDefinitions = table.freeze({
	EnemyDefault = EnemyDefaultBehavior,
	StructureDefault = StructureDefaultBehavior,
	BossDefault = BossDefaultBehavior,
})

local <ContextName>BehaviorRuntimeService = {}
<ContextName>BehaviorRuntimeService.__index = <ContextName>BehaviorRuntimeService

function <ContextName>BehaviorRuntimeService.new()
	local self = setmetatable({}, <ContextName>BehaviorRuntimeService)
	self._runtime = AI.CreateRuntime({
		Conditions = Nodes.Conditions,
		Commands = Nodes.Commands,
		Hooks = {
			PerceptionHook,
		},
		ErrorSink = function(payload: any)
			Result.MentionError("<ContextName>:BehaviorRuntime", "AI runtime defect", {
				Stage = payload.Stage,
				ActorType = payload.ActorType,
				ActorLabel = payload.ActorLabel,
				Entity = payload.Entity,
				CauseType = payload.ErrorType,
				CauseMessage = payload.ErrorMessage,
				Details = payload.Details,
			}, payload.ErrorType)
		end,
	})

	-- Register the executor map once so action ids can resolve to runtime handlers.
	self._runtime:RegisterActions(Executors)
	return self
end

function <ContextName>BehaviorRuntimeService:Init(_registry: any, _name: string)
	-- The runtime is created in new(); Init stays available for registry symmetry.
end

function <ContextName>BehaviorRuntimeService:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
	self:_RegisterActorAdapters()
end

function <ContextName>BehaviorRuntimeService:BuildBehaviorTree(behaviorName: string): (any, number)
	local definition = BehaviorDefinitions[behaviorName]
	local tickInterval = <ContextName>BehaviorConfig.DefaultTickIntervalByBehavior[behaviorName]
		or <ContextName>BehaviorConfig.DefaultTickInterval
	return self._runtime:BuildTree(definition), tickInterval
end

function <ContextName>BehaviorRuntimeService:RunFrame(frameContext: any)
	return self._runtime:RunFrame(frameContext)
end

function <ContextName>BehaviorRuntimeService:HandleActorDeath(actorType: string, entity: number, frameContext: any)
	return self._runtime:HandleActorDeath(actorType, entity, frameContext)
end

function <ContextName>BehaviorRuntimeService:CancelActorAction(actorType: string, entity: number, frameContext: any)
	return self._runtime:CancelActorAction(actorType, entity, frameContext)
end

function <ContextName>BehaviorRuntimeService:_RegisterActorAdapters()
	self._runtime:RegisterActorType("Enemy", AI.CreateFactoryAdapter({
		ActorLabel = "Enemy",
		Factory = self._enemyEntityFactory,
		QueryActiveEntities = "QueryAliveEntities",
		GetBehaviorTree = "GetBehaviorTree",
		GetActionState = "GetCombatAction",
		SetActionState = "SetCombatAction",
		ClearActionState = "ClearAction",
		SetPendingAction = "SetPendingAction",
		UpdateLastTickTime = "UpdateBTLastTickTime",
		ShouldEvaluate = function(factoryObject: any, entity: number, currentTime: number): boolean
			local tree = factoryObject:GetBehaviorTree(entity)
			if tree == nil then
				return false
			end

			return currentTime - tree.LastTickTime >= tree.TickInterval
		end,
	}))

	self._runtime:RegisterActorType("Structure", AI.CreateFactoryAdapter({
		ActorLabel = "Structure",
		Factory = self._structureEntityFactory,
		QueryActiveEntities = "QueryActiveEntities",
		GetBehaviorTree = "GetBehaviorTree",
		GetActionState = "GetCombatAction",
		SetActionState = "SetCombatAction",
		ClearActionState = "ClearAction",
		SetPendingAction = "SetPendingAction",
		UpdateLastTickTime = "UpdateBTLastTickTime",
		ShouldEvaluate = function(factoryObject: any, entity: number, currentTime: number): boolean
			local tree = factoryObject:GetBehaviorTree(entity)
			if tree == nil then
				return false
			end

			return currentTime - tree.LastTickTime >= tree.TickInterval
		end,
	}))
end

return <ContextName>BehaviorRuntimeService
```

---

## Behavior Nodes Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Conditions = {
	HasTarget = function()
		return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
			if context.Facts.TargetEntity ~= nil then
				task:success()
				return
			end

			task:fail()
		end)
	end,
}

local Commands = {
	Attack = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.PendingAction = "Attack"
			context.PendingActionData = {
				TargetEntity = context.Facts.TargetEntity,
			}
			task:success()
		end)
	end,
}

return table.freeze({
	Conditions = Conditions,
	Commands = Commands,
})
```

---

## Behavior Definition Example

```lua
--!strict

local BehaviorDefinition = {
	Priority = {
		{
			Sequence = {
				"HasTarget",
				"Attack",
			},
		},
		"Attack",
	},
}

return table.freeze(BehaviorDefinition)
```

---

## Executor Example

Executors are the action handlers that the runtime calls after a behavior issues a pending action.
The public executor lifecycle is `Start`, `Tick`, `Cancel`, `Complete`, and `Death`, while subclass code usually implements the `OnStart`, `OnTick`, `OnCancel`, `OnComplete`, and `OnDeath` hooks from `BaseExecutor`.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)

local CombatAttackExecutor = {}
CombatAttackExecutor.__index = CombatAttackExecutor
setmetatable(CombatAttackExecutor, BaseExecutor)

function CombatAttackExecutor.new()
	return BaseExecutor.new({
		ActionId = "Attack",
		IsCommitted = false,
	})
end

function CombatAttackExecutor:CanStart(entity: number, actionData: any?, services: any)
	-- Resolve preconditions and begin the action here.
	return true, nil
end

function CombatAttackExecutor:OnStart(entity: number, actionData: any?, services: any)
	-- Prime transient state for the new action here.
end

function CombatAttackExecutor:OnTick(entity: number, dt: number, services: any)
	-- Continue the action until it succeeds or fails.
	return "Success"
end

function CombatAttackExecutor:OnCancel(entity: number, services: any)
	-- Clean up transient action state here.
end

function CombatAttackExecutor:OnComplete(entity: number, services: any)
	-- Finalize the action here.
end

function CombatAttackExecutor:OnDeath(entity: number, services: any)
	-- Handle actor removal while the action is active.
	-- Release transient state, stop effects, or notify dependent services here.
end

return CombatAttackExecutor
```

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

return {
	Attack = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.PendingAction = "Attack"
			context.PendingActionData = {
				TargetEntity = context.Facts.TargetEntity,
			}
			task:success()
		end)
	end,
}
```

When the owning context detects actor removal, it calls the runtime cleanup boundary:

```lua
local deathResult = self._runtime:HandleActorDeath(actorType, entity, frameContext)
if not deathResult.success then
	warn(deathResult.message)
end
```

If the runtime owns a `BaseExecutor` subclass, that cleanup path ends up at `OnDeath`.

---

## Hook Example

```lua
--!strict

local PerceptionHook = {}

function PerceptionHook.Use(entity: number, hookContext: any)
	return {
		Facts = {
			TargetEntity = hookContext.Services.EnemyEntityFactory:GetTarget(entity),
		},
		BehaviorContext = {
			Entity = entity,
		},
		Services = {
			EnemyEntityFactory = hookContext.Services.EnemyEntityFactory,
		},
	}
end

return table.freeze(PerceptionHook)
```

---

## Setup Writer Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)

local writer = AI.CreateFactorySetupWriter({
	Factory = enemyEntityFactory,
	WriteSetup = "SetBehaviorTree",
	ClearActionState = "ClearAction",
	OnMissingBehavior = "HandleMissingBehavior",
})

local setupResult = AI.CreateActorSetup(buildResult, {
	Entity = enemyEntity,
	ActorType = "Enemy",
	BehaviorName = "EnemyDefault",
})

AI.WriteActorSetup(setupResult, writer)
AI.WriteActorSetups({
	setupResult,
	AI.CreateActorSetup(buildResult, {
		Entity = supportEntity,
		ActorType = "Support",
		BehaviorName = "SupportDefault",
	}),
}, writer)
```

---

## Builder Example

Use the builder when one context wants to assemble behaviors, actor bundles, defaults, and setup metadata in one place.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)

local builtAi = AI.CreateSystem({
	Conditions = require(script.Parent.Infrastructure.BehaviorSystem.Nodes).Conditions,
	Commands = require(script.Parent.Infrastructure.BehaviorSystem.Nodes).Commands,
	Hooks = {
		require(script.Parent.Infrastructure.BehaviorSystem.Hooks.PerceptionHook),
	},
	ErrorSink = function(payload: any)
		warn(payload.Stage, payload.ActorType, payload.Entity, payload.ErrorMessage)
	end,
})
	:AddHooks({
		require(script.Parent.Infrastructure.BehaviorSystem.Hooks.PerceptionHook),
	})
	:LoadHooks(script.Parent.Infrastructure.BehaviorSystem.Hooks)
	:AddActions(require(script.Parent.Infrastructure.BehaviorSystem.Actions.CombatActions))
	:LoadActions(script.Parent.Infrastructure.BehaviorSystem.Actions)
	:AddActionPack(AI.CreateActionPack("CombatActions", require(script.Parent.Infrastructure.BehaviorSystem.Actions.CombatActions)))
	:AddActor(AI.CreateActorRegistration({
		ActorType = "Enemy",
		Adapter = AI.CreateFactoryAdapter({
			ActorLabel = "Enemy",
			Factory = enemyEntityFactory,
			QueryActiveEntities = "QueryAliveEntities",
			GetBehaviorTree = "GetBehaviorTree",
			GetActionState = "GetCombatAction",
			SetActionState = "SetCombatAction",
			ClearActionState = "ClearAction",
			SetPendingAction = "SetPendingAction",
			UpdateLastTickTime = "UpdateBTLastTickTime",
			ShouldEvaluate = "ShouldEvaluate",
		}),
		Actions = require(script.Parent.Infrastructure.BehaviorSystem.Actions.CombatActions),
	}))
	:AddActorBundle(AI.CreateActorBundle({
		ActorType = "Structure",
		Adapter = AI.CreateFactoryAdapter({
			ActorLabel = "Structure",
			Factory = structureEntityFactory,
			QueryActiveEntities = "QueryActiveEntities",
			GetBehaviorTree = "GetBehaviorTree",
			GetActionState = "GetCombatAction",
			SetActionState = "SetCombatAction",
			ClearActionState = "ClearAction",
			SetPendingAction = "SetPendingAction",
			UpdateLastTickTime = "UpdateBTLastTickTime",
			ShouldEvaluate = "ShouldEvaluate",
		}),
		Actions = require(script.Parent.Infrastructure.BehaviorSystem.Actions.StructureActions),
		ActionPacks = {
			AI.CreateActionPack("StructureActions", require(script.Parent.Infrastructure.BehaviorSystem.Actions.StructureActions)),
		},
		DefaultBehaviorName = "StructureDefault",
		TickInterval = 0.25,
		InitializeActionState = true,
	}))
	:AddActorPackage(AI.CreateActorPackage({
		ActorBundle = AI.CreateActorBundle({
			ActorType = "Boss",
			Adapter = AI.CreateFactoryAdapter({
				ActorLabel = "Boss",
				Factory = bossEntityFactory,
				QueryActiveEntities = "QueryAliveEntities",
				GetBehaviorTree = "GetBehaviorTree",
				GetActionState = "GetCombatAction",
				SetActionState = "SetCombatAction",
				ClearActionState = "ClearAction",
				SetPendingAction = "SetPendingAction",
				UpdateLastTickTime = "UpdateBTLastTickTime",
				ShouldEvaluate = "ShouldEvaluate",
			}),
			Actions = require(script.Parent.Infrastructure.BehaviorSystem.Actions.BossActions),
			DefaultBehaviorName = "BossDefault",
		}),
		Behaviors = {
			BossDefault = require(script.Parent.Infrastructure.BehaviorSystem.Behaviors.BossDefault),
		},
		Aliases = {
			BossIdle = "BossDefault",
		},
		ArchetypeDefaults = {
			Boss = "BossDefault",
		},
		FallbackBehaviorName = "EnemyDefault",
	}))
	:AddActorBundles({
		AI.CreateActorBundle({
			ActorType = "Minion",
			Adapter = AI.CreateFactoryAdapter({
				ActorLabel = "Minion",
				Factory = minionEntityFactory,
				QueryActiveEntities = "QueryAliveEntities",
				GetBehaviorTree = "GetBehaviorTree",
				GetActionState = "GetCombatAction",
				SetActionState = "SetCombatAction",
				ClearActionState = "ClearAction",
				SetPendingAction = "SetPendingAction",
				UpdateLastTickTime = "UpdateBTLastTickTime",
				ShouldEvaluate = "ShouldEvaluate",
			}),
			Actions = require(script.Parent.Infrastructure.BehaviorSystem.Actions.MinionActions),
		}),
	})
	:AddActorPackages({
		AI.CreateActorPackage({
			ActorBundle = AI.CreateActorBundle({
				ActorType = "Scout",
				Adapter = AI.CreateFactoryAdapter({
					ActorLabel = "Scout",
					Factory = scoutEntityFactory,
					QueryActiveEntities = "QueryAliveEntities",
					GetBehaviorTree = "GetBehaviorTree",
					GetActionState = "GetCombatAction",
					SetActionState = "SetCombatAction",
					ClearActionState = "ClearAction",
					SetPendingAction = "SetPendingAction",
					UpdateLastTickTime = "UpdateBTLastTickTime",
					ShouldEvaluate = "ShouldEvaluate",
				}),
				Actions = require(script.Parent.Infrastructure.BehaviorSystem.Actions.ScoutActions),
			}),
			Behaviors = {
				ScoutDefault = require(script.Parent.Infrastructure.BehaviorSystem.Behaviors.ScoutDefault),
			},
			FallbackBehaviorName = "EnemyDefault",
		}),
	})
	:AddBehaviors({
		EnemyDefault = require(script.Parent.Infrastructure.BehaviorSystem.Behaviors.EnemyDefault),
		StructureDefault = require(script.Parent.Infrastructure.BehaviorSystem.Behaviors.StructureDefault),
	})
	:LoadBehaviors(script.Parent.Infrastructure.BehaviorSystem.Behaviors)
	:SetBehaviorAlias("EnemyIdle", "EnemyDefault")
	:SetActorDefault("Enemy", "EnemyDefault")
	:SetArchetypeDefault("Elite", "BossDefault")
	:SetFallbackBehavior("EnemyDefault")
	:SetActorTickInterval("Enemy", 0.25)
	:SetDefaultTickInterval(0.5)
	:SetClearActionStateOnSetup(true)
	:Build()

return builtAi
```

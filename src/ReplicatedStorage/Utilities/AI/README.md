# AI

Shared package root for the project's AI utilities. `AI` exposes the package entrypoint, while `AI.Runtime`, `AI.AdapterFactory`, and `AI.Behavior` expose the underlying submodules directly. The package still does not own context lifecycle, ECS state, trees, hooks, executors, or teardown orchestration.

## Package Layout

- `src/init.lua` exposes the facade entrypoint and shared type exports.
- `src/Builder.lua` collects registrations and produces the composed runtime bundle.
- `src/SetupWriter.lua` writes resolved actor setups into caller-owned storage.
- `src/BehaviorCatalog.lua` resolves named behaviors, aliases, and defaults.
- `src/Validation.lua` centralizes input-shape checks for the facade surface.
- `src/Types.lua` defines the shared facade types.
- `src/Enums.lua` defines the shared enum registries used by the facade and diagnostics.

## Purpose

- provide one package root for shared AI utilities
- expose `AI.Runtime`, `AI.AdapterFactory`, and `AI.Behavior` under one namespace
- reduce repetitive setup with a composition builder and small registration helpers

## Preferred Usage

The preferred facade path is `AI.CreateSystem(...)`, which collects hooks, actions, action packs, actors, actor bundles, and named behavior definitions before producing a ready runtime plus built behavior trees, catalog defaults, and build diagnostics.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)

local builtAi = AI.CreateSystem({
	Conditions = Conditions,
	Commands = Commands,
	GlobalHooks = {
		BaseFactsHook,
	},
	ErrorSink = ErrorSink,
})
	:LoadHooks(script.Parent.Hooks)
	:AddActionPack(AI.CreateActionPack("EnemyActions", Executors))
	:AddActorBundle(AI.CreateActorBundle({
		ActorType = "Enemy",
		Adapter = AI.CreateAdapter({
			ActorLabel = "Enemy",
			QueryActiveEntities = function(_frameContext)
				return enemyEntityFactory:QueryAliveEntities()
			end,
			GetBehaviorTree = function(entity)
				return enemyEntityFactory:GetBehaviorTree(entity)
			end,
			GetActionState = function(entity)
				return enemyEntityFactory:GetCombatAction(entity)
			end,
			SetActionState = function(entity, actionState)
				enemyEntityFactory:SetCombatAction(entity, actionState)
			end,
			ClearActionState = function(entity)
				enemyEntityFactory:ClearAction(entity)
			end,
			SetPendingAction = function(entity, actionId, actionData)
				enemyEntityFactory:SetPendingAction(entity, actionId, actionData)
			end,
			UpdateLastTickTime = function(entity, currentTime)
				enemyEntityFactory:UpdateBTLastTickTime(entity, currentTime)
			end,
			ShouldEvaluate = function(entity, currentTime)
				local tree = enemyEntityFactory:GetBehaviorTree(entity)
				if tree == nil then
					return false
				end

				return currentTime - tree.LastTickTime >= tree.TickInterval
			end,
		}),
		Actions = Executors,
		ActionPacks = {
			AI.CreateActionPack("EnemySharedActions", Executors),
		},
		DefaultBehaviorName = "EnemyDefault",
		Hooks = {
			EnemyPerceptionHook,
		},
	}))
	:SetBehaviorAlias("DefaultEnemy", "EnemyDefault")
	:SetArchetypeDefault("GroundEnemy", "DefaultEnemy")
	:SetFallbackBehavior("EnemyDefault")
	:AddBehavior("EnemyDefault", EnemyBehaviorDefinition)
	:Build()

local runtime = builtAi.Runtime
local tree = builtAi.Behaviors.EnemyDefault
local defaultEnemyTree = AI.ResolveActorDefaultBehavior(builtAi, "Enemy")
local archetypeTree = AI.ResolveBehaviorByArchetype(builtAi, "GroundEnemy")
local assignment = AI.ResolveActorAssignment(builtAi, "Enemy", {
	ArchetypeName = "GroundEnemy",
})
local resolvedTree = AI.ResolveActorBehavior(builtAi, "Enemy", {
	ArchetypeName = "GroundEnemy",
})
local manifest = AI.DescribeBuild(builtAi)
local assignmentDefaults = AI.ListAssignmentDefaults(builtAi)
local assignmentDescription = AI.DescribeAssignment(builtAi, "Enemy", {
	ArchetypeName = "GroundEnemy",
})
local setup = AI.CreateActorSetup(builtAi, {
	Entity = enemyEntity,
	ActorType = "Enemy",
	ArchetypeName = "GroundEnemy",
})

AI.WriteActorSetup(setup, AI.CreateFactorySetupWriter({
	Factory = enemyEntityFactory,
	WriteSetup = "SetBehaviorTree",
	ClearActionState = "ClearAction",
}))
```

Folder loading is optional and currently intended only for hooks, actions, and behaviors. Actor bundles stay explicit.
The builder enforces a lifecycle internally using `StateMachine`, so mutation methods are only legal before `Build()`.

## Usage

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)

local runtime = AI.CreateRuntime({
	Conditions = Conditions,
	Commands = Commands,
	Hooks = Hooks,
	ErrorSink = ErrorSink,
})

local enemyAdapter = AI.CreateAdapter({
	ActorLabel = "Enemy",
	QueryActiveEntities = function(_frameContext)
		return enemyEntityFactory:QueryAliveEntities()
	end,
	GetBehaviorTree = function(entity)
		return enemyEntityFactory:GetBehaviorTree(entity)
	end,
	GetActionState = function(entity)
		return enemyEntityFactory:GetCombatAction(entity)
	end,
	SetActionState = function(entity, actionState)
		enemyEntityFactory:SetCombatAction(entity, actionState)
	end,
	ClearActionState = function(entity)
		enemyEntityFactory:ClearAction(entity)
	end,
	SetPendingAction = function(entity, actionId, actionData)
		enemyEntityFactory:SetPendingAction(entity, actionId, actionData)
	end,
	UpdateLastTickTime = function(entity, currentTime)
		enemyEntityFactory:UpdateBTLastTickTime(entity, currentTime)
	end,
	ShouldEvaluate = function(entity, currentTime)
		local tree = enemyEntityFactory:GetBehaviorTree(entity)
		if tree == nil then
			return false
		end

		return currentTime - tree.LastTickTime >= tree.TickInterval
	end,
})

AI.RegisterActor(runtime, "Enemy", enemyAdapter, Executors)

local tree = runtime:BuildTree(BehaviorDefinition)

runtime:RunFrame({
	CurrentTime = os.clock(),
	DeltaTime = dt,
	Services = services,
})
```

## Public Surface

- `AI.CreateRuntime(config)`
- `AI.CreateSystem(config)`
- `AI.CreateAdapter(config)`
- `AI.CreateFactoryAdapter(config)`
- `AI.CreateBehaviorCatalog(config?)`
- `AI.CreateActionPack(name, definitions)`
- `AI.CreateActorRegistration(registration)`
- `AI.CreateActorBundle(bundle)`
- `AI.CreateActorPackage(package)`
- `AI.CreateBehaviorRegistration(name, definition)`
- `AI.RegisterActor(runtime, actorType, adapter, actionDefinitions?)`
- `AI.RegisterActors(runtime, registrations)`
- `AI.RegisterActorBundles(runtime, bundles)`
- `AI.RegisterActions(runtime, definitions)`
- `AI.RegisterActionPacks(runtime, actionPacks)`
- `AI.BuildBehaviors(runtime, behaviorMap)`
- `AI.ResolveActorAssignment(buildResult, actorType, options?)`
- `AI.ResolveAssignments(buildResult, actorRequests)`
- `AI.CreateActorSetup(buildResult, request, options?)`
- `AI.CreateActorSetups(buildResult, requests, options?)`
- `AI.CreateFactorySetupWriter(config)`
- `AI.WriteActorSetup(setupResult, config)`
- `AI.WriteActorSetups(setupResults, config)`
- `AI.ResolveActorBehavior(buildResult, actorType, options?)`
- `AI.ResolveActorDefaultBehavior(buildResult, actorType)`
- `AI.ResolveBehaviorByArchetype(buildResult, archetypeName)`
- `AI.ListAssignmentDefaults(buildResult)`
- `AI.DescribeAssignment(buildResult, actorType, options?)`
- `AI.DescribeBuild(buildResult)`
- `AI.ListRegisteredActors(buildResult)`
- `AI.ListRegisteredBehaviors(buildResult)`
- `AI.Runtime`
- `AI.AdapterFactory`
- `AI.Behavior`
- `AI.Types`

## Ownership

`AI` is the package root, not a new owner. Contexts still own:

- behavior-tree definitions
- hooks and fact composition
- executor registrations
- actor adapters and authoritative ECS state
- actor bundle consumption and tree assignment policy
- behavior assignment into ECS or runtime storage
- tree assignment into ECS or runtime storage
- broader cleanup and shutdown orchestration around `AI.Runtime` cleanup APIs

Actor bundles, behavior catalogs, and action packs are composition helpers only. They do not assign trees into ECS automatically, and they do not own actor lifecycle.

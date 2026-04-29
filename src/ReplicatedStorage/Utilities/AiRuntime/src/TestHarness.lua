--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorSystem = require(ReplicatedStorage.Utilities.BehaviorSystem)
local AiRuntime = require(script.Parent)

local TestHarness = {}

local FactsHook = {}
FactsHook.__index = FactsHook

function FactsHook.new()
	return setmetatable({}, FactsHook)
end

function FactsHook:Use(entity: number, hookContext: any)
	local hasTarget = entity == 1
	local pendingDamage = if hasTarget then 25 else 10

	return {
		Facts = {
			HasTarget = hasTarget,
			Damage = pendingDamage,
		},
		BehaviorContext = {
			DebugEntity = hookContext.Entity,
		},
	}
end

local ServicesHook = {}
ServicesHook.__index = ServicesHook

function ServicesHook.new()
	return setmetatable({}, ServicesHook)
end

function ServicesHook:Use(_entity: number, _hookContext: any)
	return {
		Services = {
			Recorder = {
				Events = {},
			},
		},
	}
end

local AttackExecutor = {}
AttackExecutor.__index = AttackExecutor

function AttackExecutor.new()
	return setmetatable({}, AttackExecutor)
end

function AttackExecutor:Start(_entity: number, _data: any?, _services: any): (boolean, string?)
	return true, nil
end

function AttackExecutor:Tick(_entity: number, _dt: number, _services: any): string
	return "Success"
end

function AttackExecutor:Cancel(_entity: number, _services: any) end

function AttackExecutor:Complete(_entity: number, _services: any) end

function AttackExecutor:Death(_entity: number, _services: any) end

local DefectExecutor = {}
DefectExecutor.__index = DefectExecutor

function DefectExecutor.new()
	return setmetatable({}, DefectExecutor)
end

function DefectExecutor:Start(_entity: number, _data: any?, _services: any): (boolean, string?)
	return true, nil
end

function DefectExecutor:Tick(_entity: number, _dt: number, _services: any): string
	error("DefectExecutor.Tick exploded")
end

function DefectExecutor:Cancel(_entity: number, _services: any) end

function DefectExecutor:Complete(_entity: number, _services: any) end

function DefectExecutor:Death(_entity: number, _services: any) end

local function _createConditions()
	return {
		HasTarget = function()
			return BehaviorSystem.Helpers.CreateConditionTask(function(task, context)
				if context.Facts.HasTarget then
					task:success()
					return
				end

				task:fail()
			end)
		end,
	}
end

local function _createCommands()
	return {
		Attack = function()
			return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
				context.ActionFactory:SetPendingAction(context.Entity, "Attack", {
					Damage = context.Facts.Damage,
				})
				task:success()
			end)
		end,
		Defect = function()
			return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
				context.ActionFactory:SetPendingAction(context.Entity, "Defect", nil)
				task:success()
			end)
		end,
	}
end

local function _createTree(runtime: any, commandName: string): any
	return {
		TreeInstance = runtime:BuildTree({
			Priority = {
				{
					Sequence = {
						"HasTarget",
						commandName,
					},
				},
			},
		}),
		LastTickTime = 0,
		TickInterval = 0,
	}
end

local function _createAdapter(entities: { [number]: any })
	local Adapter = {}
	Adapter.__index = Adapter

	function Adapter.new()
		local self = setmetatable({}, Adapter)
		self.Entities = entities
		return self
	end

	function Adapter:QueryActiveEntities(_frameContext: any): { number }
		local activeEntities = {}
		for entity in pairs(self.Entities) do
			table.insert(activeEntities, entity)
		end
		table.sort(activeEntities)
		return activeEntities
	end

	function Adapter:GetBehaviorTree(entity: number): any?
		local entityState = self.Entities[entity]
		return if entityState then entityState.BehaviorTree else nil
	end

	function Adapter:GetActionState(entity: number): any?
		local entityState = self.Entities[entity]
		return if entityState then entityState.ActionState else nil
	end

	function Adapter:SetActionState(entity: number, actionState: any)
		self.Entities[entity].ActionState = actionState
	end

	function Adapter:ClearActionState(entity: number)
		self.Entities[entity].ActionState = {
			CurrentActionId = nil,
			ActionState = "Idle",
			ActionData = nil,
			PendingActionId = nil,
			PendingActionData = nil,
			StartedAt = nil,
			FinishedAt = nil,
		}
	end

	function Adapter:SetPendingAction(entity: number, actionId: string, actionData: any?)
		local actionState = self:GetActionState(entity)
		if actionState == nil then
			actionState = {
				CurrentActionId = nil,
				ActionState = "Idle",
				ActionData = nil,
				PendingActionId = nil,
				PendingActionData = nil,
				StartedAt = nil,
				FinishedAt = nil,
			}
			self.Entities[entity].ActionState = actionState
		end

		actionState.PendingActionId = actionId
		actionState.PendingActionData = actionData
	end

	function Adapter:UpdateLastTickTime(entity: number, currentTime: number)
		self.Entities[entity].BehaviorTree.LastTickTime = currentTime
	end

	function Adapter:ShouldEvaluate(entity: number, currentTime: number): boolean
		local entityState = self.Entities[entity]
		if entityState == nil or entityState.BehaviorTree == nil then
			return false
		end

		return currentTime - entityState.BehaviorTree.LastTickTime >= entityState.BehaviorTree.TickInterval
	end

	function Adapter:GetActorLabel(): string
		return "Harness"
	end

	return Adapter.new()
end

function TestHarness.Run()
	local defects = {}
	local runtime = AiRuntime.new({
		Conditions = _createConditions(),
		Commands = _createCommands(),
		Hooks = {
			FactsHook.new(),
			ServicesHook.new(),
		},
		ErrorSink = function(payload)
			table.insert(defects, payload)
		end,
	})

	runtime:RegisterActions({
		Attack = {
			ActionId = "Attack",
			CreateExecutor = AttackExecutor.new,
		},
		Defect = {
			ActionId = "Defect",
			CreateExecutor = DefectExecutor.new,
		},
	})

	local entities = {
		[1] = {
			BehaviorTree = _createTree(runtime, "Attack"),
			ActionState = {
				CurrentActionId = nil,
				ActionState = "Idle",
				ActionData = nil,
				PendingActionId = nil,
				PendingActionData = nil,
				StartedAt = nil,
				FinishedAt = nil,
			},
		},
		[2] = {
			BehaviorTree = _createTree(runtime, "Defect"),
			ActionState = {
				CurrentActionId = "Attack",
				ActionState = "Running",
				ActionData = nil,
				PendingActionId = nil,
				PendingActionData = nil,
				StartedAt = nil,
				FinishedAt = nil,
			},
		},
	}

	runtime:RegisterActorType("Harness", _createAdapter(entities))

	local result = runtime:RunFrame({
		CurrentTime = 100,
		DeltaTime = 0.1,
		Services = {},
	})

	assert(#result.EntityResults == 2, "AiRuntime harness expected two entity results")
	assert(result.EntityResults[1].TreeStatus == "Ran", "AiRuntime harness expected entity 1 tree to run")
	assert(result.EntityResults[1].StartStatus == "Started", "AiRuntime harness expected entity 1 to start Attack")
	assert(result.EntityResults[1].CommitStatus == "Committed", "AiRuntime harness expected entity 1 commit to succeed")
	assert(result.EntityResults[1].TickStatus == "Success", "AiRuntime harness expected entity 1 Attack to succeed")
	assert(result.EntityResults[1].ResolveStatus == "Resolved", "AiRuntime harness expected entity 1 resolve to succeed")
	assert(result.EntityResults[2].TickStatus == "Success", "AiRuntime harness expected entity 2 current action to tick")
	assert(result.EntityResults[2].ResolveStatus == "Resolved", "AiRuntime harness expected entity 2 current action to resolve")
	assert(#defects == 0, "AiRuntime harness happy path expected no defects")

	local defectRuntime = AiRuntime.new({
		Conditions = _createConditions(),
		Commands = _createCommands(),
		Hooks = {
			FactsHook.new(),
		},
		ErrorSink = function(payload)
			table.insert(defects, payload)
		end,
	})

	defectRuntime:RegisterActions({
		Defect = {
			ActionId = "Defect",
			CreateExecutor = DefectExecutor.new,
		},
	})

	local defectEntities = {
		[1] = {
			BehaviorTree = _createTree(defectRuntime, "Defect"),
			ActionState = {
				CurrentActionId = nil,
				ActionState = "Idle",
				ActionData = nil,
				PendingActionId = nil,
				PendingActionData = nil,
				StartedAt = nil,
				FinishedAt = nil,
			},
		},
	}

	defectRuntime:RegisterActorType("DefectHarness", _createAdapter(defectEntities))
	local defectResult = defectRuntime:RunFrame({
		CurrentTime = 200,
		DeltaTime = 0.1,
		Services = {},
	})

	assert(#defectResult.Defects >= 1, "AiRuntime harness defect path expected at least one defect")
	assert(defectResult.Defects[1].Stage == "TickCurrentAction", "AiRuntime harness expected a tick defect")

	return {
		HappyPath = result,
		DefectPath = defectResult,
	}
end

return table.freeze(TestHarness)

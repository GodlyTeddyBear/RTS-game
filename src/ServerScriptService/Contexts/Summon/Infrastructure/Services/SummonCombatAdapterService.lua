--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)

local SummonCombatAdapterService = {}
SummonCombatAdapterService.__index = SummonCombatAdapterService

function SummonCombatAdapterService.new()
	return setmetatable({}, SummonCombatAdapterService)
end

function SummonCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
end

function SummonCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	return self._combatContext:RegisterActorType({
		ActorType = "Summon",
		Conditions = Nodes.Conditions,
		Commands = Nodes.Commands,
		Executors = Executors,
	})
end

return SummonCombatAdapterService

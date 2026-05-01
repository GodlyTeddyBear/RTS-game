--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local UnitIdleBehavior = require(script.Parent.Parent.BehaviorSystem.Behaviors.UnitIdleBehavior)

local UnitCombatAdapterService = {}
UnitCombatAdapterService.__index = UnitCombatAdapterService

function UnitCombatAdapterService.new()
	return setmetatable({}, UnitCombatAdapterService)
end

function UnitCombatAdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("UnitEntityFactory")
end

function UnitCombatAdapterService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
end

function UnitCombatAdapterService:RegisterActorType(): Result.Result<boolean>
	return self._combatContext:RegisterActorType({
		ActorType = "Unit",
		Conditions = Nodes.Conditions,
		Commands = Nodes.Commands,
		Executors = Executors,
	})
end

function UnitCombatAdapterService:RegisterActor(entity: number): Result.Result<string>
	return self._combatContext:RegisterCombatActor({
		ActorType = "Unit",
		ActorHandle = self:_BuildActorHandle(entity),
		BehaviorDefinition = UnitIdleBehavior,
		TickInterval = BehaviorConfig.DEFAULT.TickInterval,
		Adapter = {
			IsActive = function(): boolean
				return self._entityFactory:IsActive(entity)
			end,
			GetActorLabel = function(): string?
				return self:_BuildActorHandle(entity)
			end,
			BuildFacts = function(_currentTime: number): { [string]: any }
				return {}
			end,
			BuildServices = function(currentTime: number): { [string]: any }
				return {
					CurrentTime = currentTime,
					UnitEntityFactory = self._entityFactory,
				}
			end,
		},
	})
end

function UnitCombatAdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	return self._combatContext:UnregisterCombatActor(self:_BuildActorHandle(entity))
end

function UnitCombatAdapterService:_BuildActorHandle(entity: number): string
	local identity = self._entityFactory:GetIdentity(entity)
	if identity ~= nil and type(identity.UnitGuid) == "string" then
		return "Unit:" .. identity.UnitGuid
	end
	return "Unit:" .. tostring(entity)
end

return UnitCombatAdapterService

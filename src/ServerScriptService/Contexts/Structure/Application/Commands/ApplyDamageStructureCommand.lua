--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ensure = Result.Ensure
local Ok = Result.Ok
local Try = Result.Try

local ApplyDamageStructureCommand = {}
ApplyDamageStructureCommand.__index = ApplyDamageStructureCommand
setmetatable(ApplyDamageStructureCommand, BaseCommand)

function ApplyDamageStructureCommand.new()
	local self = BaseCommand.new("Structure", "ApplyDamageStructure")
	return setmetatable(self, ApplyDamageStructureCommand)
end

function ApplyDamageStructureCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityContext = "EntityContext",
		_readService = "StructureEntityReadService",
	})
end

function ApplyDamageStructureCommand:Start(registry: any, _name: string)
	self._placementContext = registry:Get("PlacementContext")
	self._teamContext = registry:Get("TeamContext")
end

function ApplyDamageStructureCommand:Execute(entity: any, amount: number): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(type(entity) == "number", "EntityNotFound", Errors.ENTITY_NOT_FOUND)
		Ensure(type(amount) == "number" and amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, {
			Amount = amount,
			Entity = entity,
		})
		Ensure(self._readService:IsPlaced(entity), "EntityNotFound", Errors.ENTITY_NOT_FOUND, { Entity = entity })

		local health = self._readService:GetHealth(entity)
		Ensure(type(health) == "table", "EntityNotFound", Errors.ENTITY_NOT_FOUND, { Entity = entity })
		local identity = self._readService:GetIdentity(entity)
		Ensure(type(identity) == "table" and type(identity.EntityId) == "string", "EntityNotFound", Errors.ENTITY_NOT_FOUND, {
			Entity = entity,
		})
		local sourcePlacement = self._readService:GetSourcePlacement(entity)

		local nextHp = math.max(0, health.Current - amount)
		Try(self._entityContext:Set(entity, "Health", {
			Current = nextHp,
			Max = health.Max,
		}, "Entity"))
		Try(self._entityContext:Add(entity, "DirtyTag", "Entity"))

		if nextHp > 0 then
			return Ok(false)
		end

		Try(self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle("Structure", identity.EntityId)))
		if type(sourcePlacement) == "table" and type(sourcePlacement.InstanceId) == "number" then
			Try(self._placementContext:DestroyStructureInstance(sourcePlacement.InstanceId))
		end
		Try(self._entityContext:DestroyEntity(entity))
		return Ok(true)
	end, "Structure:ApplyDamageStructureCommand")
end

return ApplyDamageStructureCommand

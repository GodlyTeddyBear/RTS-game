--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err

local EquipmentOwnerResolverService = {}
EquipmentOwnerResolverService.__index = EquipmentOwnerResolverService

function EquipmentOwnerResolverService.new()
	local self = setmetatable({}, EquipmentOwnerResolverService)
	self._contexts = {}
	return self
end

function EquipmentOwnerResolverService:Start(registry: any, _name: string)
	self._contexts = {
		Unit = registry:Get("UnitContext"),
		Enemy = registry:Get("EnemyContext"),
		Structure = registry:Get("StructureContext"),
	}
end

function EquipmentOwnerResolverService:ResolveModel(ownerKind: string, ownerId: string): Result.Result<Model>
	local context = self._contexts[ownerKind]
	if context == nil then
		return Err("InvalidOwnerKind", Errors.INVALID_OWNER_KIND, { ownerKind = ownerKind })
	end

	local entityId = tonumber(ownerId)
	if entityId == nil then
		return Err("InvalidOwnerId", Errors.INVALID_OWNER_ID, { ownerKind = ownerKind, ownerId = ownerId })
	end

	local factoryResult = context:GetInstanceFactory()
	if not factoryResult.success then
		return Err(factoryResult.type or "OwnerNotFound", factoryResult.message or Errors.OWNER_NOT_FOUND, {
			ownerKind = ownerKind,
			ownerId = ownerId,
		})
	end

	local instance = factoryResult.value:GetInstance(entityId)
	if instance == nil then
		return Err("OwnerNotFound", Errors.OWNER_NOT_FOUND, { ownerKind = ownerKind, ownerId = ownerId })
	end

	if not instance:IsA("Model") then
		return Err("OwnerModelInvalid", Errors.OWNER_MODEL_INVALID, { ownerKind = ownerKind, ownerId = ownerId })
	end

	return Ok(instance :: Model)
end

return EquipmentOwnerResolverService

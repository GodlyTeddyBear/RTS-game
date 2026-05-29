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
	self._entityContext = nil
	return self
end

function EquipmentOwnerResolverService:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
end

function EquipmentOwnerResolverService:ResolveModel(ownerKind: string, ownerId: string): Result.Result<Model>
	if ownerKind ~= "Unit" and ownerKind ~= "Enemy" and ownerKind ~= "Structure" then
		return Err("InvalidOwnerKind", Errors.INVALID_OWNER_KIND, { ownerKind = ownerKind })
	end

	local entityId = tonumber(ownerId)
	if entityId == nil then
		return Err("InvalidOwnerId", Errors.INVALID_OWNER_ID, { ownerKind = ownerKind, ownerId = ownerId })
	end

	local identityResult = self._entityContext:Get(entityId, "Identity", "Entity")
	if not identityResult.success or type(identityResult.value) ~= "table" then
		return Err("OwnerNotFound", Errors.OWNER_NOT_FOUND, {
			ownerKind = ownerKind,
			ownerId = ownerId,
		})
	end

	if identityResult.value.EntityKind ~= ownerKind then
		return Err("OwnerNotFound", Errors.OWNER_NOT_FOUND, { ownerKind = ownerKind, ownerId = ownerId })
	end

	local boundInstanceResult = self._entityContext:GetBoundInstance(entityId)
	if not boundInstanceResult.success then
		return Err(boundInstanceResult.type or "OwnerNotFound", boundInstanceResult.message or Errors.OWNER_NOT_FOUND, {
			ownerKind = ownerKind,
			ownerId = ownerId,
		})
	end

	local instance = boundInstanceResult.value
	if instance == nil then
		return Err("OwnerNotFound", Errors.OWNER_NOT_FOUND, { ownerKind = ownerKind, ownerId = ownerId })
	end

	if not instance:IsA("Model") then
		return Err("OwnerModelInvalid", Errors.OWNER_MODEL_INVALID, { ownerKind = ownerKind, ownerId = ownerId })
	end

	return Ok(instance :: Model)
end

return EquipmentOwnerResolverService

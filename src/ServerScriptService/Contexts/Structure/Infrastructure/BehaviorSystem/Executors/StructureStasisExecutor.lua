--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)

--[=[
	@class StructureStasisExecutor
	Publishes a stasis aura source into CombatContext's status service while the structure is active.
	@server
]=]
local StructureStasisExecutor = {}
StructureStasisExecutor.__index = StructureStasisExecutor
setmetatable(StructureStasisExecutor, BaseExecutor)

function StructureStasisExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Structure.Stasis",
		IsCommitted = false,
	})
	return setmetatable(self, StructureStasisExecutor)
end

local function _removeAuraSource(services: any)
	if services.StatusService ~= nil and type(services.StatusSourceHandle) == "string" then
		services.StatusService:RemoveAuraSource(services.StatusSourceHandle)
	end
end

local function _buildSourceData(entity: number, services: any): { [string]: any }?
	local position = services.StructureEntityFactory:GetPosition(entity)
	local config = services.StasisConfig
	if position == nil or type(config) ~= "table" then
		return nil
	end

	if type(config.StasisRadius) ~= "number" or type(config.MoveSpeedMultiplier) ~= "number" then
		return nil
	end

	return {
		SourceType = "StasisField",
		Position = position,
		Radius = config.StasisRadius,
		MoveSpeedMultiplier = config.MoveSpeedMultiplier,
		IsActive = true,
	}
end

function StructureStasisExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(entity) then
		return false, "InactiveStructure"
	end

	if services.StatusService == nil then
		return false, "MissingStatusService"
	end

	if _buildSourceData(entity, services) == nil then
		return false, "MissingStasisConfig"
	end

	return true, nil
end

function StructureStasisExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(entity) then
		return false, "InactiveStructure"
	end

	if services.StatusService == nil then
		return false, "MissingStatusService"
	end

	if _buildSourceData(entity, services) == nil then
		return false, "MissingStasisConfig"
	end

	return true, nil
end

function StructureStasisExecutor:OnTick(entity: number, _dt: number, services: any): string
	local sourceData = _buildSourceData(entity, services)
	if sourceData == nil then
		_removeAuraSource(services)
		return self:Fail(entity, "MissingStasisConfig")
	end

	services.StatusService:UpsertAuraSource(services.StatusSourceHandle, sourceData)
	return self:Running()
end

function StructureStasisExecutor:OnCancel(_entity: number, services: any)
	_removeAuraSource(services)
end

function StructureStasisExecutor:OnComplete(_entity: number, services: any)
	_removeAuraSource(services)
end

function StructureStasisExecutor:OnDeath(_entity: number, services: any)
	_removeAuraSource(services)
end

return StructureStasisExecutor

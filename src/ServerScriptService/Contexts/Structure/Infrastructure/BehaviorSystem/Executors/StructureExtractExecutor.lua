--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseExecutor = require(ReplicatedStorage.Utilities.BaseExecutor)

--[=[
	@class StructureExtractExecutor
	Keeps an extractor structure in a long-running active animation state.
	@server
]=]
local StructureExtractExecutor = {}
StructureExtractExecutor.__index = StructureExtractExecutor
setmetatable(StructureExtractExecutor, BaseExecutor)

function StructureExtractExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "Structure.Extract",
		IsCommitted = false,
	})
	return setmetatable(self, StructureExtractExecutor)
end

function StructureExtractExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(entity) then
		return false, "InactiveStructure"
	end

	return true, nil
end

function StructureExtractExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(entity) then
		return false, "InactiveStructure"
	end

	return true, nil
end

function StructureExtractExecutor:OnTick(_entity: number, _dt: number, _services: any): string
	return self:Running()
end

return StructureExtractExecutor

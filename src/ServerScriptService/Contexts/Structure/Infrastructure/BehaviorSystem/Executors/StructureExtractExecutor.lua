--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)

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

	if not services.MiningExtractorProxy:IsActive() then
		return false, "InactiveExtractor"
	end

	return true, nil
end

function StructureExtractExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	if not services.StructureEntityFactory:IsActive(entity) then
		return false, "InactiveStructure"
	end

	if not services.MiningExtractorProxy:IsActive() then
		return false, "InactiveExtractor"
	end

	return true, nil
end

function StructureExtractExecutor:OnTick(entity: number, dt: number, services: any): string
	if not services.MiningExtractorProxy:Advance(dt) then
		return self:Fail(entity, "InactiveExtractor")
	end

	return self:Running()
end

return StructureExtractExecutor

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local StructureExtractionSystem = {}
StructureExtractionSystem.__index = StructureExtractionSystem

local ACTION_EXTRACT = "Extract"

function StructureExtractionSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, StructureExtractionSystem)
	self._entityFactory = entityFactory
	return self
end

function StructureExtractionSystem:Run()
	-- READS: Structure.ExtractState [AUTHORITATIVE], Structure.SourcePlacement [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: Mining.ExtractWorkRequest [AUTHORITATIVE], Mining.RequestTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Structure",
		Keys = { "ExtractState", "OperationalTag" },
	})
	if not queryResult.success then
		return
	end

	local deltaTime = ServerScheduler:GetDeltaTime()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, deltaTime)
	end
end

function StructureExtractionSystem:_RunEntity(entity: number, deltaTime: number)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if type(actionState) ~= "table" or actionState.ActionId ~= ACTION_EXTRACT then
		return
	end

	if deltaTime <= 0 then
		return
	end

	local extractState = self:_Get(entity, "ExtractState", "Structure")
	local sourcePlacement = self:_Get(entity, "SourcePlacement", "Structure")
	local instanceId = if type(extractState) == "table" and type(extractState.InstanceId) == "number"
		then extractState.InstanceId
		else if type(sourcePlacement) == "table" then sourcePlacement.InstanceId else nil
	if type(instanceId) ~= "number" then
		return
	end

	self._entityFactory:CreateFromArchetype("Mining.ExtractWorkRequest", {
		ExtractWorkRequest = {
			SourceEntity = entity,
			InstanceId = instanceId,
			DeltaTime = deltaTime,
			CreatedAt = os.clock(),
			Status = "Requested",
		},
	})
end

function StructureExtractionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return StructureExtractionSystem

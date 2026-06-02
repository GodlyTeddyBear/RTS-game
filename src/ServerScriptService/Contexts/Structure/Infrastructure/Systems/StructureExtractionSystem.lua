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
	self._miningContext = dependencies.MiningContext
	return self
end

function StructureExtractionSystem:Run()
	-- READS: Structure.ExtractState [AUTHORITATIVE], Structure.SourcePlacement [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: Structure.AnimationState [DERIVED], Structure.AnimationLooping [DERIVED], Entity.DirtyTag
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
		if type(actionState) == "table" and actionState.ActionId == "Idle" then
			self:_SetPresentation(entity, "Idle", true)
		end
		return
	end

	self:_SetPresentation(entity, "Extract", true)
	if deltaTime <= 0 or self._miningContext == nil then
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

	local miningEntityResult = self._miningContext:GetExtractorEntityByInstanceId(instanceId)
	if not miningEntityResult.success or type(miningEntityResult.value) ~= "number" then
		return
	end
	local miningSystemResult = self._miningContext:GetExtractorMiningSystem()
	if not miningSystemResult.success or miningSystemResult.value == nil then
		return
	end

	miningSystemResult.value:AdvanceExtractor(miningEntityResult.value, deltaTime)
end

function StructureExtractionSystem:_SetPresentation(entity: number, animationState: string, isLooping: boolean)
	self._entityFactory:Set(entity, "AnimationState", animationState, "Structure")
	self._entityFactory:Set(entity, "AnimationLooping", isLooping, "Structure")
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

function StructureExtractionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return StructureExtractionSystem

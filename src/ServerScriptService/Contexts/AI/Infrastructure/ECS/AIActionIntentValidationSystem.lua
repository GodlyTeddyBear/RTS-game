--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local AIActionIntentValidationSystem = {}
AIActionIntentValidationSystem.__index = AIActionIntentValidationSystem

local function _IsValidActionIntent(actionIntent: any, entityFactory: any): boolean
	if type(actionIntent) ~= "table" then
		return false
	end
	if type(actionIntent.ActionId) ~= "string" or actionIntent.ActionId == "" then
		return false
	end
	if type(actionIntent.SourceEntity) ~= "number" or not entityFactory:Exists(actionIntent.SourceEntity) then
		return false
	end
	if
		actionIntent.TargetEntity ~= nil
		and (type(actionIntent.TargetEntity) ~= "number" or not entityFactory:Exists(actionIntent.TargetEntity))
	then
		return false
	end

	return true
end

function AIActionIntentValidationSystem.new(entityFactory: any)
	local self = setmetatable({}, AIActionIntentValidationSystem)
	self._entityFactory = entityFactory
	return self
end

function AIActionIntentValidationSystem:Run()
	-- READS: AI.ActionIntent [AUTHORITATIVE]
	-- WRITES: AI.ActionIntentTag, AI.ActionDirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = AISharedContract.FeatureName,
		Keys = { AISharedContract.Components.ActionIntent },
	})
	if not queryResult.success then
		return
	end

	for _, entity in ipairs(queryResult.value) do
		self:_NormalizeActionIntentTags(entity)
	end
end

function AIActionIntentValidationSystem:_NormalizeActionIntentTags(entity: number)
	local actionIntentResult =
		self._entityFactory:Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	if not actionIntentResult.success or not _IsValidActionIntent(actionIntentResult.value, self._entityFactory) then
		self._entityFactory:Remove(entity, AISharedContract.Tags.ActionIntentTag, AISharedContract.FeatureName)
		self._entityFactory:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
		return
	end

	self._entityFactory:Add(entity, AISharedContract.Tags.ActionIntentTag, AISharedContract.FeatureName)
	self._entityFactory:Add(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
end

return AIActionIntentValidationSystem

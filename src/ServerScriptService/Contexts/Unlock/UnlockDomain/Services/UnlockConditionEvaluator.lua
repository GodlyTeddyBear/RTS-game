--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnlockEntryTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockEntryTypes)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TUnlockConditions = UnlockEntryTypes.TUnlockConditions
type TConditionSnapshot = UnlockTypes.TConditionSnapshot

export type TEvaluationOptions = {
	IgnoreGold: boolean?,
}

export type TConditionFailure = {
	Key: string,
	Required: any,
	Actual: any,
	Message: string,
}

local NUMBER_FIELDS = table.freeze({
	Chapter = true,
	CommissionTier = true,
	QuestsCompleted = true,
	Gold = true,
	WorkerCount = true,
})

local BOOLEAN_FIELDS = table.freeze({
	SmelterPlaced = true,
	Ch2FirstVictory = true,
})

local FAILURE_MESSAGE_BY_KEY = table.freeze({
	Chapter = Errors.CHAPTER_TOO_LOW,
	CommissionTier = Errors.COMMISSION_TIER_TOO_LOW,
	QuestsCompleted = Errors.NOT_ENOUGH_QUESTS,
	Gold = Errors.INSUFFICIENT_GOLD,
	WorkerCount = Errors.NOT_ENOUGH_WORKERS,
	SmelterPlaced = "Required progression flag is not set",
	Ch2FirstVictory = "Required progression flag is not set",
})

local UnlockConditionEvaluator = {}
UnlockConditionEvaluator.__index = UnlockConditionEvaluator

function UnlockConditionEvaluator.new()
	return setmetatable({}, UnlockConditionEvaluator)
end

local function _buildFailure(key: string, required: any, actual: any): TConditionFailure
	return {
		Key = key,
		Required = required,
		Actual = actual,
		Message = FAILURE_MESSAGE_BY_KEY[key] or "Unlock condition not met",
	}
end

function UnlockConditionEvaluator:HasConditionKey(conditions: TUnlockConditions, key: string): boolean
	return conditions[key] ~= nil
end

function UnlockConditionEvaluator:MeetsAll(
	conditions: TUnlockConditions,
	snapshot: TConditionSnapshot,
	options: TEvaluationOptions?
): (boolean, TConditionFailure?)
	for key, required in conditions do
		if key == "Gold" and options and options.IgnoreGold then
			continue
		end

		local actual = snapshot[key]

		if NUMBER_FIELDS[key] then
			if type(required) ~= "number" or type(actual) ~= "number" or actual < required then
				return false, _buildFailure(key, required, actual)
			end
			continue
		end

		if BOOLEAN_FIELDS[key] then
			if type(required) ~= "boolean" or type(actual) ~= "boolean" or actual ~= required then
				return false, _buildFailure(key, required, actual)
			end
			continue
		end

		return false, _buildFailure(key, required, actual)
	end

	return true, nil
end

return UnlockConditionEvaluator

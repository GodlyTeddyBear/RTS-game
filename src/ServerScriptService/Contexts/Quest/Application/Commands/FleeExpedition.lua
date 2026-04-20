--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestConfig = require(ReplicatedStorage.Contexts.Quest.Config.QuestConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Err, Try = Result.Ok, Result.Err, Result.Try
local MentionSuccess = Result.MentionSuccess

--[=[
	@class FleeExpedition
	Application command that allows a player to abandon their active expedition.
	Stops combat, deducts a gold penalty (capped at the player's current gold),
	and delegates to EndExpedition with "Fled" status.
	@server
]=]

--[=[
	@interface TFleeResult
	@within FleeExpedition
	.FleePenaltyPaid number -- Gold actually deducted (may be less than configured penalty)
]=]
export type TFleeResult = {
	FleePenaltyPaid: number,
}

local FleeExpedition = {}
FleeExpedition.__index = FleeExpedition

export type TFleeExpedition = typeof(setmetatable({}, FleeExpedition))

--[=[
	@within FleeExpedition
	@private
]=]
function FleeExpedition.new(): TFleeExpedition
	local self = setmetatable({}, FleeExpedition)
	return self
end

--[=[
	@within FleeExpedition
	@private
]=]
function FleeExpedition:Init(registry: any, _name: string)
	self.Registry = registry
	self.FleePolicy = registry:Get("FleePolicy")
	self.QuestSyncService = registry:Get("QuestSyncService")
	self.QuestPersistenceService = registry:Get("QuestPersistenceService")
	self.EndExpeditionService = registry:Get("EndExpedition")
end

--[=[
	@within FleeExpedition
	@private
]=]
function FleeExpedition:Start()
	self.GuildContext = self.Registry:Get("GuildContext")
	self.CombatContext = self.Registry:Get("CombatContext")
	self.ShopContext = self.Registry:Get("ShopContext")
end

--[=[
	Stops the combat loop, deducts the flee gold penalty (capped at current gold),
	and ends the expedition with "Fled" status.
	@within FleeExpedition
	@param player Player
	@param userId number
	@return Result.Result<TFleeResult>
]=]
function FleeExpedition:Execute(player: Player, userId: number): Result.Result<TFleeResult>
	if not player or userId <= 0 then
		return Err("InvalidInput", Errors.PLAYER_NOT_FOUND, { userId = userId })
	end

	-- Policy: check expedition exists and is in combat (Domain layer)
	Try(self.FleePolicy:Check(userId))

	-- Stop combat via CombatContext
	Try(self.CombatContext:StopCombatForUser(userId))

	-- Deduct flee penalty, capped at the player's current gold
	local actualPenalty = Try(self:_DeductFleePenalty(player, userId))

	-- End the expedition with Fled status (no loot, no permadeath from stub)
	Try(self.EndExpeditionService:Execute(player, userId, "Fled"))
	MentionSuccess("Quest:FleeExpedition:Execute", "Processed flee and ended active expedition", {
		userId = userId,
		fleePenaltyPaid = actualPenalty,
	})

	return Ok({
		FleePenaltyPaid = actualPenalty,
	})
end

--[=[
	@within FleeExpedition
	@private
]=]
function FleeExpedition:_DeductFleePenalty(player: Player, userId: number): Result.Result<number>
	local configuredPenalty = QuestConfig.FLEE_PENALTY_GOLD
	local currentGold = Try(self.ShopContext:GetPlayerGold(userId))
	local actualPenalty = math.min(configuredPenalty, currentGold)
	if actualPenalty > 0 then
		Try(self.ShopContext:DeductGold(player, userId, actualPenalty))
	end
	return Ok(actualPenalty)
end

return FleeExpedition

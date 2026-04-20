--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[[
	AbandonCommission

	Removes a commission from the player's active list without penalty.
]]

--[=[
	@class AbandonCommission
	Application command that removes an active commission from the player's list without penalty.
	@server
]=]
local AbandonCommission = {}
AbandonCommission.__index = AbandonCommission

--[=[
	Construct a new AbandonCommission service.
	@within AbandonCommission
	@return AbandonCommission
]=]
function AbandonCommission.new()
	return setmetatable({}, AbandonCommission)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within AbandonCommission
	@param registry any -- The context registry
]=]
function AbandonCommission:Init(registry: any, _name: string)
	self.AbandonPolicy = registry:Get("AbandonPolicy")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

--[=[
	Abandon an active commission for the player, persisting the updated state.
	@within AbandonCommission
	@param player Player -- The player abandoning the commission
	@param userId number -- The player's UserId
	@param commissionId string -- The ID of the active commission to abandon
	@return Result<boolean> -- `Ok(true)` on success
]=]
function AbandonCommission:Execute(player: Player, userId: number, commissionId: string): Result.Result<boolean>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Validate abandon (check ID and commission in active list)
	Try(self.AbandonPolicy:Check(userId, commissionId))

	-- Remove from active (no penalty or reward)
	self.CommissionSyncService:RemoveFromActive(userId, commissionId)

	-- Persist updated state to profile
	local updatedState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, updatedState))
	end

	-- Sync state to client
	self.CommissionSyncService:HydratePlayer(player)

	MentionSuccess("Commission:AbandonCommission:Execute", "Removed commission from active list", {
		userId = userId,
		commissionId = commissionId,
	})

	return Ok(true)
end

return AbandonCommission

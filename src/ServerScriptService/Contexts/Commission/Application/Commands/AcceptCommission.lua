--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[[
	AcceptCommission

	Moves a commission from the board to the player's active list.
]]

--[=[
	@class AcceptCommission
	Application command that moves a commission from the board to the player's active list.
	@server
]=]
local AcceptCommission = {}
AcceptCommission.__index = AcceptCommission

--[=[
	Construct a new AcceptCommission service.
	@within AcceptCommission
	@return AcceptCommission
]=]
function AcceptCommission.new()
	return setmetatable({}, AcceptCommission)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within AcceptCommission
	@param registry any -- The context registry
]=]
function AcceptCommission:Init(registry: any)
	self.AcceptPolicy = registry:Get("AcceptPolicy")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

--[=[
	Accept a board commission, moving it to the player's active list and persisting state.
	@within AcceptCommission
	@param player Player -- The player accepting the commission
	@param userId number -- The player's UserId
	@param commissionId string -- The ID of the board commission to accept
	@return Result<boolean> -- `Ok(true)` on success
]=]
function AcceptCommission:Execute(player: Player, userId: number, commissionId: string): Result.Result<boolean>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Validate accept (check ID, slots, board presence)
	local ctx = Try(self.AcceptPolicy:Check(userId, commissionId))

	-- Build active commission with acceptance timestamp
	local activeCommission = self:_BuildActiveCommission(ctx.Commission)

	-- Update state: remove from board, add to active
	self.CommissionSyncService:SetBoard(userId, ctx.BoardWithout)
	self.CommissionSyncService:AddToActive(userId, activeCommission)

	-- Persist updated state to profile
	local updatedState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, updatedState))
	end

	-- Sync state to client
	self.CommissionSyncService:HydratePlayer(player)

	MentionSuccess("Commission:AcceptCommission:Execute", "Moved commission from board to active list", {
		userId = userId,
		commissionId = commissionId,
	})

	return Ok(true)
end

function AcceptCommission:_BuildActiveCommission(commission: any): any
	-- Copy board commission to active format, adding acceptance timestamp
	return {
		Id = commission.Id,
		PoolId = commission.PoolId,
		Tier = commission.Tier,
		Requirement = commission.Requirement,
		Reward = commission.Reward,
		AcceptedAt = os.time(),
		Source = commission.Source or "Board",
		VillagerId = commission.VillagerId,
		TargetUserId = commission.TargetUserId,
	}
end

return AcceptCommission

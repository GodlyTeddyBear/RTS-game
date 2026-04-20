--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Commission.Sync.SharedAtoms)
local CommissionTypes = require(ReplicatedStorage.Contexts.Commission.Types.CommissionTypes)

type TCommissionState = CommissionTypes.TCommissionState
type TBoardCommission = CommissionTypes.TBoardCommission
type TActiveCommission = CommissionTypes.TActiveCommission

--[=[
	@class CommissionSyncService
	Manages commission state synchronization via CharmSync atoms and Blink remotes; all atom mutations are centralized here.
	@server
]=]
local CommissionSyncService = setmetatable({}, { __index = BaseSyncService })
CommissionSyncService.__index = CommissionSyncService
CommissionSyncService.AtomKey = "commissions"
CommissionSyncService.BlinkEventName = "SyncCommissions"
CommissionSyncService.CreateAtom = SharedAtoms.CreateServerAtom

local function deepClone(tbl: any): any
	if type(tbl) ~= "table" then
		return tbl
	end
	local clone = {}
	for key, value in pairs(tbl) do
		clone[key] = deepClone(value)
	end
	return clone
end

local DEFAULT_STATE: TCommissionState = {
	Board = {},
	Active = {},
	Tokens = 0,
	CurrentTier = 1,
	LastRefreshTime = 0,
}

--[=[
	Construct a new CommissionSyncService.
	@within CommissionSyncService
	@return CommissionSyncService
]=]
function CommissionSyncService.new()
	return setmetatable({}, CommissionSyncService)
end

--[=[
	Wire registry dependencies and override the sync connect handler to send `DEFAULT_STATE` for unloaded players.
	@within CommissionSyncService
	@param registry any -- The context registry
	@param name string -- The service name
]=]
function CommissionSyncService:Init(registry: any, name: string)
	BaseSyncService.Init(self, registry, name)

	-- Replace the default connect handler to send DEFAULT_STATE for unloaded players
	if self.Cleanup then
		self.Cleanup()
	end

	self.Cleanup = self.Syncer:connect(function(player: Player, _: any)
		local userId = player.UserId
		local allCommissions = self.Atom()
		local playerCommissions = allCommissions[userId]

		local fullStatePayload = {
			type = "init",
			data = {
				commissions = playerCommissions or deepClone(DEFAULT_STATE),
			},
		}

		self.BlinkServer.SyncCommissions.Fire(player, fullStatePayload)
	end)
end

--[[
	READ-ONLY GETTERS
]]

--[=[
	Return a deep-cloned read-only snapshot of a user's commission state.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@return TCommissionState? -- Cloned state, or `nil` if not loaded
]=]
function CommissionSyncService:GetCommissionStateReadOnly(userId: number): TCommissionState?
	return self:GetReadOnly(userId)
end

--[=[
	Check whether a player's commission state has been loaded into the atom.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@return boolean -- `true` if state is present
]=]
function CommissionSyncService:IsPlayerLoaded(userId: number): boolean
	return self.Atom()[userId] ~= nil
end

--[=[
	Return the underlying Charm atom for commission state.
	@within CommissionSyncService
	@return any -- The server-side commissions atom
]=]
function CommissionSyncService:GetCommissionsAtom()
	return self:GetAtom()
end

--[[
	CENTRALIZED MUTATION METHODS
]]

--[=[
	Bulk-load commission state for a user into the atom (called on player join).
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param data TCommissionState -- Initial commission state to store
]=]
function CommissionSyncService:LoadUserCommissions(userId: number, data: TCommissionState)
	self:LoadUserData(userId, data)
end

--[=[
	Remove all commission state for a user from the atom (called on player leave).
	@within CommissionSyncService
	@param userId number -- The player's UserId
]=]
function CommissionSyncService:RemoveUserCommissions(userId: number)
	self:RemoveUserData(userId)
end

local function _UpdateUserField(current: any, userId: number, field: string, value: any): any
	local updated = table.clone(current)
	updated[userId] = table.clone(updated[userId])
	updated[userId][field] = value
	return updated
end

--[=[
	Replace the board array for a user.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param board {TBoardCommission} -- New board entries
]=]
function CommissionSyncService:SetBoard(userId: number, board: { TBoardCommission })
	self.Atom(function(current)
		return _UpdateUserField(current, userId, "Board", board)
	end)
end

--[=[
	Add a commission offer to the user's board list.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param commission TBoardCommission -- Board or visitor commission offer
]=]
function CommissionSyncService:AddToBoard(userId: number, commission: TBoardCommission)
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		local newBoard = table.clone(updated[userId].Board)
		table.insert(newBoard, commission)
		updated[userId].Board = newBoard
		return updated
	end)
end

--[=[
	Remove a commission from the user's board list by ID.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param commissionId string -- The offer ID to remove
]=]
function CommissionSyncService:RemoveFromBoard(userId: number, commissionId: string)
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		local newBoard = {}
		for _, commission in ipairs(updated[userId].Board) do
			if commission.Id ~= commissionId then
				table.insert(newBoard, commission)
			end
		end
		updated[userId].Board = newBoard
		return updated
	end)
end

--[=[
	Check whether a user already has a pending visitor offer.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@return boolean -- `true` if a visitor-sourced board offer is pending
]=]
function CommissionSyncService:HasPendingVisitorOffer(userId: number): boolean
	local state = self:GetCommissionStateReadOnly(userId)
	if not state then
		return false
	end

	for _, commission in ipairs(state.Board) do
		if commission.Source == "Visitor" then
			return true
		end
	end

	return false
end

--[=[
	Add a commission to the user's active list.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param commission TActiveCommission -- The commission to add
]=]
function CommissionSyncService:AddToActive(userId: number, commission: TActiveCommission)
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		local newActive = table.clone(updated[userId].Active)
		table.insert(newActive, commission)
		updated[userId].Active = newActive
		return updated
	end)
end

--[=[
	Remove a commission from the user's active list by ID.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param commissionId string -- The ID of the commission to remove
]=]
function CommissionSyncService:RemoveFromActive(userId: number, commissionId: string)
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		local newActive = {}
		for _, c in ipairs(updated[userId].Active) do
			if c.Id ~= commissionId then
				table.insert(newActive, c)
			end
		end
		updated[userId].Active = newActive
		return updated
	end)
end

--[=[
	Set the token balance for a user.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param amount number -- New token balance
]=]
function CommissionSyncService:SetTokens(userId: number, amount: number)
	self.Atom(function(current)
		return _UpdateUserField(current, userId, "Tokens", amount)
	end)
end

--[=[
	Set the current commission tier for a user.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param tier number -- New tier value
]=]
function CommissionSyncService:SetCurrentTier(userId: number, tier: number)
	self.Atom(function(current)
		return _UpdateUserField(current, userId, "CurrentTier", tier)
	end)
end

--[=[
	Set the last board refresh timestamp for a user.
	@within CommissionSyncService
	@param userId number -- The player's UserId
	@param time number -- Unix timestamp of the refresh
]=]
function CommissionSyncService:SetLastRefreshTime(userId: number, time: number)
	self.Atom(function(current)
		return _UpdateUserField(current, userId, "LastRefreshTime", time)
	end)
end

return CommissionSyncService

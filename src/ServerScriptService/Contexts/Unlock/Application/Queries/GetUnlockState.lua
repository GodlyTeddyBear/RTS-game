--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState

local Ok = Result.Ok
local MentionSuccess = Result.MentionSuccess

--[=[
	@class GetUnlockState
	Returns the resolved unlock state for a player: a map of `targetId -> boolean`
	that includes `StartsUnlocked` items as implicitly `true`, so consumers can
	do a simple boolean lookup on any `targetId`.
	@server
]=]

local GetUnlockState = {}
GetUnlockState.__index = GetUnlockState

function GetUnlockState.new()
	return setmetatable({}, GetUnlockState)
end

--[=[
	@within GetUnlockState
	@private
]=]
function GetUnlockState:Init(registry: any, _name: string)
	self.UnlockSyncService = registry:Get("UnlockSyncService")
end

--- Merges StartsUnlocked entries as implicitly true for simple client lookups
local function _MergeWithImplicitUnlocks(state: TUnlockState): TUnlockState
	local resolved = table.clone(state)
	for targetId, entry in pairs(UnlockConfig) do
		-- Add items that start unlocked so client can do simple boolean checks
		if entry.StartsUnlocked then
			resolved[targetId] = true
		end
	end
	return resolved
end

--[=[
	Returns the full resolved unlock state for a player.
	@within GetUnlockState
	@param userId number -- The player's user ID
	@return Result.Result<TUnlockState> -- Ok with resolved state map
]=]
function GetUnlockState:Execute(userId: number): Result.Result<TUnlockState>
	local state = self.UnlockSyncService:GetUnlockStateReadOnly(userId) or {}
	local resolvedState = _MergeWithImplicitUnlocks(state)
	MentionSuccess("Unlock:GetUnlockState:Execute", "Resolved unlock state including implicit defaults", {
		userId = userId,
	})
	return Ok(resolvedState)
end

return GetUnlockState

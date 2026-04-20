--!strict

--[=[
	@class DialogueFlagSyncService
	Infrastructure service managing in-memory dialogue flag state and emitting mutation events.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local MentionSuccess = Result.MentionSuccess
local FlagSet = GameEvents.Events.Dialogue.FlagSet

local DialogueFlagSyncService = {}
DialogueFlagSyncService.__index = DialogueFlagSyncService

export type TDialogueFlagSyncService = typeof(setmetatable({} :: {
	FlagsByUserId: { [number]: { [string]: any } },
}, DialogueFlagSyncService))

-- Create a deep copy of a table (or return scalars unchanged) to prevent accidental external mutations.
local function _DeepCopy(original: any): any
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for key, value in original do
		copy[key] = _DeepCopy(value)
	end
	return copy
end

function DialogueFlagSyncService.new(): TDialogueFlagSyncService
	return setmetatable({
		FlagsByUserId = {},
	}, DialogueFlagSyncService)
end

--[=[
	Check if a player's flags have been loaded into memory.
	@within DialogueFlagSyncService
	@param userId number -- The player's user ID
	@return boolean -- True if flags are in memory
]=]
function DialogueFlagSyncService:IsPlayerLoaded(userId: number): boolean
	return self.FlagsByUserId[userId] ~= nil
end

--[=[
	Load flags into memory for a player. Stores a deep copy.
	@within DialogueFlagSyncService
	@param userId number -- The player's user ID
	@param flags table -- Flags to load
]=]
function DialogueFlagSyncService:LoadPlayerFlags(userId: number, flags: { [string]: any })
	self.FlagsByUserId[userId] = _DeepCopy(flags)
end

--[=[
	Remove a player's flags from memory (cleanup on player unload).
	@within DialogueFlagSyncService
	@param userId number -- The player's user ID
]=]
function DialogueFlagSyncService:RemovePlayerFlags(userId: number)
	self.FlagsByUserId[userId] = nil
end

--[=[
	Retrieve a player's flags as a read-only deep copy.
	@within DialogueFlagSyncService
	@param userId number -- The player's user ID
	@return table? -- Deep copy of flags, or nil if not loaded
]=]
function DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId: number): { [string]: any }?
	local flags = self.FlagsByUserId[userId]
	if not flags then
		return nil
	end

	return _DeepCopy(flags)
end

--[=[
	Set a single flag, mutate internal state, and emit FlagSet event.
	@within DialogueFlagSyncService
	@param userId number -- The player's user ID
	@param flagName string -- The flag name
	@param flagValue any -- The value to set
]=]
function DialogueFlagSyncService:SetFlag(userId: number, flagName: string, flagValue: any)
	if not self.FlagsByUserId[userId] then
		self.FlagsByUserId[userId] = {}
	end

	self.FlagsByUserId[userId][flagName] = flagValue

	GameEvents.Bus:Emit(FlagSet, userId, flagName)

	MentionSuccess("Dialogue:DialogueFlagSyncService:SetFlag", "Flag set", {
		userId = userId,
		flag = flagName,
		value = flagValue,
	})
end

--[=[
	Set multiple flags atomically, mutate internal state, and emit FlagSet events for each.
	@within DialogueFlagSyncService
	@param userId number -- The player's user ID
	@param updates table -- Key-value table of flags to set
]=]
function DialogueFlagSyncService:SetFlags(userId: number, updates: { [string]: any })
	if not self.FlagsByUserId[userId] then
		self.FlagsByUserId[userId] = {}
	end

	for flagName, flagValue in pairs(updates) do
		self.FlagsByUserId[userId][flagName] = flagValue
		GameEvents.Bus:Emit(FlagSet, userId, flagName)
	end

	MentionSuccess("Dialogue:DialogueFlagSyncService:SetFlags", "Flags set", {
		userId = userId,
		updates = updates,
	})
end

return DialogueFlagSyncService

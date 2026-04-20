--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Guild.Sync.SharedAtoms)
local AdventurerTypes = require(ReplicatedStorage.Contexts.Guild.Types.AdventurerTypes)

type TAdventurer = AdventurerTypes.TAdventurer

--[=[
	@class GuildSyncService
	Manages adventurer state synchronization via Charm atoms and Blink events.
	Extends BaseSyncService and provides adventurer-specific mutations.
	All atom changes are centralized here.
	@server
]=]

local GuildSyncService = setmetatable({}, { __index = BaseSyncService })
GuildSyncService.__index = GuildSyncService
GuildSyncService.AtomKey = "adventurers"
GuildSyncService.BlinkEventName = "SyncAdventurers"
GuildSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function GuildSyncService.new()
	return setmetatable({}, GuildSyncService)
end

--[=[
	Get all adventurers for a user (deep clone).
	@within GuildSyncService
	@param userId number -- The player's user ID
	@return {[string]: TAdventurer}? -- Roster keyed by adventurer ID, or nil if not loaded
]=]
function GuildSyncService:GetAdventurersReadOnly(userId: number): { [string]: TAdventurer }?
	return self:GetReadOnly(userId)
end

--[=[
	Get a specific adventurer by ID (deep clone).
	@within GuildSyncService
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@return TAdventurer? -- Adventurer data, or nil if not found
]=]
function GuildSyncService:GetAdventurerReadOnly(userId: number, adventurerId: string): TAdventurer?
	return self:GetNestedReadOnly(userId, adventurerId)
end

--[=[
	Get the server-side atom reference.
	@within GuildSyncService
	@return any -- The Charm atom
]=]
function GuildSyncService:GetAdventurersAtom()
	return self:GetAtom()
end

--[=[
	Get the count of adventurers in a user's roster.
	@within GuildSyncService
	@param userId number -- The player's user ID
	@return number -- Number of adventurers (0 if user not loaded)
]=]
function GuildSyncService:GetRosterSize(userId: number): number
	local allAdventurers = self.Atom()
	local userAdventurers = allAdventurers[userId]
	if not userAdventurers then
		return 0
	end

	local count = 0
	for _ in pairs(userAdventurers) do
		count = count + 1
	end
	return count
end

--[=[
	Check if a player's adventurer state is loaded into the atom.
	@within GuildSyncService
	@param userId number -- The player's user ID
	@return boolean -- True if user has an entry in the atom
]=]
function GuildSyncService:IsPlayerLoaded(userId: number): boolean
	return self.Atom()[userId] ~= nil
end

--[=[
	Bulk load adventurers for a user from persisted data.
	Used on player join to restore guild state.
	@within GuildSyncService
	@param userId number -- The player's user ID
	@param adventurersData {[string]: TAdventurer} -- Roster data to load
]=]
function GuildSyncService:LoadUserAdventurers(userId: number, adventurersData: { [string]: TAdventurer }): ()
	self:LoadUserData(userId, adventurersData)
end

--[=[
	Remove all adventurers for a user from the atom.
	Used on player leave to cleanup sync state.
	@within GuildSyncService
	@param userId number -- The player's user ID
]=]
function GuildSyncService:RemoveUserAdventurers(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Create a new adventurer for a user with base stats and empty equipment slots.
	@within GuildSyncService
	@param userId number -- The player's user ID
	@param adventurerId string -- The new adventurer's ID
	@param adventurerType string -- The adventurer type (from config)
	@param config any -- Configuration table with BaseHP, BaseATK, BaseDEF
]=]
function GuildSyncService:CreateAdventurer(
	userId: number,
	adventurerId: string,
	adventurerType: string,
	config: any
)
	-- Perform 2-level clone: root and user roster
	self.Atom(function(current)
		local updated = table.clone(current)

		if not updated[userId] then
			updated[userId] = {}
		else
			updated[userId] = table.clone(updated[userId])
		end

		-- Create new adventurer with base stats and empty equipment
		updated[userId][adventurerId] = {
			Id = adventurerId,
			Type = adventurerType,
			BaseHP = config.BaseHP,
			BaseATK = config.BaseATK,
			BaseDEF = config.BaseDEF,
			Equipment = {
				Weapon = nil,
				Armor = nil,
				Accessory = nil,
			},
			HiredAt = os.time(),
		}

		return updated
	end)
end

--[=[
	Set an equipment slot on an adventurer (4-level deep clone to ensure immutability).
	@within GuildSyncService
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
	@param equipmentSlot {ItemId: string, SlotType: string} -- Equipment data
]=]
function GuildSyncService:SetEquipment(
	userId: number,
	adventurerId: string,
	slotType: string,
	equipmentSlot: { ItemId: string, SlotType: string }
)
	self.Atom(function(current)
		-- Clone all levels to prevent external mutations
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		updated[userId][adventurerId] = table.clone(updated[userId][adventurerId])
		updated[userId][adventurerId].Equipment = table.clone(updated[userId][adventurerId].Equipment)
		updated[userId][adventurerId].Equipment[slotType] = equipmentSlot
		return updated
	end)
end

--[=[
	Clear an equipment slot on an adventurer (4-level deep clone).
	@within GuildSyncService
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
]=]
function GuildSyncService:ClearEquipment(userId: number, adventurerId: string, slotType: string)
	self.Atom(function(current)
		-- Clone all levels to prevent external mutations
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		updated[userId][adventurerId] = table.clone(updated[userId][adventurerId])
		updated[userId][adventurerId].Equipment = table.clone(updated[userId][adventurerId].Equipment)
		updated[userId][adventurerId].Equipment[slotType] = nil
		return updated
	end)
end

--[=[
	Set the IsOnExpedition flag on an adventurer (3-level clone).
	@within GuildSyncService
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param isOnExpedition boolean -- Whether the adventurer is on expedition
]=]
function GuildSyncService:SetAdventurerExpeditionStatus(userId: number, adventurerId: string, isOnExpedition: boolean)
	self.Atom(function(current)
		-- Clone nested levels
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		updated[userId][adventurerId] = table.clone(updated[userId][adventurerId])
		updated[userId][adventurerId].IsOnExpedition = isOnExpedition
		return updated
	end)
end

--[=[
	Remove a specific adventurer from the user's roster.
	@within GuildSyncService
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID to remove
]=]
function GuildSyncService:RemoveAdventurer(userId: number, adventurerId: string)
	self.Atom(function(current)
		-- Clone root and user roster
		local updated = table.clone(current)
		updated[userId] = table.clone(updated[userId])
		updated[userId][adventurerId] = nil
		return updated
	end)
end

return GuildSyncService

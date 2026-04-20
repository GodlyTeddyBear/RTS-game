--!strict

--[=[
	@class UnequipPolicy
	Domain policy that answers: can the item in this slot be unequipped from this adventurer?
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuildSpecs = require(script.Parent.Parent.Specs.GuildSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

local VALID_SLOT_TYPES = {
	Weapon    = true,
	Armor     = true,
	Accessory = true,
}

local UnequipPolicy = {}
UnequipPolicy.__index = UnequipPolicy

export type TUnequipPolicy = typeof(setmetatable({}, UnequipPolicy))

function UnequipPolicy.new(): TUnequipPolicy
	return setmetatable({}, UnequipPolicy)
end

--[=[
	Initialize with dependencies available at KnitInit.
	@within UnequipPolicy
]=]
function UnequipPolicy:Init(registry: any)
	self.GuildSyncService = registry:Get("GuildSyncService")
end

--[=[
	Evaluate whether an item can be unequipped from an adventurer's slot.
	Fetches adventurer state, builds candidate, and evaluates specs.
	No cross-context dependencies — all checks are in-memory reads.
	@within UnequipPolicy
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
	@return Result<{EquippedSlot: any}> -- Current equipment slot data for command use
	@error AdventurerNotFound -- Adventurer ID not found in roster
	@error InvalidSlotType -- Slot type is not valid
	@error SlotAlreadyEmpty -- Equipment slot is empty
]=]
function UnequipPolicy:Check(
	userId: number,
	adventurerId: string,
	slotType: string
): Result.Result<{ EquippedSlot: any }>
	-- Step 1: Fetch current roster
	local adventurers = self.GuildSyncService:GetAdventurersReadOnly(userId)
	Ensure(adventurers ~= nil, "AdventurerNotFound", Errors.ADVENTURER_NOT_FOUND)

	-- Step 2: Lookup adventurer and validate slot type
	local adventurer = adventurers[adventurerId]
	local slotIsValid = VALID_SLOT_TYPES[slotType] == true

	-- Step 3: Build candidate for spec evaluation
	-- Defensive specs pass when prerequisite is false, so only root error is reported
	local candidate: GuildSpecs.TUnequipItemCandidate = {
		AdventurerExists      = adventurer ~= nil,
		UnequipSlotTypeValid  = adventurer == nil or slotIsValid,
		SlotNotEmpty          = adventurer == nil
			or not slotIsValid
			or adventurer.Equipment[slotType] ~= nil,
	}

	-- Step 4: Evaluate composite spec (short-circuits on missing adventurer)
	Try(GuildSpecs.CanUnequipItem:IsSatisfiedBy(candidate))

	-- Step 5: Return equipped slot data for command to use
	return Ok({ EquippedSlot = adventurer.Equipment[slotType] })
end

return UnequipPolicy

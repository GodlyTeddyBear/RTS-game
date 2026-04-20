--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdventurerConfig = require(ReplicatedStorage.Contexts.Guild.Config.AdventurerConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[=[
	@class HireAdventurer
	Application command that orchestrates the full hire flow:
	validate -> deduct gold -> create adventurer -> persist -> sync.
	@server
]=]

--[=[
	@interface THireResult
	@within HireAdventurer
	.AdventurerId string -- The new adventurer's ID
	.Type string -- The adventurer type
	.HireCost number -- The cost deducted from player gold
]=]
export type THireResult = {
	AdventurerId: string,
	Type: string,
	HireCost: number,
}

local HireAdventurer = {}
HireAdventurer.__index = HireAdventurer

export type THireAdventurer = typeof(setmetatable({}, HireAdventurer))

function HireAdventurer.new(): THireAdventurer
	local self = setmetatable({}, HireAdventurer)
	return self
end

--[=[
	Initialize with dependencies available at KnitInit.
	@within HireAdventurer
]=]
function HireAdventurer:Init(registry: any)
	self.Registry = registry
	self.HirePolicy = registry:Get("HirePolicy")
	self.GuildSyncService = registry:Get("GuildSyncService")
	self.PersistenceService = registry:Get("GuildPersistenceService")
end

--[=[
	Resolve cross-context dependencies available at KnitStart.
	@within HireAdventurer
]=]
function HireAdventurer:Start()
	self.ShopContext = self.Registry:Get("ShopContext")
end

--[=[
	Execute the hire command: validate -> deduct gold -> create -> persist -> sync.
	@within HireAdventurer
	@param player Player -- The player hiring
	@param userId number -- The player's user ID
	@param adventurerType string -- The adventurer type to hire
	@return Result<THireResult> -- New adventurer ID, type, and hire cost
	@error InvalidInput -- Player or adventurer type is invalid
	@error InvalidAdventurerType -- Type does not exist in config
	@error RosterFull -- Roster is at maximum capacity
	@error InsufficientGold -- Player lacks gold for hire cost
	@error PersistenceFailed -- Failed to persist to profile
]=]
function HireAdventurer:Execute(player: Player, userId: number, adventurerType: string): Result.Result<THireResult>
	-- Step 1: Validate inputs
	Ensure(player ~= nil and userId > 0, "InvalidInput", Errors.PLAYER_NOT_FOUND)
	Ensure(adventurerType ~= nil, "InvalidInput", Errors.INVALID_ADVENTURER_TYPE)

	-- Step 2: Evaluate hire eligibility and fetch hire cost
	local ctx = Try(self.HirePolicy:Check(userId, adventurerType))
	local hireCost = ctx.HireCost

	-- Step 3: Lookup adventurer config for base stats
	local config = AdventurerConfig[adventurerType]

	-- Step 4: Deduct gold first (fails early if insufficient; later steps won't execute)
	Try(self.ShopContext:DeductGold(player, userId, hireCost))

	-- Step 5: Generate unique adventurer ID
	local adventurerId = HttpService:GenerateGUID(false)

	-- Step 6: Create adventurer in sync atom (in-memory state)
	self.GuildSyncService:CreateAdventurer(userId, adventurerId, adventurerType, config)

	-- Step 7: Persist to profile (non-fatal if fails; state is already in memory)
	local adventurerData = self.GuildSyncService:GetAdventurerReadOnly(userId, adventurerId)
	if adventurerData then
		Try(self.PersistenceService:SaveAdventurer(player, adventurerId, adventurerData))
	end
	MentionSuccess("Guild:HireAdventurer:Execute", "Hired adventurer and persisted guild roster entry", {
		userId = userId,
		adventurerId = adventurerId,
		adventurerType = adventurerType,
	})

	-- Step 8: Return result
	return Ok({
		AdventurerId = adventurerId,
		Type = adventurerType,
		HireCost = hireCost,
	})
end

return HireAdventurer

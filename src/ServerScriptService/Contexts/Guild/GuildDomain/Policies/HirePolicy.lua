--!strict

--[=[
	@class HirePolicy
	Domain policy that answers: can this adventurer type be hired for this player?
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdventurerConfig = require(ReplicatedStorage.Contexts.Guild.Config.AdventurerConfig)
local GuildConfig = require(ReplicatedStorage.Contexts.Guild.Config.GuildConfig)
local GuildSpecs = require(script.Parent.Parent.Specs.GuildSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local HirePolicy = {}
HirePolicy.__index = HirePolicy

export type THirePolicy = typeof(setmetatable({}, HirePolicy))

function HirePolicy.new(): THirePolicy
	return setmetatable({}, HirePolicy)
end

--[=[
	Initialize with dependencies available at KnitInit.
	@within HirePolicy
]=]
function HirePolicy:Init(registry: any)
	self._registry = registry
	self.GuildSyncService = registry:Get("GuildSyncService")
end

--[=[
	Resolve cross-context dependencies available at KnitStart.
	@within HirePolicy
]=]
function HirePolicy:Start()
	self.ShopContext = self._registry:Get("ShopContext")
end

--[=[
	Evaluate whether an adventurer type can be hired for a player.
	Fetches gold and roster state, builds candidate, and evaluates specs.
	@within HirePolicy
	@param userId number -- The player's user ID
	@param adventurerType string -- The adventurer type key to hire
	@return Result<{HireCost: number}> -- Hire cost from config on success
	@error InvalidAdventurerType -- Type does not exist in AdventurerConfig
	@error RosterFull -- Roster is at or above maximum capacity
	@error InsufficientGold -- Player gold is less than hire cost
]=]
function HirePolicy:Check(userId: number, adventurerType: string): Result.Result<{ HireCost: number }>
	-- Step 1: Fetch current player gold and roster size
	local currentGold = Try(self.ShopContext:GetPlayerGold(userId))
	local currentRosterSize = self.GuildSyncService:GetRosterSize(userId)

	-- Step 2: Lookup adventurer config (used for validation and cost)
	local config = AdventurerConfig[adventurerType]

	-- Step 3: Build candidate for spec evaluation
	-- Defensive specs pass when prerequisite is false, so only root error is reported
	local candidate: GuildSpecs.TGuildHireCandidate = {
		AdventurerTypeValid = config ~= nil,
		RosterNotFull  = config == nil or currentRosterSize < GuildConfig.MAX_ROSTER_SIZE,
		SufficientGold = config == nil or currentGold >= config.HireCost,
	}

	-- Step 4: Evaluate composite spec (short-circuits on invalid type)
	Try(GuildSpecs.CanHireAdventurer:IsSatisfiedBy(candidate))

	-- Step 5: Return hire cost for command to use
	return Ok({ HireCost = config.HireCost })
end

return HirePolicy

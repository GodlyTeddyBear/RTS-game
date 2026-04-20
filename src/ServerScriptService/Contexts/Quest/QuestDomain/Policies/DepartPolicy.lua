--!strict

--[[
	DepartPolicy — Domain Policy

	Answers: can this player depart on a quest with this party to this zone?

	RESPONSIBILITIES:
	  1. Fetch active expedition state from Infrastructure (QuestSyncService)
	  2. Accept pre-fetched adventurers (caller is responsible for the GuildContext read)
	  3. Build a TDepartCandidate from that state + ZoneConfig
	  4. Evaluate the CanDepart spec against the candidate

	RESULT:
	  Ok(nil)   — zone valid, party size valid, no active expedition,
	              all adventurers in roster and available
	  Err(...)  — zone not found, party too small/large, expedition active,
	              adventurer missing, or adventurer already on expedition

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local allAdventurers = Try(self.GuildContext:GetAdventurersForUser(userId))
	  Try(self.DepartPolicy:Check(userId, zoneId, partyAdventurerIds, allAdventurers))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local ZoneConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneConfig)
local QuestSpecs = require(script.Parent.Parent.Specs.QuestSpecs)

--[=[
	@class DepartPolicy
	Domain policy that evaluates whether a player may depart on a quest.
	Accepts pre-fetched adventurer data from the caller — never performs
	Infrastructure reads itself.
	@server
]=]
local DepartPolicy = {}
DepartPolicy.__index = DepartPolicy

export type TDepartPolicy = typeof(setmetatable(
	{} :: {
		registry: any,
		questSyncService: any,
		unlockContext: any,
	},
	DepartPolicy
))

--[=[
	@within DepartPolicy
	@private
]=]
function DepartPolicy.new(): TDepartPolicy
	local self = setmetatable({}, DepartPolicy)
	self.registry = nil :: any
	self.questSyncService = nil :: any
	self.unlockContext = nil :: any
	return self
end

--[=[
	@within DepartPolicy
	@private
]=]
function DepartPolicy:Init(registry: any, _name: string)
	self.registry = registry
	self.questSyncService = registry:Get("QuestSyncService")
end

--[=[
	@within DepartPolicy
	@private
]=]
function DepartPolicy:Start()
	self.unlockContext = self.registry:Get("UnlockContext")
end

--[=[
	Evaluates whether the player may depart on a quest with the given party.
	Caller must pre-fetch `allAdventurers` from GuildContext before calling.
	@within DepartPolicy
	@param userId number
	@param zoneId string
	@param partyAdventurerIds {string}
	@param allAdventurers {[string]: any} -- Full roster from GuildContext
	@return Result.Result<nil>
]=]
function DepartPolicy:Check(userId: number, zoneId: string, partyAdventurerIds: { string }, allAdventurers: { [string]: any }): Result.Result<nil>
	local questState = self.questSyncService:GetQuestStateReadOnly(userId)
	local activeExpedition = questState and questState.ActiveExpedition or nil

	local zone = ZoneConfig[zoneId]
	local zoneUnlocked = self.unlockContext:IsUnlocked(userId, zoneId)
	local partySize = #partyAdventurerIds

	local candidate: QuestSpecs.TDepartCandidate = {
		ZoneExists              = zone ~= nil,
		ZoneUnlocked            = zoneUnlocked,
		-- Pass when zone is nil — ZoneExists:And short-circuits before these run
		PartySizeAtLeast        = zone == nil or partySize >= zone.MinPartySize,
		PartySizeAtMost         = zone == nil or partySize <= zone.MaxPartySize,
		NoActiveExpedition      = activeExpedition == nil,
		AllAdventurersExist     = self:_AllAdventurersInRoster(partyAdventurerIds, allAdventurers),
		NoAdventurersOnExpedition = self:_NoneCurrentlyOnExpedition(partyAdventurerIds, allAdventurers),
	}

	Try(QuestSpecs.CanDepart:IsSatisfiedBy(candidate))

	return Ok(nil)
end

--[=[
	@within DepartPolicy
	@private
]=]
function DepartPolicy:_AllAdventurersInRoster(partyAdventurerIds: { string }, allAdventurers: { [string]: any }): boolean
	for _, adventurerId in ipairs(partyAdventurerIds) do
		if not allAdventurers[adventurerId] then
			return false
		end
	end
	return true
end

--[=[
	@within DepartPolicy
	@private
]=]
function DepartPolicy:_NoneCurrentlyOnExpedition(partyAdventurerIds: { string }, allAdventurers: { [string]: any }): boolean
	for _, adventurerId in ipairs(partyAdventurerIds) do
		local adventurer = allAdventurers[adventurerId]
		if adventurer and adventurer.IsOnExpedition then
			return false
		end
	end
	return true
end

return DepartPolicy

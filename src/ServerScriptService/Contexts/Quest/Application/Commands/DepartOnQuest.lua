--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ZoneConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Ok, Err, Try = Result.Ok, Result.Err, Result.Try
local MentionSuccess = Result.MentionSuccess
local Events = GameEvents.Events

--[=[
	@class DepartOnQuest
	Application command that orchestrates expedition departure: fetches adventurers,
	validates eligibility, builds and persists expedition state, generates the dungeon,
	spawns the NPC party and first enemy wave, then schedules combat start.
	@server
]=]

--[=[
	@interface TDepartResult
	@within DepartOnQuest
	.ExpeditionId string -- Unique identifier for the new expedition
	.ZoneId string -- Zone the expedition targets
	.PartySize number -- Number of adventurers in the party
	.ZoneDisplayName string -- Human-readable zone name from ZoneConfig
]=]
export type TDepartResult = {
	ExpeditionId: string,
	ZoneId: string,
	PartySize: number,
	ZoneDisplayName: string,
}

local DepartOnQuest = {}
DepartOnQuest.__index = DepartOnQuest

export type TDepartOnQuest = typeof(setmetatable({}, DepartOnQuest))

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest.new(): TDepartOnQuest
	local self = setmetatable({}, DepartOnQuest)
	return self
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:Init(registry: any, _name: string)
	self.Registry = registry
	self.DepartPolicy = registry:Get("DepartPolicy")
	self.QuestSyncService = registry:Get("QuestSyncService")
	self.QuestPersistenceService = registry:Get("QuestPersistenceService")
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:Start()
	self.GuildContext = self.Registry:Get("GuildContext")
	self.NPCContext = self.Registry:Get("NPCContext")
	self.CombatContext = self.Registry:Get("CombatContext")
	self.DungeonContext = self.Registry:Get("DungeonContext")
end

--[=[
	Runs the full departure sequence for a player. Returns immediately after
	scheduling combat — combat itself fires asynchronously after a 3-second delay.
	@within DepartOnQuest
	@param player Player
	@param userId number
	@param zoneId string -- ZoneConfig key for the target zone
	@param partyAdventurerIds {string} -- IDs of adventurers to include
	@param onCombatComplete ((string, {string}) -> ())? -- Callback fired when combat ends
	@return Result.Result<TDepartResult>
]=]
function DepartOnQuest:Execute(player: Player, userId: number, zoneId: string, partyAdventurerIds: { string }, onCombatComplete: ((string, { string }) -> ())?): Result.Result<TDepartResult>
	if not player or userId <= 0 then
		return Err("InvalidInput", Errors.PLAYER_NOT_FOUND, { userId = userId })
	end

	-- 1. Fetch adventurers (Infrastructure) then validate eligibility (Domain)
	local allAdventurers = Try(self.GuildContext:GetAdventurersForUser(userId))
	Try(self.DepartPolicy:Check(userId, zoneId, partyAdventurerIds, allAdventurers))

	-- 2. Build expedition state
	local expeditionId = HttpService:GenerateGUID(false)
	local expedition = self:_BuildExpedition(expeditionId, zoneId, partyAdventurerIds, allAdventurers)

	-- 3. Persist expedition to atom
	self.QuestSyncService:CreateExpedition(userId, expedition)

	-- 4. Mark each adventurer as on expedition
	self:_MarkAdventurersDeparted(userId, partyAdventurerIds)

	-- 5. Generate dungeon environment (hard failure — rollback expedition)
	if self.DungeonContext then
		Try(self.DungeonContext:GenerateDungeon(player, userId, zoneId)
			:orElse(function(err)
				self:_RollbackExpedition(userId, partyAdventurerIds)
				return err
			end))
	end

	-- 6. Spawn adventurer party as NPCs (graceful — warn and continue)
	local partyAdventurers = self:_SelectPartyAdventurers(partyAdventurerIds, allAdventurers)
	local startSpawnPoints = Try(self.DungeonContext:GetSpawnPoints(userId, 0))
	local adventurerEntities = self.NPCContext:SpawnAdventurerPartyForUser(
		userId, partyAdventurers, startSpawnPoints
	):unwrapOr(nil)

	-- 7. Spawn first enemy wave (requires adventurers)
	local enemyEntities = self:_SpawnFirstEnemyWave(userId, zoneId, adventurerEntities)

	-- 8. After 3 seconds, drop the Start barrier and start combat
	if adventurerEntities and enemyEntities then
		self:_StartCombatAfterDelay(userId, adventurerEntities, enemyEntities, zoneId, onCombatComplete)
	end

	GameEvents.Bus:Emit(Events.Guide.Ch2ExpeditionLaunched, userId)

	MentionSuccess("Quest:DepartOnQuest:Execute", "Created expedition and initialized dungeon combat setup", {
		userId = userId,
		zoneId = zoneId,
		partySize = #partyAdventurerIds,
	})

	return Ok({
		ExpeditionId = expeditionId,
		ZoneId = zoneId,
		PartySize = #partyAdventurerIds,
		ZoneDisplayName = ZoneConfig[zoneId].DisplayName,
	})
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:_BuildExpedition(expeditionId: string, zoneId: string, partyAdventurerIds: { string }, allAdventurers: { [string]: any }): { [string]: any }
	local party = {}
	for _, adventurerId in ipairs(partyAdventurerIds) do
		local adventurer = allAdventurers[adventurerId]
		table.insert(party, {
			AdventurerId = adventurerId,
			AdventurerType = adventurer.Type,
		})
	end
	return {
		ExpeditionId = expeditionId,
		ZoneId = zoneId,
		Status = "InCombat",
		Party = party,
		StartedAt = os.time(),
		CompletedAt = nil,
		Loot = nil,
		GoldEarned = 0,
		DeadAdventurerIds = nil,
	}
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:_SelectPartyAdventurers(partyAdventurerIds: { string }, allAdventurers: { [string]: any }): { [string]: any }
	local partyAdventurers: { [string]: any } = {}
	for _, adventurerId in ipairs(partyAdventurerIds) do
		partyAdventurers[adventurerId] = allAdventurers[adventurerId]
	end
	return partyAdventurers
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:_MarkAdventurersDeparted(userId: number, partyAdventurerIds: { string })
	for _, adventurerId in ipairs(partyAdventurerIds) do
		self.GuildContext:MarkAdventurerDeparted(userId, adventurerId)
	end
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:_SpawnFirstEnemyWave(userId: number, zoneId: string, adventurerEntities: { any }?): { any }?
	if not adventurerEntities then
		return nil
	end
	local wave1SpawnPoints = self.DungeonContext:GetSpawnPoints(userId, 1):unwrapOr(nil)
	if not wave1SpawnPoints then
		return nil
	end
	return self.NPCContext:SpawnEnemyWaveForUser(userId, 1, zoneId, wave1SpawnPoints):unwrapOr(nil)
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:_RollbackExpedition(userId: number, partyAdventurerIds: { string })
	for _, adventurerId in ipairs(partyAdventurerIds) do
		self.GuildContext:MarkAdventurerReturned(userId, adventurerId)
	end
	self.QuestSyncService:ClearActiveExpedition(userId)
end

--[=[
	@within DepartOnQuest
	@private
]=]
function DepartOnQuest:_StartCombatAfterDelay(
	userId: number,
	adventurerEntities: { any },
	enemyEntities: { any },
	zoneId: string,
	onCombatComplete: ((string, { string }) -> ())?
)
	local startModel = self.DungeonContext:GetStartModel(userId):unwrapOr(nil)

	task.delay(3, function()
		if startModel then
			self.DungeonContext:DestroyBarrierOnPiece(startModel)
		end

		local combatResult = self.CombatContext:StartCombatForUser(
			userId, adventurerEntities, enemyEntities, zoneId, onCombatComplete
		)
		if not combatResult.success then
			warn(string.format("[Quest:DepartOnQuest] userId: %d - Failed to start combat: %s", userId, combatResult.message))
		end
	end)
end

return DepartOnQuest

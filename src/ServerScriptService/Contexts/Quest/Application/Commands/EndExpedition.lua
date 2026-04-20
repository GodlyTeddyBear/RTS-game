--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LootTableConfig = require(ReplicatedStorage.Contexts.Quest.Config.LootTableConfig)
local ZoneConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Ok, Err, Try = Result.Ok, Result.Err, Result.Try
local MentionSuccess = Result.MentionSuccess
local Events = GameEvents.Events

--[=[
	@class EndExpedition
	Application command called when combat concludes (Victory or Defeat) or when
	the player flees. Awards loot, applies permadeath, returns surviving adventurers
	to roster, records the terminal result, and persists the updated quest state.
	@server
]=]

--[=[
	@interface TEndExpeditionResult
	@within EndExpedition
	.Status string -- Final expedition status: "Victory", "Defeat", or "Fled"
	.Loot {[string]: number} -- Item drops awarded (empty on non-Victory)
	.GoldEarned number -- Gold awarded (0 on non-Victory)
]=]
export type TEndExpeditionResult = {
	Status: string,
	Loot: { [string]: number },
	GoldEarned: number,
}

local EndExpedition = {}
EndExpedition.__index = EndExpedition

export type TEndExpedition = typeof(setmetatable({}, EndExpedition))

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition.new(): TEndExpedition
	local self = setmetatable({}, EndExpedition)
	return self
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:Init(registry: any, _name: string)
	self.Registry = registry
	self.QuestSyncService = registry:Get("QuestSyncService")
	self.QuestPersistenceService = registry:Get("QuestPersistenceService")
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:Start()
	self.GuildContext = self.Registry:Get("GuildContext")
	self.ShopContext = self.Registry:Get("ShopContext")
	self.InventoryContext = self.Registry:Get("InventoryContext")
	self.DungeonContext = self.Registry:Get("DungeonContext")
end

--[=[
	Finalises the expedition for a player.
	@within EndExpedition
	@param player Player
	@param userId number
	@param status string -- "Victory", "Defeat", or "Fled"
	@param deadAdventurerIds {string}? -- Adventurers killed during the expedition
	@return Result.Result<TEndExpeditionResult>
]=]
function EndExpedition:Execute(
	player: Player,
	userId: number,
	status: string,
	deadAdventurerIds: { string }?
): Result.Result<TEndExpeditionResult>
	if not player or userId <= 0 then
		return Err("InvalidInput", Errors.PLAYER_NOT_FOUND, { userId = userId })
	end

	local expedition = self.QuestSyncService:GetActiveExpeditionReadOnly(userId)
	if not expedition then
		return Err("NoActiveExpedition", Errors.NO_ACTIVE_EXPEDITION, { userId = userId })
	end

	local loot, goldEarned = self:_AwardLootIfVictory(player, userId, status, expedition)

	-- Set result details on atom before roster mutations remove casualties
	if next(loot) ~= nil then
		self.QuestSyncService:SetExpeditionLoot(userId, loot)
	end
	self.QuestSyncService:SetExpeditionGoldEarned(userId, goldEarned)
	self.QuestSyncService:SetDeadAdventurers(userId, deadAdventurerIds or {})
	self.QuestSyncService:SetExpeditionStatus(userId, status, os.time())

	-- Permadeath: remove dead adventurers from guild roster
	Try(self:_ApplyPermadeath(player, userId, deadAdventurerIds))

	-- Return surviving party members to available status
	Try(self:_ReturnSurvivorsToRoster(userId, expedition.Party, deadAdventurerIds))

	-- Increment completed count, persist, and notify unlock system
	if status == "Victory" or status == "Defeat" then
		self.QuestSyncService:IncrementCompletedCount(userId)
		GameEvents.Bus:Emit(Events.Quest.QuestCompleted, userId)
	end

	if status == "Victory" then
		GameEvents.Bus:Emit(Events.Guide.Ch2OutcomeVictory, userId)
	elseif status == "Defeat" then
		GameEvents.Bus:Emit(Events.Guide.Ch2OutcomeDefeat, userId)
	elseif status == "Fled" then
		GameEvents.Bus:Emit(Events.Guide.Ch2OutcomeFled, userId)
	end

	local questState = self.QuestSyncService:GetQuestStateReadOnly(userId)
	if questState then
		Try(self.QuestPersistenceService:SaveQuestState(player, {
			CompletedCount = questState.CompletedCount,
			-- ActiveExpedition intentionally NOT persisted
		}))
	end
	MentionSuccess("Quest:EndExpedition:Execute", "Finalized expedition outcome and persisted quest progress", {
		userId = userId,
		status = status,
		goldEarned = goldEarned,
	})

	return Ok({
		Status = status,
		Loot = loot,
		GoldEarned = goldEarned,
	})
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:_ApplyPermadeath(player: Player, userId: number, deadAdventurerIds: { string }?): Result.Result<boolean>
	if not deadAdventurerIds or #deadAdventurerIds == 0 then return Ok(true) end
	for _, adventurerId in ipairs(deadAdventurerIds) do
		Try(self.GuildContext:RemoveAdventurer(player, userId, adventurerId))
	end
	return Ok(true)
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:_ReturnSurvivorsToRoster(userId: number, party: { any }, deadAdventurerIds: { string }?): Result.Result<boolean>
	for _, member in ipairs(party) do
		if not deadAdventurerIds or not table.find(deadAdventurerIds, member.AdventurerId) then
			Try(self.GuildContext:MarkAdventurerReturned(userId, member.AdventurerId))
		end
	end
	return Ok(true)
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:_AwardLootIfVictory(
	player: Player,
	userId: number,
	status: string,
	expedition: any
): ({ [string]: number }, number)
	if status ~= "Victory" then
		return {}, 0
	end

	local zone = ZoneConfig[expedition.ZoneId]
	if not zone then
		return {}, 0
	end

	local rolledItems, goldEarned = self:_RollLoot(zone.LootTableId, expedition.ZoneId)

	if goldEarned > 0 then
		Try(self.ShopContext:AddGold(player, userId, goldEarned))
	end

	for itemId, quantity in pairs(rolledItems) do
		Try(self.InventoryContext:AddItemToInventory(userId, itemId, quantity))
	end

	return rolledItems, goldEarned
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:_RollLoot(lootTableId: string, zoneId: string): ({ [string]: number }, number)
	local rolledItems = self:_RollWeightedItems(lootTableId)
	local goldEarned = self:_RollGold(zoneId)
	return rolledItems, goldEarned
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:_RollWeightedItems(lootTableId: string): { [string]: number }
	local lootTable = LootTableConfig[lootTableId]
	if not lootTable then return {} end

	local totalWeight = 0
	for _, entry in ipairs(lootTable) do
		totalWeight += entry.Weight
	end

	local rolledItems: { [string]: number } = {}
	local rolls = math.random(1, 3)
	for _ = 1, rolls do
		local weightRoll = math.random(1, totalWeight)
		local cumulativeWeight = 0
		for _, entry in ipairs(lootTable) do
			cumulativeWeight += entry.Weight
			if weightRoll <= cumulativeWeight then
				local qty = math.random(entry.MinQty, entry.MaxQty)
				rolledItems[entry.ItemId] = (rolledItems[entry.ItemId] or 0) + qty
				break
			end
		end
	end

	return rolledItems
end

--[=[
	@within EndExpedition
	@private
]=]
function EndExpedition:_RollGold(zoneId: string): number
	local zone = ZoneConfig[zoneId]
	if not zone then return 0 end
	return math.random(zone.BaseGoldMin, zone.BaseGoldMax)
end

return EndExpedition

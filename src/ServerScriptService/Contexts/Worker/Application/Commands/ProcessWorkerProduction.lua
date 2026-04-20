--!strict

--[[
	Process Worker Production Application Service - ECS version

	Orchestrates: query entities → policy check → production → persist

	Flow:
	1. Query all worker entities from ECS world
	2. ProductionEligibilityPolicy: check assignment, role, and accumulated production
	3. Dispatch to Forge, Brewery, or Generic handler
	4. For recipe workers: policy checks recipe + ingredients, then consume/craft
	5. Update components with new values (Infrastructure - EntityFactory)
	6. Persist changes to ProfileStore (Infrastructure - DataManager)
	7. Sync to Charm atom for client (Infrastructure - legacy bridge)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)

type Result<T> = Result.Result<T>
local Ok = Result.Ok
local Try = Result.Try
local Catch = Result.Catch

--[=[
	@class ProcessWorkerProduction
	Tick system that drives XP and crafting production for Forge, Brewery, and generic
	production-line workers. Called once per server tick from the Planck scheduler.
	@server
]=]
local ProcessWorkerProduction = {}
ProcessWorkerProduction.__index = ProcessWorkerProduction

export type TProcessWorkerProduction = typeof(setmetatable(
	{} :: {
		Registry: any,
		LevelService: any,
		EntityFactory: any,
		PersistenceService: any,
		SyncService: any,
		ProductionEligibilityPolicy: any,
		ForgeTickPolicy: any,
		BreweryTickPolicy: any,
		InventoryContext: any?,
		UpgradeContext: any?,
	},
	ProcessWorkerProduction
))

type TLevelResult = {
	ShouldLevelUp: boolean,
	NewLevel: number,
	RemainingXP: number,
	NewXP: number,
}

function ProcessWorkerProduction.new(): TProcessWorkerProduction
	return setmetatable({}, ProcessWorkerProduction)
end

function ProcessWorkerProduction:Init(registry: any, _name: string)
	self.Registry = registry
	self.LevelService = registry:Get("WorkerLevelService")
	self.EntityFactory = registry:Get("WorkerEntityFactory")
	self.PersistenceService = registry:Get("WorkerPersistenceService")
	self.SyncService = registry:Get("WorkerSyncService")
	self.ProductionEligibilityPolicy = registry:Get("ProductionEligibilityPolicy")
	self.ForgeTickPolicy = registry:Get("ForgeTickPolicy")
	self.BreweryTickPolicy = registry:Get("BreweryTickPolicy")
end

function ProcessWorkerProduction:Start()
	self.InventoryContext = self.Registry:Get("InventoryContext")
	self.UpgradeContext = self.Registry:Get("UpgradeContext")
end

--- @within ProcessWorkerProduction
--- @private
function ProcessWorkerProduction:_ApplyXPMultiplier(userId: number, xpGained: number): number
	if self.UpgradeContext then
		local mult = self.UpgradeContext:GetWorkerXPMultiplier(userId)
		return math.floor(xpGained * mult)
	end
	return xpGained
end

--[=[
	Processes one production tick for every eligible worker across all online players.
	Each entity is wrapped in `Catch` so a single failure does not abort the rest.
	@within ProcessWorkerProduction
]=]
function ProcessWorkerProduction:Execute()
	local currentTime = os.time()

	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local workerEntities = self.EntityFactory:QueryUserWorkers(userId)

		for _, workerData in workerEntities do
			Catch(function()
				self:_ProcessWorkerData(player, workerData, currentTime)
				return Ok(nil)
			end, "Worker:ProcessWorkerProduction")
		end
	end
end

--- @within ProcessWorkerProduction
--- @private
function ProcessWorkerProduction:_ProcessWorkerData(player: Player, workerData: any, currentTime: number)
	local policyResult = self.ProductionEligibilityPolicy:Check(workerData, currentTime)
	if not policyResult.success then return end

	local ctx = policyResult.value
	local assignment = ctx.Assignment
	local entity = workerData.Entity
	local worker = workerData.Worker

	-- Recipe-based workers require an assignment; skip entirely when idle (no timer reset)
	if assignment.Role == "Forge" then
		self:_ProcessRecipeProduction(player, entity, worker, assignment, currentTime, self.ForgeTickPolicy, true)
	elseif assignment.Role == "Brewery" then
		self:_ProcessRecipeProduction(player, entity, worker, assignment, currentTime, self.BreweryTickPolicy, false)
	else
		self:_ProcessGenericProduction(player, entity, worker, assignment, math.floor(ctx.Production), currentTime)
	end
end

--- @within ProcessWorkerProduction
--- @private
--- Shared production handler for all recipe-based roles (Forge, Brewery).
--- `applyQuality` controls whether a quality roll is used to pick the output item.
function ProcessWorkerProduction:_ProcessRecipeProduction(
	player: Player,
	entity: any,
	worker: any,
	assignment: any,
	currentTime: number,
	policy: any,
	applyQuality: boolean
)
	local userId = player.UserId

	-- Always advance the timer so we don't accumulate a backlog during shortages
	self.EntityFactory:UpdateLastProductionTick(entity, currentTime)
	self.SyncService:UpdateLastProductionTick(userId, worker.Id, currentTime)

	local policyResult = policy:Check(assignment, userId)
	if not policyResult.success then
		Try(self.PersistenceService:SaveWorkerEntity(player, entity))
		return
	end

	local ctx = policyResult.value
	local recipe = ctx.Recipe
	local inventoryState = ctx.InventoryState

	self:_ConsumeIngredients(userId, inventoryState, recipe.Ingredients)

	local outputItemId
	if applyQuality then
		local quality = self.LevelService:CalculateQualityRoll(worker.Level)
		outputItemId = (recipe.QualityUpgrades and recipe.QualityUpgrades[quality]) or recipe.OutputItemId
	else
		outputItemId = recipe.OutputItemId
	end
	Try(self.InventoryContext:AddItemToInventory(userId, outputItemId, recipe.OutputQuantity))

	local xpGained = self.LevelService:CalculateXPForProduction(1, assignment.Role)
	xpGained = self:_ApplyXPMultiplier(userId, xpGained)
	local levelResult = self:_BuildLevelResult(worker, xpGained)

	self:_ApplyXP(entity, worker, userId, levelResult)
	Try(self.PersistenceService:SaveWorkerEntity(player, entity))
	self:_SyncXPOrLevelUp(userId, worker.Id, levelResult)
end

--- @within ProcessWorkerProduction
--- @private
function ProcessWorkerProduction:_ProcessGenericProduction(
	player: Player,
	entity: any,
	worker: any,
	assignment: any,
	unitsProduced: number,
	currentTime: number
)
	local userId = player.UserId
	local xpGained = self.LevelService:CalculateXPForProduction(unitsProduced, assignment.Role)
	xpGained = self:_ApplyXPMultiplier(userId, xpGained)
	local levelResult = self:_BuildLevelResult(worker, xpGained)

	self:_ApplyXP(entity, worker, userId, levelResult)
	self.EntityFactory:UpdateLastProductionTick(entity, currentTime)
	Try(self.PersistenceService:SaveWorkerEntity(player, entity))

	self:_SyncXPOrLevelUp(userId, worker.Id, levelResult)
	self.SyncService:UpdateLastProductionTick(userId, worker.Id, currentTime)
end

--- @within ProcessWorkerProduction
--- @private
--- Compute level-up state from current worker XP + gained XP.
function ProcessWorkerProduction:_BuildLevelResult(worker: any, xpGained: number): TLevelResult
	local newXP = worker.Experience + xpGained
	local shouldLevelUp, newLevel, remainingXP = self.LevelService:CheckLevelUp(newXP, worker.Level)
	return {
		ShouldLevelUp = shouldLevelUp,
		NewLevel = newLevel,
		RemainingXP = remainingXP,
		NewXP = newXP,
	}
end

--- @within ProcessWorkerProduction
--- @private
function ProcessWorkerProduction:_ApplyXP(entity: any, worker: any, userId: number, levelResult: TLevelResult)
	if levelResult.ShouldLevelUp then
		self.EntityFactory:LevelUpWorker(entity, levelResult.NewLevel, levelResult.RemainingXP)
		GameEvents.Bus:Emit(Events.Worker.WorkerLeveledUp, userId, worker.Id, levelResult.NewLevel)
		self:_ApplyAutoRankPromotion(entity, worker, userId, levelResult.NewLevel)
	else
		self.EntityFactory:UpdateWorkerXP(entity, levelResult.NewXP)
	end
end

--- @within ProcessWorkerProduction
--- @private
--- Promotes worker rank automatically when level crosses a threshold.
function ProcessWorkerProduction:_ApplyAutoRankPromotion(entity: any, worker: any, userId: number, newLevel: number)
	local newRank = self.LevelService:GetRankForLevel(newLevel)
	if newRank ~= worker.Rank then
		self.EntityFactory:SetRank(entity, newRank)
		self.SyncService:UpdateWorkerRank(userId, worker.Id, newRank)
	end
end

--- @within ProcessWorkerProduction
--- @private
function ProcessWorkerProduction:_SyncXPOrLevelUp(userId: number, workerId: string, levelResult: TLevelResult)
	if levelResult.ShouldLevelUp then
		self.SyncService:LevelUpWorker(userId, workerId, levelResult.NewLevel)
		self.SyncService:UpdateWorkerXP(userId, workerId, levelResult.RemainingXP)
	else
		self.SyncService:UpdateWorkerXP(userId, workerId, levelResult.NewXP)
	end
end

--- @within ProcessWorkerProduction
--- @private
function ProcessWorkerProduction:_ConsumeIngredients(userId: number, inventoryState: any, ingredients: { any })
	for _, ingredient in ingredients do
		self:_ConsumeIngredient(userId, inventoryState, ingredient)
	end
end

--- @within ProcessWorkerProduction
--- @private
function ProcessWorkerProduction:_ConsumeIngredient(userId: number, inventoryState: any, ingredient: any)
	local remaining = ingredient.Quantity
	for slotIndex, slot in inventoryState.Slots do
		if slot.ItemId == ingredient.ItemId and remaining > 0 then
			local toRemove = math.min(slot.Quantity, remaining)
			Try(self.InventoryContext:RemoveItemFromInventory(userId, slotIndex, toRemove))
			remaining -= toRemove
			if remaining <= 0 then
				break
			end
		end
	end
end

return ProcessWorkerProduction

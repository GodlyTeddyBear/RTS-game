--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err, Try, Ensure = Result.Ok, Result.Err, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

local Errors = require(script.Parent.Parent.Parent.Errors)
local MachineEligibility = require(script.Parent.Parent.Parent.BuildingDomain.Services.MachineEligibility)

--[=[
	@class MachineQueueRecipe
	Consumes ingredients and enqueues machine recipes for processing.
	@server
]=]
local MachineQueueRecipe = {}
MachineQueueRecipe.__index = MachineQueueRecipe

--[=[
	Create a machine queue command instance.
	@within MachineQueueRecipe
	@return any -- New machine queue command instance.
]=]
function MachineQueueRecipe.new()
	return setmetatable({}, MachineQueueRecipe)
end

--[=[
	Initialize command dependencies from registry.
	@within MachineQueueRecipe
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function MachineQueueRecipe:Init(registry: any, _name: string)
	self._registry = registry
	self._store = registry:Get("MachineRuntimeStore")
	self._persistence = registry:Get("BuildingPersistenceService")
end

--[=[
	Resolve inventory context dependency after ordered startup.
	@within MachineQueueRecipe
]=]
function MachineQueueRecipe:Start()
	self._inventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Queue a machine recipe after validating machine type, queue capacity, and ingredients.
	@within MachineQueueRecipe
	@param player Player -- Player requesting recipe queue.
	@param zoneName string -- Zone containing the machine slot.
	@param slotIndex number -- One-based machine slot index.
	@param recipeId string -- Recipe identifier to enqueue.
	@return Result.Result<nil> -- Success when recipe is queued.
]=]
function MachineQueueRecipe:Execute(
	player: Player,
	zoneName: string,
	slotIndex: number,
	recipeId: string
): Result.Result<nil>
	Ensure(recipeId ~= "", "InvalidRecipe", "Recipe id required")

	local slotData = self._persistence:GetSlotData(player, zoneName, slotIndex)
	if not slotData then
		return Err("SlotEmpty", Errors.SLOT_EMPTY)
	end

	if not MachineEligibility.SlotIsFuelMachine(zoneName, slotData.BuildingType) then
		return Err("NotFuelMachine", Errors.NOT_FUEL_MACHINE)
	end

	local recipe = RecipeConfig[recipeId]
	if not recipe then
		return Err("RecipeNotFound", Errors.INVALID_MACHINE_RECIPE)
	end

	if not recipe.ProcessDurationSeconds or recipe.ProcessDurationSeconds <= 0 then
		return Err("NotMachineRecipe", Errors.INVALID_MACHINE_RECIPE)
	end

	if not MachineEligibility.SlotBuildingMatchesRecipe(slotData.BuildingType, recipe.RequiredMachines) then
		return Err("WrongMachine", Errors.INVALID_MACHINE_RECIPE)
	end

	local state = self._store:GetState(player, zoneName, slotIndex)
	if not state then
		return Err("NoProfile", Errors.NO_PROFILE_DATA)
	end

	if #state.queue >= self._store.MaxQueueSize() then
		return Err("QueueFull", Errors.MACHINE_QUEUE_FULL)
	end

	-- Spend ingredients from smallest matching stacks first to minimize fragmentation.
	local invState = Try(self._inventoryContext:GetPlayerInventory(player.UserId))

	for _, ingredient in ipairs(recipe.Ingredients) do
		local remaining = ingredient.Quantity
		local matchingSlots: { { SlotIndex: number, Quantity: number } } = {}
		for sIdx, slot in pairs(invState.Slots) do
			if slot and slot.ItemId == ingredient.ItemId then
				table.insert(matchingSlots, { SlotIndex = sIdx, Quantity = slot.Quantity })
			end
		end
		table.sort(matchingSlots, function(a, b)
			return a.Quantity < b.Quantity
		end)

		for _, info in matchingSlots do
			if remaining <= 0 then
				break
			end
			local take = math.min(remaining, info.Quantity)
			Try(self._inventoryContext:RemoveItemFromInventory(player.UserId, info.SlotIndex, take))
			remaining -= take
		end

		if remaining > 0 then
			return Err("InsufficientMaterials", Errors.INSUFFICIENT_MACHINE_INGREDIENTS)
		end
	end

	table.insert(state.queue, {
		recipeId = recipeId,
		progressSeconds = 0,
	})

	MentionSuccess("Building:MachineQueueRecipe", "Queued machine recipe", {
		userId = player.UserId,
		recipeId = recipeId,
		zoneName = zoneName,
		slotIndex = slotIndex,
	})

	return Ok(nil)
end

return MachineQueueRecipe

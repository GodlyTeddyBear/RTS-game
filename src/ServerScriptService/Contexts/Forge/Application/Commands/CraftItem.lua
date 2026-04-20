--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err, Try, Ensure = Result.Ok, Result.Err, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local ItemId = require(ReplicatedStorage.Contexts.Inventory.Types.ItemId)

local Events = GameEvents.Events

--[=[
	@class CraftItem
	Application command: execute a craft operation given recipe and inventory state. Removes ingredients, creates output item, and fires events.
	@server
]=]
local CraftItem = {}
CraftItem.__index = CraftItem

--[=[
	@function CraftItem.new
	@within CraftItem
	Create a new CraftItem command instance. Dependencies are resolved during Init/Start phases.
	@return CraftItem
]=]
function CraftItem.new()
	return setmetatable({}, CraftItem)
end

--[=[
	@method Init
	@within CraftItem
	Initialize the command: cache registry and resolve the CraftPolicy service.
	@param registry any -- Service registry for dependency resolution
	@param _name string -- Service name (unused)
]=]
function CraftItem:Init(registry: any, _name: string)
	self._registry = registry
	self.CraftPolicy = registry:Get("CraftPolicy")
end

--[=[
	@method Start
	@within CraftItem
	Start the command: resolve InventoryContext cross-context dependency after all services have initialized.
]=]
function CraftItem:Start()
	-- Cross-context dependency available after KnitStart registers it
	self.InventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	@method Execute
	@within CraftItem
	Execute a craft operation: validate recipe and materials, remove ingredients, add output, and fire events.
	@param player Player -- The player requesting the craft
	@param userId number -- The player's user ID
	@param recipeId string -- The recipe to craft
	@return Result<string> -- Ok with output item ID, or Err with failure reason
]=]
function CraftItem:Execute(player: Player, userId: number, recipeId: string): Result.Result<string>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Step 1: Validate recipe and materials via policy
	local ctx = Try(self.CraftPolicy:Check(userId, recipeId))
	local recipe         = ctx.Recipe
	local inventoryState = ctx.InventoryState

	-- Step 2: Remove ingredients from inventory (per ingredient)
	for _, ingredient in ipairs(recipe.Ingredients) do
		local remaining = ingredient.Quantity

		-- Collect all slots containing this ingredient
		local matchingSlots: { { SlotIndex: number, Quantity: number } } = {}
		for slotIndex, slot in pairs(inventoryState.Slots) do
			if slot and slot.ItemId == ingredient.ItemId then
				table.insert(matchingSlots, { SlotIndex = slotIndex, Quantity = slot.Quantity })
			end
		end

		-- Sort slots by quantity to consume smallest-stack slots first
		table.sort(matchingSlots, function(a, b)
			return a.Quantity < b.Quantity
		end)

		-- Consume from each slot until ingredient requirement is met
		for _, slotInfo in ipairs(matchingSlots) do
			if remaining <= 0 then
				break
			end
			local toRemove = math.min(remaining, slotInfo.Quantity)
			Try(self.InventoryContext:RemoveItemFromInventory(userId, slotInfo.SlotIndex, toRemove))
			remaining = remaining - toRemove
		end

		-- Guard against race condition where inventory changed after policy check
		if remaining > 0 then
			return Err("CraftFailed", Errors.CRAFT_FAILED, { itemId = ingredient.ItemId })
		end
	end

	-- Step 3: Add crafted output to inventory
	Try(self.InventoryContext:AddItemToInventory(userId, recipe.OutputItemId, recipe.OutputQuantity))

	-- Step 4: Fire context-specific events (charcoal for tutorial)
	GameEvents.Bus:Emit(Events.Crafting.CraftingCompleted, userId, recipeId, recipe.OutputItemId, recipe.OutputQuantity)

	if recipe.OutputItemId == ItemId.Charcoal then
		GameEvents.Bus:Emit(Events.Guide.CharcoalCrafted, userId)
	end

	-- Step 5: Log successful craft
	MentionSuccess("Forge:CraftItem:Execute", "Crafted output item from recipe ingredients", {
		userId = userId,
		recipeId = recipeId,
		outputItemId = recipe.OutputItemId,
		outputQuantity = recipe.OutputQuantity,
	})

	return Ok(recipe.OutputItemId)
end

return CraftItem

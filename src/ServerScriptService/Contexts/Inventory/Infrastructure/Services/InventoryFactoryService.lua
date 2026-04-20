--!strict

--[=[
    @class InventoryFactoryService
    ECS factory service for creating, querying, and mutating inventory and slot entities in the JECS world.
    @server
]=]
local InventoryFactoryService = {}
InventoryFactoryService.__index = InventoryFactoryService

--[=[
    @interface InventoryComponent
    @within InventoryFactoryService
    .OwnerId number -- The UserId of the inventory owner
    .TotalCapacity number -- Maximum number of slots in this inventory
    .UsedSlots number -- Current number of occupied slots
]=]
export type InventoryComponent = {
	OwnerId: number,
	TotalCapacity: number,
	UsedSlots: number,
}

--[=[
    @interface SlotComponent
    @within InventoryFactoryService
    .SlotIndex number -- 1-based slot position in the inventory
    .ItemId string -- The item stored in this slot
    .Quantity number -- How many of the item are in this slot
    .Category string -- The item's category
    .OwnerId number -- The UserId of the inventory owner
]=]
export type SlotComponent = {
	SlotIndex: number,
	ItemId: string,
	Quantity: number,
	Category: string,
	OwnerId: number,
}

--[=[
    @interface CapacityComponent
    @within InventoryFactoryService
    .[string] {Used: number, Max: number} -- Per-category usage keyed by category name
]=]
export type CapacityComponent = {
	[string]: { Used: number, Max: number },
}

--[=[
    Create a new InventoryFactoryService, registering inventory-related ECS components in the world.
    @within InventoryFactoryService
    @param world any -- The JECS world instance
    @return InventoryFactoryService
]=]
function InventoryFactoryService.new(world: any)
	local self = setmetatable({}, InventoryFactoryService)

	self.World = world

	-- Define components
	self.InventoryComponent = world:component()
	self.SlotComponent = world:component()
	self.CapacityComponent = world:component()
	self.DeletedTag = world:component()

	return self
end

--[=[
    Create an ECS inventory entity for the given player.
    @within InventoryFactoryService
    @param userId number -- The player's UserId
    @param totalCapacity number -- Maximum number of slots for this inventory
    @return any -- The created ECS entity
]=]
function InventoryFactoryService:CreateInventory(userId: number, totalCapacity: number): any
	local inventoryEntity = self.World:entity()

	self.World:set(inventoryEntity, self.InventoryComponent, {
		OwnerId = userId,
		TotalCapacity = totalCapacity,
		UsedSlots = 0,
	} :: any)

	return inventoryEntity
end

--[=[
    Create an ECS slot entity with the given slot data attached to an inventory owner.
    @within InventoryFactoryService
    @param ownerId number -- The UserId of the inventory owner
    @param slotData any -- Table with `SlotIndex`, `ItemId`, `Quantity`, and `Category` fields
    @return any -- The created ECS entity
]=]
function InventoryFactoryService:CreateSlot(ownerId: number, slotData: any): any
	local slotEntity = self.World:entity()

	self.World:set(slotEntity, self.SlotComponent, {
		SlotIndex = slotData.SlotIndex,
		ItemId = slotData.ItemId,
		Quantity = slotData.Quantity,
		Category = slotData.Category,
		OwnerId = ownerId,
	} :: any)

	return slotEntity
end

--[=[
    Return all non-deleted slot entities belonging to the given owner.
    @within InventoryFactoryService
    @param ownerId number -- The UserId to filter by
    @return {{Entity: any, Data: SlotComponent}} -- Array of entity/data pairs
]=]
function InventoryFactoryService:QuerySlots(ownerId: number): { any }
	local slots = {}

	for slotEntity in self.World:query(self.SlotComponent):without(self.DeletedTag) do
		local slotData = self.World:get(slotEntity, self.SlotComponent)
		if slotData and slotData.OwnerId == ownerId then
			table.insert(slots, {
				Entity = slotEntity,
				Data = slotData,
			})
		end
	end

	return slots
end

--[=[
    Return all non-deleted slot entities belonging to the given owner filtered by category.
    @within InventoryFactoryService
    @param ownerId number -- The UserId to filter by
    @param category string -- The category to filter by
    @return {{Entity: any, Data: SlotComponent}} -- Array of entity/data pairs
]=]
function InventoryFactoryService:QuerySlotsByCategory(ownerId: number, category: string): { any }
	local slots = {}

	for slotEntity in self.World:query(self.SlotComponent):without(self.DeletedTag) do
		local slotData = self.World:get(slotEntity, self.SlotComponent)
		if slotData and slotData.OwnerId == ownerId and slotData.Category == category then
			table.insert(slots, {
				Entity = slotEntity,
				Data = slotData,
			})
		end
	end

	return slots
end

--[=[
    Soft-delete a slot entity by tagging it with `DeletedTag`.
    @within InventoryFactoryService
    @param slotEntity any -- The ECS entity to delete
    @return boolean -- False if the entity does not exist in the world
]=]
function InventoryFactoryService:DeleteSlot(slotEntity: any): boolean
	if not self.World:contains(slotEntity) then
		return false
	end

	self.World:set(slotEntity, self.DeletedTag, true)
	return true
end

--[=[
    Apply key-value updates to an existing slot entity's component data.
    @within InventoryFactoryService
    @param slotEntity any -- The ECS entity to update
    @param updates any -- Table of fields to merge into the slot component
    @return boolean -- False if the entity or its slot component does not exist
]=]
function InventoryFactoryService:UpdateSlot(slotEntity: any, updates: any): boolean
	if not self.World:contains(slotEntity) then
		return false
	end

	local slotData = self.World:get(slotEntity, self.SlotComponent)
	if not slotData then
		return false
	end

	for key, value in pairs(updates) do
		slotData[key] = value
	end

	return true
end

--[=[
    Return the `InventoryComponent` data for the given inventory entity.
    @within InventoryFactoryService
    @param inventoryEntity any -- The ECS inventory entity
    @return InventoryComponent? -- The component data, or nil if not attached
]=]
function InventoryFactoryService:GetInventoryComponent(inventoryEntity: any): InventoryComponent?
	return self.World:get(inventoryEntity, self.InventoryComponent)
end

--[=[
    Apply key-value updates to an existing inventory entity's component data.
    @within InventoryFactoryService
    @param inventoryEntity any -- The ECS inventory entity to update
    @param updates any -- Table of fields to merge into the inventory component
    @return boolean -- False if the entity or its inventory component does not exist
]=]
function InventoryFactoryService:UpdateInventoryMetadata(inventoryEntity: any, updates: any): boolean
	if not self.World:contains(inventoryEntity) then
		return false
	end

	local inventoryData = self.World:get(inventoryEntity, self.InventoryComponent)
	if not inventoryData then
		return false
	end

	for key, value in pairs(updates) do
		inventoryData[key] = value
	end

	return true
end

return InventoryFactoryService

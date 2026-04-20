--!strict

local InventoryFactoryService = {}
InventoryFactoryService.__index = InventoryFactoryService

--- Component types for inventory management
export type InventoryComponent = {
	OwnerId: number,
	TotalCapacity: number,
	UsedSlots: number,
}

export type SlotComponent = {
	SlotIndex: number,
	ItemId: string,
	Quantity: number,
	Category: string,
	OwnerId: number,
}

export type CapacityComponent = {
	[string]: { Used: number, Max: number },
}

--- Creates a new InventoryFactoryService
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

--- Creates an inventory entity for a player
function InventoryFactoryService:CreateInventory(userId: number, totalCapacity: number): any
	local inventoryEntity = self.World:entity()

	self.World:set(inventoryEntity, self.InventoryComponent, {
		OwnerId = userId,
		TotalCapacity = totalCapacity,
		UsedSlots = 0,
	} :: any)

	return inventoryEntity
end

--- Creates a slot entity within an inventory
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

--- Queries all slots for an inventory owner
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

--- Queries slots by category for an owner
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

--- Removes a slot entity (soft delete)
function InventoryFactoryService:DeleteSlot(slotEntity: any): boolean
	if not self.World:contains(slotEntity) then
		return false
	end

	self.World:set(slotEntity, self.DeletedTag, true)
	return true
end

--- Updates slot data
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

--- Gets inventory component
function InventoryFactoryService:GetInventoryComponent(inventoryEntity: any): InventoryComponent?
	return self.World:get(inventoryEntity, self.InventoryComponent)
end

--- Updates inventory metadata
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

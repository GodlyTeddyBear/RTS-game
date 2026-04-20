--!strict

local InventoryPersistenceService = {}
InventoryPersistenceService.__index = InventoryPersistenceService

--- Creates a new InventoryPersistenceService
-- Constructor Injection: Receives DataManager as dependency
function InventoryPersistenceService.new(dataManager: any)
	local self = setmetatable({}, InventoryPersistenceService)

	self.DataManager = dataManager

	return self
end

--- Saves inventory state to ProfileStore via DataManager
function InventoryPersistenceService:SaveInventory(player: Player, inventoryState: any): boolean
	if not player or not inventoryState then
		return false
	end

	local success = self.DataManager:SaveInventory(player, inventoryState)
	return success
end

--- Loads inventory from ProfileStore via DataManager
function InventoryPersistenceService:LoadInventory(player: Player): any?
	if not player then
		return nil
	end

	local inventoryData = self.DataManager:GetInventory(player)
	return inventoryData
end

--- Clears inventory in ProfileStore (admin/testing)
function InventoryPersistenceService:ClearInventory(player: Player): boolean
	if not player then
		return false
	end

	local success = self.DataManager:ClearInventory(player)
	return success
end

return InventoryPersistenceService

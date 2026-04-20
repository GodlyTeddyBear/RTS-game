--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try
local Ensure = Result.Ensure

export type TUseExpeditionConsumableResult = {
	ItemId: string,
	TargetNPCId: string,
	HealAmount: number,
	NewHP: number,
	MaxHP: number,
}

local UseExpeditionConsumable = {}
UseExpeditionConsumable.__index = UseExpeditionConsumable

export type TUseExpeditionConsumable = typeof(setmetatable({}, UseExpeditionConsumable))

function UseExpeditionConsumable.new(): TUseExpeditionConsumable
	return setmetatable({}, UseExpeditionConsumable)
end

function UseExpeditionConsumable:Init(registry: any, _name: string)
	self.Registry = registry
	self.QuestSyncService = registry:Get("QuestSyncService")
end

function UseExpeditionConsumable:Start()
	self.InventoryContext = self.Registry:Get("InventoryContext")
	self.CombatContext = self.Registry:Get("CombatContext")
end

function UseExpeditionConsumable:Execute(
	userId: number,
	slotIndex: number,
	targetNpcId: string
): Result.Result<TUseExpeditionConsumableResult>
	Ensure(userId > 0, "InvalidUserId", Errors.PLAYER_NOT_FOUND, { userId = userId })
	Ensure(type(slotIndex) == "number", "InvalidSlot", "Inventory slot is invalid", { slotIndex = slotIndex })
	Ensure(type(targetNpcId) == "string" and targetNpcId ~= "", "InvalidTarget", "Target adventurer is invalid")

	local expedition = self.QuestSyncService:GetActiveExpeditionReadOnly(userId)
	if not expedition then
		return Err("NoActiveExpedition", Errors.NO_ACTIVE_EXPEDITION, { userId = userId })
	end
	if expedition.Status ~= "InCombat" then
		return Err("ExpeditionNotInCombat", Errors.EXPEDITION_NOT_IN_COMBAT, {
			userId = userId,
			status = expedition.Status,
		})
	end
	if not self:_IsTargetInParty(expedition.Party, targetNpcId) then
		return Err("TargetNotInExpedition", "Target adventurer is not in the active expedition", {
			userId = userId,
			targetNpcId = targetNpcId,
		})
	end

	local inventoryState = Try(self.InventoryContext:GetPlayerInventory(userId))
	local slot = inventoryState.Slots[slotIndex]
	if not slot then
		return Err("SlotEmpty", "Inventory slot is empty", {
			userId = userId,
			slotIndex = slotIndex,
		})
	end

	local itemData = ItemConfig[slot.ItemId]
	if not itemData then
		return Err("ItemNotFound", "Consumable item data was not found", {
			userId = userId,
			slotIndex = slotIndex,
			itemId = slot.ItemId,
		})
	end
	if itemData.category ~= "Consumable" or slot.Category ~= "Consumable" then
		return Err("ItemNotConsumable", "Item is not a consumable", {
			userId = userId,
			slotIndex = slotIndex,
			itemId = slot.ItemId,
		})
	end

	local healAmount = itemData.stats and itemData.stats.HP or nil
	if not healAmount or healAmount <= 0 then
		return Err("ConsumableNotSupported", "Only healing consumables can be used in expedition combat", {
			userId = userId,
			slotIndex = slotIndex,
			itemId = slot.ItemId,
		})
	end

	Try(self.CombatContext:ValidateAdventurerTarget(userId, targetNpcId))
	Try(self.InventoryContext:RemoveItemFromInventory(userId, slotIndex, 1))
	local healResult = Try(self.CombatContext:HealAdventurer(userId, targetNpcId, healAmount))

	return Ok({
		ItemId = slot.ItemId,
		TargetNPCId = targetNpcId,
		HealAmount = healAmount,
		NewHP = healResult.NewHP,
		MaxHP = healResult.MaxHP,
	})
end

function UseExpeditionConsumable:_IsTargetInParty(party: { any }, targetNpcId: string): boolean
	for _, member in ipairs(party) do
		if member.AdventurerId == targetNpcId then
			return true
		end
	end
	return false
end

return UseExpeditionConsumable

--!strict

--[[
	NPCEquipmentService - Attaches and detaches guild equipment on adventurer NPC rigs.

	Responsibilities:
	- Clone weapon/armor/accessory models from category registries
	- Attach weapon models via Motor6D to "Right Arm" (R6)
	- Attach armor/accessory via Humanoid:AddAccessory
	- Track attached instances per slot for deterministic re-equip cleanup

	Pattern: Infrastructure layer service with dependency injection
]]

local NPCEquipmentService = {}
NPCEquipmentService.__index = NPCEquipmentService

export type TEquipmentSlotData = {
	ItemId: string?,
	SlotType: string?,
}

export type TAdventurerEquipment = {
	Weapon: TEquipmentSlotData?,
	Armor: TEquipmentSlotData?,
	Accessory: TEquipmentSlotData?,
}

export type TNPCEquipmentService = typeof(setmetatable({} :: {
	ToolRegistry: any,
	ArmorRegistry: any,
	AccessoryRegistry: any,
}, NPCEquipmentService))

local SLOT_ATTR = "GuildEquipmentSlot"
local EQUIPPED_ITEM_ATTR = "GuildEquipmentItemId"
local DEFAULT_ASSET_ID = "Default"
local CLOTHING_ACCESSORY_NAMES = {
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
	Torso = true,
}

function NPCEquipmentService.new(toolRegistry: any, armorRegistry: any, accessoryRegistry: any): TNPCEquipmentService
	assert(toolRegistry, "NPCEquipmentService requires a ToolRegistry")
	assert(armorRegistry, "NPCEquipmentService requires an ArmorRegistry")
	assert(accessoryRegistry, "NPCEquipmentService requires an AccessoryRegistry")

	local self = setmetatable({}, NPCEquipmentService)
	self.ToolRegistry = toolRegistry
	self.ArmorRegistry = armorRegistry
	self.AccessoryRegistry = accessoryRegistry
	return self
end

function NPCEquipmentService:EquipAdventurer(model: Model, equipment: TAdventurerEquipment?)
	self:UnequipAll(model)
	if not equipment then
		return
	end

	self:_EquipWeapon(model, equipment.Weapon)
	self:_EquipArmorSlot(model, equipment.Armor)
	self:_EquipAccessorySlot(model, equipment.Accessory)
end

function NPCEquipmentService:UnequipAll(model: Model)
	self:_UnequipSlot(model, "Weapon")
	self:_UnequipSlot(model, "Armor")
	self:_UnequipSlot(model, "Accessory")
end

function NPCEquipmentService:_EquipWeapon(model: Model, slotData: TEquipmentSlotData?)
	local itemId = slotData and slotData.ItemId
	if not itemId then
		return
	end

	local toolClone: Model? = self.ToolRegistry:GetToolModel(itemId)
	if not toolClone then
		return
	end
	if self:_AttachWeaponClone(model, toolClone, itemId) then
		return
	end

	if itemId == DEFAULT_ASSET_ID then
		return
	end

	local fallbackClone: Model? = self.ToolRegistry:GetToolModel(DEFAULT_ASSET_ID)
	if fallbackClone then
		self:_AttachWeaponClone(model, fallbackClone, DEFAULT_ASSET_ID)
	end
end

function NPCEquipmentService:_AttachWeaponClone(model: Model, toolClone: Model, itemId: string): boolean
	local rightArm = model:FindFirstChild("Right Arm", true)
	if not rightArm or not rightArm:IsA("BasePart") then
		toolClone:Destroy()
		return false
	end

	local handle = (toolClone :: any).PrimaryPart or toolClone:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		toolClone:Destroy()
		return false
	end

	local motorsFolder = toolClone:FindFirstChild("Motors")
	if not motorsFolder then
		toolClone:Destroy()
		return false
	end

	local motor = motorsFolder:FindFirstChildWhichIsA("Motor6D")
	if not motor then
		toolClone:Destroy()
		return false
	end

	motor.Part0 = rightArm
	motor.Part1 = handle
	motor:SetAttribute(SLOT_ATTR, "Weapon")
	motor.Parent = rightArm

	toolClone:SetAttribute(SLOT_ATTR, "Weapon")
	toolClone:SetAttribute(EQUIPPED_ITEM_ATTR, itemId)
	toolClone.Parent = model
	return true
end

function NPCEquipmentService:_EquipArmorSlot(model: Model, slotData: TEquipmentSlotData?)
	local itemId = slotData and slotData.ItemId
	if not itemId then
		return
	end

	local armorClone: Model? = self.ArmorRegistry:GetArmorModel(itemId)
	if not armorClone then
		return
	end
	if self:_AttachAccessoryClone(model, armorClone, itemId, "Armor", true) then
		return
	end

	if itemId == DEFAULT_ASSET_ID then
		return
	end

	local fallbackClone: Model? = self.ArmorRegistry:GetArmorModel(DEFAULT_ASSET_ID)
	if fallbackClone then
		self:_AttachAccessoryClone(model, fallbackClone, DEFAULT_ASSET_ID, "Armor", true)
	end
end

function NPCEquipmentService:_EquipAccessorySlot(model: Model, slotData: TEquipmentSlotData?)
	local itemId = slotData and slotData.ItemId
	if not itemId then
		return
	end

	local accessoryClone: Model? = self.AccessoryRegistry:GetAccessoryModel(itemId)
	if not accessoryClone then
		return
	end
	if self:_AttachAccessoryClone(model, accessoryClone, itemId, "Accessory") then
		return
	end

	if itemId == DEFAULT_ASSET_ID then
		return
	end

	local fallbackClone: Model? = self.AccessoryRegistry:GetAccessoryModel(DEFAULT_ASSET_ID)
	if fallbackClone then
		self:_AttachAccessoryClone(model, fallbackClone, DEFAULT_ASSET_ID, "Accessory")
	end
end

function NPCEquipmentService:_AttachAccessoryClone(
	model: Model,
	toolClone: Model,
	itemId: string,
	slotName: "Armor" | "Accessory",
	removeMatchingClothing: boolean?
): boolean
	local accessory = self:_ExtractAccessory(toolClone)
	if not accessory then
		toolClone:Destroy()
		return false
	end

	if removeMatchingClothing == true then
		self:_RemoveMatchingClothingAccessory(model, accessory.Name)
	end

	accessory:SetAttribute(SLOT_ATTR, slotName)
	accessory:SetAttribute(EQUIPPED_ITEM_ATTR, itemId)

	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid:AddAccessory(accessory)
	else
		accessory.Parent = model
	end

	toolClone:Destroy()
	return true
end

function NPCEquipmentService:_RemoveMatchingClothingAccessory(model: Model, targetName: string)
	if not CLOTHING_ACCESSORY_NAMES[targetName] then
		return
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Accessory")
			and descendant.Name == targetName
			and CLOTHING_ACCESSORY_NAMES[descendant.Name] then
			descendant:Destroy()
		end
	end
end

function NPCEquipmentService:_ExtractAccessory(toolClone: Model): Accessory?
	local directAccessory = toolClone:FindFirstChildWhichIsA("Accessory")
	if directAccessory then
		return directAccessory:Clone()
	end

	for _, descendant in toolClone:GetDescendants() do
		if descendant:IsA("Accessory") then
			return descendant:Clone()
		end
	end

	return nil
end

function NPCEquipmentService:_UnequipSlot(model: Model, slotName: string)
	for _, descendant in model:GetDescendants() do
		if descendant:GetAttribute(SLOT_ATTR) == slotName then
			if descendant:IsA("Motor6D") then
				descendant:Destroy()
			elseif descendant:IsA("Accessory") then
				descendant:Destroy()
			elseif descendant:IsA("Model") then
				descendant:Destroy()
			end
		end
	end
end

return NPCEquipmentService

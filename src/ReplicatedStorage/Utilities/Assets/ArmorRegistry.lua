--!strict

--[[
	ArmorRegistry - Load Armor Models by ID

	Provides a registry for cloning armor models from the Assets/Items/Armor folder.

	Folder Structure:
		Armor/
		├── Default/
		└── [ArmorItemId]/
]]

local ArmorRegistry = {}
ArmorRegistry.__index = ArmorRegistry

function ArmorRegistry.new(armorFolder: Folder)
	assert(armorFolder, "ArmorRegistry requires a valid Armor folder")
	assert(armorFolder:IsA("Folder"), "ArmorRegistry requires a Folder instance")

	local self = setmetatable({}, ArmorRegistry)
	self._armorFolder = armorFolder
	return self
end

function ArmorRegistry:GetArmorModel(itemId: string): Model?
	local armorEntry = self._armorFolder:FindFirstChild(itemId)
	local usedFallback = false
	if not armorEntry then
		armorEntry = self._armorFolder:FindFirstChild("Default")
		if not armorEntry then
			warn("[ArmorRegistry] Armor not found and no Default fallback:", itemId)
			return nil
		end
		usedFallback = true
	end

	local model = self:_ExtractModel(armorEntry)
	if not model then
		if not usedFallback then
			local defaultEntry = self._armorFolder:FindFirstChild("Default")
			if defaultEntry then
				model = self:_ExtractModel(defaultEntry)
				if model then
					return model:Clone()
				end
			end
		end
		warn("[ArmorRegistry] No Model found in Armor folder:", armorEntry.Name)
		return nil
	end

	return model:Clone()
end

function ArmorRegistry:ArmorModelExists(itemId: string): boolean
	local armorEntry = self._armorFolder:FindFirstChild(itemId)
	if not armorEntry then
		armorEntry = self._armorFolder:FindFirstChild("Default")
		if not armorEntry then
			return false
		end
		return self:_ExtractModel(armorEntry) ~= nil
	end

	if self:_ExtractModel(armorEntry) ~= nil then
		return true
	end

	local defaultEntry = self._armorFolder:FindFirstChild("Default")
	return defaultEntry ~= nil and self:_ExtractModel(defaultEntry) ~= nil
end

function ArmorRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

return ArmorRegistry

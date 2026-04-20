--!strict

--[[
	AccessoryRegistry - Load Accessory Models by ID

	Provides a registry for cloning accessory models from the Assets/Items/Accessories folder.

	Folder Structure:
		Accessories/
		├── Default/
		└── [AccessoryItemId]/
]]

local AccessoryRegistry = {}
AccessoryRegistry.__index = AccessoryRegistry

function AccessoryRegistry.new(accessoriesFolder: Folder)
	assert(accessoriesFolder, "AccessoryRegistry requires a valid Accessories folder")
	assert(accessoriesFolder:IsA("Folder"), "AccessoryRegistry requires a Folder instance")

	local self = setmetatable({}, AccessoryRegistry)
	self._accessoriesFolder = accessoriesFolder
	return self
end

function AccessoryRegistry:GetAccessoryModel(itemId: string): Model?
	local accessoryEntry = self._accessoriesFolder:FindFirstChild(itemId)
	local usedFallback = false
	if not accessoryEntry then
		accessoryEntry = self._accessoriesFolder:FindFirstChild("Default")
		if not accessoryEntry then
			warn("[AccessoryRegistry] Accessory not found and no Default fallback:", itemId)
			return nil
		end
		usedFallback = true
	end

	local model = self:_ExtractModel(accessoryEntry)
	if not model then
		if not usedFallback then
			local defaultEntry = self._accessoriesFolder:FindFirstChild("Default")
			if defaultEntry then
				model = self:_ExtractModel(defaultEntry)
				if model then
					return model:Clone()
				end
			end
		end
		warn("[AccessoryRegistry] No Model found in Accessories folder:", accessoryEntry.Name)
		return nil
	end

	return model:Clone()
end

function AccessoryRegistry:AccessoryModelExists(itemId: string): boolean
	local accessoryEntry = self._accessoriesFolder:FindFirstChild(itemId)
	if not accessoryEntry then
		accessoryEntry = self._accessoriesFolder:FindFirstChild("Default")
		if not accessoryEntry then
			return false
		end
		return self:_ExtractModel(accessoryEntry) ~= nil
	end

	if self:_ExtractModel(accessoryEntry) ~= nil then
		return true
	end

	local defaultEntry = self._accessoriesFolder:FindFirstChild("Default")
	return defaultEntry ~= nil and self:_ExtractModel(defaultEntry) ~= nil
end

function AccessoryRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

return AccessoryRegistry

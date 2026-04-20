--!strict

--[[
	LotRegistry - Load Lot Models with Default Fallback

	Provides a registry for loading lot models with automatic fallback
	to Default models when type-specific models are missing.

	Folder Structure:
		Lots/
		├── Default/
		│   └── Model
		├── Basic/
		│   └── Model
		└── [OtherTypes]/
		    └── Model

	Usage:
		local lotRegistry = LotRegistry.new(Assets.Lots)
		local basicModel = lotRegistry:GetLotModel("Basic")
		local exists = lotRegistry:LotModelExists("Basic")
]]

local LotRegistry = {}
LotRegistry.__index = LotRegistry

--[=[
	Creates a new LotRegistry.

	@param lotsFolder Folder - The root Lots folder
	@return LotRegistry - New registry instance
]=]
function LotRegistry.new(lotsFolder: Folder)
	assert(lotsFolder, "LotRegistry requires a valid Lots folder")
	assert(lotsFolder:IsA("Folder"), "LotRegistry requires a Folder instance")

	local self = setmetatable({}, LotRegistry)
	self._lotsFolder = lotsFolder

	return self
end

--[=[
	Gets a lot model with type-specific fallback to Default.

	Lookup order:
	1. Try Lots/{lotType}
	2. If missing, try Lots/Default
	3. If still missing, throw error

	@param lotType string - The lot type (e.g., "Basic", "Premium")
	@return Model - Cloned model

	Example:
		local basicModel = registry:GetLotModel("Basic")
		local defaultModel = registry:GetLotModel("Default")
]=]
function LotRegistry:GetLotModel(lotType: string): Model
	assert(self._lotsFolder, "Lots folder not found")

	-- Try type-specific model
	local modelFolder = self._lotsFolder:FindFirstChild(lotType)

	-- Fallback to Default
	if not modelFolder then
		modelFolder = self._lotsFolder:FindFirstChild("Default")
	end

	assert(modelFolder, "Lot model not found: " .. lotType)

	-- Extract and clone model
	local model = self:_ExtractModel(modelFolder)
	assert(model, "No Model found in folder: " .. modelFolder.Name)

	local clone = model:Clone()

	return clone
end

--[=[
	Checks if a lot model exists with type-specific fallback.

	@param lotType string - The lot type
	@return boolean - True if model exists (including Default fallback)

	Example:
		if registry:LotModelExists("Basic") then
			local model = registry:GetLotModel("Basic")
		end
]=]
function LotRegistry:LotModelExists(lotType: string): boolean
	if not self._lotsFolder then
		return false
	end

	local modelFolder = self._lotsFolder:FindFirstChild(lotType)
	if not modelFolder then
		modelFolder = self._lotsFolder:FindFirstChild("Default")
	end

	return modelFolder ~= nil
end

--[=[
	Extracts a Model from a Folder or returns the Model directly.

	Handles two cases:
	- Direct Model instance (e.g., Lots/Basic is a Model)
	- Folder containing Model (e.g., Lots/Default/TemplateModel)

	@private
	@param instance Instance - The folder or model instance
	@return Model? - The model if found, nil otherwise
]=]
function LotRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		-- Look for Model inside Folder
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

return LotRegistry

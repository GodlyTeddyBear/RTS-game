--!strict

--[[
	WorkerRegistry - Load Worker Models with Default Fallback

	Provides a registry for loading worker models with automatic fallback
	to Default models when type-specific models are missing.

	Folder Structure:
		Workers/
		├── Default/
		│   └── Model
		├── Miner/
		│   └── Model
		├── Lumberjack/
		│   └── Model
		└── [OtherOccupations]/
		    └── Model

	Models are keyed by occupation/role (e.g. "Miner", "Lumberjack"), not by rank.
	Falls back to Default when no occupation-specific model exists.

	Usage:
		local workerRegistry = WorkerRegistry.new(Assets.Entities.Workers)
		local minerModel = workerRegistry:GetWorkerModel("Miner")
		local exists = workerRegistry:WorkerModelExists("Miner")
]]

local WorkerRegistry = {}
WorkerRegistry.__index = WorkerRegistry

--[=[
	Creates a new WorkerRegistry.

	@param workersFolder Folder - The root Workers folder
	@return WorkerRegistry - New registry instance
]=]
function WorkerRegistry.new(workersFolder: Folder)
	assert(workersFolder, "WorkerRegistry requires a valid Workers folder")
	assert(workersFolder:IsA("Folder"), "WorkerRegistry requires a Folder instance")

	local self = setmetatable({}, WorkerRegistry)
	self._workersFolder = workersFolder

	return self
end

--[=[
	Gets a worker model with type-specific fallback to Default.

	Lookup order:
	1. Try Workers/{workerType}
	2. If missing, try Workers/Default
	3. If still missing, throw error

	@param workerType string - The worker type (e.g., "Basic", "Advanced")
	@return Model - Cloned model

	Example:
		local basicModel = registry:GetWorkerModel("Basic")
		local defaultModel = registry:GetWorkerModel("Default")
]=]
function WorkerRegistry:GetWorkerModel(workerType: string): Model
	assert(self._workersFolder, "Workers folder not found")

	-- Try type-specific model
	local modelFolder = self._workersFolder:FindFirstChild(workerType)

	-- Fallback to Default
	if not modelFolder then
		modelFolder = self._workersFolder:FindFirstChild("Default")
	end

	assert(modelFolder, "Worker model not found: " .. workerType)

	-- Extract and clone model
	local model = self:_ExtractModel(modelFolder)
	assert(model, "No Model found in folder: " .. modelFolder.Name)

	local clone = model:Clone()

	return clone
end

--[=[
	Checks if a worker model exists with type-specific fallback.

	@param workerType string - The worker type
	@return boolean - True if model exists (including Default fallback)

	Example:
		if registry:WorkerModelExists("Basic") then
			local model = registry:GetWorkerModel("Basic")
		end
]=]
function WorkerRegistry:WorkerModelExists(workerType: string): boolean
	if not self._workersFolder then
		return false
	end

	local modelFolder = self._workersFolder:FindFirstChild(workerType)
	if not modelFolder then
		modelFolder = self._workersFolder:FindFirstChild("Default")
	end

	return modelFolder ~= nil
end

--[=[
	Extracts a Model from a Folder or returns the Model directly.

	Handles two cases:
	- Direct Model instance (e.g., Workers/Basic is a Model)
	- Folder containing Model (e.g., Workers/Default/TemplateModel)

	@private
	@param instance Instance - The folder or model instance
	@return Model? - The model if found, nil otherwise
]=]
function WorkerRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		-- Look for Model inside Folder
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

return WorkerRegistry

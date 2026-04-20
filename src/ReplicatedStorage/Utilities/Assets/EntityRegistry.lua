--!strict

--[[
	EntityRegistry - Load Player/Enemy Models with Default Fallback

	Provides a registry for loading entity models (player characters and enemies)
	with automatic fallback to Default models when class-specific models are missing.

	Folder Structure:
		Entities/
		├── Players/
		│   ├── Default/
		│   │   └── Model (or Folder with Model inside)
		│   ├── Warrior/
		│   ├── Mage/
		│   ├── Rogue/
		│   └── Cleric/
		└── Enemies/
		    ├── Default/
		    ├── Goblin/
		    ├── Orc/
		    └── Troll/

	Usage:
		local entityRegistry = EntityRegistry.new(Assets.Entities)
		local warriorModel = entityRegistry:GetPlayerModel("Warrior")
		local goblinModel = entityRegistry:GetEnemyModel("Goblin")

	Matches the existing CharacterModelService behavior for backward compatibility.
]]

local EntityRegistry = {}
EntityRegistry.__index = EntityRegistry

--[=[
	Creates a new EntityRegistry.

	@param entitiesFolder Folder - The root Entities folder
	@return EntityRegistry - New registry instance
]=]
function EntityRegistry.new(entitiesFolder: Folder)
	assert(entitiesFolder, "EntityRegistry requires a valid Entities folder")
	assert(entitiesFolder:IsA("Folder"), "EntityRegistry requires a Folder instance")

	local self = setmetatable({}, EntityRegistry)
	self._playersFolder = entitiesFolder:FindFirstChild("Players")
	self._enemiesFolder = entitiesFolder:FindFirstChild("Enemies")

	return self
end

--[=[
	Gets a player model with class-specific fallback to Default.

	Lookup order:
	1. Try Players/{class}
	2. If missing, try Players/Default
	3. If still missing, throw error

	@param class string - The character class (e.g., "Warrior", "Mage")
	@return Model - Cloned model with validated HumanoidRootPart

	Example:
		local warriorModel = registry:GetPlayerModel("Warrior")
		local defaultModel = registry:GetPlayerModel("Default")
]=]
function EntityRegistry:GetPlayerModel(class: string): Model
	assert(self._playersFolder, "Players folder not found in Entities")

	-- Try class-specific model
	local modelFolder = self._playersFolder:FindFirstChild(class)

	-- Fallback to Default
	if not modelFolder then
		modelFolder = self._playersFolder:FindFirstChild("Default")
	end

	assert(modelFolder, "Player model not found: " .. class)

	-- Extract and clone model
	local model = self:_ExtractModel(modelFolder)
	assert(model, "No Model found in folder: " .. modelFolder.Name)

	local clone = model:Clone()
	self:_ValidateModel(clone)

	return clone
end

--[=[
	Gets an enemy model with enemy-specific fallback to Default.

	Lookup order:
	1. Try Enemies/{enemyName}
	2. If missing, try Enemies/Default
	3. If still missing, throw error

	@param enemyName string - The enemy name (e.g., "Goblin", "Orc")
	@return Model - Cloned model with validated HumanoidRootPart

	Example:
		local goblinModel = registry:GetEnemyModel("Goblin")
		local defaultEnemy = registry:GetEnemyModel("Default")
]=]
function EntityRegistry:GetEnemyModel(enemyName: string): Model
	assert(self._enemiesFolder, "Enemies folder not found in Entities")

	-- Try enemy-specific model
	local modelFolder = self._enemiesFolder:FindFirstChild(enemyName)

	-- Fallback to Default
	if not modelFolder then
		modelFolder = self._enemiesFolder:FindFirstChild("Default")
	end

	assert(modelFolder, "Enemy model not found: " .. enemyName)

	-- Extract and clone model
	local model = self:_ExtractModel(modelFolder)
	assert(model, "No Model found in folder: " .. modelFolder.Name)

	local clone = model:Clone()
	self:_ValidateModel(clone)

	return clone
end

--[=[
	Checks if a player model exists with class-specific fallback.

	@param class string - The character class
	@return boolean - True if model exists (including Default fallback)

	Example:
		if registry:PlayerModelExists("Warrior") then
			local model = registry:GetPlayerModel("Warrior")
		end
]=]
function EntityRegistry:PlayerModelExists(class: string): boolean
	if not self._playersFolder then
		return false
	end

	local modelFolder = self._playersFolder:FindFirstChild(class)
	if not modelFolder then
		modelFolder = self._playersFolder:FindFirstChild("Default")
	end

	return modelFolder ~= nil
end

--[=[
	Checks if an enemy model exists with enemy-specific fallback.

	@param enemyName string - The enemy name
	@return boolean - True if model exists (including Default fallback)

	Example:
		if registry:EnemyModelExists("Goblin") then
			local model = registry:GetEnemyModel("Goblin")
		end
]=]
function EntityRegistry:EnemyModelExists(enemyName: string): boolean
	if not self._enemiesFolder then
		return false
	end

	local modelFolder = self._enemiesFolder:FindFirstChild(enemyName)
	if not modelFolder then
		modelFolder = self._enemiesFolder:FindFirstChild("Default")
	end

	return modelFolder ~= nil
end

--[=[
	Extracts a Model from a Folder or returns the Model directly.

	Handles two cases:
	- Direct Model instance (e.g., Players/Warrior is a Model)
	- Folder containing Model (e.g., Players/Default/TemplateR6)

	@private
	@param instance Instance - The folder or model instance
	@return Model? - The model if found, nil otherwise
]=]
function EntityRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		-- Look for Model inside Folder
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

--[=[
	Validates that a model has a HumanoidRootPart.

	@private
	@param model Model - The model to validate
	@throws Error if HumanoidRootPart is missing
]=]
function EntityRegistry:_ValidateModel(model: Model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	assert(hrp, "Model missing HumanoidRootPart: " .. model.Name)
end

return EntityRegistry

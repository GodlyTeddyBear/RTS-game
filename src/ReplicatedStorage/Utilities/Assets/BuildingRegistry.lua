--!strict

--[[
	BuildingRegistry - Load Building and Companion Models by Zone

	Provides a registry for loading building and companion models organized
	by zone subfolder under Assets/Buildings/. Falls back to Default/Default
	if the zone-specific model is missing.

	Folder Structure:
		Buildings/
		├── Default/
		│   └── Default        (placeholder model)
		├── Forge/
		│   ├── Anvil
		│   └── Bellows
		├── Farm/
		│   ├── WheatField
		│   ├── Wheat          (companion)
		│   └── CornField
		└── ...

	Usage:
		local buildingRegistry = BuildingRegistry.new(Assets.Buildings)
		local model = buildingRegistry:GetBuildingModel("Forge", "Anvil")
		local companion = buildingRegistry:GetCompanionModel("Farm", "Wheat")
]]

local BuildingRegistry = {}
BuildingRegistry.__index = BuildingRegistry

--[=[
	Creates a new BuildingRegistry.

	@param buildingsFolder Folder - The root Buildings folder
	@return BuildingRegistry - New registry instance
]=]
function BuildingRegistry.new(buildingsFolder: Folder)
	assert(buildingsFolder, "BuildingRegistry requires a valid Buildings folder")
	assert(buildingsFolder:IsA("Folder"), "BuildingRegistry requires a Folder instance")

	local self = setmetatable({}, BuildingRegistry)
	self._folder = buildingsFolder

	return self
end

function BuildingRegistry:_GetTemplate(zoneName: string, modelName: string): Model?
	local zoneFolder = self._folder:FindFirstChild(zoneName)
	if not zoneFolder then
		warn("[BuildingRegistry] Missing zone folder '" .. zoneName .. "' under Assets/Buildings; trying Default fallback")
	end

	local template = zoneFolder and zoneFolder:FindFirstChild(modelName)
	if not template and zoneFolder then
		warn("[BuildingRegistry] Missing template '" .. modelName .. "' in zone folder '" .. zoneName .. "'; trying Default fallback")
	end

	-- Fall back to Default/Default placeholder if zone-specific model is missing
	if not template then
		local defaultFolder = self._folder:FindFirstChild("Default")
		if not defaultFolder then
			warn("[BuildingRegistry] Missing required fallback folder 'Default' under Assets/Buildings")
		end
		template = defaultFolder and defaultFolder:FindFirstChild("Default")
	end

	if not template then
		warn("[BuildingRegistry] Missing fallback template 'Default/Default' under Assets/Buildings")
		return nil
	end

	if not template:IsA("Model") then
		warn(
			"[BuildingRegistry] Template '"
				.. template.Name
				.. "' for zone='"
				.. zoneName
				.. "', model='"
				.. modelName
				.. "' is a "
				.. template.ClassName
				.. ", expected Model (wrap asset in a Model in Studio)"
		)
		return nil
	end

	return template :: Model
end

--[=[
	Clones a building model from the zone subfolder, falling back to Default/Default.

	@param zoneName string - The zone name (e.g., "Forge", "Farm")
	@param buildingType string - The building type (e.g., "Anvil", "WheatField")
	@return Model? - Cloned model, or nil if neither zone nor Default exists
]=]
function BuildingRegistry:GetBuildingModel(zoneName: string, buildingType: string): Model?
	local template = self:_GetTemplate(zoneName, buildingType)
	if not template then
		warn(
			"[BuildingRegistry] Failed to resolve building template for zone='"
				.. zoneName
				.. "', buildingType='"
				.. buildingType
				.. "'"
		)
		return nil
	end
	return template:Clone()
end

--[=[
	Clones a companion model from the zone subfolder, falling back to Default/Default.

	@param zoneName string - The zone name (e.g., "Farm", "Garden")
	@param companionModel string - The companion model name (e.g., "Wheat", "HerbPlant")
	@return Model? - Cloned model, or nil if neither zone nor Default exists
]=]
function BuildingRegistry:GetCompanionModel(zoneName: string, companionModel: string): Model?
	local template = self:_GetTemplate(zoneName, companionModel)
	if not template then
		warn(
			"[BuildingRegistry] Failed to resolve companion template for zone='"
				.. zoneName
				.. "', companionModel='"
				.. companionModel
				.. "'"
		)
		return nil
	end
	return template:Clone()
end

return BuildingRegistry

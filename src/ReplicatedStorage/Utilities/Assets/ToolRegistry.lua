--!strict

--[[
	ToolRegistry - Load Tool Models by ID

	Provides a registry for cloning tool models from the Assets/Items/Tools folder.

	Folder Structure:
		Tools/
		├── Pickaxe/   ← Model with Handle (PrimaryPart) and Motors folder
		└── [OtherTools]/

	Usage:
		local toolRegistry = ToolRegistry.new(Assets.Items.Tools)
		local pickaxeClone = toolRegistry:GetToolModel("Pickaxe")
		local exists = toolRegistry:ToolModelExists("Pickaxe")
]]

local ToolRegistry = {}
ToolRegistry.__index = ToolRegistry

--[=[
	Creates a new ToolRegistry.

	@param toolsFolder Folder - The root Tools folder (Assets/Items/Tools)
	@return ToolRegistry - New registry instance
]=]
function ToolRegistry.new(toolsFolder: Folder)
	assert(toolsFolder, "ToolRegistry requires a valid Tools folder")
	assert(toolsFolder:IsA("Folder"), "ToolRegistry requires a Folder instance")

	local self = setmetatable({}, ToolRegistry)
	self._toolsFolder = toolsFolder

	return self
end

--[=[
	Gets a tool model clone by tool ID.

	Lookup order:
	1. Tools/{toolId}
	2. Tools/Default
	If neither resolves to a valid model, warns and returns nil.

	@param toolId string - The tool ID (e.g. "Pickaxe")
	@return Model? - Cloned model, or nil if not found
]=]
function ToolRegistry:GetToolModel(toolId: string): Model?
	local toolFolder = self._toolsFolder:FindFirstChild(toolId)
	local usedFallback = false
	if not toolFolder then
		toolFolder = self._toolsFolder:FindFirstChild("Default")
		if not toolFolder then
			warn("[ToolRegistry] Tool not found and no Default fallback:", toolId)
			return nil
		end
		usedFallback = true
	end

	local model = self:_ExtractModel(toolFolder)
	if not model then
		if not usedFallback then
			local defaultFolder = self._toolsFolder:FindFirstChild("Default")
			if defaultFolder then
				model = self:_ExtractModel(defaultFolder)
				if model then
					return model:Clone()
				end
			end
		end
		warn("[ToolRegistry] No Model found in Tools folder:", toolFolder.Name)
		return nil
	end

	return model:Clone()
end

--[=[
	Checks if a tool model exists.

	@param toolId string - The tool ID
	@return boolean - True if model exists
]=]
function ToolRegistry:ToolModelExists(toolId: string): boolean
	local toolFolder = self._toolsFolder:FindFirstChild(toolId)
	if not toolFolder then
		toolFolder = self._toolsFolder:FindFirstChild("Default")
		if not toolFolder then
			return false
		end
		return self:_ExtractModel(toolFolder) ~= nil
	end

	if self:_ExtractModel(toolFolder) ~= nil then
		return true
	end

	local defaultFolder = self._toolsFolder:FindFirstChild("Default")
	return defaultFolder ~= nil and self:_ExtractModel(defaultFolder) ~= nil
end

--[=[
	Extracts a Model from a Folder or returns the Model directly.

	@private
	@param instance Instance - The folder or model instance
	@return Model? - The model if found, nil otherwise
]=]
function ToolRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

return ToolRegistry

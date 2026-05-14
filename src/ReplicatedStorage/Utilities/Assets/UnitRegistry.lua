--!strict

local UnitRegistry = {}
UnitRegistry.__index = UnitRegistry

function UnitRegistry.new(unitsFolder: Folder)
	assert(unitsFolder, "UnitRegistry requires a valid Units folder")
	assert(unitsFolder:IsA("Folder"), "UnitRegistry requires a Folder instance")

	local self = setmetatable({}, UnitRegistry)
	self._unitsFolder = unitsFolder

	return self
end

function UnitRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end

	return nil
end

function UnitRegistry:_ResolveTemplate(unitId: string): Model?
	local typeNode = self._unitsFolder:FindFirstChild(unitId)
	local typeModel = typeNode and self:_ExtractModel(typeNode)
	if typeModel ~= nil then
		return typeModel
	end

	local defaultNode = self._unitsFolder:FindFirstChild("Default")
	local defaultModel = defaultNode and self:_ExtractModel(defaultNode)
	return defaultModel
end

function UnitRegistry:GetUnitModel(unitId: string): Model?
	local template = self:_ResolveTemplate(unitId)
	if template == nil then
		return nil
	end

	return template:Clone()
end

function UnitRegistry:UnitModelExists(unitId: string): boolean
	return self:_ResolveTemplate(unitId) ~= nil
end

return UnitRegistry

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)

local StructureRegistry = {}
StructureRegistry.__index = StructureRegistry

function StructureRegistry.new(structuresFolder: Folder)
	assert(structuresFolder, "StructureRegistry requires a valid Structures folder")
	assert(structuresFolder:IsA("Folder"), "StructureRegistry requires a Folder instance")

	local self = setmetatable({}, StructureRegistry)
	self._structuresFolder = structuresFolder

	return self
end

local function resolveCanonicalStructureType(rawType: string): string
	return StructureConfig.TYPE_ALIASES[rawType] or rawType
end

function StructureRegistry:_ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	elseif instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end
	return nil
end

function StructureRegistry:_ResolveTemplate(structureType: string): Model?
	local canonicalType = resolveCanonicalStructureType(structureType)

	local typeNode = self._structuresFolder:FindFirstChild(canonicalType)
	local typeModel = typeNode and self:_ExtractModel(typeNode)
	if typeModel ~= nil then
		return typeModel
	end

	local defaultNode = self._structuresFolder:FindFirstChild("Default")
	local defaultModel = defaultNode and self:_ExtractModel(defaultNode)
	return defaultModel
end

function StructureRegistry:GetStructureModel(structureType: string): Model?
	local template = self:_ResolveTemplate(structureType)
	if template == nil then
		return nil
	end

	return template:Clone()
end

function StructureRegistry:StructureModelExists(structureType: string): boolean
	return self:_ResolveTemplate(structureType) ~= nil
end

return StructureRegistry

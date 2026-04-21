--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)

type StructureType = StructureTypes.StructureType

--[=[
	@class StructureSpecs
	Provides pure predicates and alias resolution for structure registration.
	@server
]=]
local StructureSpecs = {}

--[=[
	Resolves a raw structure key to its canonical type.
	@within StructureSpecs
	@param rawStructureType string -- The placement key to normalize.
	@return StructureType? -- The canonical type or `nil` if unknown.
]=]
function StructureSpecs.ResolveStructureType(rawStructureType: string): StructureType?
	local alias = StructureConfig.TYPE_ALIASES[rawStructureType]
	if alias == nil then
		return nil
	end

	return alias :: StructureType
end

--[=[
	Checks whether a structure key maps to a known canonical type.
	@within StructureSpecs
	@param rawStructureType string -- The placement key to validate.
	@return boolean -- Whether the type is known.
]=]
function StructureSpecs.IsValidStructureType(rawStructureType: string): boolean
	return StructureSpecs.ResolveStructureType(rawStructureType) ~= nil
end

--[=[
	Validates that the placement instance id is a positive integer.
	@within StructureSpecs
	@param instanceId any -- The candidate instance id.
	@return boolean -- Whether the instance id is valid.
]=]
function StructureSpecs.HasValidInstanceId(instanceId: any): boolean
	return type(instanceId) == "number" and instanceId > 0 and math.floor(instanceId) == instanceId
end

return table.freeze(StructureSpecs)

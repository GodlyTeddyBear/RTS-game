--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local EntityDefinitionSpecs = require(ReplicatedStorage.Contexts.Entity.Specs.EntityDefinitionSpecs)

type StructureType = StructureTypes.StructureType

--[=[
	@class StructureSpecs
	Provides pure predicates and alias resolution for structure registration.
	@server
]=]
local StructureSpecs = {}

local function _IsPositiveFiniteNumber(value: any): boolean
	return type(value) == "number" and value > 0 and value == value and value < math.huge
end

local function _IsValidDefinition(definition: any): boolean
	if not EntityDefinitionSpecs.IsValid(definition) or type(definition.Capabilities) ~= "table" then
		return false
	end
	local construction = definition.Capabilities.Construction
	if type(construction) ~= "table" or not _IsPositiveFiniteNumber(construction.RequiredWork) then
		return false
	end
	local attack = definition.Capabilities.Attack
	if attack ~= nil then
		if not _IsPositiveFiniteNumber(attack.Damage) or not _IsPositiveFiniteNumber(attack.Range) or not _IsPositiveFiniteNumber(attack.Cooldown) then
			return false
		end
	end
	local statusAura = definition.Capabilities.StatusAura
	if statusAura ~= nil then
		if not _IsPositiveFiniteNumber(statusAura.Radius) or not _IsPositiveFiniteNumber(statusAura.MoveSpeedMultiplier) then
			return false
		end
	end
	return true
end

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
	local resolvedType = StructureSpecs.ResolveStructureType(rawStructureType)
	local definition = if resolvedType ~= nil then StructureConfig.Definitions[resolvedType] else nil
	return resolvedType ~= nil and definition ~= nil and definition.DefinitionId == resolvedType and _IsValidDefinition(definition)
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

function StructureSpecs.HasValidConstructionWorkAmount(workAmount: any): boolean
	return type(workAmount) == "number" and workAmount > 0 and workAmount == workAmount and workAmount < math.huge
end

return table.freeze(StructureSpecs)

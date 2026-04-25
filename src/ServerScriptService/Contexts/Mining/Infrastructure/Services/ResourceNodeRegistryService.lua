--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local MiningTypes = require(ReplicatedStorage.Contexts.Mining.Types.MiningTypes)
local Result = require(ReplicatedStorage.Utilities.Result)

local MiningSpecs = require(script.Parent.Parent.Parent.MiningDomain.Specs.MiningSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

type TResourceNodeRecord = MiningTypes.TResourceNodeRecord

local ResourceNodeRegistryService = {}
ResourceNodeRegistryService.__index = ResourceNodeRegistryService

local function _BuildNodeId(resourceType: string, resourcePart: BasePart): string
	return (`{resourceType}:{resourcePart:GetFullName()}`)
end

local function _CollectResourceParts(resourcesZone: Instance): { BasePart }
	local resourceParts = {}

	if resourcesZone:IsA("BasePart") then
		table.insert(resourceParts, resourcesZone)
	end

	for _, descendant in ipairs(resourcesZone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(resourceParts, descendant)
		end
	end

	return resourceParts
end

function ResourceNodeRegistryService.new()
	return setmetatable({}, ResourceNodeRegistryService)
end

function ResourceNodeRegistryService:Init(_registry: any, _name: string)
end

function ResourceNodeRegistryService:Start(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
	self._mapContext = registry:Get("MapContext")
end

function ResourceNodeRegistryService:RegisterNodesFromMapZone(): Result.Result<number>
	local zoneResult = self._mapContext:GetZoneInstance(MiningConfig.RESOURCE_ZONE_NAME)
	if not zoneResult.success then
		return zoneResult
	end

	local resourcesZone = zoneResult.value
	Ensure(resourcesZone ~= nil, "MissingResourceZone", Errors.MISSING_RESOURCE_ZONE)
	Ensure(typeof(resourcesZone) == "Instance", "InvalidResourceZone", Errors.INVALID_RESOURCE_ZONE)

	local registeredCount = 0
	for _, resourcePart in ipairs(_CollectResourceParts(resourcesZone)) do
		local registerResult = self:_RegisterResourceNode(resourcePart)
		if registerResult.success then
			registeredCount += 1
		else
			Result.MentionError("Mining:RegisterResourceNodes", "Skipping invalid resource node part", {
				PartName = resourcePart.Name,
				PartPath = resourcePart:GetFullName(),
				CauseType = registerResult.type,
				CauseMessage = registerResult.message,
			}, registerResult.type)
		end
	end

	return Ok(registeredCount)
end

function ResourceNodeRegistryService:_RegisterResourceNode(resourcePart: BasePart): Result.Result<number>
	Ensure(MiningSpecs.HasValidResourceNodePart(resourcePart), "InvalidResourceNode", Errors.INVALID_RESOURCE_NODE)
	Ensure(MiningSpecs.IsKnownResourceType(resourcePart.Name), "UnknownResourceNodeType", Errors.UNKNOWN_RESOURCE_NODE_TYPE, {
		PartName = resourcePart.Name,
	})

	local existingEntity = self._factory:FindResourceNodeByInstance(resourcePart)
	if existingEntity ~= nil then
		return Ok(existingEntity)
	end

	local nodeRecord: TResourceNodeRecord = {
		nodeId = _BuildNodeId(resourcePart.Name, resourcePart),
		instance = resourcePart,
		resourceType = resourcePart.Name,
	}

	local entity = self._factory:CreateResourceNode(nodeRecord)
	return Ok(entity)
end

return ResourceNodeRegistryService

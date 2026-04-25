--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Contexts.Economy.Config.EconomyConfig)

local MiningSpecs = {}

local KNOWN_RESOURCE_TYPES = (function(): { [string]: boolean }
	local lookup = {}
	for _, resourceType in ipairs(EconomyConfig.RESOURCE_TYPES) do
		lookup[resourceType] = true
	end
	return table.freeze(lookup)
end)()

function MiningSpecs.HasValidOwner(userId: any): boolean
	return type(userId) == "number" and userId > 0 and math.floor(userId) == userId
end

function MiningSpecs.HasValidResourceType(resourceType: any): boolean
	return type(resourceType) == "string" and #resourceType > 0
end

function MiningSpecs.HasValidInstanceId(instanceId: any): boolean
	return type(instanceId) == "number" and instanceId > 0 and math.floor(instanceId) == instanceId
end

function MiningSpecs.HasValidInterval(intervalSeconds: any): boolean
	return type(intervalSeconds) == "number" and intervalSeconds > 0
end

function MiningSpecs.HasValidAmount(amount: any): boolean
	return type(amount) == "number" and amount > 0 and math.floor(amount) == amount
end

function MiningSpecs.IsKnownResourceType(resourceType: any): boolean
	return type(resourceType) == "string" and KNOWN_RESOURCE_TYPES[resourceType] == true
end

function MiningSpecs.HasValidResourceNodePart(resourcePart: any): boolean
	return typeof(resourcePart) == "Instance" and resourcePart:IsA("BasePart")
end

return table.freeze(MiningSpecs)

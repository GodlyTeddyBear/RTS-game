--!strict

local MiningSpecs = {}

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

return table.freeze(MiningSpecs)

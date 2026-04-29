--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)

local ResolveStructureAimRequest = {}

function ResolveStructureAimRequest.Execute(model: Model, context: any): any?
	local structureType = model:GetAttribute("StructureType")
	if type(structureType) ~= "string" then
		return nil
	end

	local structureConfig = StructureConfig.STRUCTURES[structureType]
	if structureConfig == nil or structureConfig.AimRig == nil then
		return nil
	end

	local getTargetWorldPosition = context.GetTargetWorldPosition
	if type(getTargetWorldPosition) ~= "function" then
		return nil
	end

	return {
		Model = model,
		Strategy = structureConfig.AimRig.Strategy,
		GetTargetWorldPosition = getTargetWorldPosition,
		RigConfig = structureConfig.AimRig,
		Context = context,
	}
end

return ResolveStructureAimRequest

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)

local ResolveStructureAimRequest = {}

function ResolveStructureAimRequest.Execute(model: Model, context: any): any?
	local structureType = model:GetAttribute("StructureType")
	if type(structureType) ~= "string" then
		return nil
	end

	local structureConfig = StructureConfig.Definitions[structureType]
	local aim = if structureConfig ~= nil then structureConfig.Capabilities.Aim else nil
	if aim == nil then
		return nil
	end

	local getTargetWorldPosition = context.GetTargetWorldPosition
	if type(getTargetWorldPosition) ~= "function" then
		return nil
	end

	return {
		Model = model,
		Strategy = aim.Strategy,
		GetTargetWorldPosition = getTargetWorldPosition,
		RigConfig = aim,
		Context = context,
	}
end

return ResolveStructureAimRequest

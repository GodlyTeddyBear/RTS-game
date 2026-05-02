--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)

local StructureExtractAction = {}
StructureExtractAction.__index = StructureExtractAction
setmetatable(StructureExtractAction, BaseAction)

StructureExtractAction.AnimationKey = "StructureExtract"
StructureExtractAction.Looped = true

function StructureExtractAction.new()
	local self = BaseAction.new()
	return setmetatable(self :: any, StructureExtractAction)
end

return StructureExtractAction

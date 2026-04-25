--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)

local AttackAction = {}
AttackAction.__index = AttackAction
setmetatable(AttackAction, BaseAction)

AttackAction.AnimationKey = "AttackStructure"
AttackAction.Looped = false

AttackAction.Events = {
	Strike = { ServerCallback = "ActivateHitbox" },
}

function AttackAction.new()
	local self = BaseAction.new()
	return setmetatable(self :: any, AttackAction)
end

return AttackAction

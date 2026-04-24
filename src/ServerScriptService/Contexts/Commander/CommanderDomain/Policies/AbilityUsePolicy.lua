--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

local Ok = Result.Ok

type SlotKey = CommanderTypes.SlotKey

local AbilityUsePolicy = {}
AbilityUsePolicy.__index = AbilityUsePolicy

function AbilityUsePolicy.new()
	return setmetatable({}, AbilityUsePolicy)
end

function AbilityUsePolicy:Init(_registry: any, _name: string)
end

function AbilityUsePolicy:CheckCanUseInRunState(_slotKey: SlotKey, _runState: string): Result.Result<nil>
	return Ok(nil)
end

return AbilityUsePolicy

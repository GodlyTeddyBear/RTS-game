--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ensure = Result.Ensure

local UpdateCombatWaveContextCommand = {}
UpdateCombatWaveContextCommand.__index = UpdateCombatWaveContextCommand
setmetatable(UpdateCombatWaveContextCommand, BaseCommand)

function UpdateCombatWaveContextCommand.new()
	local self = BaseCommand.new("Combat", "UpdateCombatWaveContext")
	return setmetatable(self, UpdateCombatWaveContextCommand)
end

function UpdateCombatWaveContextCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
	})
end

function UpdateCombatWaveContextCommand:Execute(
	userId: number,
	waveNumber: number,
	isEndless: boolean
): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)
		return self._loopService:SetWaveContext(userId, waveNumber, isEndless)
	end, self:_Label())
end

return UpdateCombatWaveContextCommand

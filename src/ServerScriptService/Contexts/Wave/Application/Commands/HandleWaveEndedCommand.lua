--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

--[=[
	@class HandleWaveEndedCommand
	Cleans up the wave runtime session when the run leaves combat.
	@server
]=]
local HandleWaveEndedCommand = {}
HandleWaveEndedCommand.__index = HandleWaveEndedCommand
setmetatable(HandleWaveEndedCommand, BaseCommand)

function HandleWaveEndedCommand.new()
	local self = BaseCommand.new("Wave", "HandleWaveEnded")
	return setmetatable(self, HandleWaveEndedCommand)
end

function HandleWaveEndedCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_scheduler = "WaveSpawnScheduler",
		_state = "WaveEntityFactory",
		_lifecycle = "WaveLifecycleService"
	})
end

function HandleWaveEndedCommand:Execute(waveNumber: number): Result.Result<boolean>
	return Result.Catch(function()
		local state = self._state:GetStateReadOnly()
		if not self._lifecycle:IsCurrentWave(state, waveNumber) then
			return Ok(false)
		end

		self._scheduler:CancelAll()
		self._state:SetState(self._lifecycle:MarkWaveCompleted(state))

		return Ok(true)
	end, "Wave:HandleWaveEnded")
end

return HandleWaveEndedCommand



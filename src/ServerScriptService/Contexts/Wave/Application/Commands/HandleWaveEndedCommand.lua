--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

--[=[
	@class HandleWaveEndedCommand
	Cleans up the wave runtime session when the run leaves combat.
	@server
]=]
local HandleWaveEndedCommand = {}
HandleWaveEndedCommand.__index = HandleWaveEndedCommand

function HandleWaveEndedCommand.new()
	return setmetatable({}, HandleWaveEndedCommand)
end

function HandleWaveEndedCommand:Init(registry: any, _name: string)
	self._scheduler = registry:Get("WaveSpawnScheduler")
	self._state = registry:Get("WaveRuntimeStateService")
	self._lifecycle = registry:Get("WaveLifecycleService")
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

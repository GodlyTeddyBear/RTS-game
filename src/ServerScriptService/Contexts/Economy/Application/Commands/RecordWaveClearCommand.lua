--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try

type ProfileRunStats = EconomyTypes.ProfileRunStats

--[=[
	@class RecordWaveClearCommand
	Records wave-clear progress and persists updated run stats.
	@server
]=]
local RecordWaveClearCommand = {}
RecordWaveClearCommand.__index = RecordWaveClearCommand

function RecordWaveClearCommand.new()
	return setmetatable({}, RecordWaveClearCommand)
end

function RecordWaveClearCommand:Init(registry: any, _name: string)
	self._persistenceService = registry:Get("EconomyPersistenceService")
	self._syncService = registry:Get("ResourceSyncService")
end

--[=[
	Updates and persists run stats for a cleared wave.
	@within RecordWaveClearCommand
	@param player Player -- The player whose run stats should be updated.
	@param waveNumber number -- Cleared wave number.
	@return Result.Result<ProfileRunStats> -- Updated run stats.
]=]
function RecordWaveClearCommand:Execute(player: Player, waveNumber: number): Result.Result<ProfileRunStats>
	if type(waveNumber) ~= "number" or waveNumber <= 0 or math.floor(waveNumber) ~= waveNumber then
		return Result.Err("InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER, {
			waveNumber = waveNumber,
		})
	end

	local updatedRunStats = Try(self._persistenceService:RecordWaveClear(player, waveNumber))
	self._syncService:SyncRunStats(player.UserId, updatedRunStats)
	return Ok(updatedRunStats)
end

return RecordWaveClearCommand

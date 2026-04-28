--!strict

--[[
	Module: RecordWaveClearCommand
	Purpose: Records a cleared wave and synchronizes the updated run stats snapshot.
	Used In System: Invoked by EconomyContext when the run enters Resolution after a wave clear.
	Boundaries: Owns command orchestration only; does not own persistence schema or sync atom mutation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try

type ProfileRunStats = EconomyTypes.ProfileRunStats

-- [Initialization]

--[=[
	@class RecordWaveClearCommand
	Records wave-clear progress and persists updated run stats.
	@server
]=]
local RecordWaveClearCommand = {}
RecordWaveClearCommand.__index = RecordWaveClearCommand
setmetatable(RecordWaveClearCommand, BaseCommand)

--[=[
	Creates a new wave-clear command.
	@within RecordWaveClearCommand
	@return RecordWaveClearCommand -- The new command instance.
]=]
function RecordWaveClearCommand.new()
	local self = BaseCommand.new("Economy", "RecordWaveClearCommand")
	return setmetatable(self, RecordWaveClearCommand)
end

--[=[
	Initializes command dependencies.
	@within RecordWaveClearCommand
	@param registry any -- The registry that owns this command.
	@param _name string -- The registered module name.
]=]
function RecordWaveClearCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_persistenceService = "EconomyPersistenceService",
		_syncService = "ResourceSyncService",
	})
end

-- [Public API]

--[=[
	Updates and persists run stats for a cleared wave.
	@within RecordWaveClearCommand
	@param player Player -- The player whose run stats should be updated.
	@param waveNumber number -- Cleared wave number.
	@return Result.Result<ProfileRunStats> -- Updated run stats.
]=]
function RecordWaveClearCommand:Execute(player: Player, waveNumber: number): Result.Result<ProfileRunStats>
	-- Reject malformed wave values before touching persistence or sync state.
	if type(waveNumber) ~= "number" or waveNumber <= 0 or math.floor(waveNumber) ~= waveNumber then
		return Result.Err("InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER, {
			waveNumber = waveNumber,
		})
	end

	-- Persist the cleared wave and reuse the authoritative run-stat snapshot.
	local updatedRunStats = Try(self._persistenceService:RecordWaveClear(player, waveNumber))

	-- Mirror the persisted snapshot into the replicated wallet atom.
	self._syncService:SyncRunStats(player.UserId, updatedRunStats)

	-- Return the updated snapshot so callers can keep the same state without rereading storage.
	return Ok(updatedRunStats)
end

return RecordWaveClearCommand

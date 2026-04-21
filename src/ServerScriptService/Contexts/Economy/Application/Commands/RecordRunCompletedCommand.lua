--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

local Ok = Result.Ok
local Try = Result.Try

type ProfileRunStats = EconomyTypes.ProfileRunStats

--[=[
	@class RecordRunCompletedCommand
	Records completed-run progress and persists updated run stats.
	@server
]=]
local RecordRunCompletedCommand = {}
RecordRunCompletedCommand.__index = RecordRunCompletedCommand

function RecordRunCompletedCommand.new()
	return setmetatable({}, RecordRunCompletedCommand)
end

function RecordRunCompletedCommand:Init(registry: any, _name: string)
	self._persistenceService = registry:Get("EconomyPersistenceService")
	self._syncService = registry:Get("ResourceSyncService")
end

--[=[
	Updates and persists run stats for a completed run.
	@within RecordRunCompletedCommand
	@param player Player -- The player whose run stats should be updated.
	@return Result.Result<ProfileRunStats> -- Updated run stats.
]=]
function RecordRunCompletedCommand:Execute(player: Player): Result.Result<ProfileRunStats>
	local updatedRunStats = Try(self._persistenceService:AddCompletedRun(player))
	self._syncService:SyncRunStats(player.UserId, updatedRunStats)
	return Ok(updatedRunStats)
end

return RecordRunCompletedCommand

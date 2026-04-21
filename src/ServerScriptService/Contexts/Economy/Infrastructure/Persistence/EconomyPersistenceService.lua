--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local Result = require(ReplicatedStorage.Utilities.Result)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local fromNilable = Result.fromNilable

type ProfileRunStats = EconomyTypes.ProfileRunStats
type ResultType<T> = Result.Result<T>

--[=[
	@class EconomyPersistenceService
	Owns the Economy profile persistence path and converts run stats to and from `profile.Data`.
	@server
]=]
local EconomyPersistenceService = {}
EconomyPersistenceService.__index = EconomyPersistenceService

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, item in pairs(value :: any) do
		(clone :: any)[key] = deepCopy(item)
	end
	return clone :: any
end

local function validateRunStats(runStats: any): ResultType<ProfileRunStats>
	if type(runStats) ~= "table" then
		return Err("InvalidProfileData", Errors.PERSISTENCE_RUN_STATS_MUST_BE_TABLE)
	end

	local totalRuns = runStats.TotalRuns
	local bestWave = runStats.BestWave
	local totalWavesCleared = runStats.TotalWavesCleared

	if type(totalRuns) ~= "number" or type(bestWave) ~= "number" or type(totalWavesCleared) ~= "number" then
		return Err("InvalidProfileData", Errors.PERSISTENCE_RUN_STATS_FIELDS_MUST_BE_NUMBERS)
	end

	return Ok({
		TotalRuns = totalRuns,
		BestWave = bestWave,
		TotalWavesCleared = totalWavesCleared,
	})
end

local function getOrCreateRunStats(profileData: any): ResultType<ProfileRunStats>
	local runStats = profileData.RunStats
	if runStats == nil then
		local created = {
			TotalRuns = 0,
			BestWave = 0,
			TotalWavesCleared = 0,
		}
		profileData.RunStats = created
		return Ok(created)
	end

	return validateRunStats(runStats)
end

function EconomyPersistenceService.new()
	return setmetatable({}, EconomyPersistenceService)
end

--[=[
	Loads persisted run stats from profile data.
	@within EconomyPersistenceService
	@param player Player -- The player whose profile should be read.
	@return Result.Result<ProfileRunStats?> -- Deep copied run stats, or `Ok(nil)` when no run stats exist.
]=]
function EconomyPersistenceService:LoadRunStatsData(player: Player): ResultType<ProfileRunStats?>
	local profileDataResult = fromNilable(
		ProfileManager:GetData(player),
		"ProfileNotLoaded",
		Errors.PERSISTENCE_PROFILE_NOT_LOADED
	)
	if not profileDataResult.success then
		return profileDataResult
	end

	local profileData = profileDataResult.value
	local runStats = profileData.RunStats
	if runStats == nil then
		return Ok(nil)
	end

	local validatedRunStatsResult = validateRunStats(runStats)
	if not validatedRunStatsResult.success then
		return validatedRunStatsResult
	end

	return Ok(deepCopy(validatedRunStatsResult.value))
end

--[=[
	Adds one completed run to the persisted run stats.
	@within EconomyPersistenceService
	@param player Player -- The player whose profile should be written.
	@return Result.Result<ProfileRunStats> -- Updated persisted run stats snapshot.
]=]
function EconomyPersistenceService:AddCompletedRun(player: Player): ResultType<ProfileRunStats>
	local profileDataResult = fromNilable(
		ProfileManager:GetData(player),
		"ProfileNotLoaded",
		Errors.PERSISTENCE_PROFILE_NOT_LOADED
	)
	if not profileDataResult.success then
		return profileDataResult
	end

	local profileData = profileDataResult.value
	local runStatsResult = getOrCreateRunStats(profileData)
	if not runStatsResult.success then
		return runStatsResult
	end

	local runStats = runStatsResult.value
	runStats.TotalRuns += 1
	profileData.RunStats = runStats
	return Ok(deepCopy(runStats))
end

--[=[
	Records one cleared wave in persisted run stats.
	@within EconomyPersistenceService
	@param player Player -- The player whose profile should be written.
	@param waveNumber number -- Cleared wave number.
	@return Result.Result<ProfileRunStats> -- Updated persisted run stats snapshot.
]=]
function EconomyPersistenceService:RecordWaveClear(player: Player, waveNumber: number): ResultType<ProfileRunStats>
	if type(waveNumber) ~= "number" or waveNumber <= 0 or math.floor(waveNumber) ~= waveNumber then
		return Err("InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER, {
			waveNumber = waveNumber,
		})
	end

	local profileDataResult = fromNilable(
		ProfileManager:GetData(player),
		"ProfileNotLoaded",
		Errors.PERSISTENCE_PROFILE_NOT_LOADED
	)
	if not profileDataResult.success then
		return profileDataResult
	end

	local profileData = profileDataResult.value
	local runStatsResult = getOrCreateRunStats(profileData)
	if not runStatsResult.success then
		return runStatsResult
	end

	local runStats = runStatsResult.value
	runStats.TotalWavesCleared += 1
	runStats.BestWave = math.max(runStats.BestWave, waveNumber)
	profileData.RunStats = runStats
	return Ok(deepCopy(runStats))
end

return EconomyPersistenceService

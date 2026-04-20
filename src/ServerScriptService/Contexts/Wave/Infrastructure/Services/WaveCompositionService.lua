--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local WaveConfig = require(ReplicatedStorage.Contexts.Wave.Config.WaveConfig)
local WaveTypes = require(ReplicatedStorage.Contexts.Wave.Types.WaveTypes)

local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err

type WaveComposition = WaveTypes.WaveComposition

--[=[
	@class WaveCompositionService
	Builds scripted and endless wave spawn compositions.
	@server
]=]
local WaveCompositionService = {}
WaveCompositionService.__index = WaveCompositionService

-- Copies a frozen composition so callers can safely work with a mutable result.
local function copyComposition(source: WaveComposition): WaveComposition
	local copy: WaveComposition = table.create(#source)
	for index, group in source do
		copy[index] = {
			role = group.role,
			count = group.count,
			groupDelay = group.groupDelay,
		}
	end
	return copy
end

--[=[
	Creates a new wave-composition service.
	@within WaveCompositionService
	@return WaveCompositionService -- The new service instance.
]=]
function WaveCompositionService.new()
	return setmetatable({}, WaveCompositionService)
end

--[=[
	Initializes the service and captures endless-scaling dependencies.
	@within WaveCompositionService
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function WaveCompositionService:Init(registry: any, _name: string)
	self._endlessScaling = registry:Get("EndlessScalingService")
end

--[=[
	Builds the wave composition for a scripted or endless wave.
	@within WaveCompositionService
	@param waveNumber number -- The current wave number.
	@param isEndless boolean -- Whether the wave is in the endless loop.
	@param endlessWaveIndex number? -- Endless offset used for scaling.
	@return Result.Result<WaveComposition> -- The selected composition or an error.
]=]
function WaveCompositionService:BuildWave(
	waveNumber: number,
	isEndless: boolean,
	endlessWaveIndex: number?
): Result.Result<WaveComposition>
	if waveNumber <= 0 then
		return Err("UnknownWave", Errors.UNKNOWN_WAVE, { WaveNumber = waveNumber })
	end

	if not isEndless then
		local scriptedWave = WaveConfig.WAVE_TABLE[waveNumber]
		if not scriptedWave then
			return Err("UnknownWave", Errors.UNKNOWN_WAVE, { WaveNumber = waveNumber })
		end
		return Ok(copyComposition(scriptedWave))
	end

	local baseWave = WaveConfig.WAVE_TABLE[#WaveConfig.WAVE_TABLE]
	if not baseWave then
		return Err("UnknownWave", Errors.UNKNOWN_WAVE, { WaveNumber = waveNumber })
	end

	local resolvedIndex = endlessWaveIndex or 0
	local scaledComposition: WaveComposition = table.create(#baseWave)
	local scaleMultiplier = 1 + WaveConfig.ENDLESS_SCALE_FACTOR * resolvedIndex

	for index, group in baseWave do
		scaledComposition[index] = {
			role = group.role,
			count = math.floor(group.count * scaleMultiplier),
			groupDelay = group.groupDelay,
		}
	end

	return Ok(self._endlessScaling:ApplyRoleUpgrades(scaledComposition, resolvedIndex))
end

return WaveCompositionService

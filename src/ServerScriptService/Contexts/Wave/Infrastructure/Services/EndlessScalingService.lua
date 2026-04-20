--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveConfig = require(ReplicatedStorage.Contexts.Wave.Config.WaveConfig)
local WaveTypes = require(ReplicatedStorage.Contexts.Wave.Types.WaveTypes)

type WaveComposition = WaveTypes.WaveComposition
type EndlessRoleThreshold = WaveTypes.EndlessRoleThreshold

--[=[
	@class EndlessScalingService
	Computes endless-wave scaling and role threshold upgrades.
	@server
]=]
local EndlessScalingService = {}
EndlessScalingService.__index = EndlessScalingService

--[=[
	Creates a new endless-scaling service.
	@within EndlessScalingService
	@return EndlessScalingService -- The new service instance.
]=]
function EndlessScalingService.new()
	return setmetatable({}, EndlessScalingService)
end

--[=[
	Initializes the service for registry ownership.
	@within EndlessScalingService
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function EndlessScalingService:Init(_registry: any, _name: string)
end

--[=[
	Computes the endless index from the current wave number.
	@within EndlessScalingService
	@param waveNumber number -- The current wave number.
	@param climaxWave number -- The configured climax transition wave.
	@return number -- The endless-wave offset.
]=]
function EndlessScalingService:GetEndlessWaveIndex(waveNumber: number, climaxWave: number): number
	return math.max(0, waveNumber - climaxWave)
end

--[=[
	Appends any threshold-based role upgrades to the composition.
	@within EndlessScalingService
	@param composition WaveComposition -- The scaled scripted composition.
	@param endlessWaveIndex number -- The current endless offset.
	@return WaveComposition -- The upgraded composition.
]=]
function EndlessScalingService:ApplyRoleUpgrades(composition: WaveComposition, endlessWaveIndex: number): WaveComposition
	local upgraded: WaveComposition = table.clone(composition)
	local thresholdKeys = {}

	for thresholdIndex in WaveConfig.ENDLESS_ROLE_THRESHOLDS do
		table.insert(thresholdKeys, thresholdIndex)
	end

	table.sort(thresholdKeys)

	for _, thresholdIndex in thresholdKeys do
		if thresholdIndex <= endlessWaveIndex then
			local threshold: EndlessRoleThreshold = WaveConfig.ENDLESS_ROLE_THRESHOLDS[thresholdIndex]
			table.insert(upgraded, {
				role = threshold.role,
				count = threshold.count,
				groupDelay = 0,
			})
		end
	end

	return upgraded
end

return EndlessScalingService

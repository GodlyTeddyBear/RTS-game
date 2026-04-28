--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local SummonConfig = require(ReplicatedStorage.Contexts.Summon.Config.SummonConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local SpawnSwarmDronesCommand = {}
SpawnSwarmDronesCommand.__index = SpawnSwarmDronesCommand
setmetatable(SpawnSwarmDronesCommand, BaseCommand)

function SpawnSwarmDronesCommand.new()
	local self = BaseCommand.new("Summon", "SpawnSwarmDrones")
	return setmetatable(self, SpawnSwarmDronesCommand)
end

function SpawnSwarmDronesCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_runtimeService = "SummonRuntimeService"
	})
end

local function _toPositiveInt(value: any, fallback: number): number
	if type(value) ~= "number" then
		return fallback
	end
	if value <= 0 then
		return fallback
	end
	return math.floor(value)
end

function SpawnSwarmDronesCommand:Execute(
	player: Player,
	slotMetadata: { [string]: any }?,
	castOriginCFrame: CFrame
): Result.Result<{ spawnedCount: number }>
	return Result.Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(castOriginCFrame, "InvalidCastOrigin", Errors.INVALID_CAST_ORIGIN)
		Ensure(slotMetadata == nil or type(slotMetadata) == "table", "InvalidMetadata", Errors.INVALID_METADATA)

		local defaults = SummonConfig.SWARM_DRONES
		local summonCount = _toPositiveInt(if slotMetadata then slotMetadata.summonCount else nil, defaults.summonCount)
		local lifetime = if slotMetadata
				and type(slotMetadata.lifetime) == "number"
				and slotMetadata.lifetime > 0
			then slotMetadata.lifetime
			else defaults.lifetime

		Ensure(summonCount > 0, "InvalidSummonCount", Errors.INVALID_SUMMON_COUNT)
		Ensure(lifetime > 0, "InvalidLifetime", Errors.INVALID_LIFETIME)

		local spawnedCount = self._runtimeService:SpawnSwarmDrones(player, castOriginCFrame, summonCount, lifetime)
		Ensure(spawnedCount > 0, "MaxConcurrentReached", Errors.MAX_CONCURRENT_REACHED, {
			userId = player.UserId,
		})
		return Ok({
			spawnedCount = spawnedCount,
		})
	end, "Summon:SpawnSwarmDrones")
end

return SpawnSwarmDronesCommand



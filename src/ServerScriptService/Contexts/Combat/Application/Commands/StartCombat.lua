--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local StartCombat = {}
StartCombat.__index = StartCombat
setmetatable(StartCombat, BaseCommand)

function StartCombat.new()
	local self = BaseCommand.new("Combat", "StartCombat")
	return setmetatable(self, StartCombat)
end

function StartCombat:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_actorRegistryService = "CombatActorRegistryService",
	})
end

function StartCombat:Execute(waveNumber: number, isEndless: boolean): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)

		local primaryPlayer = Players:GetPlayers()[1]
		Ensure(primaryPlayer ~= nil, "MissingPrimaryPlayer", Errors.MISSING_PRIMARY_PLAYER)

		local runtimeStarted = self._actorRegistryService:IsRuntimeStarted()
		local actorTypePayloads = self._actorRegistryService:GetActorTypePayloads()
		Result.MentionEvent("Combat:StartCombat", "Processing combat start request", {
			WaveNumber = waveNumber,
			IsEndless = isEndless,
			PrimaryPlayerUserId = primaryPlayer.UserId,
			RuntimeStarted = runtimeStarted,
			ActorTypeCount = #actorTypePayloads,
		})

		if not runtimeStarted then
			local startResult = self._behaviorRuntimeService:StartRuntime()
			if not startResult.success then
				Result.MentionError("Combat:StartCombat", "Combat runtime failed to start", {
					WaveNumber = waveNumber,
					IsEndless = isEndless,
					PrimaryPlayerUserId = primaryPlayer.UserId,
					ActorTypeCount = #actorTypePayloads,
					CauseType = startResult.type,
					CauseMessage = startResult.message,
					Details = startResult.data,
				}, startResult.type)
				return startResult
			end
		end

		self._loopService:StartCombat(primaryPlayer.UserId, waveNumber, isEndless)
		return Ok(true)
	end, self:_Label())
end

return StartCombat

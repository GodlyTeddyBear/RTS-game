--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

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
		-- Validate the start request and resolve the combat owner first.
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

		if self._loopService:HasSession(primaryPlayer.UserId) then
			return Ok(false)
		end

		-- Reserve the session before touching the shared runtime.
		Try(self._loopService:BeginSession(primaryPlayer.UserId, waveNumber, isEndless))

		-- Start the runtime only when this session needs to own it.
		if not runtimeStarted then
			local startResult = self._behaviorRuntimeService:StartRuntime()
			if not startResult.success then
				Try(self._loopService:MarkSessionFailed(primaryPlayer.UserId, startResult.message))
				Try(self._loopService:ClearSession(primaryPlayer.UserId))
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

		-- Promote the reserved session through readiness before enabling combat work.
		local runtimeReadyResult = self._loopService:MarkRuntimeReady(primaryPlayer.UserId)
		if not runtimeReadyResult.success then
			Try(self._loopService:MarkSessionFailed(primaryPlayer.UserId, runtimeReadyResult.message))
			Try(self._behaviorRuntimeService:StopRuntime())
			Try(self._loopService:ClearSession(primaryPlayer.UserId))
			return runtimeReadyResult
		end

		local activateResult = self._loopService:ActivateSession(primaryPlayer.UserId)
		if not activateResult.success then
			Try(self._loopService:MarkSessionFailed(primaryPlayer.UserId, activateResult.message))
			Try(self._behaviorRuntimeService:StopRuntime())
			Try(self._loopService:ClearSession(primaryPlayer.UserId))
			return activateResult
		end

		return Ok(true)
	end, self:_Label())
end

return StartCombat

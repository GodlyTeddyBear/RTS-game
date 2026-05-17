--!strict

--[=[
	@class ProcessCombatTick
	Advances the combat runtime by one frame.
	@server
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local schedulerProfilingEnabled = DebugConfig.COMBAT_SCHEDULER_PROFILING
local processSessionsIsRunnableProfileTag = "Combat.Scheduler.CombatTick.ProcessSessions.IsRunnable"
local processSessionsRunFrameProfileTag = "Combat.Scheduler.CombatTick.ProcessSessions.RunFrame"
local processSessionsNotifyActorResultsProfileTag = "Combat.Scheduler.CombatTick.ProcessSessions.NotifyActorResults"
local processSessionsNotifyActorResultsIterateProfileTag =
	"Combat.Scheduler.CombatTick.ProcessSessions.NotifyActorResults.Iterate"

local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick
setmetatable(ProcessCombatTick, BaseCommand)

--[=[
	Creates a combat tick command instance.
	@within ProcessCombatTick
	@return ProcessCombatTick -- New command instance.
]=]
function ProcessCombatTick.new()
	local self = BaseCommand.new("Combat", "ProcessCombatTick")
	return setmetatable(self, ProcessCombatTick)
end

--[=[
	Resolves the combat command dependencies used during each tick.
	@within ProcessCombatTick
	@param registry any -- Registry supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function ProcessCombatTick:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_actorRegistryService = "CombatActorRegistryService",
	})
end

--[=[
	Processes one combat tick for a running session.
	@within ProcessCombatTick
	@param userId number -- Combat session owner to tick.
	@param dt number -- Delta time in seconds for the frame.
	@return Result.Result<boolean> -- Whether the tick ran successfully.
]=]
function ProcessCombatTick:Execute(userId: number, dt: number): Result.Result<boolean>
	return Result.Catch(function()
		local isRunnable = DebugPlus.profile(processSessionsIsRunnableProfileTag, function()
			return self._loopService:IsRunnable(userId)
		end, schedulerProfilingEnabled)
		if not isRunnable then
			return Ok(false)
		end

		local currentTime = os.clock()
		local tickId = self._loopService:AdvanceTickId()
		local ok, frameResult = pcall(function()
			return DebugPlus.profile(processSessionsRunFrameProfileTag, function()
				return self._behaviorRuntimeService:RunFrame({
					CurrentTime = currentTime,
					TickId = tickId,
					DeltaTime = dt,
					Services = {
						CombatActorRegistryService = self._actorRegistryService,
					},
				})
			end, schedulerProfilingEnabled)
		end)
		if not ok then
			error(frameResult)
		end
		DebugPlus.profile(processSessionsNotifyActorResultsProfileTag, function()
			self:_NotifyActorResults(frameResult)
		end, schedulerProfilingEnabled)

		return Ok(true)
	end, self:_Label())
end

function ProcessCombatTick:_NotifyActorResults(frameResult: any)
	DebugPlus.profile(processSessionsNotifyActorResultsIterateProfileTag, function()
		for _, entityResult in ipairs(frameResult.EntityResults) do
			self._actorRegistryService:NotifyActionResult(entityResult.Entity, entityResult)
		end
	end, schedulerProfilingEnabled)
end

return ProcessCombatTick

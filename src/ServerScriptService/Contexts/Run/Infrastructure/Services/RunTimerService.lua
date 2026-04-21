--!strict

local Workspace = game:GetService("Workspace")

--[=[
	@class RunTimerService
	Owns cancellable countdowns for the run phase transitions.
	@server
]=]

local RunTimerService = {}
RunTimerService.__index = RunTimerService

--[=[
	Creates a new timer service configured with the run durations.
	@within RunTimerService
	@param config table -- Shared run timing constants.
	@return RunTimerService -- The new timer service.
]=]
function RunTimerService.new(config: {
	Phases: {
		Prep: number,
		Wave: number,
		Resolution: number,
	},
})
	local self = setmetatable({}, RunTimerService)
	self._config = config
	self._activeThread = nil :: thread?
	self._phaseStartedAt = nil :: number?
	self._phaseEndsAt = nil :: number?
	self._phaseDuration = nil :: number?
	return self
end

--[=[
	Initializes the timer service for registry ownership.
	@within RunTimerService
	@param registry any -- The module registry that owns this service.
	@param name string -- The registered module name.
]=]
function RunTimerService:Init(_registry: any, _name: string)
end

-- Cancels the current timer before starting a new countdown so phase timers never overlap.
function RunTimerService:_StartCountdown(duration: number, onExpire: () -> ())
	-- Reset any active delay before scheduling the next phase timeout.
	self:Cancel()
	local startedAt = Workspace:GetServerTimeNow()
	self._phaseStartedAt = startedAt
	self._phaseDuration = duration
	self._phaseEndsAt = startedAt + duration

	local activeThread: thread? = nil
	-- Capture the newly scheduled delay so stale callbacks can self-disqualify.
	activeThread = task.delay(duration, function()
		-- Ignore callbacks from a superseded timer and keep the latest countdown authoritative.
		if self._activeThread ~= activeThread then
			return
		end

		self._activeThread = nil
		onExpire()
	end)

	self._activeThread = activeThread
end

--[=[
	Starts the prep countdown.
	@within RunTimerService
	@param onExpire function -- Callback fired when the countdown completes.
]=]
function RunTimerService:StartPrepCountdown(onExpire: () -> ())
	self:_StartCountdown(self._config.Phases.Prep, onExpire)
end

--[=[
	Starts the wave countdown.
	@within RunTimerService
	@param onExpire function -- Callback fired when the countdown completes.
]=]
function RunTimerService:StartWaveCountdown(onExpire: () -> ())
	self:_StartCountdown(self._config.Phases.Wave, onExpire)
end

--[=[
	Starts the resolution countdown.
	@within RunTimerService
	@param onExpire function -- Callback fired when the countdown completes.
]=]
function RunTimerService:StartResolutionCountdown(onExpire: () -> ())
	self:_StartCountdown(self._config.Phases.Resolution, onExpire)
end

--[=[
	Cancels the active countdown if one exists.
	@within RunTimerService
]=]
function RunTimerService:Cancel()
	local activeThread = self._activeThread
	if activeThread then
		task.cancel(activeThread)
	end
	self._activeThread = nil
	self:ClearPhaseClock()
end

function RunTimerService:ClearPhaseClock()
	self._phaseStartedAt = nil
	self._phaseEndsAt = nil
	self._phaseDuration = nil
end

function RunTimerService:GetPhaseClock()
	return {
		phaseStartedAt = self._phaseStartedAt,
		phaseEndsAt = self._phaseEndsAt,
		phaseDuration = self._phaseDuration,
	}
end

return RunTimerService

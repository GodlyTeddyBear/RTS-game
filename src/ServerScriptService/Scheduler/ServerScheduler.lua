--!strict

--[=[
    @class ServerScheduler
    Singleton Planck scheduler that owns and drives all server-side ECS systems.

    Contexts register their systems during `KnitStart()` via `RegisterSystem()`.
    `Runtime.server.lua` calls `Initialize()` after `Knit.Start()` resolves, which
    builds the pipeline, flushes queued systems, and gates execution behind a fixed
    `RunService.Heartbeat` accumulator.

    Phase execution order (per scheduler tick):
    1. `MovementTick`
    2. `EntityTick`
    3. `MiningTick`

    Entity-backed AI, action orchestration, combat, cleanup, sync, and replication
    run inside the shared Entity runtime phases rather than per-feature scheduler phases.
    @server
]=]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local Planck = require(ReplicatedStorage.Packages.Planck)
local Jabby = require(ReplicatedStorage.Packages.Jabby)
local Phases = require(script.Parent.Phases)

--[=[
    @interface TQueuedSystem
    @within ServerScheduler
    .SystemFn (...any) -> any -- The ECS system function to run each frame
    .PhaseName string -- The phase key the system is registered to
    .JabbyName string -- The display name used in the Jabby scheduler UI
]=]
type TQueuedSystem = { SystemFn: (...any) -> any, PhaseName: string, JabbyName: string }
type TCombatRuntimeEstimate = {
	SchedulerIntervalSeconds: number,
	TicksPerSecond: number,
	TickBudgetSeconds: number,
	TickBudgetMilliseconds: number,
	EstimatedRuntimePerSecondSeconds: number,
	EstimatedRuntimePerSecondMilliseconds: number,
	ExceedsTickBudgetMillisecondsWarning: boolean,
	ExceedsRuntimeMillisecondsWarning: boolean,
	ExceedsTickRateWarning: boolean,
}

local ServerScheduler = {}

-- Phase name → Phase object lookup (derived from ordered Phases array)
local PHASE_MAP: { [string]: any } = {}
for _, entry in ipairs(Phases) do
	PHASE_MAP[entry.Name] = entry.Phase
end

-- Queued systems before Initialize() is called
local _queuedSystems: { TQueuedSystem } = {}
local _scheduler: any = nil
local _jabbyScheduler: any = nil
local _heartbeatPipeline: any = nil
local _schedulerSignal: BindableEvent? = nil
local _initialized = false
local _heartbeatAccumulator: number = 0
local SCHEDULER_INTERVAL = DebugConfig.SCHEDULER_INTERVAL
-- Delta time captured by the currently-running wrapper (for GetDeltaTime())
local _currentDeltaTime: number = 0

--[=[
    Register a system to run in a specific phase.

    Called by contexts during `KnitStart()`. If called before `Initialize()`, the system
    is queued and flushed when the pipeline starts. If called after, it is added immediately.
    @within ServerScheduler
    @param systemFn (...any) -> any -- The ECS system function (closure capturing dependencies)
    @param phaseName string -- Phase key from the `Phases` module (e.g. `"NPCPositionPoll"`)
    @error string -- Thrown if `phaseName` is not a recognized phase key
]=]
function ServerScheduler:RegisterSystem(systemFn: (...any) -> any, phaseName: string)
	assert(PHASE_MAP[phaseName], "[ServerScheduler] Unknown phase: " .. phaseName)

	if _initialized then
		self:_AddSystemImmediately(systemFn, phaseName)
	else
		self:_EnqueueSystem(systemFn, phaseName)
	end
end

--[=[
    Initialize the Planck scheduler, build the pipeline, flush queued systems, and connect to `RunService.Heartbeat`.

    Called once by `Runtime.server.lua` after `Knit.Start()` resolves.
    @within ServerScheduler
    @error string -- Thrown if called more than once
]=]
function ServerScheduler:Initialize()
	assert(not _initialized, "[ServerScheduler] Already initialized")
	self:_CreateJabbyScheduler()
	self:_CreateSchedulerSignal()
	self:_BuildHeartbeatPipeline()
	self:_FlushQueuedSystems()
	_initialized = true
	print("[ServerScheduler] Initialized with Planck scheduler")
end

--[=[
    Return the underlying Planck scheduler instance.
    @within ServerScheduler
    @return any -- The `Planck.Scheduler` instance
    @error string -- Thrown if called before `Initialize()`
]=]
function ServerScheduler:GetScheduler(): any
	assert(_initialized, "[ServerScheduler] Not yet initialized")
	return _scheduler
end

--[=[
    Return the delta time for the currently-running system.

    Use this instead of `scheduler:getDeltaTime()` — Jabby wrapping means the inner
    system function is not directly registered with Planck, so this captures delta time
    in the outer wrapper and exposes it here.
    @within ServerScheduler
    @return number -- Seconds elapsed since the last scheduler tick
]=]
function ServerScheduler:GetDeltaTime(): number
	return _currentDeltaTime
end

function ServerScheduler:CalculateCombatRuntimeEstimate(): TCombatRuntimeEstimate
	local schedulerInterval = DebugConfig.SCHEDULER_INTERVAL
	local tickBudgetSeconds = DebugConfig.COMBAT_TICK_TIME_BUDGET_SECONDS
	local tickBudgetMillisecondsWarningThreshold = DebugConfig.COMBAT_RUNTIME_ESTIMATE_WARN_MILLISECONDS_PER_TICK
	local runtimeMillisecondsWarningThreshold = DebugConfig.COMBAT_RUNTIME_ESTIMATE_WARN_MILLISECONDS_PER_SECOND
	local ticksPerSecondWarningThreshold = DebugConfig.COMBAT_RUNTIME_ESTIMATE_WARN_TICKS_PER_SECOND

	if schedulerInterval <= 0 or tickBudgetSeconds <= 0 then
		return {
			SchedulerIntervalSeconds = schedulerInterval,
			TicksPerSecond = 0,
			TickBudgetSeconds = tickBudgetSeconds,
			TickBudgetMilliseconds = 0,
			EstimatedRuntimePerSecondSeconds = 0,
			EstimatedRuntimePerSecondMilliseconds = 0,
			ExceedsTickBudgetMillisecondsWarning = false,
			ExceedsRuntimeMillisecondsWarning = false,
			ExceedsTickRateWarning = false,
		}
	end

	local ticksPerSecond = 1 / schedulerInterval
	local tickBudgetMilliseconds = tickBudgetSeconds / DebugConfig.MILLISECOND
	local estimatedRuntimePerSecondSeconds = ticksPerSecond * tickBudgetSeconds
	local estimatedRuntimePerSecondMilliseconds = estimatedRuntimePerSecondSeconds / DebugConfig.MILLISECOND

	return {
		SchedulerIntervalSeconds = schedulerInterval,
		TicksPerSecond = ticksPerSecond,
		TickBudgetSeconds = tickBudgetSeconds,
		TickBudgetMilliseconds = tickBudgetMilliseconds,
		EstimatedRuntimePerSecondSeconds = estimatedRuntimePerSecondSeconds,
		EstimatedRuntimePerSecondMilliseconds = estimatedRuntimePerSecondMilliseconds,
		ExceedsTickBudgetMillisecondsWarning = tickBudgetMillisecondsWarningThreshold > 0
			and tickBudgetSeconds >= tickBudgetMillisecondsWarningThreshold,
		ExceedsRuntimeMillisecondsWarning = runtimeMillisecondsWarningThreshold > 0
			and estimatedRuntimePerSecondSeconds >= runtimeMillisecondsWarningThreshold,
		ExceedsTickRateWarning = ticksPerSecondWarningThreshold > 0
			and ticksPerSecond >= ticksPerSecondWarningThreshold,
	}
end

function ServerScheduler:LogCombatRuntimeEstimate()
	local runtimeEstimate = self:CalculateCombatRuntimeEstimate()

	warn(
		string.format(
			"[ServerScheduler] Combat runtime estimate: %.2f ticks/sec * %.3f ms budget = %.2f ms/sec",
			runtimeEstimate.TicksPerSecond,
			runtimeEstimate.TickBudgetMilliseconds,
			runtimeEstimate.EstimatedRuntimePerSecondMilliseconds
		)
	)

	self:_WarnIfCombatRuntimeEstimateExceedsRecommendedBounds(runtimeEstimate)
end

-- ── Private ──────────────────────────────────────────────────────────────────

function ServerScheduler:_WarnIfCombatRuntimeEstimateExceedsRecommendedBounds(runtimeEstimate: TCombatRuntimeEstimate)
	if runtimeEstimate.TicksPerSecond <= 0 or runtimeEstimate.TickBudgetSeconds <= 0 then
		return
	end

	if
		not runtimeEstimate.ExceedsTickBudgetMillisecondsWarning
		and not runtimeEstimate.ExceedsRuntimeMillisecondsWarning
		and not runtimeEstimate.ExceedsTickRateWarning
	then
		return
	end

	local exceededBounds = {}

	if runtimeEstimate.ExceedsTickBudgetMillisecondsWarning then
		table.insert(
			exceededBounds,
			string.format(
				"tick budget %.3f ms/tick exceeds recommended combat-script warn bound %.3f ms/tick",
				runtimeEstimate.TickBudgetMilliseconds,
				DebugConfig.COMBAT_RUNTIME_ESTIMATE_WARN_MILLISECONDS_PER_TICK / DebugConfig.MILLISECOND
			)
		)
	end

	if runtimeEstimate.ExceedsRuntimeMillisecondsWarning then
		table.insert(
			exceededBounds,
			string.format(
				"runtime %.2f ms/sec exceeds recommended combat-script warn bound %.2f ms/sec",
				runtimeEstimate.EstimatedRuntimePerSecondMilliseconds,
				DebugConfig.COMBAT_RUNTIME_ESTIMATE_WARN_MILLISECONDS_PER_SECOND / DebugConfig.MILLISECOND
			)
		)
	end

	if runtimeEstimate.ExceedsTickRateWarning then
		table.insert(
			exceededBounds,
			string.format(
				"tick rate %.2f ticks/sec exceeds warn bound %.2f ticks/sec",
				runtimeEstimate.TicksPerSecond,
				DebugConfig.COMBAT_RUNTIME_ESTIMATE_WARN_TICKS_PER_SECOND
			)
		)
	end

	warn(
		string.format(
			"[ServerScheduler] Estimated combat runtime exceeds recommended combat-script bounds (does not include Roblox engine/internal frame cost): %.2f ticks/sec, %.3f ms/tick, %.2f ms/sec | %s",
			runtimeEstimate.TicksPerSecond,
			runtimeEstimate.TickBudgetMilliseconds,
			runtimeEstimate.EstimatedRuntimePerSecondMilliseconds,
			table.concat(exceededBounds, "; ")
		)
	)
end

function ServerScheduler:_AddSystemImmediately(systemFn: (...any) -> any, phaseName: string)
	local systemId = _jabbyScheduler:register_system({
		name = phaseName .. ":" .. tostring(os.clock()),
		phase = phaseName,
	})
	local wrapped = self:_WrapWithJabbyTiming(systemId, systemFn)
	_scheduler:addSystem(wrapped, PHASE_MAP[phaseName])
end

function ServerScheduler:_EnqueueSystem(systemFn: (...any) -> any, phaseName: string)
	local jabbyName = phaseName .. ":" .. tostring(#_queuedSystems + 1)
	table.insert(_queuedSystems, {
		SystemFn = systemFn,
		PhaseName = phaseName,
		JabbyName = jabbyName,
	})
end

function ServerScheduler:_CreateJabbyScheduler()
	_jabbyScheduler = Jabby.scheduler.create()
	Jabby.register({
		name = "ServerScheduler",
		applet = Jabby.applets.scheduler,
		configuration = { scheduler = _jabbyScheduler },
	})
	_scheduler = Planck.Scheduler.new()
end

function ServerScheduler:_CreateSchedulerSignal()
	local schedulerSignal = Instance.new("BindableEvent")
	schedulerSignal.Name = "ServerSchedulerSignal"
	_schedulerSignal = schedulerSignal
end

function ServerScheduler:_BuildHeartbeatPipeline()
	_heartbeatPipeline = Planck.Pipeline.new("ServerHeartbeat")
	for _, entry in ipairs(Phases) do
		_heartbeatPipeline:insert(entry.Phase)
	end

	assert(_schedulerSignal ~= nil, "[ServerScheduler] Scheduler signal not initialized")
	_scheduler:insert(_heartbeatPipeline, _schedulerSignal, "Event")

	RunService.Heartbeat:Connect(function(deltaTime: number)
		_heartbeatAccumulator += deltaTime
		if _heartbeatAccumulator < SCHEDULER_INTERVAL then
			return
		end

		_heartbeatAccumulator = 0
		_schedulerSignal:Fire()
	end)
end

function ServerScheduler:_FlushQueuedSystems()
	for _, entry in ipairs(_queuedSystems) do
		self:_RegisterQueuedSystem(entry)
	end
	table.clear(_queuedSystems)
end

function ServerScheduler:_RegisterQueuedSystem(entry: TQueuedSystem)
	local phase = PHASE_MAP[entry.PhaseName]
	local systemId = _jabbyScheduler:register_system({ name = entry.JabbyName, phase = entry.PhaseName })
	local wrapped = self:_WrapWithJabbyTiming(systemId, entry.SystemFn)
	_scheduler:addSystem(wrapped, phase)
end

function ServerScheduler:_WrapWithJabbyTiming(systemId: any, systemFn: (...any) -> any): () -> ()
	return function()
		_currentDeltaTime = _scheduler:getDeltaTime()
		_jabbyScheduler:run(systemId, systemFn)
	end
end

return ServerScheduler

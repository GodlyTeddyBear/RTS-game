--!strict

--[=[
    @class ServerScheduler
    Singleton Planck scheduler that owns and drives all server-side ECS systems.

    Contexts register their systems during `KnitStart()` via `RegisterSystem()`.
    `Runtime.server.lua` calls `Initialize()` after `Knit.Start()` resolves, which
    builds the pipeline, flushes queued systems, and gates execution behind a fixed
    `RunService.Heartbeat` accumulator.

    Phase execution order (per scheduler tick):
    1. `EnemyPositionPoll`
    2. `EnemySync`
    3. `UnitSync`
    4. `CombatTick`
    5. `MiningTick`
    6. `StructureSync`
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

-- ── Private ──────────────────────────────────────────────────────────────────

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

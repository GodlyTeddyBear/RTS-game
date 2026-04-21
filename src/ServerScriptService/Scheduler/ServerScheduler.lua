--!strict

--[=[
    @class ServerScheduler
    Singleton Planck scheduler that owns and drives all server-side ECS systems.

    Contexts register their systems during `KnitStart()` via `RegisterSystem()`.
    `Runtime.server.lua` calls `Initialize()` after `Knit.Start()` resolves, which
    builds the pipeline, flushes queued systems, and connects to `RunService.Heartbeat`.

    Phase execution order (per Heartbeat frame):
    1. `NPCPositionPoll`  — Model CFrame → PositionComponent
    2. `NPCSync`          — Animation state sync for dirty entities
    3. `CombatTick`       — Per-user combat: BT + Actions + Completion
    4. `WorkerSync`       — Worker dirty entity sync
    5. `LotSync`          — Lot dirty entity sync
    6. `BuildingSync`     — Building dirty entity sync
    7. `MachineRuntime`  — Fuel burn + smelt progress for lot machines
    8. `WorkerProduction` — Production + Mining (gated: runs once per second)
    @server
]=]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local _initialized = false
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
    @return number -- Seconds elapsed since the last Heartbeat frame
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

function ServerScheduler:_BuildHeartbeatPipeline()
	local pipeline = Planck.Pipeline.new("ServerHeartbeat")
	for _, entry in ipairs(Phases) do
		pipeline:insert(entry.Phase)
	end
	_scheduler:insert(pipeline, RunService, "Heartbeat")
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

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local WaveConfig = require(ReplicatedStorage.Contexts.Wave.Config.WaveConfig)
local WaveTypes = require(ReplicatedStorage.Contexts.Wave.Types.WaveTypes)

local Errors = require(script.Parent.Parent.Parent.Errors)

type WaveComposition = WaveTypes.WaveComposition

--[=[
	@class WaveSpawnScheduler
	Schedules cancellable drip-spawn callbacks for a wave composition.
	@server
]=]
local WaveSpawnScheduler = {}
WaveSpawnScheduler.__index = WaveSpawnScheduler

--[=[
	Creates a new wave-spawn scheduler.
	@within WaveSpawnScheduler
	@return WaveSpawnScheduler -- The new scheduler instance.
]=]
function WaveSpawnScheduler.new()
	local self = setmetatable({}, WaveSpawnScheduler)
	self._activeThreads = {} :: { thread }
	self._generation = 0
	return self
end

--[=[
	Initializes the scheduler for registry ownership.
	@within WaveSpawnScheduler
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function WaveSpawnScheduler:Init(_registry: any, _name: string)
end

-- Tracks a spawned task handle so cancellation can clean it up later.
function WaveSpawnScheduler:_Track(handle: thread?)
	if handle then
		table.insert(self._activeThreads, handle)
	end
end

--[=[
	Schedules delayed spawn callbacks for each group and enemy in a composition.
	@within WaveSpawnScheduler
	@param composition WaveComposition -- The ordered wave composition.
	@param spawnCFrames { CFrame } -- Available spawn points for round-robin placement.
	@param waveNumber number -- The current wave number.
	@param onSpawned function -- Callback invoked when a spawn becomes active.
]=]
function WaveSpawnScheduler:Schedule(
	composition: WaveComposition,
	spawnCFrames: { CFrame },
	waveNumber: number,
	onSpawned: () -> ()
)
	-- Replace any previous schedule so stale callbacks cannot leak into the new wave.
	self:CancelAll()

	if #spawnCFrames == 0 then
		Result.MentionError("Wave:WaveSpawnScheduler", Errors.NO_SPAWN_POINTS, { WaveNumber = waveNumber }, "NoSpawnPoints")
		return
	end

	local generation = self._generation

	for _, group in composition do
		-- Delay the group so composition pacing survives the whole wave lifecycle.
		local outerHandle = task.delay(group.groupDelay, function()
			if self._generation ~= generation then
				return
			end

			for unitIndex = 1, group.count do
				-- Drip each unit within the group so the lane pressure ramps gradually.
				local spawnDelay = (unitIndex - 1) * WaveConfig.SPAWN_DRIP_INTERVAL
				local innerHandle = task.delay(spawnDelay, function()
					if self._generation ~= generation then
						return
					end

					local spawnIndex = ((unitIndex - 1) % #spawnCFrames) + 1
					local spawnCFrame = spawnCFrames[spawnIndex]

					-- Mark the spawn active before listeners react, so death callbacks cannot race the counter.
					onSpawned()
					GameEvents.Bus:Emit(GameEvents.Events.Wave.SpawnEnemy, group.role, spawnCFrame, waveNumber)
				end)

				self:_Track(innerHandle)
			end
		end)

		self:_Track(outerHandle)
	end
end

--[=[
	Cancels every pending spawn task and invalidates older generations.
	@within WaveSpawnScheduler
]=]
function WaveSpawnScheduler:CancelAll()
	self._generation += 1

	for _, activeThread in self._activeThreads do
		task.cancel(activeThread)
	end

	table.clear(self._activeThreads)
end

return WaveSpawnScheduler

--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(script.Parent.Lifecycle)
local ParallelRunner = if RunService:IsServer() then require(ReplicatedStorage.Utilities.ParallelRunner) else nil
local Query = require(script.Parent.Query)
local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox
type THitboxRunner = Types.HitboxRunner

type TPendingParallelHitbox = {
	Hitbox: THitbox,
	QueryCFrame: CFrame,
	Size: Vector3,
	ShapeId: number,
	FilterToken: string,
}

type TParallelSnapshot = {
	Hitboxes: { THitbox },
	QueryCFrames: { CFrame },
	Sizes: { Vector3 },
	ShapeIds: { number },
	FilterTokens: { string },
	DispatchSerial: number,
}

type TParallelResult = {
	DispatchSerial: number,
	Snapshot: TParallelSnapshot,
	Rows: { [string]: any }?,
	Err: any?,
}

local internalRunnerConnection: RBXScriptConnection? = nil
local internalRunner: THitboxRunner? = nil

local OPERATION_NAME = "MuchachoHitboxPresence"
local PARALLEL_ACTOR_COUNT = 32
local PARALLEL_BATCH_SIZE = 1

local Runner = {}

local function _CreateAsyncState()
	return {
		NextDispatchSerial = 0,
		LatestAppliedDispatchSerial = 0,
		LatestCompletedResult = nil,
		InFlight = false,
		InFlightDispatchSerial = nil,
		InFlightHandle = nil,
		ShouldDropInFlightResult = false,
	}
end

local function _CreateParallelSnapshot(
	pendingHitboxes: { TPendingParallelHitbox },
	dispatchSerial: number
): TParallelSnapshot
	local snapshot: TParallelSnapshot = {
		Hitboxes = table.create(#pendingHitboxes),
		QueryCFrames = table.create(#pendingHitboxes),
		Sizes = table.create(#pendingHitboxes),
		ShapeIds = table.create(#pendingHitboxes),
		FilterTokens = table.create(#pendingHitboxes),
		DispatchSerial = dispatchSerial,
	}

	for index, pendingHitbox in ipairs(pendingHitboxes) do
		snapshot.Hitboxes[index] = pendingHitbox.Hitbox
		snapshot.QueryCFrames[index] = pendingHitbox.QueryCFrame
		snapshot.Sizes[index] = pendingHitbox.Size
		snapshot.ShapeIds[index] = pendingHitbox.ShapeId
		snapshot.FilterTokens[index] = pendingHitbox.FilterToken
	end

	return snapshot
end

local function _ApplySerialForSnapshot(runner: THitboxRunner, snapshot: TParallelSnapshot)
	for index, hitbox in ipairs(snapshot.Hitboxes) do
		if hitbox._Runner == runner then
			Lifecycle.RunSerialDetection(hitbox, snapshot.QueryCFrames[index])
		end
	end
end

local function _ApplyCompletedResult(runner: THitboxRunner)
	local state = runner._queryAsyncState
	local result = state.LatestCompletedResult :: TParallelResult?
	if result == nil then
		return
	end

	state.LatestCompletedResult = nil
	if result.DispatchSerial <= state.LatestAppliedDispatchSerial then
		return
	end

	state.LatestAppliedDispatchSerial = result.DispatchSerial
	if result.Err ~= nil or result.Rows == nil then
		_ApplySerialForSnapshot(runner, result.Snapshot)
		return
	end

	for _, row in ipairs(result.Rows) do
		local hitboxIndex = row.HitboxIndex
		if type(hitboxIndex) ~= "number" then
			continue
		end

		local hitbox = result.Snapshot.Hitboxes[hitboxIndex]
		local queryCFrame = result.Snapshot.QueryCFrames[hitboxIndex]
		if hitbox == nil or queryCFrame == nil or hitbox._Runner ~= runner then
			continue
		end

		if row.HasAny == true then
			Lifecycle.RunSerialDetection(hitbox, queryCFrame)
		else
			Lifecycle.RunNoHitDetection(hitbox)
		end
	end
end

local function _DispatchParallelSnapshot(runner: THitboxRunner, snapshot: TParallelSnapshot)
	local parallelRunner = runner._parallelRunner
	local state = runner._queryAsyncState
	if parallelRunner == nil then
		_ApplySerialForSnapshot(runner, snapshot)
		return
	end

	local dispatchSerial = snapshot.DispatchSerial
	state.InFlight = true
	state.InFlightDispatchSerial = dispatchSerial
	state.InFlightHandle = nil
	state.ShouldDropInFlightResult = false

	local runResult = parallelRunner:Run({
		JobName = OPERATION_NAME,
		Args = {
			DispatchSerial = dispatchSerial,
		},
		LogicalWorkCount = #snapshot.Hitboxes,
		BatchSize = PARALLEL_BATCH_SIZE,
		WorkerPayload = {
			QueryCFrames = snapshot.QueryCFrames,
			Sizes = snapshot.Sizes,
			ShapeIds = snapshot.ShapeIds,
			FilterTokens = snapshot.FilterTokens,
		},
	})
	if not runResult.success then
		state.InFlight = false
		state.InFlightDispatchSerial = nil
		state.InFlightHandle = nil
		_ApplySerialForSnapshot(runner, snapshot)
		return
	end

	local handle = runResult.value
	state.InFlightHandle = handle

	handle
		:GetPromise()
		:andThen(function(result)
			if state.InFlightDispatchSerial ~= dispatchSerial then
				return
			end

			state.InFlight = false
			state.InFlightDispatchSerial = nil
			state.InFlightHandle = nil
			if state.ShouldDropInFlightResult then
				state.ShouldDropInFlightResult = false
				return
			end

			if result.success then
				state.LatestCompletedResult = {
					DispatchSerial = dispatchSerial,
					Snapshot = snapshot,
					Rows = result.value.Rows :: any,
					Err = nil,
				}
				return
			end

			state.LatestCompletedResult = {
				DispatchSerial = dispatchSerial,
				Snapshot = snapshot,
				Rows = nil,
				Err = result,
			}
		end)
		:catch(function(err)
			if state.InFlightDispatchSerial ~= dispatchSerial then
				return
			end

			state.InFlight = false
			state.InFlightDispatchSerial = nil
			state.InFlightHandle = nil
			if state.ShouldDropInFlightResult then
				state.ShouldDropInFlightResult = false
				return
			end

			state.LatestCompletedResult = {
				DispatchSerial = dispatchSerial,
				Snapshot = snapshot,
				Rows = nil,
				Err = err,
			}
		end)
end

local function _CreateParallelRunner()
	if ParallelRunner == nil then
		return nil
	end

	local runner = ParallelRunner.new({
		Name = "MuchachoHitboxPresenceRunner",
		ActorCount = PARALLEL_ACTOR_COUNT,
		DefaultBatchSize = PARALLEL_BATCH_SIZE,
	})

	local registerResult = runner:RegisterJob({
		Job = require(script.Parent:WaitForChild("ParallelPresenceOperation") :: ModuleScript),
		WorkerModule = script.Parent:WaitForChild("ParallelPresenceWorker") :: ModuleScript,
	})
	if registerResult.success then
		return runner
	end

	local destroyResult = runner:Destroy()
	if not destroyResult.success then
		return nil
	end

	return nil
end

function Runner.Create(): THitboxRunner
	local runner = {} :: THitboxRunner
	runner._hitboxes = {}
	runner._destroyed = false
	runner._parallelRunner = _CreateParallelRunner()
	runner._queryAsyncState = _CreateAsyncState()

	function runner:Register(hitbox: THitbox)
		if self._destroyed then
			error("Cannot register hitbox on a destroyed MuchachoHitbox runner")
		end

		self._hitboxes[hitbox] = true
	end

	function runner:Unregister(hitbox: THitbox)
		self._hitboxes[hitbox] = nil
	end

	function runner:Step(deltaTime: number)
		if self._destroyed then
			return
		end

		_ApplyCompletedResult(self)

		local serialHitboxes = {}
		local parallelHitboxes = {}

		for hitbox in pairs(self._hitboxes) do
			if hitbox._Runner ~= self then
				continue
			end
			if not Lifecycle.IsStepDue(hitbox, deltaTime) then
				continue
			end

			local queryCFrame = Lifecycle.ResolveStep(hitbox)
			local parallelSnapshot = Query.BuildParallelSnapshot(hitbox, queryCFrame)
			if parallelSnapshot == nil then
				table.insert(serialHitboxes, {
					Hitbox = hitbox,
					QueryCFrame = queryCFrame,
				})
				continue
			end

			table.insert(parallelHitboxes, {
				Hitbox = hitbox,
				QueryCFrame = queryCFrame,
				Size = parallelSnapshot.Size,
				ShapeId = parallelSnapshot.ShapeId,
				FilterToken = parallelSnapshot.FilterToken,
			})
		end

		for _, pendingHitbox in ipairs(serialHitboxes) do
			if pendingHitbox.Hitbox._Runner == self then
				Lifecycle.RunSerialDetection(pendingHitbox.Hitbox, pendingHitbox.QueryCFrame)
			end
		end

		if #parallelHitboxes == 0 then
			return
		end

		local nextDispatchSerial = self._queryAsyncState.NextDispatchSerial + 1
		self._queryAsyncState.NextDispatchSerial = nextDispatchSerial
		local snapshot = _CreateParallelSnapshot(parallelHitboxes, nextDispatchSerial)
		if self._queryAsyncState.InFlight then
			self._queryAsyncState.ShouldDropInFlightResult = true
			_ApplySerialForSnapshot(self, snapshot)
			return
		end

		_DispatchParallelSnapshot(self, snapshot)
	end

	function runner:Destroy()
		if self._destroyed then
			return
		end

		self._destroyed = true
		local asyncState = self._queryAsyncState
		local inFlightHandle = asyncState.InFlightHandle
		if inFlightHandle ~= nil then
			inFlightHandle:Cancel()
		end
		asyncState.InFlight = false
		asyncState.InFlightDispatchSerial = nil
		asyncState.InFlightHandle = nil
		asyncState.ShouldDropInFlightResult = false
		asyncState.LatestCompletedResult = nil

		local parallelRunner = self._parallelRunner
		if parallelRunner ~= nil then
			parallelRunner:Destroy()
			self._parallelRunner = nil
		end

		for hitbox in pairs(self._hitboxes) do
			if hitbox._Runner == self then
				hitbox._Runner = nil
			end
		end

		table.clear(self._hitboxes)
	end

	return runner
end

function Runner.GetInternal(): THitboxRunner
	if internalRunner == nil then
		internalRunner = Runner.Create()
	end

	if internalRunnerConnection == nil then
		internalRunnerConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			local runner = internalRunner
			if runner ~= nil then
				runner:Step(deltaTime)
			end
		end)
	end

	return internalRunner
end

return Runner

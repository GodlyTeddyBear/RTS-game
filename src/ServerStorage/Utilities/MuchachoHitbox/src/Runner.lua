--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Lifecycle = require(script.Parent.Lifecycle)
local ParallelRunner = if RunService:IsServer() then require(ServerStorage.Utilities.ParallelRunner) else nil
local Query = require(script.Parent.Query)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)
local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox
type THitboxRunner = Types.HitboxRunner
type TTableRecyclerHandle = TableRecycler.TTableRecyclerHandle

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
local PARALLEL_MISS_THRESHOLD = 2

local Runner = {}

local function _CreateAsyncState()
	return {
		NextDispatchSerial = 0,
		LatestAppliedDispatchSerial = 0,
		LatestCompletedResult = nil,
		InFlight = false,
		InFlightDispatchSerial = nil,
		InFlightHandle = nil,
		InFlightSnapshot = nil,
		ShouldDropInFlightResult = false,
	}
end

local function _CreateRecycler(): TTableRecyclerHandle
	return TableRecycler.new({
		Strict = true,
		DebugName = "MuchachoHitbox.Runner",
	})
end

local function _AcquireArray<TValue>(runner: THitboxRunner, capacityHint: number?): { TValue }
	return runner._tableRecycler:AcquireArray(capacityHint) :: { TValue }
end

local function _AcquireMap<TKey, TValue>(runner: THitboxRunner): { [TKey]: TValue }
	return runner._tableRecycler:AcquireMap() :: { [TKey]: TValue }
end

local function _ReleaseArray(runner: THitboxRunner, tbl: { any })
	local didRelease, releaseError = runner._tableRecycler:ReleaseArray(tbl)
	assert(didRelease, releaseError)
end

local function _ReleaseMap(runner: THitboxRunner, tbl: { [any]: any })
	local didRelease, releaseError = runner._tableRecycler:ReleaseMap(tbl)
	assert(didRelease, releaseError)
end

local function _CreateParallelSnapshot(runner: THitboxRunner, dispatchSerial: number): TParallelSnapshot
	local snapshot = _AcquireMap(runner) :: any
	snapshot.Hitboxes = _AcquireArray(runner, nil)
	snapshot.QueryCFrames = _AcquireArray(runner, nil)
	snapshot.Sizes = _AcquireArray(runner, nil)
	snapshot.ShapeIds = _AcquireArray(runner, nil)
	snapshot.FilterTokens = _AcquireArray(runner, nil)
	snapshot.DispatchSerial = dispatchSerial
	return snapshot :: TParallelSnapshot
end

local function _ReleaseParallelSnapshot(runner: THitboxRunner, snapshot: TParallelSnapshot)
	_ReleaseMap(runner, snapshot :: any)
end

local function _ApplySerialForSnapshot(runner: THitboxRunner, snapshot: TParallelSnapshot)
	for index, hitbox in ipairs(snapshot.Hitboxes) do
		if hitbox._Runner == runner then
			local didHitAny = Lifecycle.RunSerialDetection(hitbox, snapshot.QueryCFrames[index])
			hitbox._ParallelMissCount = if didHitAny then 0 else ((hitbox._ParallelMissCount or 0) + 1)
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
		_ReleaseParallelSnapshot(runner, result.Snapshot)
		return
	end

	state.LatestAppliedDispatchSerial = result.DispatchSerial
	if result.Err ~= nil or result.Rows == nil then
		_ApplySerialForSnapshot(runner, result.Snapshot)
		_ReleaseParallelSnapshot(runner, result.Snapshot)
		return
	end

	for _, row in result.Rows do
		local hitboxIndex = row.HitboxIndex
		if type(hitboxIndex) ~= "number" then
			continue
		end

		local hitbox = result.Snapshot.Hitboxes[hitboxIndex]
		local queryCFrame = result.Snapshot.QueryCFrames[hitboxIndex]
		if not hitbox or not queryCFrame or hitbox._Runner ~= runner then
			continue
		end

		if row.HasAny then
			local didHitAny = Lifecycle.RunSerialDetection(hitbox, queryCFrame)
			hitbox._ParallelMissCount = if didHitAny then 0 else ((hitbox._ParallelMissCount or 0) + 1)
		else
			Lifecycle.RunNoHitDetection(hitbox)
			hitbox._ParallelMissCount = (hitbox._ParallelMissCount or 0) + 1
		end
	end

	_ReleaseParallelSnapshot(runner, result.Snapshot)
end

local function _DispatchParallelSnapshot(runner: THitboxRunner, snapshot: TParallelSnapshot)
	local parallelRunner = runner._parallelRunner
	local state = runner._queryAsyncState
	if not parallelRunner then
		_ApplySerialForSnapshot(runner, snapshot)
		_ReleaseParallelSnapshot(runner, snapshot)
		return
	end

	local dispatchSerial = snapshot.DispatchSerial
	state.InFlight = true
	state.InFlightDispatchSerial = dispatchSerial
	state.InFlightHandle = nil
	state.InFlightSnapshot = snapshot
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
		state.InFlightSnapshot = nil
		_ApplySerialForSnapshot(runner, snapshot)
		_ReleaseParallelSnapshot(runner, snapshot)
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

			local completedSnapshot = state.InFlightSnapshot :: TParallelSnapshot
			state.InFlight = false
			state.InFlightDispatchSerial = nil
			state.InFlightHandle = nil
			state.InFlightSnapshot = nil
			if state.ShouldDropInFlightResult then
				state.ShouldDropInFlightResult = false
				_ReleaseParallelSnapshot(runner, completedSnapshot)
				return
			end

			if result.success then
				state.LatestCompletedResult = {
					DispatchSerial = dispatchSerial,
					Snapshot = completedSnapshot,
					Rows = result.value.Rows :: any,
					Err = nil,
				}
				return
			end

			state.LatestCompletedResult = {
				DispatchSerial = dispatchSerial,
				Snapshot = completedSnapshot,
				Rows = nil,
				Err = result,
			}
		end)
		:catch(function(err)
			if state.InFlightDispatchSerial ~= dispatchSerial then
				return
			end

			local completedSnapshot = state.InFlightSnapshot :: TParallelSnapshot
			state.InFlight = false
			state.InFlightDispatchSerial = nil
			state.InFlightHandle = nil
			state.InFlightSnapshot = nil
			if state.ShouldDropInFlightResult then
				state.ShouldDropInFlightResult = false
				_ReleaseParallelSnapshot(runner, completedSnapshot)
				return
			end

			state.LatestCompletedResult = {
				DispatchSerial = dispatchSerial,
				Snapshot = completedSnapshot,
				Rows = nil,
				Err = err,
			}
		end)
end

local function _CreateParallelRunner()
	if not ParallelRunner then
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
	runner._tableRecycler = _CreateRecycler()

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

		local serialHitboxes = _AcquireArray(self, nil)
		local serialQueryCFrames = _AcquireArray(self, nil)
		local nextDispatchSerial = self._queryAsyncState.NextDispatchSerial + 1
		local snapshot = _CreateParallelSnapshot(self, nextDispatchSerial)

		for hitbox in pairs(self._hitboxes) do
			if hitbox._Runner ~= self then
				continue
			end
			if not Lifecycle.IsStepDue(hitbox, deltaTime) then
				continue
			end

			local queryCFrame = Lifecycle.ResolveStep(hitbox)
			local missCount = hitbox._ParallelMissCount or 0
			if missCount < PARALLEL_MISS_THRESHOLD then
				table.insert(serialHitboxes, hitbox)
				table.insert(serialQueryCFrames, queryCFrame)
				continue
			end

			local parallelSize, shapeId, filterToken = Query.BuildParallelSnapshot(hitbox, queryCFrame)
			if not parallelSize or not shapeId or not filterToken then
				table.insert(serialHitboxes, hitbox)
				table.insert(serialQueryCFrames, queryCFrame)
				continue
			end

			table.insert(snapshot.Hitboxes, hitbox)
			table.insert(snapshot.QueryCFrames, queryCFrame)
			table.insert(snapshot.Sizes, parallelSize)
			table.insert(snapshot.ShapeIds, shapeId)
			table.insert(snapshot.FilterTokens, filterToken)
		end

		for index, hitbox in ipairs(serialHitboxes) do
			if hitbox._Runner == self then
				local didHitAny = Lifecycle.RunSerialDetection(hitbox, serialQueryCFrames[index])
				hitbox._ParallelMissCount = if didHitAny then 0 else ((hitbox._ParallelMissCount or 0) + 1)
			end
		end
		_ReleaseArray(self, serialQueryCFrames)
		_ReleaseArray(self, serialHitboxes)

		if #snapshot.Hitboxes == 0 then
			_ReleaseParallelSnapshot(self, snapshot)
			return
		end

		self._queryAsyncState.NextDispatchSerial = nextDispatchSerial
		if self._queryAsyncState.InFlight then
			self._queryAsyncState.ShouldDropInFlightResult = true
			_ApplySerialForSnapshot(self, snapshot)
			_ReleaseParallelSnapshot(self, snapshot)
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
		if inFlightHandle then
			inFlightHandle:Cancel()
		end
		asyncState.InFlight = false
		asyncState.InFlightDispatchSerial = nil
		asyncState.InFlightHandle = nil
		local inFlightSnapshot = asyncState.InFlightSnapshot :: TParallelSnapshot?
		if inFlightSnapshot then
			_ReleaseParallelSnapshot(self, inFlightSnapshot)
		end
		asyncState.InFlightSnapshot = nil
		asyncState.ShouldDropInFlightResult = false
		local latestCompletedResult = asyncState.LatestCompletedResult :: TParallelResult?
		if latestCompletedResult then
			_ReleaseParallelSnapshot(self, latestCompletedResult.Snapshot)
		end
		asyncState.LatestCompletedResult = nil

		local parallelRunner = self._parallelRunner
		if parallelRunner then
			parallelRunner:Destroy()
			self._parallelRunner = nil
		end

		for hitbox in pairs(self._hitboxes) do
			if hitbox._Runner == self then
				hitbox._Runner = nil
			end
		end

		table.clear(self._hitboxes)
		local didDestroyRecycler, destroyRecyclerError = self._tableRecycler:Destroy()
		assert(didDestroyRecycler, destroyRecyclerError)
	end

	return runner
end

function Runner.GetInternal(): THitboxRunner
	if not internalRunner then
		internalRunner = Runner.Create()
	end

	if not internalRunnerConnection then
		internalRunnerConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			local runner = internalRunner
			if runner then
				runner:Step(deltaTime)
			end
		end)
	end

	return internalRunner
end

return Runner

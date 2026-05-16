--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(script.Parent.Lifecycle)
local Query = require(script.Parent.Query)
local ParallelQuery = if RunService:IsServer() then require(ReplicatedStorage.Utilities.ParallelQuery) else nil
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
}

type TParallelResult = {
	RequestId: number,
	Snapshot: TParallelSnapshot,
	Rows: { [string]: any }?,
	Err: any?,
}

local internalRunnerConnection: RBXScriptConnection? = nil
local internalRunner: THitboxRunner? = nil

local OPERATION_NAME = "MuchachoHitboxPresence"
local PARALLEL_ACTOR_COUNT = 32
local PARALLEL_BATCH_SIZE = 1
local PARALLEL_TIMEOUT_SECONDS = 0.2

local Runner = {}

local function _CreateAsyncState()
	return {
		PendingRequestId = 0,
		LatestAppliedRequestId = 0,
		LatestCompletedResult = nil,
		InFlight = false,
		InFlightRequestId = nil,
		ShouldDropInFlightResult = false,
	}
end

local function _CreateParallelMemory(snapshot: TParallelSnapshot): SharedTable
	local memory = SharedTable.new()
	local queryCFrames = SharedTable.new()
	local sizes = SharedTable.new()
	local shapeIds = SharedTable.new()
	local filterTokens = SharedTable.new()

	for index, queryCFrame in ipairs(snapshot.QueryCFrames) do
		queryCFrames[index] = queryCFrame
		sizes[index] = snapshot.Sizes[index]
		shapeIds[index] = snapshot.ShapeIds[index]
		filterTokens[index] = snapshot.FilterTokens[index]
	end

	memory.QueryCFrames = queryCFrames
	memory.Sizes = sizes
	memory.ShapeIds = shapeIds
	memory.FilterTokens = filterTokens
	return memory
end

local function _CreateParallelSnapshot(pendingHitboxes: { TPendingParallelHitbox }): TParallelSnapshot
	local snapshot: TParallelSnapshot = {
		Hitboxes = table.create(#pendingHitboxes),
		QueryCFrames = table.create(#pendingHitboxes),
		Sizes = table.create(#pendingHitboxes),
		ShapeIds = table.create(#pendingHitboxes),
		FilterTokens = table.create(#pendingHitboxes),
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
	if result.RequestId <= state.LatestAppliedRequestId then
		return
	end

	state.LatestAppliedRequestId = result.RequestId
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

	local requestId = state.PendingRequestId + 1
	state.PendingRequestId = requestId
	state.InFlight = true
	state.InFlightRequestId = requestId
	state.ShouldDropInFlightResult = false

	local promise = nil
	local ok = pcall(function()
		parallelRunner:SetLocalMemory(OPERATION_NAME, _CreateParallelMemory(snapshot))
		promise = parallelRunner:RunAsync(OPERATION_NAME, {
			WorkCount = #snapshot.Hitboxes,
			BatchSize = PARALLEL_BATCH_SIZE,
			TimeoutSeconds = PARALLEL_TIMEOUT_SECONDS,
		})
	end)

	if not ok or promise == nil then
		state.InFlight = false
		state.InFlightRequestId = nil
		_ApplySerialForSnapshot(runner, snapshot)
		return
	end

	promise
		:andThen(function(rows)
			if state.InFlightRequestId ~= requestId then
				return
			end

			state.InFlight = false
			state.InFlightRequestId = nil
			if state.ShouldDropInFlightResult then
				state.ShouldDropInFlightResult = false
				return
			end

			state.LatestCompletedResult = {
				RequestId = requestId,
				Snapshot = snapshot,
				Rows = rows :: any,
				Err = nil,
			}
		end)
		:catch(function(err)
			if state.InFlightRequestId ~= requestId then
				return
			end

			state.InFlight = false
			state.InFlightRequestId = nil
			if state.ShouldDropInFlightResult then
				state.ShouldDropInFlightResult = false
				return
			end

			state.LatestCompletedResult = {
				RequestId = requestId,
				Snapshot = snapshot,
				Rows = nil,
				Err = err,
			}
		end)
end

local function _CreateParallelRunner(): any
	if ParallelQuery == nil then
		return nil
	end

	return ParallelQuery.new({
		Name = "MuchachoHitboxPresenceRunner",
		ActorCount = PARALLEL_ACTOR_COUNT,
		Operations = {
			script.Parent:WaitForChild("ParallelPresenceOperation") :: ModuleScript,
		},
	})
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

		if self._queryAsyncState.InFlight then
			self._queryAsyncState.ShouldDropInFlightResult = true
			_ApplySerialForSnapshot(self, _CreateParallelSnapshot(parallelHitboxes))
			return
		end

		_DispatchParallelSnapshot(self, _CreateParallelSnapshot(parallelHitboxes))
	end

	function runner:Destroy()
		if self._destroyed then
			return
		end

		self._destroyed = true
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

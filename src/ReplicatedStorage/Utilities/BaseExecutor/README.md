# BaseExecutor

Shared executor base for behavior-tree actions that need synchronous ticks, Promise-backed async work, explicit partial progress, and deterministic cleanup keyed by entity id.

## What It Does

`BaseExecutor` owns reusable execution mechanics for shared action executors:

- runs the common action lifecycle through `Start`, `Tick`, `Cancel`, `Complete`, and `Death`
- tracks executor-local state per entity id
- tracks Promise-only async work and polls it from synchronous ticks
- tracks cursor-based partial work across multiple ticks
- gates combined async + partial progression through `TickCombined`
- invalidates stale async completions with per-entity generation tokens
- clears Promise, cursor, and tracked async resources during terminal lifecycle paths

The base does **not** own:

- behavior-tree authoring
- action selection policy
- entity storage outside executor-local state
- gameplay-specific chunking rules
- Promise creation logic for a concrete action
- action-specific success or failure semantics beyond the shared status strings

## Folder Layout

- `init.lua` - package entry point and exported types
- `src/init.lua` - composed base class surface
- `src/Types.lua` - shared executor, Promise, and cursor types
- `src/Public/Lifecycle.lua` - lifecycle entrypoints and generation invalidation
- `src/Public/Status.lua` - shared `Running`, `Success`, `Fail` helpers
- `src/Public/EntityState.lua` - entity-scoped state bag helpers
- `src/Public/AsyncResources.lua` - generic tracked async resource cleanup
- `src/Public/PromiseState.lua` - Promise-only async slots and polling helpers
- `src/Public/CursorState.lua` - cursor slot helpers and snapshot reads
- `src/Public/TickHelpers.lua` - `TickPromise`, `TickPartial`, and `TickCombined`
- `src/Public/Guards.lua` - shared guard execution helpers

## Public Surface

Lifecycle:

- `Start(entity, data, services)`
- `Tick(entity, dt, services)`
- `Cancel(entity, services)`
- `Complete(entity, services)`
- `Death(entity, services)`
- `CanStart`, `OnStart`, `CanContinue`, `OnTick`, `OnCancel`, `OnComplete`, `OnDeath`

Statuses:

- `Running()`
- `Success()`
- `Fail(entity, reason?)`
- `GetLastFailureReason(entity)`

Entity state:

- `GetEntityState(entity)`
- `SetEntityValue(entity, key, value)`
- `GetEntityValue(entity, key)`
- `HasEntityValue(entity, key)`
- `GetOrCreateEntityValue(entity, key, createValue)`
- `ClearEntityValue(entity, key)`
- `ClearEntityState(entity)`

Promise-only async:

- `BeginPromise(entity, key, promise, options?)`
- `GetPromiseState(entity, key)`
- `GetPromiseSnapshot(entity, key)`
- `GetPromiseStatus(entity, key)`
- `GetPromiseResult(entity, key)`
- `GetPromiseError(entity, key)`
- `HasPendingPromise(entity, key)`
- `HasResolvedPromise(entity, key)`
- `HasRejectedPromise(entity, key)`
- `PollPromise(entity, key)`
- `ConsumePromiseResult(entity, key, shouldClear?)`
- `ConsumePromiseError(entity, key, shouldClear?)`
- `CancelPromise(entity, key)`
- `ClearPromise(entity, key, shouldCancel?)`
- `ClearAllPromises(entity, shouldCancel?)`

Cursor / partial work:

- `BeginCursor(entity, key, initialCursor)`
- `GetCursor(entity, key)`
- `GetCursorSnapshot(entity, key)`
- `GetCursorPhase(entity, key)`
- `SetCursorPhase(entity, key, phase)`
- `GetCursorIndex(entity, key)`
- `SetCursorIndex(entity, key, index)`
- `AdvanceCursorIndex(entity, key, amount)`
- `MarkCursorDone(entity, key, result?)`
- `IsCursorDone(entity, key)`
- `GetCursorData(entity, key)`
- `SetCursorData(entity, key, data)`
- `ClearCursor(entity, key)`
- `ClearAllCursors(entity)`

Combined helpers:

- `TickCursor(entity, key, callback)`
- `RunCursorChunk(entity, key, callback)`
- `TransitionCursorPhase(entity, key, nextPhase, resetFields?)`
- `TickPartial(entity, key, dt, services, config)`
- `TickPromise(entity, key, dt, services, config)`
- `TickCombined(entity, dt, services, config)`
- `ArePromisesResolved(entity, keys)`
- `HasPromiseRejected(entity, keys)`
- `AreCursorsDone(entity, keys)`
- `IsCombinedWorkDone(entity, config)`
- `IsWorkPending(entity, config)`

Queue helpers:

- `BeginQueue(queueKey, config)`
- `HasQueue(queueKey)`
- `ClearQueue(queueKey)`
- `ClearAllQueues()`
- `IsQueued(entity, queueKey)`
- `Enqueue(entity, queueKey, metadata?)`
- `Dequeue(entity, queueKey)`
- `RemoveEntityFromQueues(entity)`
- `HasQueuedWork(queueKey)`
- `GetQueueSize(queueKey)`
- `GetQueueSnapshot(queueKey)`
- `RequestQueueTurn(entity, queueKey, services, config)`
- `RunQueued(entity, queueKey, services, config)`

Generation and cleanup:

- `BumpEntityGeneration(entity)`
- `GetEntityGeneration(entity)`
- `CaptureEntityGeneration(entity)`
- `IsGenerationCurrent(entity, generation)`
- `TrackAsyncResource(entity, key, resource, cleanup?)`
- `GetAsyncResource(entity, key)`
- `ReleaseAsyncResource(entity, key, shouldCleanup?)`
- `CleanupAsyncResources(entity)`
- `TrackTask(entity, key, taskLike)`
- `GetTrackedTask(entity, key)`
- `ClearTrackedTask(entity, key)`
- `CancelTrackedTasks(entity)`

## Lifecycle Model

`BaseExecutor` stays synchronous at the runtime boundary.

1. `Start` runs `CanStart`, bumps the entity generation, then calls `OnStart`.
2. `Tick` runs `CanContinue`, then calls `OnTick`.
3. `Cancel`, `Complete`, and `Death` are terminal lifecycle paths.
4. `Cancel` and `Death` always clear Promise slots, cursor slots, tracked async resources, and entity state.
5. `Complete` always clears Promise slots, cursor slots, tracked async resources, and cursor gating state. `AutoCleanupOnComplete` only controls whether generic `_entityState` is also cleared.

The runtime only needs the shared status strings:

- `Running` - keep ticking
- `Success` - finish cleanly
- `Fail` - fail or cancel the action

## Async Work

Async work must enter `BaseExecutor` as a Promise.

- `BeginPromise` registers a Promise under an entity + key and captures the current entity generation.
- Promise settlement is written into executor-local Promise state and later polled from `Tick`.
- `PollPromise` reports the current slot state such as `Pending`, `Resolved`, `Rejected`, `Cancelled`, or `Missing`.
- `ConsumePromiseResult` and `ConsumePromiseError` read settled data and can optionally clear the slot.
- `CancelPromise` is terminal for that slot: it releases cleanup and removes the tracked Promise slot so later settlement cannot overwrite cancellation.

Important async rules:

- Promise work is polled from synchronous ticks; `Tick` does not yield.
- Missing Promise slots fail by default in `TickPromise`.
- `TickPromise` only treats a missing slot as non-fatal when `AllowMissingPromise = true`.
- Late Promise settlement is ignored after the entity generation changes or the slot is replaced.

## Partial Work

Partial work is explicit cursor state, not coroutines or suspended execution.

- `BeginCursor` creates one cursor slot for an entity and deep-clones the seed table.
- A cursor stores explicit progress such as `Phase`, `Index`, `BatchSize`, `IsDone`, `Data`, and `Meta`.
- `OnTick` or `TickPartial` advances one bounded chunk per frame.
- `MarkCursorDone` marks the cursor complete when the final chunk has been processed.

Typical cursor usage:

- initialize progress in `OnStart`
- read current phase and index in `OnTick`
- process one bounded chunk
- update the cursor with helper mutators
- return `Running` until the cursor is done

## Combined Async + Partial

Use `TickCombined` when one action needs both Promise polling and cursor-based progression.

`TickCombined` builds a combined state object containing:

- `state.Cursors` - read-only cursor snapshots
- `state.Promises` - read-only Promise snapshots
- `state.PromiseStatuses` - polled status strings by Promise key
- `state.CursorDependencies` - dependency map from cursor key to Promise keys
- `state.CursorCanAdvance` - whether each configured cursor is allowed to advance on this tick

Key contract:

- `TickCombined` provides read-only snapshots for inspection only.
- Cursor progress inside `Advance` must happen through cursor helper mutators such as `SetCursorIndex`, `AdvanceCursorIndex`, `SetCursorPhase`, `TransitionCursorPhase`, `SetCursorData`, and `MarkCursorDone`.
- `CursorDependencies` gates cursor advancement until the required Promise keys are all `Resolved`.
- A pending dependent Promise keeps that cursor parked.

## Queue Work

Use the queue helpers when one shared executor instance needs to throttle a specific step across many entities.

- Queues are shared per executor instance and `queueKey`.
- Queue servicing is synchronous and caller-driven from `Tick`.
- Queue servicing requires `services.TickId` as the canonical per-frame id. `FrameId` is only a temporary compatibility fallback.
- `BeginQueue` treats `CapacityPerTick` as queue-key owned config. Reusing the same queue key with a different capacity asserts.
- `RequestQueueTurn` returns `Granted`, `Queued`, or `Dropped`.
- `RunQueued` returns `Running` when still waiting, executes `config.Run` when granted, and resolves dropped turns through required `config.DroppedStatus` after `OnDropped` runs.
- `GetQueueSnapshot` is a debug snapshot. It reports wrapper state and buffered `SchedulePlus.Queue` state, but it is not a transactional source of truth.

## How To Use It

Typical usage pattern:

1. Create a subclass that inherits from `BaseExecutor`.
2. Return `BaseExecutor.new({ ActionId = "...", IsCommitted = ... })` from `.new()`.
3. Initialize Promise slots and/or cursor slots in `OnStart`.
4. In `OnTick`, either:
   - poll a Promise with `TickPromise`
   - advance a cursor with `TickPartial`
   - coordinate both with `TickCombined`
5. Let lifecycle cleanup clear tracked work through `Cancel`, `Complete`, or `Death`.

## Examples

### Promise-only

```lua
function AsyncExecutor:OnStart(entity, data, services)
	local promise = services.PathService:BuildAsync(data.Target)
	self:BeginPromise(entity, "PathBuild", promise)
end

function AsyncExecutor:OnTick(entity, dt, services)
	return self:TickPromise(entity, "PathBuild", dt, services, {
		OnResolved = function(result)
			self:SetEntityValue(entity, "BuiltPath", result)
		end,
	})
end
```

### Partial-only

```lua
function PartialExecutor:OnStart(entity, data, _services)
	self:BeginCursor(entity, "Scan", {
		Phase = "Scanning",
		Index = 1,
		BatchSize = 16,
		Data = {
			Items = data.Items,
		},
	})
end

function PartialExecutor:OnTick(entity, dt, services)
	return self:TickPartial(entity, "Scan", dt, services, {
		Run = function(cursor)
			local items = cursor.Data.Items
			local startIndex = cursor.Index
			local endIndex = math.min(startIndex + cursor.BatchSize - 1, #items)

			for index = startIndex, endIndex do
				services.ScanService:Visit(items[index])
			end

			if endIndex >= #items then
				self:MarkCursorDone(entity, "Scan")
				return "Success"
			end

			self:SetCursorIndex(entity, "Scan", endIndex + 1)
			return "Running"
		end,
	})
end
```

### Combined async + partial

```lua
function CombinedExecutor:OnStart(entity, data, services)
	self:BeginCursor(entity, "ApplyRows", {
		Phase = "WaitingForRows",
		Index = 1,
		BatchSize = 8,
		Data = {
			Rows = nil,
		},
	})

	local promise = services.RowService:BuildRowsAsync(data.Input)
	self:BeginPromise(entity, "RowsPromise", promise)
end

function CombinedExecutor:OnTick(entity, dt, services)
	return self:TickCombined(entity, dt, services, {
		CursorKeys = { "ApplyRows" },
		PromiseKeys = { "RowsPromise" },
		CursorDependencies = {
			ApplyRows = { "RowsPromise" },
		},
		Poll = function(state)
			local cursor = state.Cursors.ApplyRows
			if cursor == nil then
				return "Fail", "MissingCursor"
			end

			if cursor.Data.Rows == nil and state.PromiseStatuses.RowsPromise == "Resolved" then
				local rows = self:ConsumePromiseResult(entity, "RowsPromise")
				self:SetCursorData(entity, "ApplyRows", {
					Rows = rows,
				})
				self:TransitionCursorPhase(entity, "ApplyRows", "Applying")
			end

			return "Running"
		end,
		Advance = function(state)
			local cursor = state.Cursors.ApplyRows
			if cursor == nil or cursor.Phase ~= "Applying" then
				return "Running"
			end

			local rows = cursor.Data.Rows
			if type(rows) ~= "table" then
				return "Fail", "MissingRows"
			end

			local startIndex = cursor.Index
			local endIndex = math.min(startIndex + cursor.BatchSize - 1, #rows)

			for index = startIndex, endIndex do
				services.ApplyService:ApplyRow(entity, rows[index])
			end

			if endIndex >= #rows then
				self:MarkCursorDone(entity, "ApplyRows")
				return "Running"
			end

			self:SetCursorIndex(entity, "ApplyRows", endIndex + 1)
			return "Running"
		end,
		IsDone = function(state)
			return state.Cursors.ApplyRows ~= nil and state.Cursors.ApplyRows.IsDone == true
		end,
	})
end
```

In combined flows:

- read from `state.Cursors.ApplyRows`
- mutate stored progress with helper mutators on `self`
- do **not** mutate `state.Cursors.ApplyRows` directly

## Failure / Cleanup Notes

- Late Promise settlement is ignored after generation invalidation from `Cancel`, `Complete`, `Death`, or slot replacement.
- Cancelled Promises are terminal and removed from tracked slots.
- Dependent cursors stay parked while required Promise keys are still pending.
- Cursor seed tables are deep-cloned, so nested `Data` and `Meta` tables are isolated per entity.
- `TickCombined` snapshots are read-only by design; direct mutation there is not part of the contract.
- `ClearEntityState` is the destructive executor-local reset for entity state, Promise state, cursor state, generation state, and stored failure reasons.
- Queue cleanup is owned by `BaseExecutor` lifecycle paths. `Cancel`, `Complete`, `Death`, and `ClearEntityState` remove the entity from all queue memberships.
- `RunQueued` never returns raw `"Dropped"` to the runtime. The caller must provide `DroppedStatus` so the helper resolves dropped turns into a valid runtime status.

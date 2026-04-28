--[=[
    @class PathfindingHelper
    Shared utility for creating and running `SimplePath` instances while keeping
    lifecycle management, cleanup, and runtime guards out of movement contexts.

    Flow: validate entity model -> create path -> run path -> settle or cancel.
    This module owns path setup and promise coordination only; it does not own
    movement policy or entity construction.
    @server
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimplePath = require(ReplicatedStorage.Utilities.SimplePath)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Result = require(ReplicatedStorage.Utilities.Result)

-- ── Constants ────────────────────────────────────────────────────────────────

local DEFAULT_AGENT_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
}

local DEFAULT_PATH_OPTIONS = {
	VisualizeSimplePath = false,
	DebugTarget = false,
	InitialRunDelaySeconds = 0,
	RetryComputationErrors = false,
	ReconcileTargetYOnWaypointFailure = false,
	MaxTargetYReconcileAttempts = 0,
}

local COMPUTATION_ERROR_RETRY_COUNT = 1
local GUARD_LOG_THROTTLE_SECONDS = 1.0
local _lastGuardLogByKey: { [string]: number } = {}

local PathfindingHelper = {}

-- ── Private ──────────────────────────────────────────────────────────────────

-- Resolves the context factory that can provide a model reference for path setup.
local function _resolveFactory(services: any): any?
	if not services then
		return nil
	end

	return services.EntityFactory or services.NPCEntityFactory or services.EnemyEntityFactory
end

-- Throttles repeated guard logs so the same invalid path request does not spam diagnostics.
local function _throttledGuardLog(entityKey: string, reason: string, data: { [string]: any }?)
	local now = os.clock()
	local logKey = string.format("%s:%s", entityKey, reason)
	local previous = _lastGuardLogByKey[logKey]
	if previous and now - previous < GUARD_LOG_THROTTLE_SECONDS then
		return
	end

	_lastGuardLogByKey[logKey] = now
	Result.MentionError("PathfindingHelper", "Path request rejected by runtime guard", data, reason)
end

-- Normalizes `SimplePath` failures into a warning that is safe to log.
local function _warnPathRunFailure(entity: any?, err: any)
	local function toLogString(value: any): string
		if type(value) ~= "table" then
			return tostring(value)
		end

		-- Prefer the nested message when `SimplePath` wraps the error payload.
		local nestedMessage = value.message
		if nestedMessage ~= nil and type(nestedMessage) ~= "table" then
			return tostring(nestedMessage)
		end

		-- Fall back to the nested error field for other wrapper shapes.
		local nestedError = value.error
		if nestedError ~= nil and type(nestedError) ~= "table" then
			return tostring(nestedError)
		end

		-- Flatten scalar fields so the warning still carries useful context.
		local parts = {}
		for key, nestedValue in pairs(value) do
			if type(nestedValue) ~= "table" then
				table.insert(parts, string.format("%s=%s", tostring(key), tostring(nestedValue)))
			end
		end

		if #parts > 0 then
			return table.concat(parts, ", ")
		end

		return tostring(value)
	end

	local entityLabel = tostring(entity ~= nil and entity or "UnknownEntity")
	if type(err) == "table" then
		local errType = tostring(err.type or "UnknownType")
		local errMessage = toLogString(err.message ~= nil and err.message or err)
		warn(string.format("[PathfindingHelper] RunPath rejected for entity=%s type=%s message=%s", entityLabel, errType, errMessage))
		return
	end

	warn(string.format("[PathfindingHelper] RunPath rejected for entity=%s reason=%s", entityLabel, tostring(err)))
end

-- Returns the configured path option or its default value when no override exists.
local function _resolvePathOption(options: { [string]: any }?, key: string): any
	if options ~= nil and options[key] ~= nil then
		return options[key]
	end

	return DEFAULT_PATH_OPTIONS[key]
end

-- Formats a `Vector3` for debug output and guard logs.
local function _formatVector3(value: Vector3?): string
	if value == nil then
		return "nil"
	end

	return string.format("(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
end

-- Builds structured position debug data for error reporting.
local function _buildPositionDebug(prefix: string, value: Vector3?): { [string]: any }
	if value == nil then
		return {
			[prefix .. "Text"] = "nil",
		}
	end

	return {
		[prefix .. "Text"] = _formatVector3(value),
		[prefix .. "X"] = value.X,
		[prefix .. "Y"] = value.Y,
		[prefix .. "Z"] = value.Z,
	}
end

-- Merges debug payloads into one table so Result logging receives a flat shape.
local function _mergeDebugData(...: { [string]: any }): { [string]: any }
	local result = {}
	for _, data in ipairs({ ... }) do
		for key, value in pairs(data) do
			result[key] = value
		end
	end
	return result
end

-- Reads the agent start position from a live path when the model is still available.
local function _getStartPosition(path: any): Vector3?
	if type(path) ~= "table" then
		return nil
	end

	local agent = path._agent
	local primaryPart = if agent ~= nil then agent.PrimaryPart else nil
	return if primaryPart ~= nil then primaryPart.Position else nil
end

-- Reconciles target Y to the agent's current Y so path retries stay on valid terrain.
local function _ReconcileTargetYToStart(targetPosition: Vector3, startPosition: Vector3): Vector3
	return Vector3.new(targetPosition.X, startPosition.Y, targetPosition.Z)
end

-- Captures the path status and waypoint count without assuming the path is readable.
local function _GetPathComputationSnapshot(path: any): { StatusName: string, WaypointCount: number? }
	local statusName = "Unknown"
	local waypointCount = nil :: number?

	if type(path) ~= "table" or path._path == nil then
		return {
			StatusName = statusName,
			WaypointCount = waypointCount,
		}
	end

	-- Read the path status defensively because the underlying object can disappear mid-run.
	pcall(function()
		statusName = path._path.Status.Name
	end)

	-- Count waypoints defensively for the same reason.
	pcall(function()
		waypointCount = #path._path:GetWaypoints()
	end)

	return {
		StatusName = statusName,
		WaypointCount = waypointCount,
	}
end

-- Detects the computation-failure shape that can be recovered by Y reconciliation.
local function _isWaypointComputationFailure(snapshot: { StatusName: string, WaypointCount: number? }): boolean
	return snapshot.StatusName == "NoPath" or (snapshot.WaypointCount ~= nil and snapshot.WaypointCount < 2)
end

-- Emits a structured debug record for target scheduling and retry behavior.
local function _debugPathTarget(
	path: any,
	entity: any?,
	activeTargetPosition: Vector3,
	delaySeconds: number,
	originalTargetPosition: Vector3,
	reconciledTargetPosition: Vector3?,
	reconcileUsed: boolean,
	snapshot: { StatusName: string, WaypointCount: number? }?
)
	local startPosition = _getStartPosition(path)
	warn(string.format(
		"[PathfindingHelper] entity=%s start=%s target=%s originalTarget=%s reconciledTarget=%s reconcileUsed=%s delay=%.2f",
		tostring(entity ~= nil and entity or "UnknownEntity"),
		_formatVector3(startPosition),
		_formatVector3(activeTargetPosition),
		_formatVector3(originalTargetPosition),
		_formatVector3(reconciledTargetPosition),
		tostring(reconcileUsed),
		delaySeconds
	))
	Result.MentionSuccess(
		"PathfindingHelper:RunPath",
		"Path target scheduled",
		_mergeDebugData(
			{
				Entity = entity,
				DelaySeconds = delaySeconds,
				ReconcileUsed = reconcileUsed,
				PathStatus = snapshot and snapshot.StatusName or nil,
				WaypointCount = snapshot and snapshot.WaypointCount or nil,
			},
			_buildPositionDebug("StartPosition", startPosition),
			_buildPositionDebug("ActiveTargetPosition", activeTargetPosition),
			_buildPositionDebug("OriginalTargetPosition", originalTargetPosition),
			_buildPositionDebug("ReconciledTargetPosition", reconciledTargetPosition)
		)
	)
end

-- Builds the failure payload used by both blocked and error path settlements.
local function _buildPathFailure(
	path: any,
	fallbackReason: string,
	entity: any?,
	targetPosition: Vector3?,
	useLastError: boolean?
): { [string]: any }
	local lastError = fallbackReason
	if useLastError ~= false and type(path) == "table" and path.LastError ~= nil then
		lastError = tostring(path.LastError)
	end

	local startPosition = _getStartPosition(path)

	return _mergeDebugData(
		{
			type = "PathError",
			message = lastError,
			Entity = entity,
		},
		_buildPositionDebug("StartPosition", startPosition),
		_buildPositionDebug("TargetPosition", targetPosition)
	)
end

-- Validates that the entity can provide a live model and primary part for path creation.
local function _validateEntityModel(entity: any, services: any): (any?, any?, string?)
	local factory = _resolveFactory(services)
	if not factory then
		return nil, nil, "MissingFactory"
	end

	if type(factory.GetModelRef) ~= "function" then
		return nil, nil, "MissingGetModelRef"
	end

	local modelRef = factory:GetModelRef(entity)
	if not modelRef then
		return nil, nil, "MissingModelRef"
	end

	local model = modelRef.Model
	if not model or not model.Parent then
		return nil, nil, "MissingModel"
	end

	local primaryPart = model.PrimaryPart
	if not primaryPart or not primaryPart.Parent then
		return nil, nil, "MissingPrimaryPart"
	end

	return modelRef, model, nil
end

-- Validates that the path object still has a live agent model before running.
local function _validatePathRunnable(path: any): (boolean, string)
	if type(path) ~= "table" then
		return false, "InvalidPathObject"
	end

	if type(path.Run) ~= "function" then
		return false, "InvalidPathRunMethod"
	end

	local agent = path._agent
	if not agent or not agent.Parent then
		return false, "MissingAgentModel"
	end

	local primaryPart = agent.PrimaryPart
	if not primaryPart or not primaryPart.Parent then
		return false, "MissingPrimaryPart"
	end

	return true, "Ok"
end

-- ── Public ───────────────────────────────────────────────────────────────────

--[=[
    Creates a `SimplePath` for the supplied entity model when all prerequisites are available.
    @within PathfindingHelper
    @param entity any -- Entity whose model should be used as the path agent.
    @param services any -- Service container that provides an entity factory.
    @param agentParams { [string]: any }? -- Optional path agent parameters.
    @param options { [string]: any }? -- Optional path behavior overrides.
    @return any? -- The constructed path or `nil` when validation fails.
]=]
function PathfindingHelper.CreatePath(
	entity: any,
	services: any,
	agentParams: { [string]: any }?,
	options: { [string]: any }?
): any?
	-- Validate the entity model before constructing a path.
	local modelRef, model, failureReason = _validateEntityModel(entity, services)
	if not modelRef or not model or failureReason then
		_throttledGuardLog(tostring(entity), failureReason or "MissingModel", {
			Entity = entity,
		})
		return nil
	end

	-- Construct the path with the configured agent parameters.
	local success, path = pcall(function()
		return SimplePath.new(model, agentParams or DEFAULT_AGENT_PARAMS)
	end)

	if not success then
		_throttledGuardLog(tostring(entity), "PathConstructionFailed", {
			Entity = entity,
		})
		return nil
	end

	-- Apply visualization only when the caller explicitly enables it.
	path.Visualize = _resolvePathOption(options, "VisualizeSimplePath") == true
	return path
end

--[=[
    Runs a path toward the supplied target and settles a promise when the path succeeds or fails.
    @within PathfindingHelper
    @param path any -- Path object created by `CreatePath`.
    @param targetPosition Vector3 -- Target world position to navigate to.
    @param entity any? -- Entity associated with the path for diagnostics.
    @param options { [string]: any }? -- Optional runtime and retry overrides.
    @return any -- Promise that resolves when the path reaches the target.
]=]
function PathfindingHelper.RunPath(path: any, targetPosition: Vector3, entity: any?, options: { [string]: any }?): any
	local pathPromise = Promise.new(function(resolve, reject, onCancel)
		-- Set up cancellation-safe cleanup before wiring any callbacks.
		local janitor: any? = Janitor.new()
		local entityKey = tostring(entity ~= nil and entity or "UnknownEntity")
		local retryThread: thread? = nil
		local computationErrorRetries = 0
		local targetYReconcileAttempts = 0
		local originalTargetPosition = targetPosition
		local activeTargetPosition = targetPosition
		local latestReconciledTargetPosition = nil :: Vector3?

		-- Destroy the path and cancel deferred retries exactly once.
		local function cleanup()
			if janitor then
				local current = janitor
				janitor = nil
				current:Destroy()
			end
		end

		-- Schedule a run immediately or after a delay, optionally reusing a reconciled target.
		local function scheduleRun(
			delaySeconds: number,
			nextTargetPosition: Vector3?,
			reconcileUsed: boolean?,
			snapshot: { StatusName: string, WaypointCount: number? }?
		)
			if janitor == nil then
				return
			end

			if nextTargetPosition ~= nil then
				activeTargetPosition = nextTargetPosition
			end

			if _resolvePathOption(options, "DebugTarget") == true then
				_debugPathTarget(
					path,
					entity,
					activeTargetPosition,
					delaySeconds,
					originalTargetPosition,
					latestReconciledTargetPosition,
					reconcileUsed == true,
					snapshot
				)
			end

			local function runNow()
				retryThread = nil
				local stillRunnable, runFailureReason = _validatePathRunnable(path)
				if not stillRunnable then
					_throttledGuardLog(entityKey, runFailureReason, {
						Entity = entity,
						Stage = "RunStart",
						TargetPositionText = _formatVector3(activeTargetPosition),
					})
					cleanup()
					reject(runFailureReason)
					return
				end

				Promise.try(function()
					path:Run(activeTargetPosition)
				end):catch(function(err)
					cleanup()
					reject(err)
				end)
			end

			if delaySeconds > 0 then
				retryThread = task.delay(delaySeconds, runNow)
				return
			end

			runNow()
		end

		-- Validate the target and runnable path before wiring listeners.
		local currentJanitor = janitor
		if not currentJanitor then
			reject("MissingJanitor")
			return
		end

		currentJanitor:Add(function()
			if type(path) ~= "table" then
				return
			end

			pcall(function()
				if path.Status == SimplePath.StatusType.Active then
					path:Stop()
				end
			end)
			pcall(function()
				path:Destroy()
			end)
		end)
		currentJanitor:Add(function()
			if retryThread ~= nil then
				task.cancel(retryThread)
				retryThread = nil
			end
		end)

		if typeof(targetPosition) ~= "Vector3" then
			_throttledGuardLog(entityKey, "InvalidTargetPosition", {
				Entity = entity,
			})
			cleanup()
			reject("InvalidTargetPosition")
			return
		end

		local pathIsRunnable, pathFailureReason = _validatePathRunnable(path)
		if not pathIsRunnable then
			_throttledGuardLog(entityKey, pathFailureReason, {
				Entity = entity,
			})
			cleanup()
			reject(pathFailureReason)
			return
		end

		-- Wire lifecycle events so success, failure, and cancellation all settle cleanly.
		currentJanitor:Add(path.Reached:Connect(function()
			cleanup()
			resolve()
		end))

		currentJanitor:Add(path.Error:Connect(function(errorType)
			local snapshot = _GetPathComputationSnapshot(path)
			local failure = _buildPathFailure(path, tostring(errorType or "PathError"), entity, activeTargetPosition)
			local isComputationError = failure.message == SimplePath.ErrorType.ComputationError
			local maxReconcileAttempts = tonumber(_resolvePathOption(options, "MaxTargetYReconcileAttempts")) or 0
			-- Only reconcile Y when the path failed to compute a viable waypoint set.
			local canReconcileTargetY = _resolvePathOption(options, "ReconcileTargetYOnWaypointFailure") == true
				and isComputationError
				and _isWaypointComputationFailure(snapshot)
				and targetYReconcileAttempts < maxReconcileAttempts
			-- Retry the original target once for transient computation errors.
			local shouldRetry = _resolvePathOption(options, "RetryComputationErrors") == true
				and targetYReconcileAttempts == 0
				and failure.message == SimplePath.ErrorType.ComputationError
				and computationErrorRetries < COMPUTATION_ERROR_RETRY_COUNT

			if canReconcileTargetY then
				-- Reuse the agent's current Y so the retry uses a walkable target height.
				local startPosition = _getStartPosition(path)
				if startPosition ~= nil then
					targetYReconcileAttempts += 1
					latestReconciledTargetPosition = _ReconcileTargetYToStart(activeTargetPosition, startPosition)
					scheduleRun(
						_resolvePathOption(options, "InitialRunDelaySeconds"),
						latestReconciledTargetPosition,
						true,
						snapshot
					)
					return
				end
			end

			if shouldRetry then
				-- Re-run with the same target after a short delay to absorb transient failures.
				computationErrorRetries += 1
				scheduleRun(_resolvePathOption(options, "InitialRunDelaySeconds"))
				return
			end

			-- Emit one structured guard record before rejecting the promise.
			_throttledGuardLog(entityKey, failure.message, {
				Entity = entity,
				StartPositionText = failure.StartPositionText,
				ActiveTargetPositionText = failure.TargetPositionText,
				OriginalTargetPositionText = _formatVector3(originalTargetPosition),
				ReconciledTargetPositionText = _formatVector3(latestReconciledTargetPosition),
				ActiveTargetPositionX = failure.TargetPositionX,
				ActiveTargetPositionY = failure.TargetPositionY,
				ActiveTargetPositionZ = failure.TargetPositionZ,
				PathStatus = snapshot.StatusName,
				WaypointCount = snapshot.WaypointCount,
				Retry = false,
				ReconcileUsed = false,
			})

			cleanup()
			reject(failure)
		end))

		-- A blocked path settles as a failure because the caller needs a fresh route decision.
		currentJanitor:Add(path.Blocked:Connect(function()
			local failure = _buildPathFailure(path, "PathBlocked", entity, targetPosition, false)
			cleanup()
			reject(failure)
		end))

		-- Register cancellation cleanup so stopped promises tear down the path.
		onCancel(function()
			cleanup()
		end)

		-- Start the initial run using the configured delay.
		scheduleRun(_resolvePathOption(options, "InitialRunDelaySeconds"), nil, false, nil)
	end)

	pathPromise:catch(function(err)
		_warnPathRunFailure(entity, err)
	end)

	return pathPromise
end

return PathfindingHelper

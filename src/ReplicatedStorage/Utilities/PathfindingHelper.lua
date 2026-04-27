--[[
	PathfindingHelper - Shared utility for SimplePath lifecycle management.

	Used by movement systems to create and run SimplePath instances. Keeps pathfinding
	plumbing out of individual context files.

	RunPath returns a Promise that:
		- Resolves when Reached fires
		- Rejects when Error or Blocked fires
		- Cleans up (Stop + Destroy) on cancel or settlement

	Callers store the returned Promise and check its status each Tick via
	Promise.Status (Started = running, Resolved = reached, Rejected = failed).
	Cancelling the Promise stops and destroys the path immediately.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimplePath = require(ReplicatedStorage.Utilities.SimplePath)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Result = require(ReplicatedStorage.Utilities.Result)

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

local function _resolveFactory(services: any): any?
	if not services then
		return nil
	end

	return services.EntityFactory or services.NPCEntityFactory or services.EnemyEntityFactory
end

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

local function _warnPathRunFailure(entity: any?, err: any)
	local function toLogString(value: any): string
		if type(value) ~= "table" then
			return tostring(value)
		end

		local nestedMessage = value.message
		if nestedMessage ~= nil and type(nestedMessage) ~= "table" then
			return tostring(nestedMessage)
		end

		local nestedError = value.error
		if nestedError ~= nil and type(nestedError) ~= "table" then
			return tostring(nestedError)
		end

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

local function _resolvePathOption(options: { [string]: any }?, key: string): any
	if options ~= nil and options[key] ~= nil then
		return options[key]
	end

	return DEFAULT_PATH_OPTIONS[key]
end

local function _formatVector3(value: Vector3?): string
	if value == nil then
		return "nil"
	end

	return string.format("(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
end

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

local function _mergeDebugData(...: { [string]: any }): { [string]: any }
	local result = {}
	for _, data in ipairs({ ... }) do
		for key, value in pairs(data) do
			result[key] = value
		end
	end
	return result
end

local function _getStartPosition(path: any): Vector3?
	if type(path) ~= "table" then
		return nil
	end

	local agent = path._agent
	local primaryPart = if agent ~= nil then agent.PrimaryPart else nil
	return if primaryPart ~= nil then primaryPart.Position else nil
end

local function _ReconcileTargetYToStart(targetPosition: Vector3, startPosition: Vector3): Vector3
	return Vector3.new(targetPosition.X, startPosition.Y, targetPosition.Z)
end

local function _GetPathComputationSnapshot(path: any): { StatusName: string, WaypointCount: number? }
	local statusName = "Unknown"
	local waypointCount = nil :: number?

	if type(path) ~= "table" or path._path == nil then
		return {
			StatusName = statusName,
			WaypointCount = waypointCount,
		}
	end

	pcall(function()
		statusName = path._path.Status.Name
	end)

	pcall(function()
		waypointCount = #path._path:GetWaypoints()
	end)

	return {
		StatusName = statusName,
		WaypointCount = waypointCount,
	}
end

local function _isWaypointComputationFailure(snapshot: { StatusName: string, WaypointCount: number? }): boolean
	return snapshot.StatusName == "NoPath" or (snapshot.WaypointCount ~= nil and snapshot.WaypointCount < 2)
end

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

	local model = modelRef.model
	if not model or not model.Parent then
		return nil, nil, "MissingModel"
	end

	local primaryPart = model.PrimaryPart
	if not primaryPart or not primaryPart.Parent then
		return nil, nil, "MissingPrimaryPart"
	end

	return modelRef, model, nil
end

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

--[[
	Create a SimplePath for an entity's model.
	Returns the Path instance or nil if the model is missing/invalid.
]]
function PathfindingHelper.CreatePath(
	entity: any,
	services: any,
	agentParams: { [string]: any }?,
	options: { [string]: any }?
): any?
	local modelRef, model, failureReason = _validateEntityModel(entity, services)
	if not modelRef or not model or failureReason then
		_throttledGuardLog(tostring(entity), failureReason or "MissingModel", {
			Entity = entity,
		})
		return nil
	end

	local success, path = pcall(function()
		return SimplePath.new(model, agentParams or DEFAULT_AGENT_PARAMS)
	end)

	if not success then
		_throttledGuardLog(tostring(entity), "PathConstructionFailed", {
			Entity = entity,
		})
		return nil
	end

	path.Visualize = _resolvePathOption(options, "VisualizeSimplePath") == true
	return path
end

--[[
	Run a path to targetPosition.
	Returns a Promise that resolves on Reached, rejects on Error/Blocked,
	and stops + destroys the path on cancel or settlement.
]]
function PathfindingHelper.RunPath(path: any, targetPosition: Vector3, entity: any?, options: { [string]: any }?): any
	local pathPromise = Promise.new(function(resolve, reject, onCancel)
		local janitor: any? = Janitor.new()
		local entityKey = tostring(entity ~= nil and entity or "UnknownEntity")
		local retryThread: thread? = nil
		local computationErrorRetries = 0
		local targetYReconcileAttempts = 0
		local originalTargetPosition = targetPosition
		local activeTargetPosition = targetPosition
		local latestReconciledTargetPosition = nil :: Vector3?

		local function cleanup()
			if janitor then
				local current = janitor
				janitor = nil
				current:Destroy()
			end
		end

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

		currentJanitor:Add(path.Reached:Connect(function()
			cleanup()
			resolve()
		end))

		currentJanitor:Add(path.Error:Connect(function(errorType)
			local snapshot = _GetPathComputationSnapshot(path)
			local failure = _buildPathFailure(path, tostring(errorType or "PathError"), entity, activeTargetPosition)
			local isComputationError = failure.message == SimplePath.ErrorType.ComputationError
			local maxReconcileAttempts = tonumber(_resolvePathOption(options, "MaxTargetYReconcileAttempts")) or 0
			local canReconcileTargetY = _resolvePathOption(options, "ReconcileTargetYOnWaypointFailure") == true
				and isComputationError
				and _isWaypointComputationFailure(snapshot)
				and targetYReconcileAttempts < maxReconcileAttempts
			local shouldRetry = _resolvePathOption(options, "RetryComputationErrors") == true
				and targetYReconcileAttempts == 0
				and failure.message == SimplePath.ErrorType.ComputationError
				and computationErrorRetries < COMPUTATION_ERROR_RETRY_COUNT

			if canReconcileTargetY then
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
				computationErrorRetries += 1
				scheduleRun(_resolvePathOption(options, "InitialRunDelaySeconds"))
				return
			end

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

		currentJanitor:Add(path.Blocked:Connect(function()
			local failure = _buildPathFailure(path, "PathBlocked", entity, targetPosition, false)
			cleanup()
			reject(failure)
		end))

		onCancel(function()
			cleanup()
		end)

		scheduleRun(_resolvePathOption(options, "InitialRunDelaySeconds"), nil, false, nil)
	end)

	pathPromise:catch(function(err)
		_warnPathRunFailure(entity, err)
	end)

	return pathPromise
end

return PathfindingHelper

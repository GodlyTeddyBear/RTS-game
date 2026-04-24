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
function PathfindingHelper.CreatePath(entity: any, services: any, agentParams: { [string]: any }?): any?
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

	path.Visualize = false
	return path
end

--[[
	Run a path to targetPosition.
	Returns a Promise that resolves on Reached, rejects on Error/Blocked,
	and stops + destroys the path on cancel or settlement.
]]
function PathfindingHelper.RunPath(path: any, targetPosition: Vector3, entity: any?): any
	return Promise.new(function(resolve, reject, onCancel)
		local janitor: any? = Janitor.new()
		local entityKey = tostring(entity ~= nil and entity or "UnknownEntity")

		local function cleanup()
			if janitor then
				local current = janitor
				janitor = nil
				current:Destroy()
			end
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

		currentJanitor:Add(path.Error:Connect(function()
			cleanup()
			reject("PathError")
		end))

		currentJanitor:Add(path.Blocked:Connect(function()
			cleanup()
			reject("PathBlocked")
		end))

		onCancel(function()
			cleanup()
		end)

		Promise.try(function()
			local stillRunnable, runFailureReason = _validatePathRunnable(path)
			if not stillRunnable then
				_throttledGuardLog(entityKey, runFailureReason, {
					Entity = entity,
					Stage = "RunStart",
				})
				cleanup()
				reject(runFailureReason)
				return
			end

			path:Run(targetPosition)
		end):catch(function(err)
			cleanup()
			reject(err)
		end)
	end):catch(function(err)
		_warnPathRunFailure(entity, err)
	end)
end

return PathfindingHelper

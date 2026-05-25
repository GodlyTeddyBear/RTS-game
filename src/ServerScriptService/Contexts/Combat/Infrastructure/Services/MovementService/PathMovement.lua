--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)

type TAgentParams = MovementTypes.TAgentParams
type TMovementActorKey = MovementTypes.TMovementActorKey
type TMovementActorBinding = MovementTypes.TMovementActorBinding
type TMovementService = MovementTypes.TMovementService
type TPathMovementState = MovementTypes.TPathMovementState

local GOAL_POSITION_EPSILON = 0.01

return function(MovementService: TMovementService)
	local function _GetBinding(self: TMovementService, actorKey: TMovementActorKey): TMovementActorBinding?
		return self:_GetMovementBinding(actorKey)
	end

	-- Clone pathfinding options so direct path retargets can add warmup flags without mutating shared config.
	local function _ClonePathfindingOptions(extraOptions: { [string]: any }?): { [string]: any }
		local options = table.clone(CombatMovementConfig.PATHFINDING)
		if extraOptions then
			for key, value in extraOptions do
				options[key] = value
			end
		end
		return options
	end

	-- Returns the agent params for one entity, falling back to the default movement config.
	function MovementService:_GetAgentParams(actorKey: TMovementActorKey): TAgentParams
		local binding = _GetBinding(self, actorKey)
		if binding ~= nil then
			return binding:GetAgentParams()
		end

		return CombatMovementConfig.DEFAULT_AGENT_PARAMS
	end

	-- Builds the service payload used by PathfindingHelper for one actor.
	function MovementService:_CreatePathServices(actorKey: TMovementActorKey, binding: TMovementActorBinding): any
		local entityId = binding.EntityId
		return {
			EntityFactory = {
				GetModelRef = function(_factory: any, requestedEntity: number)
					if requestedEntity ~= entityId then
						return nil
					end
					local currentBinding = self:_GetMovementBinding(actorKey)
					return if currentBinding ~= nil then currentBinding:GetModelRef() else nil
				end,
			},
		}
	end

	-- Creates a reusable SimplePath runtime for one actor.
	function MovementService:_CreatePathRuntime(actorKey: TMovementActorKey): (any?, TMovementActorBinding?)
		local binding = _GetBinding(self, actorKey)
		if binding == nil then
			return nil, nil
		end

		local path = PathfindingHelper.CreatePath(
			binding.EntityId,
			self:_CreatePathServices(actorKey, binding),
			self:_GetAgentParams(actorKey),
			CombatMovementConfig.PATHFINDING
		)
		if not path then
			return nil, binding
		end

		return path, binding
	end

	-- Starts a path run on an already-created path runtime.
	function MovementService:_RunPathPromise(path: any, goalPosition: Vector3, actorKey: TMovementActorKey): MovementTypes.TPathPromiseLike
		local binding = _GetBinding(self, actorKey)
		local entityId = if binding ~= nil then binding.EntityId else actorKey
		return PathfindingHelper.RunPath(path, goalPosition, entityId, CombatMovementConfig.PATHFINDING)
	end

	-- Clears any warmed replacement path state, optionally cancelling the pending compute promise first.
	function MovementService:_ClearPendingPathReplacement(
		movementState: TPathMovementState,
		cancelPromise: boolean?
	)
		local pendingPromise = movementState.PendingPromise
		if cancelPromise == true and pendingPromise and type(pendingPromise.cancel) == "function" then
			pendingPromise:cancel()
		end

		local pendingPath = movementState.PendingPath
		if pendingPath ~= nil and pendingPath ~= movementState.Path then
			pcall(function()
				pendingPath:Destroy()
			end)
		end

		movementState.PendingPath = nil
		movementState.PendingPromise = nil
		movementState.PendingGoalSnapshot = nil
	end

	-- Swaps the active path run to a warmed replacement after waypoint computation succeeds.
	function MovementService:_CommitPathReplacement(
		actorKey: TMovementActorKey,
		movementState: TPathMovementState,
		transitionId: number
	): boolean
		if movementState.PendingTransitionId ~= transitionId then
			return false
		end

		local pendingPath = movementState.PendingPath
		local pendingGoalSnapshot = movementState.PendingGoalSnapshot
		if pendingPath == nil or pendingGoalSnapshot == nil then
			return false
		end

		local replacementPromise = self:_RunPathPromise(pendingPath, pendingGoalSnapshot, actorKey)
		local previousPromise = movementState.Promise

		movementState.Path = pendingPath
		movementState.Promise = replacementPromise
		movementState.GoalSnapshot = pendingGoalSnapshot
		movementState.PendingPath = nil
		movementState.PendingPromise = nil
		movementState.PendingGoalSnapshot = nil

		if previousPromise and previousPromise ~= replacementPromise and type(previousPromise.cancel) == "function" then
			previousPromise:cancel()
		end

		local binding = _GetBinding(self, actorKey)
		if binding ~= nil then
			binding:SetPathMoving(true)
		end
		return true
	end

	-- Warms a replacement path and commits it only after waypoint compute succeeds.
	function MovementService:_TransitionPathRuntimeAdvance(
		actorKey: TMovementActorKey,
		movementState: TPathMovementState,
		goalPosition: Vector3
	): (boolean, string?)
		if (goalPosition - movementState.GoalSnapshot).Magnitude <= GOAL_POSITION_EPSILON then
			self:_ClearPendingPathReplacement(movementState, true)
			return true, nil
		end

		local pendingGoalSnapshot = movementState.PendingGoalSnapshot
		if pendingGoalSnapshot and (goalPosition - pendingGoalSnapshot).Magnitude <= GOAL_POSITION_EPSILON then
			return true, nil
		end

		self:_ClearPendingPathReplacement(movementState, true)

		local replacementPath = self:_CreatePathRuntime(actorKey)
		if replacementPath == nil then
			return true, nil
		end

		local nextTransitionId = movementState.PendingTransitionId + 1
		local computePromise = PathfindingHelper.ComputeWaypointsPromise(
			replacementPath,
			goalPosition,
			self:_GetMovementEntityId(actorKey),
			_ClonePathfindingOptions({
				RetainPathAfterWaypointCompute = true,
			})
		)

		movementState.PendingTransitionId = nextTransitionId
		movementState.PendingPath = replacementPath
		movementState.PendingPromise = computePromise
		movementState.PendingGoalSnapshot = goalPosition

		computePromise:andThen(function()
			local currentState = self._movementByActorKey[actorKey]
			if currentState ~= movementState or currentState == nil or currentState.Mode ~= "Path" then
				pcall(function()
					replacementPath:Destroy()
				end)
				return
			end

			if not self:_CommitPathReplacement(actorKey, currentState :: TPathMovementState, nextTransitionId) then
				pcall(function()
					replacementPath:Destroy()
				end)
			end
		end):catch(function()
			local currentState = self._movementByActorKey[actorKey]
			if currentState ~= movementState or currentState == nil or currentState.Mode ~= "Path" then
				return
			end
			if currentState.PendingTransitionId ~= nextTransitionId then
				return
			end

			currentState.PendingPath = nil
			currentState.PendingPromise = nil
			currentState.PendingGoalSnapshot = nil
		end)

		return true, nil
	end

	-- Starts one direct path runtime advance and marks the actor as path-moving.
	function MovementService:_StartPathRuntimeAdvance(actorKey: TMovementActorKey, goalPosition: Vector3): boolean
		local path, binding = self:_CreatePathRuntime(actorKey)
		if path == nil or binding == nil then
			return false
		end

		self._movementByActorKey[actorKey] = {
			Mode = "Path",
			GoalSnapshot = goalPosition,
			Path = path,
			Promise = self:_RunPathPromise(path, goalPosition, actorKey),
			PendingPath = nil,
			PendingPromise = nil,
			PendingGoalSnapshot = nil,
			PendingTransitionId = 0,
		}
		binding:SetPathMoving(true)
		return true
	end

	-- Polls one direct path runtime promise and converts the result into a lifecycle outcome.
	function MovementService:_StepPathRuntimeAdvance(
		actorKey: TMovementActorKey,
		movementState: TPathMovementState
	): ("Running" | "Success" | "Fail", string?)
		local promise = movementState.Promise
		if not promise then
			local binding = _GetBinding(self, actorKey)
			if binding ~= nil then
				self:StopMovement(binding)
			end
			return "Fail", "MissingPathPromise"
		end

		local status = promise:getStatus()
		if movementState.PendingPromise ~= nil and (status == Promise.Status.Started or status == Promise.Status.Resolved) then
			return "Running", nil
		end
		if movementState.PendingPromise ~= nil and status == Promise.Status.Rejected then
			return "Running", nil
		end
		if status == Promise.Status.Started then
			return "Running", nil
		end

		self:_ClearPendingPathReplacement(movementState, true)
		self._movementByActorKey[actorKey] = nil
		local binding = _GetBinding(self, actorKey)
		if binding ~= nil then
			binding:SetPathMoving(false)
		end

		if status == Promise.Status.Resolved then
			return "Success", nil
		end

		return "Fail", "PathPromiseRejected"
	end

	-- Stops the active direct path runtime and tears down any warmed replacements.
	function MovementService:_StopPathRuntime(movementState: TPathMovementState)
		self:_ClearPendingPathReplacement(movementState, true)

		local promise = movementState.Promise
		if promise and type(promise.cancel) == "function" then
			promise:cancel()
		end

		local path = movementState.Path
		if path ~= nil then
			pcall(function()
				path:Destroy()
			end)
		end
	end
end

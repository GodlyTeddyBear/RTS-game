--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local PathfindingHelper = require(ServerStorage.Utilities.PathfindingHelper)

local GOAL_POSITION_EPSILON = 0.01

return function(MovementService: any)
	local function _GetUnitActorRefs(self: any, entity: number)
		local refs = self._unitActorRefsByEntity[entity]
		if refs ~= nil then
			return refs
		end

		refs = {
			Model = nil,
			Humanoid = nil,
		}
		self._unitActorRefsByEntity[entity] = refs
		return refs
	end

	local function _GetUnitModel(self: any, entity: number): Model?
		local refs = _GetUnitActorRefs(self, entity)
		if refs.Model ~= nil and refs.Model.Parent ~= nil then
			return refs.Model
		end

		local model = nil
		if self._unitInstanceFactory ~= nil and type(self._unitInstanceFactory.GetInstance) == "function" then
			model = self._unitInstanceFactory:GetInstance(entity)
		end
		if model ~= nil and model:IsA("Model") then
			refs.Model = model
			return model
		end

		refs.Model = nil
		refs.Humanoid = nil
		return nil
	end

	local function _GetUnitHumanoid(self: any, entity: number): Humanoid?
		local refs = _GetUnitActorRefs(self, entity)
		if refs.Humanoid ~= nil and refs.Humanoid.Parent ~= nil then
			return refs.Humanoid
		end

		local model = _GetUnitModel(self, entity)
		if model == nil then
			refs.Humanoid = nil
			return nil
		end

		local humanoid = model:FindFirstChildWhichIsA("Humanoid")
		if humanoid == nil then
			refs.Humanoid = nil
			return nil
		end

		refs.Humanoid = humanoid
		return humanoid
	end

	function MovementService:_GetUnitAgentParams(entity: number)
		local role = if self._unitEntityFactory ~= nil then self._unitEntityFactory:GetRole(entity) else nil
		local roleName = if role ~= nil then role.Role else nil
		local roleConfig = if type(roleName) == "string" then CombatMovementConfig.AGENT_PARAMS_BY_UNIT_ROLE[roleName] else nil
		if roleConfig ~= nil then
			return roleConfig
		end

		return CombatMovementConfig.DEFAULT_AGENT_PARAMS
	end

	function MovementService:_ApplyUnitCurrentMoveSpeed(entity: number): number
		local humanoid = _GetUnitHumanoid(self, entity)
		local currentMoveSpeed = if self._unitEntityFactory ~= nil then self._unitEntityFactory:GetCurrentMoveSpeed(entity) else nil
		local resolvedMoveSpeed = (type(currentMoveSpeed) == "number" and currentMoveSpeed > 0) and currentMoveSpeed or 16
		if humanoid ~= nil and math.abs(humanoid.WalkSpeed - resolvedMoveSpeed) > 0.05 then
			humanoid.WalkSpeed = resolvedMoveSpeed
		end

		return resolvedMoveSpeed
	end

	function MovementService:_ClearUnitMovementRuntimeState(entity: number)
		self._unitMovementByEntity[entity] = nil
		self._unitActorRefsByEntity[entity] = nil
		if self._unitEntityFactory ~= nil then
			self._unitEntityFactory:SetPathMoving(entity, false)
		end
	end

	function MovementService:_StartUnitPath(entity: number, goalPosition: Vector3): (boolean, string?)
		local path = PathfindingHelper.CreatePath(entity, {
			EntityFactory = self._unitEntityFactory,
		}, self:_GetUnitAgentParams(entity), CombatMovementConfig.PATHFINDING)
		if path == nil then
			return false, "PathStartFailed"
		end

		self._unitMovementByEntity[entity] = {
			Promise = PathfindingHelper.RunPath(path, goalPosition, entity, CombatMovementConfig.PATHFINDING),
			GoalSnapshot = goalPosition,
		}
		self._unitEntityFactory:SetPathMoving(entity, true)
		return true, nil
	end

	function MovementService:StartUnitMove(entity: number): (boolean, string?)
		self:StopUnitMovement(entity)

		if self._unitEntityFactory == nil then
			return false, "MissingUnitEntityFactory"
		end

		local pathState = self._unitEntityFactory:GetPathState(entity)
		if pathState == nil or pathState.GoalPosition == nil then
			return false, "MissingGoalPosition"
		end

		return self:_StartUnitPath(entity, pathState.GoalPosition)
	end

	function MovementService:StepUnitMove(entity: number): (boolean, string?)
		if self._unitEntityFactory == nil then
			return false, "MissingUnitEntityFactory"
		end

		local pathState = self._unitEntityFactory:GetPathState(entity)
		if pathState == nil or pathState.GoalPosition == nil then
			return false, "MissingGoalPosition"
		end

		local movementState = self._unitMovementByEntity[entity]
		if movementState == nil then
			return false, "MissingMovementState"
		end

		if (pathState.GoalPosition - movementState.GoalSnapshot).Magnitude > GOAL_POSITION_EPSILON then
			local restarted, restartReason = self:StartUnitMove(entity)
			if not restarted then
				return false, restartReason
			end
			return false, nil
		end

		self:_ApplyUnitCurrentMoveSpeed(entity)

		local promise = movementState.Promise
		if promise == nil then
			self:_ClearUnitMovementRuntimeState(entity)
			return false, "MissingPathPromise"
		end

		local status = promise:getStatus()
		if status == Promise.Status.Started then
			return false, nil
		end

		self:_ClearUnitMovementRuntimeState(entity)
		if status == Promise.Status.Resolved then
			return true, nil
		end

		return false, "PathPromiseRejected"
	end

	function MovementService:StopUnitMovement(entity: number)
		local movementState = self._unitMovementByEntity[entity]
		if movementState == nil then
			if self._unitEntityFactory ~= nil then
				self._unitEntityFactory:SetPathMoving(entity, false)
			end
			self._unitActorRefsByEntity[entity] = nil
			return
		end

		local promise = movementState.Promise
		if promise ~= nil and type(promise.cancel) == "function" then
			promise:cancel()
		end

		self:_ClearUnitMovementRuntimeState(entity)
	end
end

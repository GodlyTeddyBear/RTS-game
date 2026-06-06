--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Orient = require(ReplicatedStorage.Utilities.Orient)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local MovementApplySystem = {}
MovementApplySystem.__index = MovementApplySystem

function MovementApplySystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MovementApplySystem)
	self._entityFactory = entityFactory
	self._applyBridgeService = dependencies.ApplyBridgeService
	return self
end

function MovementApplySystem:Run()
	-- READS: Movement.ApplyState [AUTHORITATIVE], Movement.ActorProfile [AUTHORITATIVE], Movement.SpeedState [AUTHORITATIVE], Entity.Transform [DERIVED]
	-- WRITES: Movement.ApplyResult [AUTHORITATIVE], Entity.Transform [DERIVED], Entity.DirtyTag [DERIVED]
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "ApplyState" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function MovementApplySystem:_RunEntity(entity: number, now: number)
	local applyState = self:_Get(entity, "ApplyState", "Movement")
	if type(applyState) ~= "table" then
		return
	end

	local status = applyState.Status
	if status == "Cancelled" or status == "Failed" or status == "Done" then
		self._applyBridgeService:Stop(entity)
		self:_WriteResult(entity, applyState, now, status, false, applyState.FailureReason)
		return
	end
	if status ~= "Running" then
		return
	end

	local runtimeState = self:_Get(entity, "PathRuntimeState", "Movement")
	if type(runtimeState) == "table" and runtimeState.Mode == "Path" then
		self:_WriteResult(entity, applyState, now, "Running", true, nil)
		return
	end

	local profile = self:_Get(entity, "ActorProfile", "Movement")
	if type(profile) ~= "table" then
		self:_WriteResult(entity, applyState, now, "Failed", false, "MissingMovementActorProfile")
		return
	end

	local applied, reason
	if profile.ApplyMode == "Kinematic" then
		applied, reason = self:_ApplyKinematic(entity, applyState)
	elseif profile.ApplyMode == "Humanoid" then
		applied, reason = self._applyBridgeService:Apply(self._entityFactory, entity, applyState)
	else
		applied, reason = false, "InvalidMovementApplyMode"
	end
	self:_WriteResult(entity, applyState, now, if applied then "Running" else "Failed", applied, reason)
end

function MovementApplySystem:_ApplyKinematic(entity: number, applyState: any): (boolean, string?)
	local transform = self:_Get(entity, "Transform", "Entity")
	local speedState = self:_Get(entity, "SpeedState", "Movement")
	local targetPosition = applyState.TargetPosition
	if type(transform) ~= "table" or typeof(transform.CFrame) ~= "CFrame" or typeof(targetPosition) ~= "Vector3" then
		return false, "MissingKinematicTransform"
	end
	if type(speedState) ~= "table" or type(speedState.CurrentSpeed) ~= "number" then
		return false, "MissingMovementSpeed"
	end

	local nextPosition =
		Orient.MoveTowards(transform.CFrame.Position, targetPosition, speedState.CurrentSpeed * ServerScheduler:GetDeltaTime())
	local nextCFrame = Orient.BuildLookAt(nextPosition, targetPosition) or CFrame.new(nextPosition)
	self._entityFactory:Set(entity, "Transform", { CFrame = nextCFrame }, "Entity")
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
	return true, nil
end

function MovementApplySystem:_WriteResult(entity: number, applyState: any, now: number, status: string, isMoving: boolean, reason: string?)
	self._entityFactory:Set(entity, "ApplyResult", {
		RequestedAt = applyState.RequestedAt,
		UpdatedAt = now,
		Status = status,
		IsMoving = isMoving,
		IsDone = status == "Done",
		FailureReason = reason,
	}, "Movement")
end

function MovementApplySystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementApplySystem

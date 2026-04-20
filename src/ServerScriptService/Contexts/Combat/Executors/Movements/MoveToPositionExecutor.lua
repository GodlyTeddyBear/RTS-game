--!strict

--[[
    MoveToPositionExecutor - Pathfind an NPC to a player-commanded world position.

    Non-committed (cancellable by new commands).

    Dual-mode:
    - Solo / small group: Uses PathfindingHelper/SimplePath (existing behavior)
    - Group with CommandGroupId: Uses BoidsHelper for natural formation movement

    Returns "Success" on arrival, "Running" while in transit, "Fail" on error.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)
local BaseExecutor = require(script.Parent.Parent.Base.BaseExecutor)
local PathfindingHelper = require(script.Parent.Parent.Helpers.PathfindingHelper)
local BoidsHelper = require(script.Parent.Parent.Helpers.BoidsHelper)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices

local MoveToPositionExecutor = {}
MoveToPositionExecutor.__index = MoveToPositionExecutor
setmetatable(MoveToPositionExecutor, { __index = BaseExecutor })

export type TMoveToPositionExecutor = typeof(setmetatable(
	{} :: {
		Config: ExecutorTypes.TExecutorConfig,
		_promises: { [Entity]: any },
		_boidsEntities: { [Entity]: string },
		_previousVelocities: { [Entity]: Vector3 },
	},
	MoveToPositionExecutor
))

function MoveToPositionExecutor.new(): TMoveToPositionExecutor
	local self = BaseExecutor.new({
		ActionId = "MoveToPosition",
		IsCommitted = false,
		Duration = nil,
	})
	self._promises = {}
	self._boidsEntities = {}
	self._previousVelocities = {}
	return setmetatable(self :: any, MoveToPositionExecutor)
end

function MoveToPositionExecutor:_CleanupEntity(entity: Entity, services: TActionServices?)
	-- SimplePath cleanup
	if self._promises[entity] then
		self._promises[entity]:cancel()
		self._promises[entity] = nil
	end

	-- Boids cleanup
	local commandGroupId = self._boidsEntities[entity]
	if commandGroupId then
		if services then
			BoidsHelper.CleanupEntity(entity, commandGroupId, services)
		end
		self._boidsEntities[entity] = nil
		self._previousVelocities[entity] = nil
	end
end

function MoveToPositionExecutor:Start(entity: Entity, actionData: { [string]: any }?, services: TActionServices): (boolean, string?)
	if not actionData or not actionData.Position then
		return false, "No target position"
	end

	self:_CleanupEntity(entity, services)

	local commandGroupId = actionData.CommandGroupId

	-- Try boids mode if we have a group ID
	if commandGroupId then
		local userId = services.UserId
		if userId then
			local ok = BoidsHelper.InitGroupMovement(entity, actionData, services, userId)
			if ok then
				self._boidsEntities[entity] = commandGroupId
				self._previousVelocities[entity] = Vector3.zero

				services.NPCEntityFactory:SetLocomotionState(entity, "Moving")
				services.NPCEntityFactory:SetTarget(entity, nil)
				return true, nil
			end
		end
		-- Fall through to SimplePath if boids init failed
	end

	-- SimplePath mode (solo or fallback)
	local path = PathfindingHelper.CreatePath(entity, services)
	if not path then
		return false, "Failed to create pathfinding path"
	end

	local position = actionData.Position
	local targetVec = Vector3.new(position.X, position.Y, position.Z)
	self._promises[entity] = PathfindingHelper.RunPath(path, targetVec)

	services.NPCEntityFactory:SetLocomotionState(entity, "Moving")
	services.NPCEntityFactory:SetTarget(entity, nil)
	return true, nil
end

function MoveToPositionExecutor:Tick(entity: Entity, _deltaTime: number, services: TActionServices): string
	local npc = services.NPCEntityFactory

	-- Boids mode
	local commandGroupId = self._boidsEntities[entity]
	if commandGroupId then
		local previousVelocity = self._previousVelocities[entity] or Vector3.zero
		local moveDirection, hasArrived = BoidsHelper.TickEntity(
			entity, commandGroupId, previousVelocity, services
		)

		if hasArrived then
			npc:SetLocomotionState(entity, "Idle")
			return "Success"
		end

		-- Apply movement via Humanoid:Move
		local modelRef = npc:GetModelRef(entity)
		if modelRef and modelRef.Instance then
			local humanoid = modelRef.Instance:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid:Move(moveDirection)
				humanoid.AutoRotate = moveDirection.Magnitude > 0.1
			end
		end

		self._previousVelocities[entity] = moveDirection
		npc:SetLocomotionState(entity, "Moving")
		return "Running"
	end

	-- SimplePath mode
	local promise = self._promises[entity]

	if not promise or promise:getStatus() == Promise.Status.Rejected then
		return "Fail"
	end

	if promise:getStatus() == Promise.Status.Resolved then
		npc:SetLocomotionState(entity, "Idle")
		return "Success"
	end

	npc:SetLocomotionState(entity, "Moving")
	return "Running"
end

function MoveToPositionExecutor:Cancel(entity: Entity, services: TActionServices)
	-- Stop humanoid if in boids mode
	if self._boidsEntities[entity] then
		local modelRef = services.NPCEntityFactory:GetModelRef(entity)
		if modelRef and modelRef.Instance then
			local humanoid = modelRef.Instance:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid:Move(Vector3.zero)
			end
		end
	end

	self:_CleanupEntity(entity, services)
	services.NPCEntityFactory:SetLocomotionState(entity, "Idle")
end

function MoveToPositionExecutor:Complete(entity: Entity, services: TActionServices)
	-- Stop humanoid if in boids mode
	if self._boidsEntities[entity] then
		local modelRef = services.NPCEntityFactory:GetModelRef(entity)
		if modelRef and modelRef.Instance then
			local humanoid = modelRef.Instance:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid:Move(Vector3.zero)
			end
		end
	end

	self:_CleanupEntity(entity, services)
end

return MoveToPositionExecutor

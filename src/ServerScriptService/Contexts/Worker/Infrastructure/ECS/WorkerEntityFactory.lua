--!strict

--[[
    Worker Entity Factory - Creates and manipulates worker entities.

    Responsibilities:
    - Create worker entities with components
    - Update worker components (with immutability)
    - Query worker entities
    - Delete worker entities

    Pattern: Infrastructure layer service with dependency injection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

local ComponentRegistry = require(script.Parent.ComponentRegistry)

export type TWorkerComponent = ComponentRegistry.TWorkerComponent
export type TAssignmentComponent = ComponentRegistry.TAssignmentComponent
export type TPositionComponent = ComponentRegistry.TPositionComponent
export type TMiningStateComponent = ComponentRegistry.TMiningStateComponent
export type TEquipmentComponent = ComponentRegistry.TEquipmentComponent

--[=[
	@class WorkerEntityFactory
	Creates and manipulates worker ECS entities. Owns the authoritative component
	read/write interface — all other layers access worker state through this class.
	@server
]=]
local WorkerEntityFactory = {}
WorkerEntityFactory.__index = WorkerEntityFactory

export type TWorkerEntityFactory = typeof(setmetatable({} :: { World: any, Components: any, GameObjectFactory: any }, WorkerEntityFactory))

function WorkerEntityFactory.new(): TWorkerEntityFactory
	return setmetatable({}, WorkerEntityFactory)
end

function WorkerEntityFactory:Init(registry: any, _name: string)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.GameObjectFactory = registry:Get("GameObjectFactory")
end

--[=[
	Creates a new worker entity with all required components at the given position.
	@within WorkerEntityFactory
	@param userId number
	@param workerId string
	@param workerType string
	@param position Vector3? -- Spawns at origin when nil
	@return any -- JECS entity
]=]
function WorkerEntityFactory:CreateWorker(
	userId: number,
	workerId: string,
	workerType: string,
	position: Vector3?
): any
	local entity = self.World:entity()
	local world = self.World :: any

	-- WorkerComponent (core data)
	world:set(
		entity,
		self.Components.WorkerComponent,
		{
			Id = workerId,
			UserId = userId,
			Rank = workerType,
			Level = 1,
			Experience = 0,
		} :: TWorkerComponent
	)

	-- AssignmentComponent (production data)
	world:set(
		entity,
		self.Components.AssignmentComponent,
		{
			Role = "Undecided", -- Workers start as Undecided until role assigned
			TaskTarget = nil,
			LastProductionTick = os.time(),
		} :: TAssignmentComponent
	)

	-- PositionComponent (spatial data)
	local pos = position or Vector3.new(0, 0, 0)
	world:set(
		entity,
		self.Components.PositionComponent,
		{
			X = pos.X,
			Y = pos.Y,
			Z = pos.Z,
		} :: TPositionComponent
	)

	-- Mark as dirty for GameObject sync
	self.World:add(entity, self.Components.DirtyTag)
	self.World:set(entity, self.Components.EntityTag, `Worker:{workerId}`)
	self.World:set(entity, JECS.Name, `Worker:{workerId}`)

	return entity
end

--[=[
	Updates worker XP using the immutable clone pattern. Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
	@param newXP number
]=]
function WorkerEntityFactory:UpdateWorkerXP(entity: any, newXP: number)
	local worker = self.World:get(entity, self.Components.WorkerComponent)
	if not worker then
		warn("[WorkerEntityFactory:UpdateWorkerXP] Entity missing WorkerComponent")
		return
	end

	local updated = table.clone(worker)
	updated.Experience = newXP

	self.World:set(entity, self.Components.WorkerComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Sets level and XP together on level-up. Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
	@param newLevel number
	@param newXP number -- Remaining XP after level threshold
]=]
function WorkerEntityFactory:LevelUpWorker(entity: any, newLevel: number, newXP: number)
	local worker = self.World:get(entity, self.Components.WorkerComponent)
	if not worker then
		warn("[WorkerEntityFactory:LevelUpWorker] Entity missing WorkerComponent")
		return
	end

	local updated = table.clone(worker)
	updated.Level = newLevel
	updated.Experience = newXP

	self.World:set(entity, self.Components.WorkerComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Sets the worker's guild rank. Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
	@param rankId string
]=]
function WorkerEntityFactory:SetRank(entity: any, rankId: string)
	local worker = self.World:get(entity, self.Components.WorkerComponent)
	if not worker then
		warn("[WorkerEntityFactory:SetRank] Entity missing WorkerComponent")
		return
	end

	local updated = table.clone(worker)
	updated.Rank = rankId

	self.World:set(entity, self.Components.WorkerComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Records the timestamp of the last completed production cycle. Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
	@param tick number -- `os.time()` timestamp
]=]
function WorkerEntityFactory:UpdateLastProductionTick(entity: any, tick: number)
	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	if not assignment then
		warn("[WorkerEntityFactory:UpdateLastProductionTick] Entity missing AssignmentComponent")
		return
	end

	local updated = table.clone(assignment)
	updated.LastProductionTick = tick

	self.World:set(entity, self.Components.AssignmentComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Assigns the worker to a role. Clears TaskTarget and slot when the role changes.
	Marks entity dirty.

	:::caution
	Switching roles automatically calls `StopMining` and clears the slot index.
	Call this before setting a new TaskTarget for the new role.
	:::
	@within WorkerEntityFactory
	@param entity any
	@param roleId string
]=]
function WorkerEntityFactory:AssignRole(entity: any, roleId: string)
	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	if not assignment then
		warn("[WorkerEntityFactory:AssignRole] Entity missing AssignmentComponent")
		return
	end

	local updated = table.clone(assignment)
	local previousRole = assignment.Role
	updated.Role = roleId
	if roleId ~= previousRole then
		updated.TaskTarget = nil
		updated.SlotIndex = nil
		self:StopMining(entity)
	end

	self.World:set(entity, self.Components.AssignmentComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Sets the role-specific task target (e.g. ore type for Miner, recipe ID for Forge).
	Pass `nil` to clear. Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
	@param target string? -- nil clears the current target
]=]
function WorkerEntityFactory:AssignTaskTarget(entity: any, target: string?)
	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	if not assignment then
		warn("[WorkerEntityFactory:AssignTaskTarget] Entity missing AssignmentComponent")
		return
	end

	local updated = table.clone(assignment)
	updated.TaskTarget = target

	self.World:set(entity, self.Components.AssignmentComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Records the claimed radial slot index on the assignment. Pass `nil` to clear.
	Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
	@param slotIndex number?
]=]
function WorkerEntityFactory:AssignSlotIndex(entity: any, slotIndex: number?)
	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	if not assignment then
		warn("[WorkerEntityFactory:AssignSlotIndex] Entity missing AssignmentComponent")
		return
	end

	local updated = table.clone(assignment)
	updated.SlotIndex = slotIndex

	self.World:set(entity, self.Components.AssignmentComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Returns the AssignmentComponent for the entity, or nil if missing.
	@within WorkerEntityFactory
	@param entity any
	@return TAssignmentComponent?
]=]
function WorkerEntityFactory:GetAssignment(entity: any): TAssignmentComponent?
	return self.World:get(entity, self.Components.AssignmentComponent)
end

--[=[
	Returns the WorkerComponent for the entity, or nil if missing.
	@within WorkerEntityFactory
	@param entity any
	@return TWorkerComponent?
]=]
function WorkerEntityFactory:GetWorker(entity: any): TWorkerComponent?
	return self.World:get(entity, self.Components.WorkerComponent)
end

--[=[
	Returns the PositionComponent for the entity, or nil if missing.
	@within WorkerEntityFactory
	@param entity any
	@return TPositionComponent?
]=]
function WorkerEntityFactory:GetPosition(entity: any): TPositionComponent?
	return self.World:get(entity, self.Components.PositionComponent)
end

--[=[
	Returns the live workspace position of the worker's model, or nil if not yet spawned.
	@within WorkerEntityFactory
	@param entity any
	@return Vector3?
]=]
function WorkerEntityFactory:GetInstancePosition(entity: any): Vector3?
	local gameObj = self.World:get(entity, self.Components.GameObjectComponent)
	if not gameObj or not gameObj.Instance then
		return nil
	end
	return self.GameObjectFactory:GetWorkerPosition(gameObj.Instance)
end

--[=[
	Returns all worker entities belonging to the given user.
	@within WorkerEntityFactory
	@param userId number
	@return { { Entity: any, Worker: any, Assignment: any } }
]=]
function WorkerEntityFactory:QueryUserWorkers(userId: number): { { Entity: any, Worker: any, Assignment: any } }
	local workers = {}

	for entity in self.World:query(self.Components.WorkerComponent, self.Components.AssignmentComponent) do
		local worker = self.World:get(entity, self.Components.WorkerComponent)

		if worker and worker.UserId == userId then
			local assignment = self.World:get(entity, self.Components.AssignmentComponent)
			table.insert(workers, {
				Entity = entity,
				Worker = worker,
				Assignment = assignment,
			})
		end
	end

	return workers
end

--[=[
	Finds and returns the entity with the given worker ID, or nil.
	@within WorkerEntityFactory
	@param workerId string
	@return any?
]=]
function WorkerEntityFactory:FindWorkerById(workerId: string): any?
	for entity in self.World:query(self.Components.WorkerComponent) do
		local worker = self.World:get(entity, self.Components.WorkerComponent)
		if worker and worker.Id == workerId then
			return entity
		end
	end

	return nil
end

--[=[
	Deletes the worker entity from the ECS world.

	:::caution
	Call `GameObjectSyncService:DeleteEntity` before this so the workspace model
	is cleaned up before the component data is gone.
	:::
	@within WorkerEntityFactory
	@param entity any
]=]
function WorkerEntityFactory:DeleteWorker(entity: any)
	self.World:delete(entity)
end

--[=[
	Starts a timed action (mining, chopping, harvesting) on the entity. Reuses
	`MiningStateComponent` for all action-based roles. Marks entity dirty.

	:::note
	If the animation is already `"Mining"`, the state cycles through `"Idle"` first
	so `GetAttributeChangedSignal` fires and the animation restarts correctly.
	:::
	@within WorkerEntityFactory
	@param entity any
	@param oreId string -- Target ID (ore, tree, plant, or crop)
	@param duration number -- Action duration in seconds
]=]
function WorkerEntityFactory:StartMining(entity: any, oreId: string, duration: number, animationState: string?)
	local animState = animationState or "Mining"
	self.World:set(entity, self.Components.MiningStateComponent, {
		MiningStartTime = os.clock(),
		MiningDuration = duration,
		TargetOreId = oreId,
		AnimationState = animState,
	} :: TMiningStateComponent)
	self.World:add(entity, self.Components.DirtyTag)

	-- Signal animation state change — cycle through Idle first if already active
	-- so GetAttributeChangedSignal fires and the animation replays
	local gameObject = self.World:get(entity, self.Components.GameObjectComponent)
	if gameObject and self.GameObjectFactory then
		local model = gameObject.Instance
		if model:GetAttribute("AnimationState") == animState then
			self.GameObjectFactory:SetAnimationState(model, "Idle", false)
		end
		self.GameObjectFactory:SetAnimationState(model, animState, true)
	end
end

--[=[
	Stops the active timed action by removing `MiningStateComponent`. No-op if none.
	Marks entity dirty and transitions animation to `"Idle"`.
	@within WorkerEntityFactory
	@param entity any
]=]
function WorkerEntityFactory:StopMining(entity: any)
	if self.World:get(entity, self.Components.MiningStateComponent) then
		self.World:remove(entity, self.Components.MiningStateComponent)
		self.World:add(entity, self.Components.DirtyTag)

		-- Signal animation state change
		local gameObject = self.World:get(entity, self.Components.GameObjectComponent)
		if gameObject and self.GameObjectFactory then
			self.GameObjectFactory:SetAnimationState(gameObject.Instance, "Idle", false)
		end
	end
end

--[=[
	Teleports the worker model to the given position and updates `PositionComponent`.
	When `lookAt` coords are provided the model faces that point.
	@within WorkerEntityFactory
	@param entity any
	@param x number
	@param y number
	@param z number
	@param lookAtX number?
	@param lookAtY number?
	@param lookAtZ number?
]=]
function WorkerEntityFactory:UpdatePosition(
	entity: any,
	x: number,
	y: number,
	z: number,
	lookAtX: number?,
	lookAtY: number?,
	lookAtZ: number?
)
	-- Teleport the model directly — position is no longer driven by the sync loop
	local gameObj = self.World:get(entity, self.Components.GameObjectComponent)
	if gameObj and gameObj.Instance then
		local pos = Vector3.new(x, y, z)
		local lookAt = (lookAtX and lookAtY and lookAtZ)
			and Vector3.new(lookAtX, lookAtY, lookAtZ)
			or nil
		self.GameObjectFactory:UpdateWorkerPosition(gameObj.Instance, pos, lookAt)
	end

	-- Reflect into PositionComponent as a read value
	self.World:set(entity, self.Components.PositionComponent, {
		X = x,
		Y = y,
		Z = z,
		LookAtX = lookAtX,
		LookAtY = lookAtY,
		LookAtZ = lookAtZ,
	} :: TPositionComponent)
end

--[=[
	Sets the `EquipmentComponent`, triggering `GameObjectSyncService` to attach the tool.
	Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
	@param toolId string
	@param slot string -- e.g. `"MainHand"`
]=]
function WorkerEntityFactory:SetEquipment(entity: any, toolId: string, slot: string)
	self.World:set(entity, self.Components.EquipmentComponent, {
		ToolId = toolId,
		Slot = slot,
	} :: TEquipmentComponent)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Removes the `EquipmentComponent`, triggering `GameObjectSyncService` to detach the tool.
	No-op if none equipped. Marks entity dirty.
	@within WorkerEntityFactory
	@param entity any
]=]
function WorkerEntityFactory:ClearEquipment(entity: any)
	if self.World:get(entity, self.Components.EquipmentComponent) then
		self.World:remove(entity, self.Components.EquipmentComponent)
		self.World:add(entity, self.Components.DirtyTag)
	end
end

--[=[
	Returns all entities that currently have an active `MiningStateComponent`.
	Includes miners, lumberjacks, herbalists, and farmers — any role using timed actions.
	@within WorkerEntityFactory
	@return { { Entity: any, Worker: any, Assignment: any, MiningState: any } }
]=]
function WorkerEntityFactory:QueryActiveMiners(): { { Entity: any, Worker: any, Assignment: any, MiningState: any } }
	local miners = {}

	for entity in self.World:query(
		self.Components.WorkerComponent,
		self.Components.AssignmentComponent,
		self.Components.MiningStateComponent
	) do
		local worker = self.World:get(entity, self.Components.WorkerComponent)
		local assignment = self.World:get(entity, self.Components.AssignmentComponent)
		local miningState = self.World:get(entity, self.Components.MiningStateComponent)
		table.insert(miners, {
			Entity = entity,
			Worker = worker,
			Assignment = assignment,
			MiningState = miningState,
		})
	end

	return miners
end

return WorkerEntityFactory

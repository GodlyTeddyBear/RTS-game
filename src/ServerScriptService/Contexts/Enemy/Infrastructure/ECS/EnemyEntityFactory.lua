--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

type TCombatActionState = "None" | "Running" | "Committed"

type TCombatAction = {
	CurrentActionId: string?,
	ActionState: TCombatActionState,
	ActionData: any?,
	PendingActionId: string?,
	PendingActionData: any?,
	ActionStartedAt: number?,
}

--[=[
	@class EnemyEntityFactory
	Creates and mutates enemy entities in the EnemyContext ECS world.
	@server
]=]
local EnemyEntityFactory = {}
EnemyEntityFactory.__index = EnemyEntityFactory

function EnemyEntityFactory.new()
	return setmetatable({}, EnemyEntityFactory)
end

local function _buildDefaultAction(): TCombatAction
	return {
		CurrentActionId = nil,
		ActionState = "None",
		ActionData = nil,
		PendingActionId = nil,
		PendingActionData = nil,
		ActionStartedAt = nil,
	}
end

function EnemyEntityFactory:Init(registry: any, _name: string)
	self._world = registry:Get("World")
	self._components = registry:Get("EnemyComponentRegistry"):GetComponents()
	assert(self._components ~= nil and self._components.AliveTag ~= nil, "EnemyEntityFactory: missing EnemyComponentRegistry components")
end

function EnemyEntityFactory:CreateEnemy(enemyId: string, role: string, spawnCFrame: CFrame, waveNumber: number): number
	local roleConfig = EnemyConfig.ROLES[role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(role))
	local entity = self._world:entity()

	self._world:set(entity, self._components.Health, {
		current = roleConfig.maxHp,
		max = roleConfig.maxHp,
	})
	self._world:set(entity, self._components.Position, {
		cframe = spawnCFrame,
	})
	self._world:set(entity, self._components.Role, {
		role = role,
		moveSpeed = roleConfig.moveSpeed,
		damage = roleConfig.damage,
		targetPreference = roleConfig.targetPreference,
	})
	self._world:set(entity, self._components.PathState, {
		waypointIndex = 1,
		waypoints = {},
		isMoving = false,
	})
	self._world:set(entity, self._components.Identity, {
		enemyId = enemyId,
		role = role,
		waveNumber = waveNumber,
	})
	self._world:set(entity, self._components.CombatAction, _buildDefaultAction())
	self._world:set(entity, self._components.AttackCooldown, {
		Cooldown = 0,
		LastAttackTime = 0,
	})
	self._world:set(entity, self._components.BehaviorConfig, {
		TickInterval = 0.15,
	})
	self._world:add(entity, self._components.AliveTag)

	return entity
end

function EnemyEntityFactory:SetModelRef(entity: number, model: Model)
	self._world:set(entity, self._components.ModelRef, { model = model })
	self._world:add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:SetWaypoints(entity: number, waypoints: { Vector3 })
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self._world:set(entity, self._components.PathState, {
		waypointIndex = 1,
		waypoints = table.clone(waypoints),
		isMoving = false,
	})
end

function EnemyEntityFactory:SetPathMoving(entity: number, isMoving: boolean)
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end
	if state.isMoving == isMoving then
		return
	end

	self._world:set(entity, self._components.PathState, {
		waypointIndex = state.waypointIndex,
		waypoints = state.waypoints,
		isMoving = isMoving,
	})
	self._world:add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:SetWaypointIndex(entity: number, waypointIndex: number)
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self._world:set(entity, self._components.PathState, {
		waypointIndex = waypointIndex,
		waypoints = state.waypoints,
		isMoving = state.isMoving,
	})
end

function EnemyEntityFactory:SetBehaviorTree(entity: number, treeInstance: any, tickInterval: number)
	self._world:set(entity, self._components.BehaviorTree, {
		TreeInstance = treeInstance,
		TickInterval = tickInterval,
		LastTickTime = 0,
	})
end

function EnemyEntityFactory:GetBehaviorTree(entity: number)
	return self._world:get(entity, self._components.BehaviorTree)
end

function EnemyEntityFactory:UpdateBTLastTickTime(entity: number, currentTime: number)
	local behaviorTree = self:GetBehaviorTree(entity)
	if behaviorTree == nil then
		return
	end

	self._world:set(entity, self._components.BehaviorTree, {
		TreeInstance = behaviorTree.TreeInstance,
		TickInterval = behaviorTree.TickInterval,
		LastTickTime = currentTime,
	})
end

function EnemyEntityFactory:GetCombatAction(entity: number)
	return self._world:get(entity, self._components.CombatAction)
end

function EnemyEntityFactory:SetPendingAction(entity: number, actionId: string, actionData: any?)
	local action = self:GetCombatAction(entity) or _buildDefaultAction()
	self._world:set(entity, self._components.CombatAction, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = actionId,
		PendingActionData = actionData,
		ActionStartedAt = action.ActionStartedAt,
	})
end

function EnemyEntityFactory:ClearPendingAction(entity: number)
	local action = self:GetCombatAction(entity) or _buildDefaultAction()
	self._world:set(entity, self._components.CombatAction, {
		CurrentActionId = action.CurrentActionId,
		ActionState = action.ActionState,
		ActionData = action.ActionData,
		PendingActionId = nil,
		PendingActionData = nil,
		ActionStartedAt = action.ActionStartedAt,
	})
end

function EnemyEntityFactory:StartAction(entity: number, actionId: string, actionData: any?, currentTime: number)
	self._world:set(entity, self._components.CombatAction, {
		CurrentActionId = actionId,
		ActionState = "Running",
		ActionData = actionData,
		PendingActionId = nil,
		PendingActionData = nil,
		ActionStartedAt = currentTime,
	})
end

function EnemyEntityFactory:ClearAction(entity: number)
	self._world:set(entity, self._components.CombatAction, _buildDefaultAction())
end

function EnemyEntityFactory:ResetActionState(entity: number)
	local action = self:GetCombatAction(entity)
	if action == nil then
		return
	end

	self._world:set(entity, self._components.CombatAction, {
		CurrentActionId = action.CurrentActionId,
		ActionState = "None",
		ActionData = action.ActionData,
		PendingActionId = nil,
		PendingActionData = nil,
		ActionStartedAt = action.ActionStartedAt,
	})
end

function EnemyEntityFactory:GetBehaviorConfig(entity: number)
	return self._world:get(entity, self._components.BehaviorConfig)
end

function EnemyEntityFactory:SetBehaviorConfig(entity: number, config: { TickInterval: number })
	self._world:set(entity, self._components.BehaviorConfig, {
		TickInterval = config.TickInterval,
	})

	local behaviorTree = self:GetBehaviorTree(entity)
	if behaviorTree ~= nil then
		self._world:set(entity, self._components.BehaviorTree, {
			TreeInstance = behaviorTree.TreeInstance,
			TickInterval = config.TickInterval,
			LastTickTime = behaviorTree.LastTickTime,
		})
	end
end

function EnemyEntityFactory:MarkGoalReached(entity: number)
	self._world:remove(entity, self._components.AliveTag)
	self._world:add(entity, self._components.GoalReachedTag)
	self._world:add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:ClearGoalReached(entity: number)
	self._world:remove(entity, self._components.GoalReachedTag)
	self._world:add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:ApplyDamage(entity: number, amount: number): boolean
	local health = self:GetHealth(entity)
	if health == nil then
		return false
	end

	local nextHp = math.max(0, health.current - amount)
	self._world:set(entity, self._components.Health, {
		current = nextHp,
		max = health.max,
	})
	self._world:add(entity, self._components.DirtyTag)

	return nextHp <= 0
end

function EnemyEntityFactory:UpdatePosition(entity: number, cframe: CFrame)
	self._world:set(entity, self._components.Position, { cframe = cframe })
end

function EnemyEntityFactory:GetDeathCFrame(entity: number): CFrame?
	local modelRef = self:GetModelRef(entity)
	if modelRef ~= nil then
		return modelRef.model:GetPivot()
	end

	local position = self:GetPosition(entity)
	if position ~= nil then
		return position.cframe
	end

	return nil
end

function EnemyEntityFactory:IsAlive(entity: number): boolean
	return self._world:has(entity, self._components.AliveTag)
end

function EnemyEntityFactory:GetHealth(entity: number)
	return self._world:get(entity, self._components.Health)
end

function EnemyEntityFactory:GetRole(entity: number)
	return self._world:get(entity, self._components.Role)
end

function EnemyEntityFactory:GetIdentity(entity: number)
	return self._world:get(entity, self._components.Identity)
end

function EnemyEntityFactory:GetPathState(entity: number)
	return self._world:get(entity, self._components.PathState)
end

function EnemyEntityFactory:GetModelRef(entity: number)
	return self._world:get(entity, self._components.ModelRef)
end

function EnemyEntityFactory:GetPosition(entity: number)
	return self._world:get(entity, self._components.Position)
end

function EnemyEntityFactory:QueryAliveEntities(): { number }
	local entities = {}
	for entity in self._world:query(self._components.AliveTag) do
		table.insert(entities, entity)
	end
	return entities
end

function EnemyEntityFactory:QueryGoalReachedEntities(): { number }
	local entities = {}
	for entity in self._world:query(self._components.GoalReachedTag) do
		table.insert(entities, entity)
	end
	return entities
end

function EnemyEntityFactory:DeleteEntity(entity: number)
	self._world:delete(entity)
end

return EnemyEntityFactory

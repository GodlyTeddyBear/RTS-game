--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local EnemyEntityReadService = {}
EnemyEntityReadService.__index = EnemyEntityReadService

function EnemyEntityReadService.new(entityContext: any)
	local self = setmetatable({}, EnemyEntityReadService)
	self._entityContext = entityContext
	return self
end

function EnemyEntityReadService:Configure(entityContext: any)
	self._entityContext = entityContext
end

function EnemyEntityReadService:QueryAliveEntities(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Enemy",
		Keys = { "AliveTag" },
	})
	if not queryResult.success then
		return {}
	end

	return queryResult.value
end

function EnemyEntityReadService:QueryGoalReachedEntities(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Enemy",
		Keys = { "GoalReachedTag" },
	})
	if not queryResult.success then
		return {}
	end

	return queryResult.value
end

function EnemyEntityReadService:IsAlive(entity: number): boolean
	local hasResult = self._entityContext:Has(entity, "AliveTag", "Enemy")
	return hasResult.success and hasResult.value == true
end

function EnemyEntityReadService:GetIdentity(entity: number): any?
	local identityResult = self._entityContext:Get(entity, "Identity", "Entity")
	local roleResult = self._entityContext:Get(entity, "Role", "Enemy")
	if not identityResult.success or type(identityResult.value) ~= "table" then
		return nil
	end

	local role = if roleResult.success and type(roleResult.value) == "table" then roleResult.value else nil

	return {
		EnemyId = identityResult.value.EntityId,
		Role = identityResult.value.DefinitionId or (role and role.Role) or nil,
		WaveNumber = role and role.WaveNumber or nil,
	}
end

function EnemyEntityReadService:GetRole(entity: number): any?
	local roleResult = self._entityContext:Get(entity, "Role", "Enemy")
	if roleResult.success then
		return roleResult.value
	end

	return nil
end

function EnemyEntityReadService:GetBaseMoveSpeed(entity: number): number?
	local role = self:GetRole(entity)
	if type(role) == "table" and type(role.MoveSpeed) == "number" then
		return role.MoveSpeed
	end

	return nil
end

function EnemyEntityReadService:GetCurrentMoveSpeed(entity: number): number?
	local moveSpeedResult = self._entityContext:Get(entity, "CurrentMoveSpeed", "Enemy")
	if moveSpeedResult.success and type(moveSpeedResult.value) == "table" then
		return moveSpeedResult.value.Value
	end

	return nil
end

function EnemyEntityReadService:SetCurrentMoveSpeed(entity: number, speed: number)
	if type(speed) ~= "number" then
		return
	end

	self._entityContext:Set(entity, "CurrentMoveSpeed", {
		Value = speed,
	}, "Enemy")
end

function EnemyEntityReadService:GetHealth(entity: number): any?
	local healthResult = self._entityContext:Get(entity, "Health", "Entity")
	if healthResult.success then
		return healthResult.value
	end

	return nil
end

function EnemyEntityReadService:GetPosition(entity: number): any?
	local transformResult = self._entityContext:Get(entity, "Transform", "Entity")
	if not transformResult.success or type(transformResult.value) ~= "table" then
		return nil
	end

	return transformResult.value
end

function EnemyEntityReadService:GetEntityCFrame(entity: number): CFrame?
	local transform = self:GetPosition(entity)
	if transform == nil or typeof(transform.CFrame) ~= "CFrame" then
		return nil
	end

	return transform.CFrame
end

function EnemyEntityReadService:GetDeathCFrame(entity: number): CFrame?
	return self:GetEntityCFrame(entity)
end

function EnemyEntityReadService:GetPathState(entity: number): any?
	local pathStateResult = self._entityContext:Get(entity, "PathState", "Enemy")
	if pathStateResult.success then
		return pathStateResult.value
	end

	return nil
end

function EnemyEntityReadService:GetTarget(entity: number): any?
	local targetResult = self._entityContext:Get(entity, "Target", "Entity")
	if targetResult.success then
		return targetResult.value
	end

	return nil
end

function EnemyEntityReadService:GetEntityByEnemyId(enemyId: string): number?
	if type(enemyId) ~= "string" or enemyId == "" then
		return nil
	end

	local queryResult = self._entityContext:Query({
		FeatureName = "Enemy",
		Keys = { "Role" },
	})
	if not queryResult.success then
		return nil
	end

	for _, entity in ipairs(queryResult.value) do
		local identity = self:GetIdentity(entity)
		if type(identity) == "table" and identity.EnemyId == enemyId then
			return entity
		end
	end

	return nil
end

function EnemyEntityReadService:GetNearestAliveEnemy(position: Vector3, maxRange: number): { Entity: number, CFrame: CFrame }?
	local nearestEntity = SpatialQuery.FindBestCandidate(
		position,
		self:QueryAliveEntities(),
		function(entity: number): Vector3?
			local cframe = self:GetEntityCFrame(entity)
			return if cframe ~= nil then cframe.Position else nil
		end,
		function(_entity: number, distance: number): number?
			return -distance
		end,
		maxRange
	)

	if nearestEntity == nil then
		return nil
	end

	local nearestCFrame = self:GetEntityCFrame(nearestEntity)
	if nearestCFrame == nil then
		return nil
	end

	return {
		Entity = nearestEntity,
		CFrame = nearestCFrame,
	}
end

return EnemyEntityReadService

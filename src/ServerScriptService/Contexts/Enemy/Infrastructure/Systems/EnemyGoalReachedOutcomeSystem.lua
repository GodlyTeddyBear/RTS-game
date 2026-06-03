--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local EnemyGoalReachedOutcomeSystem = {}
EnemyGoalReachedOutcomeSystem.__index = EnemyGoalReachedOutcomeSystem

function EnemyGoalReachedOutcomeSystem.new(entityFactory: any)
	return setmetatable({ _entityFactory = entityFactory }, EnemyGoalReachedOutcomeSystem)
end

function EnemyGoalReachedOutcomeSystem:Run()
	-- READS: Combat.GoalReachedOutcomeRequest, Combat.RequestTag
	-- WRITES: Enemy.GoalReachedTag, Combat.BaseDamageRequest, Combat.ProcessedTag, Entity.DestructionQueue
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "GoalReachedOutcomeRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function EnemyGoalReachedOutcomeSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "GoalReachedOutcomeRequest", "Combat")
	if type(request) ~= "table" or request.OutcomeId ~= "EnemyGoalReached" then
		return
	end

	local enemyEntity = request.SourceEntity
	if type(enemyEntity) ~= "number" or not self._entityFactory:Exists(enemyEntity) then
		self:_Processed(requestEntity)
		return
	end

	self._entityFactory:Remove(enemyEntity, "AliveTag", "Enemy")
	self._entityFactory:Add(enemyEntity, "GoalReachedTag", "Enemy")
	self:_EmitEnemyDeath(enemyEntity)
	self:_RequestBaseDamage(enemyEntity)
	self._entityFactory:MarkEntityForDestruction(enemyEntity)
	self:_Processed(requestEntity)
end

function EnemyGoalReachedOutcomeSystem:_RequestBaseDamage(entity: number)
	local role = self:_Get(entity, "Role", "Enemy")
	local roleId = if type(role) == "table" then role.Role else nil
	local roleConfig = if type(roleId) == "string" then EnemyConfig.Roles[roleId] else nil
	if roleConfig == nil or type(roleConfig.Damage) ~= "number" then
		return
	end

	local now = os.clock()
	self._entityFactory:CreateFromArchetype("Combat.BaseDamageRequest", {
		BaseDamageRequest = {
			Amount = roleConfig.Damage,
			CreatedAt = now,
			ExpiresAt = now + 1,
		},
	})
end

function EnemyGoalReachedOutcomeSystem:_EmitEnemyDeath(entity: number)
	local identity = self:_Get(entity, "Identity", "Entity")
	local role = self:_Get(entity, "Role", "Enemy")
	local transform = self:_Get(entity, "Transform", "Entity")
	local roleId = if type(role) == "table" then role.Role else nil
	local waveNumber = if type(role) == "table" then role.WaveNumber else nil
	if type(identity) ~= "table" or type(roleId) ~= "string" or type(waveNumber) ~= "number" then
		return
	end

	local deathCFrame = if type(transform) == "table" and typeof(transform.CFrame) == "CFrame"
		then transform.CFrame
		else CFrame.new()
	GameEvents.Bus:Emit(GameEvents.Events.Wave.EnemyDied, roleId, waveNumber, deathCFrame)
end

function EnemyGoalReachedOutcomeSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

function EnemyGoalReachedOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyGoalReachedOutcomeSystem

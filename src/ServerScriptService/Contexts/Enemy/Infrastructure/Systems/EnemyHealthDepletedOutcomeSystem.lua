--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local EnemyHealthDepletedOutcomeSystem = {}
EnemyHealthDepletedOutcomeSystem.__index = EnemyHealthDepletedOutcomeSystem

function EnemyHealthDepletedOutcomeSystem.new(entityFactory: any)
	return setmetatable({ _entityFactory = entityFactory }, EnemyHealthDepletedOutcomeSystem)
end

function EnemyHealthDepletedOutcomeSystem:Run()
	-- READS: Combat.HealthDepletedOutcomeRequest, Combat.RequestTag
	-- WRITES: Combat.ProcessedTag, Entity.DestructionQueue
	local result =
		self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthDepletedOutcomeRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function EnemyHealthDepletedOutcomeSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "HealthDepletedOutcomeRequest", "Combat")
	if type(request) ~= "table" or request.OutcomeId ~= "EnemyDeath" then
		return
	end

	local enemyEntity = request.VictimEntity
	if type(enemyEntity) == "number" and self._entityFactory:Exists(enemyEntity) then
		self:_EmitEnemyDeath(enemyEntity)
		self._entityFactory:MarkEntityForDestruction(enemyEntity)
	end
	self:_Processed(requestEntity)
end

function EnemyHealthDepletedOutcomeSystem:_EmitEnemyDeath(entity: number)
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

function EnemyHealthDepletedOutcomeSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

function EnemyHealthDepletedOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyHealthDepletedOutcomeSystem

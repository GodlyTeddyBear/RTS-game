--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local EnemyDeathEventSystem = {}
EnemyDeathEventSystem.__index = EnemyDeathEventSystem

function EnemyDeathEventSystem.new(entityFactory: any)
	return setmetatable({
		_entityFactory = entityFactory,
	}, EnemyDeathEventSystem)
end

function EnemyDeathEventSystem:Run()
	-- READS: Enemy.DeathEventRequest, Enemy.RequestTag
	-- WRITES: Enemy.ProcessedTag
	local result = self._entityFactory:Query({ FeatureName = "Enemy", Keys = { "DeathEventRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function EnemyDeathEventSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "DeathEventRequest", "Enemy")
	local enemyEntity = if type(request) == "table" then request.EnemyEntity or request.SourceEntity else nil
	if type(enemyEntity) == "number" then
		self:_EmitEnemyDeath(enemyEntity)
	end
	self._entityFactory:Add(requestEntity, "ProcessedTag", "Enemy")
end

function EnemyDeathEventSystem:_EmitEnemyDeath(entity: number)
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

function EnemyDeathEventSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyDeathEventSystem

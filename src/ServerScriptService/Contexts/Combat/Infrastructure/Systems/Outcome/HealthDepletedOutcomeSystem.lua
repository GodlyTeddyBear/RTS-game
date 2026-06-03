--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local HealthDepletedOutcomeSystem = {}
HealthDepletedOutcomeSystem.__index = HealthDepletedOutcomeSystem

function HealthDepletedOutcomeSystem.new(entityFactory: any, dependencies: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_entityContext = dependencies.EntityContext,
		_ruleRegistry = dependencies.RuleRegistry,
	}, HealthDepletedOutcomeSystem)
end

function HealthDepletedOutcomeSystem:Run()
	-- READS: Combat.HealthDepletedRequest [AUTHORITATIVE]
	-- WRITES: Combat.ProcessedTag, Entity.DestructionQueue
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthDepletedRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function HealthDepletedOutcomeSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "HealthDepletedRequest", "Combat")
	if type(request) ~= "table" or type(request.VictimKind) ~= "string" then
		self:_Processed(requestEntity)
		return
	end

	local outcome = if type(request.VictimEntity) == "number"
		then self:_Get(request.VictimEntity, "HealthDepletedOutcome", "Entity")
		else nil
	local outcomeId = if type(outcome) == "table" and type(outcome.OutcomeId) == "string"
		then outcome.OutcomeId
		else request.VictimKind
	local rule = self._ruleRegistry:GetHealthDepletedRule(outcomeId)
	if type(rule) ~= "table" then
		self:_Processed(requestEntity)
		return
	end

	if rule.EmitEnemyDeath == true and request.VictimKind == "Enemy" then
		self:_EmitEnemyDeath(request.VictimEntity)
	end
	if rule.MarkVictimForDestruction == true and type(request.VictimEntity) == "number" then
		self._entityContext:MarkForDestruction(request.VictimEntity)
	end

	self:_Processed(requestEntity)
end

function HealthDepletedOutcomeSystem:_EmitEnemyDeath(entity: number?)
	if type(entity) ~= "number" then
		return
	end

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

function HealthDepletedOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function HealthDepletedOutcomeSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return HealthDepletedOutcomeSystem

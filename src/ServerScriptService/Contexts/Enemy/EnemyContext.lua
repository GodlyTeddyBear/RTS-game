--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local EnemyEntityReadService = require(script.Parent.Infrastructure.Entity.EnemyEntityReadService)
local EnemyEntitySchema = require(script.Parent.Infrastructure.Entity.EnemyEntitySchema)
local EnemySpawnPolicy = require(script.Parent.EnemyDomain.Policies.EnemySpawnPolicy)
local EnemyAIBehaviors = require(script.Parent.Config.AIBehaviors)
local EnemyAIProfiles = require(script.Parent.Config.AIProfiles)
local EnemyCombatRules = require(script.Parent.Config.CombatRules)
local EnemyDeathEventSystem = require(script.Parent.Infrastructure.Systems.EnemyDeathEventSystem)
local EnemyGoalReachedOutcomeSystem = require(script.Parent.Infrastructure.Systems.EnemyGoalReachedOutcomeSystem)
local EnemyRequestCleanupSystem = require(script.Parent.Infrastructure.Systems.EnemyRequestCleanupSystem)

local SpawnEnemyCommand = require(script.Parent.Application.Commands.SpawnEnemy)
local DespawnEnemyCommand = require(script.Parent.Application.Commands.DespawnEnemy)
local ApplyDamageEnemyCommand = require(script.Parent.Application.Commands.ApplyDamageEnemy)
local CleanupAllEnemiesCommand = require(script.Parent.Application.Commands.CleanupAllEnemies)
local GetAliveEnemiesQuery = require(script.Parent.Application.Queries.GetAliveEnemiesQuery)
local GetEnemyCountQuery = require(script.Parent.Application.Queries.GetEnemyCountQuery)
local GetNearestAliveEnemyQuery = require(script.Parent.Application.Queries.GetNearestAliveEnemyQuery)

local Catch = Result.Catch
local Ok = Result.Ok

local function moduleSpec(name: string, module: any, cacheAs: string?): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "EnemyEntityReadService",
		Factory = function(service: any, _baseContext: any)
			return EnemyEntityReadService.new(service._entityContext)
		end,
		CacheAs = "_enemyEntityReadService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	moduleSpec("EnemySpawnPolicy", EnemySpawnPolicy),
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("SpawnEnemyCommand", SpawnEnemyCommand, "_spawnEnemyCommand"),
	moduleSpec("DespawnEnemyCommand", DespawnEnemyCommand, "_despawnEnemyCommand"),
	moduleSpec("ApplyDamageEnemyCommand", ApplyDamageEnemyCommand, "_applyDamageEnemyCommand"),
	moduleSpec("CleanupAllEnemiesCommand", CleanupAllEnemiesCommand, "_cleanupAllEnemiesCommand"),
	moduleSpec("GetAliveEnemiesQuery", GetAliveEnemiesQuery, "_getAliveEnemiesQuery"),
	moduleSpec("GetEnemyCountQuery", GetEnemyCountQuery, "_getEnemyCountQuery"),
	moduleSpec("GetNearestAliveEnemyQuery", GetNearestAliveEnemyQuery, "_getNearestAliveEnemyQuery"),
}

local EnemyContext = Knit.CreateService({
	Name = "EnemyContext",
	Client = {},
	Modules = {
		Infrastructure = InfrastructureModules,
		Domain = DomainModules,
		Application = ApplicationModules,
	},
	ExternalServices = {
		{ Name = "AIContext", CacheAs = "_aiContext" },
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "StructureContext", CacheAs = "_structureContext" },
		{ Name = "BaseContext", CacheAs = "_baseContext" },
		{ Name = "CombatContext", CacheAs = "_combatContext" },
		{ Name = "TeamContext", CacheAs = "_teamContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_spawnConnection", Method = "Disconnect" },
			{ Field = "_waveEndedConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
		},
	},
})

local EnemyBaseContext = BaseContext.new(EnemyContext)

function EnemyContext:KnitInit()
	EnemyBaseContext:KnitInit()
	self._spawnConnection = nil :: any
	self._waveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
end

function EnemyContext:KnitStart()
	EnemyBaseContext:KnitStart()
	self._enemyEntityReadService:Configure(self._entityContext)

	local registrationResult = self:_RegisterEntityInfrastructure()
	if not registrationResult.success then
		error(("EnemyContext failed to register Entity infrastructure: [%s] %s"):format(
			tostring(registrationResult.type),
			tostring(registrationResult.message)
		))
	end

	local aiResult = self:_RegisterAIContracts()
	if not aiResult.success then
		error(("EnemyContext failed to register AI contracts: [%s] %s"):format(
			tostring(aiResult.type),
			tostring(aiResult.message)
		))
	end

	local combatRuleResult = self:_RegisterCombatRules()
	if not combatRuleResult.success then
		error(("EnemyContext failed to register Combat rules: [%s] %s"):format(
			tostring(combatRuleResult.type),
			tostring(combatRuleResult.message)
		))
	end

	EnemyBaseContext:OnContextEvent(
		"Wave",
		"SpawnEnemy",
		function(role: string, spawnCFrame: CFrame, waveNumber: number)
			self:_OnWaveSpawnEnemy(role, spawnCFrame, waveNumber)
		end,
		"_spawnConnection"
	)

	EnemyBaseContext:OnContextEvent("Run", "WaveEnded", function()
		self:_OnWaveEnded()
	end, "_waveEndedConnection")

	EnemyBaseContext:OnContextEvent("Run", "RunEnded", function()
		self:_OnRunEnded()
	end, "_runEndedConnection")
end

function EnemyContext:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		local featureResult = self._entityContext:RegisterEntityFeature({
			FeatureName = "Enemy",
			Schema = EnemyEntitySchema,
		})
		if not featureResult.success then
			return featureResult
		end

		local goalReachedResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "EnemyGoalReachedOutcomeSystem",
			Phase = "RequestResolve",
			Reads = {
				"Combat.GoalReachedOutcomeRequest",
				"Combat.RequestTag",
			},
			Writes = {
				"Enemy.GoalReachedTag",
				"Combat.HealthChangeRequest",
				"Combat.ProcessedTag",
				"Entity.DestructionQueue",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return EnemyGoalReachedOutcomeSystem.new(entityFactory)
			end,
		})
		if not goalReachedResult.success then
			return goalReachedResult
		end

		local deathEventResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "EnemyDeathEventSystem",
			Phase = "RequestResolve",
			Reads = {
				"Enemy.DeathEventRequest",
				"Enemy.RequestTag",
			},
			Writes = {
				"Enemy.ProcessedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return EnemyDeathEventSystem.new(entityFactory)
			end,
		})
		if not deathEventResult.success then
			return deathEventResult
		end

		return self._entityContext:RegisterSystem("Cleanup", {
			Name = "EnemyRequestCleanupSystem",
			Phase = "Cleanup",
			Reads = {
				"Enemy.DeathEventRequest",
				"Enemy.RequestTag",
				"Enemy.ProcessedTag",
			},
			Writes = {
				"Entity.DestructionQueue",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return EnemyRequestCleanupSystem.new(entityFactory)
			end,
		})
	end, "EnemyContext:RegisterEntityInfrastructure")
end

function EnemyContext:_RegisterAIContracts(): Result.Result<boolean>
	return Catch(function()
		for _, behaviorPayload in pairs(EnemyAIBehaviors) do
			local behaviorResult = self._aiContext:RegisterBehaviorDefinition(behaviorPayload)
			if not behaviorResult.success and behaviorResult.type ~= "DuplicateBehaviorDefinition" then
				return behaviorResult
			end
		end

		for _, profilePayload in pairs(EnemyAIProfiles) do
			local profileResult = self._aiContext:RegisterProfile(profilePayload)
			if not profileResult.success and profileResult.type ~= "DuplicateProfile" then
				return profileResult
			end
		end

		return Ok(true)
	end, "EnemyContext:RegisterAIContracts")
end

function EnemyContext:_RegisterCombatRules(): Result.Result<boolean>
	return Catch(function()
		for _, payload in ipairs(EnemyCombatRules.MovementPresentation or {}) do
			local result = self._combatContext:RegisterMovementPresentationRule(payload)
			if not result.success then
				return result
			end
		end
		for _, payload in ipairs(EnemyCombatRules.GoalReached or {}) do
			local result = self._combatContext:RegisterMovementGoalReachedRule(payload)
			if not result.success then
				return result
			end
		end
		for _, payload in ipairs(EnemyCombatRules.HealthDepleted or {}) do
			local result = self._combatContext:RegisterHealthDepletedRule(payload)
			if not result.success then
				return result
			end
		end
		return Ok(true)
	end, "EnemyContext:RegisterCombatRules")
end

function EnemyContext:_OnWaveSpawnEnemy(role: string, spawnCFrame: CFrame, waveNumber: number)
	local result = self:SpawnEnemy(role, spawnCFrame, waveNumber)
	if not result.success then
		Result.MentionError("Enemy:OnWaveSpawnEnemy", "Failed to spawn enemy", {
			Role = role,
			WaveNumber = waveNumber,
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function EnemyContext:_OnRunEnded()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Enemy:OnRunEnded", "Failed to cleanup enemies after run ended", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function EnemyContext:_OnWaveEnded()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Enemy:OnWaveEnded", "Failed to cleanup enemies after wave ended", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function EnemyContext:SpawnEnemy(role: string, spawnCFrame: CFrame, waveNumber: number): Result.Result<number>
	return Catch(function()
		return self._spawnEnemyCommand:Execute(role, spawnCFrame, waveNumber)
	end, "Enemy:SpawnEnemy")
end

function EnemyContext:DespawnEnemy(entity: any): Result.Result<boolean>
	return Catch(function()
		return self._despawnEnemyCommand:Execute(entity)
	end, "Enemy:DespawnEnemy")
end

function EnemyContext:ApplyDamage(entity: any, amount: number): Result.Result<boolean>
	return Catch(function()
		return self._applyDamageEnemyCommand:Execute(entity, amount)
	end, "Enemy:ApplyDamage")
end

function EnemyContext:WarmFastFlowForRun(): Result.Result<boolean>
	return self._combatContext:WarmMovementRuntime()
end

function EnemyContext:GetAliveEnemies(): Result.Result<{ any }>
	return Catch(function()
		return Ok(self._getAliveEnemiesQuery:Execute())
	end, "Enemy:GetAliveEnemies")
end

function EnemyContext:GetEnemyCount(): Result.Result<number>
	return Catch(function()
		return Ok(self._getEnemyCountQuery:Execute())
	end, "Enemy:GetEnemyCount")
end

function EnemyContext:GetNearestAliveEnemy(position: Vector3, maxRange: number): Result.Result<{ Entity: number, CFrame: CFrame }?>
	return Catch(function()
		return Ok(self._getNearestAliveEnemyQuery:Execute(position, maxRange))
	end, "Enemy:GetNearestAliveEnemy")
end

function EnemyContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupAllEnemiesCommand:Execute()
	end, "Enemy:CleanupAll")
end

function EnemyContext:_BeforeDestroy()
	local cleanupResult = self:CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Enemy:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end
end

function EnemyContext:Destroy()
	local destroyResult = EnemyBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Enemy:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return EnemyContext

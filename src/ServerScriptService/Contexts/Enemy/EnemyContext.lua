--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local EntityCollisionService = require(ServerScriptService.Infrastructure.EntityCollisionService)

local EnemyEntityReadService = require(script.Parent.Infrastructure.Entity.EnemyEntityReadService)
local EnemyEntitySchema = require(script.Parent.Infrastructure.Entity.EnemyEntitySchema)
local EnemyActionExecutionSystem = require(script.Parent.Infrastructure.Entity.EnemyActionExecutionSystem)
local EnemySpawnPolicy = require(script.Parent.EnemyDomain.Policies.EnemySpawnPolicy)
local EnemyAIBehaviors = require(script.Parent.Config.AIBehaviors)
local EnemyAIProfiles = require(script.Parent.Config.AIProfiles)

local SpawnEnemyCommand = require(script.Parent.Application.Commands.SpawnEnemy)
local DespawnEnemyCommand = require(script.Parent.Application.Commands.DespawnEnemy)
local ApplyDamageEnemyCommand = require(script.Parent.Application.Commands.ApplyDamageEnemy)
local HandleGoalReachedCommand = require(script.Parent.Application.Commands.HandleGoalReached)
local CleanupAllEnemiesCommand = require(script.Parent.Application.Commands.CleanupAllEnemies)
local GetAliveEnemiesQuery = require(script.Parent.Application.Queries.GetAliveEnemiesQuery)
local GetEnemyCountQuery = require(script.Parent.Application.Queries.GetEnemyCountQuery)
local GetNearestAliveEnemyQuery = require(script.Parent.Application.Queries.GetNearestAliveEnemyQuery)

local Catch = Result.Catch
local Ok = Result.Ok
local ANIMATED_ENEMY_TAG = "AnimatedEnemy"

local function _EnsureAnimationsFolderValue(model: Model, animationsFolder: Folder?)
	local animationsFolderRef = model:FindFirstChild("AnimationsFolder")
	if animationsFolderRef ~= nil and not animationsFolderRef:IsA("ObjectValue") then
		animationsFolderRef:Destroy()
		animationsFolderRef = nil
	end

	if animationsFolderRef == nil then
		animationsFolderRef = Instance.new("ObjectValue")
		animationsFolderRef.Name = "AnimationsFolder"
		animationsFolderRef.Parent = model
	end

	if animationsFolder ~= nil then
		(animationsFolderRef :: ObjectValue).Value = animationsFolder
	end
end

local function moduleSpec(name: string, module: any, cacheAs: string?): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local function readEntityValue(entityContext: any, entity: number, key: string, featureName: string): any
	local result = entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
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
	moduleSpec("HandleGoalReachedCommand", HandleGoalReachedCommand, "_handleGoalReachedCommand"),
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
	self._enemyAssetRegistry = nil :: any
	self._animationsFolder = nil :: Folder?
	self:_InitializeEnemyAssets()
end

function EnemyContext:KnitStart()
	EnemyBaseContext:KnitStart()

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
		local schemaResult = self._entityContext:RegisterFeatureSchema("Enemy", EnemyEntitySchema)
		if not schemaResult.success then
			return schemaResult
		end

		local bindingResult = self._entityContext:RegisterInstanceBinding("Enemy", {
			FeatureName = "Enemy",
			ResolveAsset = function(_entityContext: any, snapshot: any): Instance
				local identity = snapshot.Identity or {}
				local role = snapshot.FeatureData.Role or {}
				return self:_BuildEnemyModel(role.Role, identity.EntityId)
			end,
			PrepareInstance = function(_entityContext: any, instance: Instance, snapshot: any)
				if not instance:IsA("Model") then
					return
				end

				local role = snapshot.FeatureData.Role or {}
				self:_PrepareEnemyModel(instance :: Model, role.Role, snapshot.Identity and snapshot.Identity.EntityId)

				local transform = snapshot.Transform
				if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
					instance:PivotTo(transform.CFrame)
				end
			end,
			BuildRevealAttributes = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				local role = snapshot.FeatureData.Role or {}
				return {
					EnemyId = identity.EntityId,
					EnemyRole = role.Role,
					WaveNumber = role.WaveNumber,
				}
			end,
			BuildRevealTags = function()
				return {
					[ANIMATED_ENEMY_TAG] = true,
				}
			end,
			BuildName = function(_entityContext: any, snapshot: any)
				local identity = snapshot.Identity or {}
				local role = snapshot.FeatureData.Role or {}
				return string.format("Enemy_%s_%s", tostring(role.Role), tostring(identity.EntityId))
			end,
		})
		if not bindingResult.success then
			return bindingResult
		end

		local syncResult = self._entityContext:RegisterSyncContributor("Enemy", {
			FeatureName = "Enemy",
			QuerySyncEntities = function(entityContext: any): { number }
				local queryResult = entityContext:Query({
					FeatureName = "Enemy",
					Keys = { "Role" },
				})
				if not queryResult.success then
					return {}
				end
				return queryResult.value
			end,
			BuildRuntimeAttributes = function(entityContext: any, entity: number)
				local identity = readEntityValue(entityContext, entity, "Identity", "Entity")
				local health = readEntityValue(entityContext, entity, "Health", "Entity")
				local role = readEntityValue(entityContext, entity, "Role", "Enemy")
				local moveSpeed = readEntityValue(entityContext, entity, "CurrentMoveSpeed", "Enemy")
				local animationState = readEntityValue(entityContext, entity, "AnimationState", "Enemy")
				local animationLooping = readEntityValue(entityContext, entity, "AnimationLooping", "Enemy")

				return {
					EnemyId = if type(identity) == "table" then identity.EntityId else nil,
					EnemyRole = if type(role) == "table" then role.Role else nil,
					WaveNumber = if type(role) == "table" then role.WaveNumber else nil,
					Health = if type(health) == "table" then health.Current else nil,
					MaxHealth = if type(health) == "table" then health.Max else nil,
					CurrentMoveSpeed = if type(moveSpeed) == "table" then moveSpeed.Value else nil,
					AnimationState = if type(animationState) == "string" then animationState else nil,
					AnimationLooping = if type(animationLooping) == "boolean" then animationLooping else nil,
				}
			end,
			BuildHumanoidProperties = function(entityContext: any, entity: number)
				local health = readEntityValue(entityContext, entity, "Health", "Entity")
				local moveSpeed = readEntityValue(entityContext, entity, "CurrentMoveSpeed", "Enemy")

				return {
					MaxHealth = if type(health) == "table" then health.Max else nil,
					Health = if type(health) == "table" then health.Current else nil,
					WalkSpeed = if type(moveSpeed) == "table" then moveSpeed.Value else nil,
				}
			end,
			BuildTransformProjection = function(entityContext: any, entity: number)
				local transform = readEntityValue(entityContext, entity, "Transform", "Entity")
				return if type(transform) == "table" then transform.CFrame else nil
			end,
		})
		if not syncResult.success then
			return syncResult
		end

		local replicationResult = self._entityContext:RegisterReplicationSurface("Enemy", {
			FeatureName = "Enemy",
			BuildSchema = function(entityContext: any): any
				local entityComponentsResult = entityContext:GetFeatureComponents("Entity")
				local enemyComponentsResult = entityContext:GetFeatureComponents("Enemy")
				assert(entityComponentsResult.success, "Enemy replication surface missing Entity compiled components")
				assert(enemyComponentsResult.success, "Enemy replication surface missing Enemy compiled components")

				return {
					sharedComponents = {
						entityComponentsResult.value.Identity,
						entityComponentsResult.value.Health,
						enemyComponentsResult.value.Role,
						enemyComponentsResult.value.CurrentMoveSpeed,
						enemyComponentsResult.value.AnimationState,
						enemyComponentsResult.value.AnimationLooping,
					},
					sharedTags = {
						enemyComponentsResult.value.AliveTag,
						enemyComponentsResult.value.GoalReachedTag,
					},
				}
			end,
		})
		if not replicationResult.success then
			return replicationResult
		end

		local systemResult = self._entityContext:RegisterSystem("Cleanup", {
			Name = "EnemyActionExecutionSystem",
			Phase = "Cleanup",
			Reads = {
				"Enemy.Role",
				"Enemy.PathState",
				"Enemy.AttackCooldown",
				"Entity.Transform",
				"Entity.Target",
				"AI.ActionState",
				"AI.ActionIntent",
			},
			Writes = {
				"Entity.Transform",
				"Enemy.PathState",
				"Enemy.AttackCooldown",
				"Enemy.CurrentMoveSpeed",
				"Enemy.AnimationState",
				"Enemy.AnimationLooping",
				"Enemy.AliveTag",
				"Enemy.GoalReachedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return EnemyActionExecutionSystem.new(entityFactory, {
					EntityContext = self._entityContext,
					BaseContext = self._baseContext,
					StructureContext = self._structureContext,
				})
			end,
		})
		if not systemResult.success then
			return systemResult
		end

		return Ok(true)
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

function EnemyContext:_InitializeEnemyAssets()
	local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
	if assetsRoot == nil or not assetsRoot:IsA("Folder") then
		return
	end

	local enemiesFolder = assetsRoot:FindFirstChild("Enemies")
	if enemiesFolder ~= nil and enemiesFolder:IsA("Folder") then
		self._enemyAssetRegistry = AssetFetcher.CreateEnemyRegistry(enemiesFolder)
	end

	local animationsFolder = assetsRoot:FindFirstChild("Animations")
	if animationsFolder ~= nil and animationsFolder:IsA("Folder") then
		self._animationsFolder = animationsFolder
	end
end

function EnemyContext:_BuildEnemyModel(role: string?, enemyId: string?): Model
	local resolvedRole = if type(role) == "string" and role ~= "" then role else "Swarm"
	local resolvedEnemyId = if type(enemyId) == "string" and enemyId ~= "" then enemyId else tostring(os.clock())

	if self._enemyAssetRegistry ~= nil then
		local assetModel = self._enemyAssetRegistry:GetEnemyModel(resolvedRole)
		if assetModel ~= nil then
			return assetModel
		end
	end

	return self:_CreateFallbackEnemyModel(resolvedRole, resolvedEnemyId)
end

function EnemyContext:_CreateFallbackEnemyModel(role: string, enemyId: string): Model
	local roleConfig = EnemyConfig.Roles[role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(role))

	local model = Instance.new("Model")
	model.Name = "Enemy_" .. role .. "_" .. enemyId

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = roleConfig.ModelScale
	rootPart.Color = roleConfig.ModelColor
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = roleConfig.MaxHp
	humanoid.Health = roleConfig.MaxHp
	humanoid.WalkSpeed = roleConfig.MoveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	return model
end

function EnemyContext:_PrepareEnemyModel(model: Model, role: string?, enemyId: string?)
	local resolvedRole = if type(role) == "string" and role ~= "" then role else "Swarm"
	local resolvedEnemyId = if type(enemyId) == "string" and enemyId ~= "" then enemyId else tostring(os.clock())
	local roleConfig = EnemyConfig.Roles[resolvedRole]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(resolvedRole))

	model.Name = "Enemy_" .. resolvedRole .. "_" .. resolvedEnemyId
	_EnsureAnimationsFolderValue(model, self._animationsFolder)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end

	humanoid.MaxHealth = roleConfig.MaxHp
	humanoid.Health = roleConfig.MaxHp
	humanoid.WalkSpeed = roleConfig.MoveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if model.PrimaryPart == nil then
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			model.PrimaryPart = rootPart
		end
	end

	assert(model.PrimaryPart ~= nil, "Enemy model missing PrimaryPart: " .. model.Name)
	model.PrimaryPart.Anchored = true
	EntityCollisionService:ApplyModel(model)
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

function EnemyContext:HandleGoalReached(entity: any): Result.Result<boolean>
	return Catch(function()
		return self._handleGoalReachedCommand:Execute(entity)
	end, "Enemy:HandleGoalReached")
end

function EnemyContext:WarmFastFlowForRun(): Result.Result<boolean>
	return Ok(false)
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

function EnemyContext:GetEntityFactory(): Result.Result<any>
	return Ok(self._enemyEntityReadService)
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

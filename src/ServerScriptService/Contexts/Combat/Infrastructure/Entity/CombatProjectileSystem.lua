--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CombatProjectileSystem = {}
CombatProjectileSystem.__index = CombatProjectileSystem

local function getService(serviceName: string): any?
	local ok, service = pcall(function()
		return Knit.GetService(serviceName)
	end)
	return if ok then service else nil
end

function CombatProjectileSystem.new(entityFactory: any, projectileService: any, entityContext: any)
	local self = setmetatable({}, CombatProjectileSystem)
	self._entityFactory = entityFactory
	self._projectileService = projectileService
	self._entityContext = entityContext
	self._enemyReadService = nil
	self._didConfigureProjectileResolver = false
	return self
end

function CombatProjectileSystem:Run()
	-- READS: Combat.ProjectileRequest [AUTHORITATIVE], Combat.RequestTag
	-- WRITES: Combat.ProcessedTag
	self:_ConfigureProjectileResolver()

	local queryResult = self._entityFactory:Query({
		FeatureName = "Combat",
		Keys = { "ProjectileRequest", "RequestTag" },
	})
	if not queryResult.success then
		return
	end

	for _, requestEntity in ipairs(queryResult.value) do
		self:_ResolveProjectileRequest(requestEntity)
	end
end

function CombatProjectileSystem:_ResolveProjectileRequest(requestEntity: number)
	local request = self:_Get(requestEntity, "ProjectileRequest", "Combat")
	if type(request) ~= "table" then
		self:_MarkProcessed(requestEntity)
		return
	end
	if type(request.SourceEntity) ~= "number" or type(request.TargetEntity) ~= "number" then
		self:_MarkProcessed(requestEntity)
		return
	end

	local fireResult = self._projectileService:FireStructureBullet({
		StructureEntity = request.SourceEntity,
		TargetEnemyEntity = request.TargetEntity,
		Damage = if type(request.Damage) == "number" then request.Damage else 0,
		MaxDistance = if type(request.Range) == "number" then request.Range else 0,
	})
	if fireResult.success == true then
		self:_MarkProcessed(requestEntity)
	end
end

function CombatProjectileSystem:_ConfigureProjectileResolver()
	if self._didConfigureProjectileResolver or self._projectileService == nil then
		return
	end

	local enemyContext = getService("EnemyContext")
	local enemyFactoryResult = if enemyContext ~= nil and type(enemyContext.GetEntityFactory) == "function"
		then enemyContext:GetEntityFactory()
		else nil
	self._enemyReadService = if enemyFactoryResult ~= nil and enemyFactoryResult.success then enemyFactoryResult.value else nil

	self._projectileService:ConfigureStructureBulletResolver({
		ResolveStructureModel = function(structureEntity: number): Model?
			local boundResult = self._entityContext:GetBoundInstance(structureEntity)
			local instance = if boundResult.success then boundResult.value else nil
			return if instance ~= nil and instance:IsA("Model") then instance else nil
		end,
		ResolveEnemyCFrame = function(enemyEntity: number): CFrame?
			return if self._enemyReadService ~= nil then self._enemyReadService:GetEntityCFrame(enemyEntity) else nil
		end,
		ResolveEnemyEntity = function(hitPart: Instance): number?
			local boundEntityResult = self._entityContext:GetBoundEntity(hitPart)
			local entity = if boundEntityResult.success then boundEntityResult.value else nil
			return if type(entity) == "number" and self:_IsEnemyAlive(entity) then entity else nil
		end,
		IsEnemyAlive = function(enemyEntity: number): boolean
			return self:_IsEnemyAlive(enemyEntity)
		end,
		ApplyEnemyDamage = function(enemyEntity: number, damage: number)
			if enemyContext ~= nil then
				enemyContext:ApplyDamage(enemyEntity, damage)
			end
		end,
	})
	self._didConfigureProjectileResolver = true
end

function CombatProjectileSystem:_IsEnemyAlive(enemyEntity: number): boolean
	return self._enemyReadService ~= nil and self._enemyReadService:IsAlive(enemyEntity)
end

function CombatProjectileSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function CombatProjectileSystem:_MarkProcessed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return CombatProjectileSystem

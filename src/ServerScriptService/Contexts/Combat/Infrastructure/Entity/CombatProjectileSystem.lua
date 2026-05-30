--!strict

local CombatProjectileSystem = {}
CombatProjectileSystem.__index = CombatProjectileSystem

function CombatProjectileSystem.new(entityFactory: any, projectileService: any)
	local self = setmetatable({}, CombatProjectileSystem)
	self._entityFactory = entityFactory
	self._projectileService = projectileService
	return self
end

function CombatProjectileSystem:Run()
	-- READS: Combat.ProjectileRequest [AUTHORITATIVE], Combat.RequestTag
	-- WRITES: Combat.ProcessedTag
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

function CombatProjectileSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function CombatProjectileSystem:_MarkProcessed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return CombatProjectileSystem

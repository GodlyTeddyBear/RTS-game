--!strict

local ProjectileSpawnSystem = {}
ProjectileSpawnSystem.__index = ProjectileSpawnSystem

function ProjectileSpawnSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, ProjectileSpawnSystem)
	self._entityFactory = entityFactory
	self._simulation = dependencies.Simulation
	self._targetRead = dependencies.TargetRead
	return self
end

function ProjectileSpawnSystem:Run()
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "ProjectileSpawnRequest", "RequestTag" } })
	if not result.success then return end
	for _, requestEntity in ipairs(result.value) do
		self:_Spawn(requestEntity)
	end
end

function ProjectileSpawnSystem:_Spawn(requestEntity: number)
	local request = self:_Get(requestEntity, "ProjectileSpawnRequest", "Combat")
	if type(request) ~= "table" or type(request.SourceEntity) ~= "number" or type(request.TargetEntity) ~= "number" then
		self:_Processed(requestEntity)
		return
	end
	local origin = self._targetRead:ResolveProjectileOrigin(request.SourceEntity)
	local targetPosition = self._targetRead:GetPosition(self._entityFactory, request.TargetEntity)
	local result = self._simulation:Spawn({
		Origin = origin,
		TargetPosition = targetPosition,
		SourceEntity = request.SourceEntity,
		AbilityId = request.AbilityId,
		Damage = request.Damage,
		MaxDistance = request.Range,
		ResolveEntity = function(instance: Instance): number?
			local targetEntity = self._targetRead:ResolveBoundEntity(instance)
			return if targetEntity ~= request.SourceEntity then targetEntity else nil
		end,
	})
	if result.success then
		self._entityFactory:CreateFromArchetype("Combat.ActiveProjectile", {
			ActiveProjectileState = {
				Handle = result.handle,
				SourceEntity = request.SourceEntity,
				AbilityId = request.AbilityId,
				CreatedAt = os.clock(),
			},
		})
	end
	self:_Processed(requestEntity)
end

function ProjectileSpawnSystem:_Get(entity: number, key: string, feature: string): any
	local result = self._entityFactory:Get(entity, key, feature)
	return if result.success then result.value else nil
end
function ProjectileSpawnSystem:_Processed(entity: number) self._entityFactory:Add(entity, "ProcessedTag", "Combat") end

return ProjectileSpawnSystem

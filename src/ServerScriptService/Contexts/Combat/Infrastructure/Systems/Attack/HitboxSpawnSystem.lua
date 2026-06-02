--!strict

local HitboxSpawnSystem = {}
HitboxSpawnSystem.__index = HitboxSpawnSystem

function HitboxSpawnSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, HitboxSpawnSystem)
	self._entityFactory = entityFactory
	self._simulation = dependencies.Simulation
	self._targetRead = dependencies.TargetRead
	return self
end

function HitboxSpawnSystem:Run()
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HitboxSpawnRequest", "RequestTag" } })
	if not result.success then return end
	for _, requestEntity in ipairs(result.value) do self:_Spawn(requestEntity) end
end

function HitboxSpawnSystem:_Spawn(requestEntity: number)
	local request = self:_Get(requestEntity, "HitboxSpawnRequest", "Combat")
	if type(request) ~= "table" or type(request.SourceEntity) ~= "number" then
		self:_Processed(requestEntity)
		return
	end
	local config = if type(request.Hitbox) == "table" then request.Hitbox else {}
	local result = self._simulation:Create({
		SourceEntity = request.SourceEntity,
		SourceModel = self._targetRead:GetBoundModel(request.SourceEntity),
		AbilityId = request.AbilityId,
		Damage = request.Damage,
		DetectionMode = config.DetectionMode,
		Shape = config.Shape,
		Size = config.Size,
		Offset = config.Offset,
		ResolveEntity = function(instance: Instance): number?
			local targetEntity = self._targetRead:ResolveBoundEntity(instance)
			return if targetEntity ~= request.SourceEntity then targetEntity else nil
		end,
	})
	if result.success then
		self._entityFactory:CreateFromArchetype("Combat.ActiveHitbox", {
			ActiveHitboxState = {
				Handle = result.handle,
				SourceEntity = request.SourceEntity,
				AbilityId = request.AbilityId,
				Damage = request.Damage,
				CreatedAt = os.clock(),
				ExpiresAt = os.clock() + (config.MaxDuration or 0.2),
			},
		})
	end
	self:_Processed(requestEntity)
end

function HitboxSpawnSystem:_Get(entity: number, key: string, feature: string): any
	local result = self._entityFactory:Get(entity, key, feature)
	return if result.success then result.value else nil
end
function HitboxSpawnSystem:_Processed(entity: number) self._entityFactory:Add(entity, "ProcessedTag", "Combat") end

return HitboxSpawnSystem

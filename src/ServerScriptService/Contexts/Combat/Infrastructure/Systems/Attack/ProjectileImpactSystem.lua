--!strict

local ProjectileImpactSystem = {}
ProjectileImpactSystem.__index = ProjectileImpactSystem

function ProjectileImpactSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, ProjectileImpactSystem)
	self._entityFactory = entityFactory
	self._simulation = dependencies.Simulation
	self._requestFactory = dependencies.RequestFactory
	return self
end

function ProjectileImpactSystem:Run()
	for _, impact in ipairs(self._simulation:DrainImpacts()) do
		self._requestFactory:Create(self._entityFactory, "Combat.HealthChangeRequest", "HealthChangeRequest", {
			AbilityId = impact.AbilityId,
			SourceEntity = impact.SourceEntity,
			TargetEntity = impact.TargetEntity,
			Amount = impact.Damage,
			ChangeType = "Damage",
			ExpiresAt = os.clock() + 1,
			Reason = "ProjectileImpact",
		})
	end
end

return ProjectileImpactSystem

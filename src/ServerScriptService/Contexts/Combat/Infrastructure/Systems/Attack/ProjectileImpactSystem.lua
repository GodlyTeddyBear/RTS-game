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
		self._requestFactory:Create(self._entityFactory, "Combat.DamageRequest", "DamageRequest", {
			AbilityId = impact.AbilityId,
			AttackerEntity = impact.SourceEntity,
			VictimEntity = impact.TargetEntity,
			Amount = impact.Damage,
			ExpiresAt = os.clock() + 1,
			Reason = "ProjectileImpact",
		})
	end
end

return ProjectileImpactSystem

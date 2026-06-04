--!strict

local HitboxImpactSystem = {}
HitboxImpactSystem.__index = HitboxImpactSystem

function HitboxImpactSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, HitboxImpactSystem)
	self._entityFactory = entityFactory
	self._simulation = dependencies.Simulation
	self._requestFactory = dependencies.RequestFactory
	return self
end

function HitboxImpactSystem:Run()
	for _, impact in ipairs(self._simulation:DrainImpacts()) do
		self._requestFactory:Create(self._entityFactory, "Combat.HealthChangeRequest", "HealthChangeRequest", {
			AbilityId = impact.AbilityId,
			SourceEntity = impact.SourceEntity,
			TargetEntity = impact.TargetEntity,
			Amount = impact.Damage,
			ChangeType = "Damage",
			ExpiresAt = os.clock() + 1,
			Reason = "HitboxImpact",
		})
	end
end

return HitboxImpactSystem

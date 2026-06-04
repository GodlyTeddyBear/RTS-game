--!strict

local HealthChangeResolveSystem = {}
HealthChangeResolveSystem.__index = HealthChangeResolveSystem

function HealthChangeResolveSystem.new(entityFactory: any, requestFactory: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_requestFactory = requestFactory,
	}, HealthChangeResolveSystem)
end

function HealthChangeResolveSystem:Run()
	-- READS: Combat.HealthChangeRequest, Combat.RequestTag, Entity.Health
	-- WRITES: Entity.Health, Entity.DirtyTag, Combat.HealthDepletedRequest, Combat.ProcessedTag
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthChangeRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function HealthChangeResolveSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "HealthChangeRequest", "Combat")
	if type(request) ~= "table" then
		self:_Processed(requestEntity)
		return
	end

	local target = request.TargetEntity
	if type(target) ~= "number" or not self._entityFactory:Exists(target) then
		self:_Processed(requestEntity)
		return
	end

	local amount = request.Amount
	if type(amount) ~= "number" or amount <= 0 then
		self:_Processed(requestEntity)
		return
	end

	local health = self:_Get(target, "Health", "Entity")
	if type(health) ~= "table" or type(health.Current) ~= "number" then
		self:_Processed(requestEntity)
		return
	end

	local maxHealth = if type(health.Max) == "number" then health.Max else health.Current
	local previous = health.Current
	local nextHealth = previous
	if request.ChangeType == "Heal" then
		nextHealth = math.min(maxHealth, previous + amount)
	elseif request.ChangeType == "SetMax" then
		maxHealth = math.max(0, amount)
		nextHealth = math.min(previous, maxHealth)
	else
		nextHealth = math.max(0, previous - amount)
	end

	self._entityFactory:Set(target, "Health", {
		Current = nextHealth,
		Max = maxHealth,
	}, "Entity")
	self._entityFactory:Add(target, "DirtyTag", "Entity")

	if previous > 0 and nextHealth <= 0 then
		local now = os.clock()
		self._requestFactory:Create(self._entityFactory, "Combat.HealthDepletedRequest", "HealthDepletedRequest", {
			VictimEntity = target,
			VictimKind = self:_ResolveTargetKind(target, request.TargetKind),
			CreatedAt = now,
			ExpiresAt = now + 1,
		})
	end

	self:_Processed(requestEntity)
end

function HealthChangeResolveSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function HealthChangeResolveSystem:_ResolveTargetKind(target: number, targetKind: any): string
	if type(targetKind) == "string" and targetKind ~= "" then
		return targetKind
	end

	local identity = self:_Get(target, "Identity", "Entity")
	if type(identity) == "table" and type(identity.EntityKind) == "string" and identity.EntityKind ~= "" then
		return identity.EntityKind
	end

	return "Entity"
end

function HealthChangeResolveSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return HealthChangeResolveSystem

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageResolveSystem = {}
DamageResolveSystem.__index = DamageResolveSystem

function DamageResolveSystem.new(entityFactory: any, requestFactory: any)
	local self = setmetatable({}, DamageResolveSystem)
	self._entityFactory = entityFactory
	self._requestFactory = requestFactory
	return self
end

function DamageResolveSystem:Run()
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "DamageRequest", "RequestTag" } })
	if not result.success then return end
	for _, requestEntity in ipairs(result.value) do self:_Resolve(requestEntity) end
end

function DamageResolveSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "DamageRequest", "Combat")
	if type(request) ~= "table" or type(request.Amount) ~= "number" or request.Amount <= 0 then
		self:_Processed(requestEntity)
		return
	end
	if request.VictimKind == "Base" then
		local now = os.clock()
		self._requestFactory:Create(self._entityFactory, "Combat.BaseDamageRequest", "BaseDamageRequest", {
			Amount = request.Amount,
			CreatedAt = now,
			ExpiresAt = now + 1,
		})
		self:_Processed(requestEntity)
		return
	end
	local victim = request.VictimEntity
	if type(victim) ~= "number" or not self._entityFactory:Exists(victim) then
		self:_Processed(requestEntity)
		return
	end
	local health = self:_Get(victim, "Health", "Entity")
	if type(health) == "table" and type(health.Current) == "number" then
		self._entityFactory:Set(victim, "Health", {
			Current = math.max(0, health.Current - request.Amount),
			Max = if type(health.Max) == "number" then health.Max else health.Current,
		}, "Entity")
		self._entityFactory:Add(victim, "DirtyTag", "Entity")
		if health.Current > 0 and (health.Current - request.Amount) <= 0 then
			local now = os.clock()
			self._requestFactory:Create(self._entityFactory, "Combat.HealthDepletedRequest", "HealthDepletedRequest", {
				VictimEntity = victim,
				VictimKind = request.VictimKind,
				CreatedAt = now,
				ExpiresAt = now + 1,
			})
		end
	end
	self:_Processed(requestEntity)
end

function DamageResolveSystem:_Get(entity: number, key: string, feature: string): any
	local result = self._entityFactory:Get(entity, key, feature)
	return if result.success then result.value else nil
end
function DamageResolveSystem:_Processed(entity: number) self._entityFactory:Add(entity, "ProcessedTag", "Combat") end

return DamageResolveSystem

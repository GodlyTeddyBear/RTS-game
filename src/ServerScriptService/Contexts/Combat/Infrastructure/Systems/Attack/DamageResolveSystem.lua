--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local DamageResolveSystem = {}
DamageResolveSystem.__index = DamageResolveSystem

function DamageResolveSystem.new(entityFactory: any)
	local self = setmetatable({}, DamageResolveSystem)
	self._entityFactory = entityFactory
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
		local ok, baseContext = pcall(function() return Knit.GetService("BaseContext") end)
		if ok and baseContext ~= nil then baseContext:ApplyDamage(request.Amount) end
		self:_Processed(requestEntity)
		return
	end
	-- Transitional adapters preserve feature-owned death orchestration until
	-- health-depletion request consumers are migrated into Entity systems.
	if request.VictimKind == "Enemy" or request.VictimKind == "Structure" then
		local contextName = if request.VictimKind == "Enemy" then "EnemyContext" else "StructureContext"
		local ok, featureContext = pcall(function() return Knit.GetService(contextName) end)
		if ok and featureContext ~= nil and type(request.VictimEntity) == "number" then
			featureContext:ApplyDamage(request.VictimEntity, request.Amount)
		end
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
	end
	self:_Processed(requestEntity)
end

function DamageResolveSystem:_Get(entity: number, key: string, feature: string): any
	local result = self._entityFactory:Get(entity, key, feature)
	return if result.success then result.value else nil
end
function DamageResolveSystem:_Processed(entity: number) self._entityFactory:Add(entity, "ProcessedTag", "Combat") end

return DamageResolveSystem

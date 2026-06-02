--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local EnemyHealthDepletedSystem = {}
EnemyHealthDepletedSystem.__index = EnemyHealthDepletedSystem

function EnemyHealthDepletedSystem.new(entityFactory: any, entityContext: any)
	return setmetatable({ _entityFactory = entityFactory, _entityContext = entityContext }, EnemyHealthDepletedSystem)
end

function EnemyHealthDepletedSystem:Run()
	-- READS: Combat.HealthDepletedRequest [AUTHORITATIVE]
	-- WRITES: Combat.ProcessedTag, Entity.DestructionQueue
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthDepletedRequest", "RequestTag" } })
	if not result.success then return end
	for _, requestEntity in ipairs(result.value) do
		local request = self:_Get(requestEntity, "HealthDepletedRequest", "Combat")
		if type(request) == "table" and request.VictimKind == "Enemy" and type(request.VictimEntity) == "number" then
			local identity = self:_Get(request.VictimEntity, "Identity", "Enemy")
			local transform = self:_Get(request.VictimEntity, "Transform", "Entity")
			if type(identity) == "table" and type(identity.Role) == "string" and type(identity.WaveNumber) == "number" then
				local deathCFrame = if type(transform) == "table" and typeof(transform.CFrame) == "CFrame"
					then transform.CFrame
					else CFrame.new()
				GameEvents.Bus:Emit(GameEvents.Events.Wave.EnemyDied, identity.Role, identity.WaveNumber, deathCFrame)
			end
			self._entityContext:MarkForDestruction(request.VictimEntity)
			self._entityFactory:Add(requestEntity, "ProcessedTag", "Combat")
		end
	end
end

function EnemyHealthDepletedSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyHealthDepletedSystem

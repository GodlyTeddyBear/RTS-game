--!strict

local HealthDepletedOutcomeResolveSystem = {}
HealthDepletedOutcomeResolveSystem.__index = HealthDepletedOutcomeResolveSystem

function HealthDepletedOutcomeResolveSystem.new(entityFactory: any, dependencies: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_ruleRegistry = dependencies.RuleRegistry,
	}, HealthDepletedOutcomeResolveSystem)
end

function HealthDepletedOutcomeResolveSystem:Run()
	-- READS: Combat.HealthDepletedOutcomeRequest, Combat.RequestTag
	-- WRITES: Combat.ProcessedTag, Entity.DestructionQueue, optional feature request entities
	local result =
		self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthDepletedOutcomeRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function HealthDepletedOutcomeResolveSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "HealthDepletedOutcomeRequest", "Combat")
	if type(request) ~= "table" or type(request.OutcomeId) ~= "string" then
		self:_Processed(requestEntity)
		return
	end

	local rule = self._ruleRegistry:GetHealthDepletedRule(request.OutcomeId)
	if type(rule) ~= "table" then
		self:_Processed(requestEntity)
		return
	end

	if rule.DestroyVictim == true and type(request.VictimEntity) == "number" and self._entityFactory:Exists(request.VictimEntity) then
		self._entityFactory:MarkEntityForDestruction(request.VictimEntity)
	end

	self:_EmitConfiguredRequest(rule.EmitRequest, request)
	self:_Processed(requestEntity)
end

function HealthDepletedOutcomeResolveSystem:_EmitConfiguredRequest(emitRequest: any, request: any)
	if type(emitRequest) ~= "table" then
		return
	end

	local archetypeName = emitRequest.ArchetypeName
	local componentKey = emitRequest.ComponentKey
	if type(archetypeName) ~= "string" or archetypeName == "" or type(componentKey) ~= "string" or componentKey == "" then
		return
	end

	local now = os.clock()
	self._entityFactory:CreateFromArchetype(archetypeName, {
		[componentKey] = {
			EnemyEntity = request.VictimEntity,
			SourceEntity = request.VictimEntity,
			OutcomeId = request.OutcomeId,
			CreatedAt = now,
			ExpiresAt = now + 1,
		},
	})
end

function HealthDepletedOutcomeResolveSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function HealthDepletedOutcomeResolveSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return HealthDepletedOutcomeResolveSystem

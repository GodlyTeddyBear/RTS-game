--!strict

local MovementPresentationProjectionSystem = {}
MovementPresentationProjectionSystem.__index = MovementPresentationProjectionSystem

function MovementPresentationProjectionSystem.new(entityFactory: any, ruleRegistry: any)
	return setmetatable({ _entityFactory = entityFactory, _ruleRegistry = ruleRegistry }, MovementPresentationProjectionSystem)
end

function MovementPresentationProjectionSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE], Movement.SpeedState [AUTHORITATIVE]
	-- WRITES: configured movement presentation components [DERIVED], Entity.DirtyTag
	for _, rule in ipairs(self._ruleRegistry:GetMovementPresentationRules()) do
		self:_RunRule(rule)
	end
end

function MovementPresentationProjectionSystem:_RunRule(rule: any)
	local query = rule.Query
	if type(query) ~= "table" then
		return
	end

	local result = self._entityFactory:Query(query)
	if not result.success then
		return
	end

	for _, entity in ipairs(result.value) do
		self:_ProjectEntity(rule, entity)
	end
end

function MovementPresentationProjectionSystem:_ProjectEntity(rule: any, entity: number)
	local intent = self:_Get(entity, "MoveIntent", "Movement")
	local applyResult = self:_Get(entity, "ApplyResult", "Movement")
	local speed = self:_Get(entity, "SpeedState", "Movement")
	local isMoving = type(applyResult) == "table" and applyResult.IsMoving == true

	self:_ApplyMovementProjection(rule, entity, intent, speed, isMoving)
end

function MovementPresentationProjectionSystem:_ApplyMovementProjection(rule: any, entity: number, intent: any, speed: any, isMoving: boolean)
	local didWrite = false
	if type(rule.PathState) == "table" then
		local previous = self:_Get(entity, rule.PathState.Key, rule.PathState.FeatureName)
		local nextState = {
			GoalPosition = if type(intent) == "table" then intent.GoalPosition else nil,
			IsMoving = isMoving,
		}
		if type(rule.PathState.PreserveKeys) == "table" and type(previous) == "table" then
			for _, key in ipairs(rule.PathState.PreserveKeys) do
				nextState[key] = previous[key]
			end
		end
		self._entityFactory:Set(entity, rule.PathState.Key, nextState, rule.PathState.FeatureName)
		didWrite = true
	end
	if type(rule.Speed) == "table" then
		self._entityFactory:Set(entity, rule.Speed.Key, {
			Value = if isMoving and type(speed) == "table" then speed.CurrentSpeed or 0 else 0,
		}, rule.Speed.FeatureName)
		didWrite = true
	end
	if didWrite then
		self:_MarkDirty(entity, rule)
	end
end

function MovementPresentationProjectionSystem:_MarkDirty(entity: number, rule: any)
	if rule.MarkDirty ~= false then
		self._entityFactory:Add(entity, "DirtyTag", "Entity")
	end
end

function MovementPresentationProjectionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementPresentationProjectionSystem

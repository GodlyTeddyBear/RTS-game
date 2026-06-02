--!strict

local MovementActorReadService = {}
MovementActorReadService.__index = MovementActorReadService

local GOAL_POSITION_EPSILON = 0.01

function MovementActorReadService.new()
	return setmetatable({}, MovementActorReadService)
end

function MovementActorReadService:GetActorKey(entity: number): string
	return tostring(entity)
end

function MovementActorReadService:GetBoundModel(entityContext: any, entity: number): Model?
	local result = entityContext:GetBoundInstance(entity)
	local instance = if result.success then result.value else nil
	return if instance ~= nil and instance:IsA("Model") then instance else nil
end

function MovementActorReadService:GetBoundInstance(entityContext: any, entity: number): Instance?
	local result = entityContext:GetBoundInstance(entity)
	return if result.success then result.value else nil
end

function MovementActorReadService:GetModelRef(entityFactory: any, entityContext: any, entity: number): any?
	local modelRef = self:_Get(entityFactory, entity, "ModelRef", "Entity")
	if type(modelRef) == "table" and modelRef.Model ~= nil then
		return modelRef
	end

	local model = self:GetBoundModel(entityContext, entity)
	return if model ~= nil then { Model = model } else nil
end

function MovementActorReadService:GetPosition(entityFactory: any, entityContext: any, entity: number): Vector3?
	local transform = self:_Get(entityFactory, entity, "Transform", "Entity")
	local cframe = if type(transform) == "table" then transform.CFrame else nil
	if typeof(cframe) == "CFrame" then
		return cframe.Position
	end

	local model = self:GetBoundModel(entityContext, entity)
	return if model ~= nil and model.PrimaryPart ~= nil then model.PrimaryPart.Position else nil
end

function MovementActorReadService:GetCurrentMoveSpeed(entityFactory: any, entity: number): number
	local speedState = self:_Get(entityFactory, entity, "SpeedState", "Movement")
	return if type(speedState) == "table" and type(speedState.CurrentSpeed) == "number" then speedState.CurrentSpeed else 0
end

function MovementActorReadService:GetActorProfile(entityFactory: any, entity: number): any?
	return self:_Get(entityFactory, entity, "ActorProfile", "Movement")
end

function MovementActorReadService:CountFlowEligiblePeers(entityFactory: any, goalPosition: Vector3): number
	local count = 0
	local queryResult = entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "MoveIntent" },
	})
	if not queryResult.success then
		return count
	end

	for _, entity in ipairs(queryResult.value) do
		local intent = self:_Get(entityFactory, entity, "MoveIntent", "Movement")
		local candidateGoal = if type(intent) == "table" then intent.GoalPosition else nil
		local mode = if type(intent) == "table" then intent.MovementMode else nil
		if
			typeof(candidateGoal) == "Vector3"
			and (candidateGoal - goalPosition).Magnitude <= GOAL_POSITION_EPSILON
			and (mode == "Any" or mode == "Boids")
		then
			count += 1
		end
	end

	return count
end

function MovementActorReadService:_Get(entityFactory: any, entity: number, key: string, featureName: string): any
	local result = entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementActorReadService

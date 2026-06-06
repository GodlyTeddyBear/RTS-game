--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local CombatTargetReadService = {}
CombatTargetReadService.__index = CombatTargetReadService

function CombatTargetReadService.new()
	local self = setmetatable({}, CombatTargetReadService)
	self._entityContext = nil
	return self
end

function CombatTargetReadService:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	assert(self._entityContext ~= nil, "CombatTargetReadService missing EntityContext in Start")
end

function CombatTargetReadService:GetBoundInstance(entity: number): Instance?
	if self._entityContext == nil then
		return nil
	end
	local result = self._entityContext:GetBoundInstance(entity)
	return if result.success and typeof(result.value) == "Instance" then result.value else nil
end

function CombatTargetReadService:GetBoundModel(entity: number): Model?
	local instance = self:GetBoundInstance(entity)
	return if instance ~= nil and instance:IsA("Model") then instance else nil
end

function CombatTargetReadService:GetPosition(entityFactory: any, entity: number): Vector3?
	local transformResult = entityFactory:Get(entity, "Transform", "Entity")
	local transform = if transformResult.success then transformResult.value else nil
	if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
		return transform.CFrame.Position
	end

	local model = self:GetBoundModel(entity)
	return if model ~= nil then model:GetPivot().Position else nil
end

function CombatTargetReadService:IsAlive(entityFactory: any, entity: number): boolean
	if not entityFactory:Exists(entity) then
		return false
	end
	local healthResult = entityFactory:Get(entity, "Health", "Entity")
	local health = if healthResult.success then healthResult.value else nil
	return type(health) ~= "table" or type(health.Current) ~= "number" or health.Current > 0
end

function CombatTargetReadService:ResolveBoundEntity(instance: Instance): number?
	if self._entityContext == nil then
		return nil
	end
	local result = self._entityContext:GetBoundEntity(instance)
	return if result.success and type(result.value) == "number" then result.value else nil
end

function CombatTargetReadService:ResolveProjectileOrigin(entity: number): CFrame?
	local model = self:GetBoundModel(entity)
	if model == nil then
		return nil
	end
	local muzzle = model:FindFirstChild("Muzzle", true)
	if muzzle ~= nil and muzzle:IsA("Attachment") then
		return muzzle.WorldCFrame
	end
	return model:GetPivot()
end

function CombatTargetReadService:_GetEntityPosition(entity: number): Vector3?
	if self._entityContext == nil then
		return nil
	end

	local transformResult = self._entityContext:Get(entity, "Transform", "Entity")
	local transform = if transformResult.success then transformResult.value else nil
	if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
		return transform.CFrame.Position
	end

	local instance = self:GetBoundInstance(entity)
	if instance == nil then
		return nil
	end

	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end

	return nil
end

function CombatTargetReadService:_GetInstanceAimPosition(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return ModelPlus.GetCenterPosition(instance)
	elseif instance:IsA("BasePart") then
		return instance.Position
	end

	return nil
end

function CombatTargetReadService:_ClosestPointOnBox(sourcePosition: Vector3, boxCFrame: CFrame, boxSize: Vector3): Vector3
	local halfSize = boxSize * 0.5
	local localPoint = boxCFrame:PointToObjectSpace(sourcePosition)
	local clampedPoint = Vector3.new(
		math.clamp(localPoint.X, -halfSize.X, halfSize.X),
		math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
	)
	return boxCFrame:PointToWorldSpace(clampedPoint)
end

function CombatTargetReadService:_ResolveBoundsSurface(sourcePosition: Vector3, instance: Instance): Vector3?
	if instance:IsA("Model") then
		local boundsCFrame, boundsSize = ModelPlus.GetBounds(instance)
		return self:_ClosestPointOnBox(sourcePosition, boundsCFrame, boundsSize)
	elseif instance:IsA("BasePart") then
		return self:_ClosestPointOnBox(sourcePosition, instance.CFrame, instance.Size)
	end

	return nil
end

function CombatTargetReadService:_ResolveRaycastSurface(
	sourcePosition: Vector3,
	aimPosition: Vector3,
	instance: Instance
): Vector3?
	local options = SpatialQuery.WithIncludedInstances({ instance })
	local result = SpatialQuery.RaycastTo(sourcePosition, aimPosition, options)
	return if result ~= nil then result.Position else nil
end

function CombatTargetReadService:ResolveTargetGeometry(
	sourcePosition: Vector3,
	targetEntity: number,
	fallbackTargetPosition: Vector3?
): any?
	if typeof(sourcePosition) ~= "Vector3" or type(targetEntity) ~= "number" then
		return nil
	end

	local instance = self:GetBoundInstance(targetEntity)
	local aimPosition = if instance ~= nil then self:_GetInstanceAimPosition(instance) else nil
	if aimPosition == nil then
		aimPosition = fallbackTargetPosition or self:_GetEntityPosition(targetEntity)
	end
	if aimPosition == nil then
		return nil
	end

	local surfacePosition = nil :: Vector3?
	local usedSurface = false
	if instance ~= nil then
		surfacePosition = self:_ResolveRaycastSurface(sourcePosition, aimPosition, instance)
		if surfacePosition ~= nil then
			usedSurface = true
		else
			surfacePosition = self:_ResolveBoundsSurface(sourcePosition, instance)
			usedSurface = surfacePosition ~= nil
		end
	end

	local resolvedPosition = surfacePosition or aimPosition
	local horizontalDelta = Vector2.new(resolvedPosition.X, resolvedPosition.Z) - Vector2.new(sourcePosition.X, sourcePosition.Z)
	return {
		TargetEntity = targetEntity,
		BoundInstance = instance,
		AimPosition = aimPosition,
		SurfacePosition = surfacePosition,
		Distance = (resolvedPosition - sourcePosition).Magnitude,
		Distance3D = (resolvedPosition - sourcePosition).Magnitude,
		HorizontalDistance = horizontalDelta.Magnitude,
		UsedSurface = usedSurface,
	}
end

function CombatTargetReadService:IsTargetInRange(
	sourcePosition: Vector3,
	targetEntity: number,
	range: number,
	fallbackTargetPosition: Vector3?
): (boolean, any?)
	local geometry = self:ResolveTargetGeometry(sourcePosition, targetEntity, fallbackTargetPosition)
	if geometry == nil or type(geometry.Distance) ~= "number" then
		return false, geometry
	end

	return geometry.Distance <= range, geometry
end

function CombatTargetReadService:ResolveApproachGoal(
	sourcePosition: Vector3,
	targetEntity: number,
	fallbackTargetPosition: Vector3?
): Vector3?
	local geometry = self:ResolveTargetGeometry(sourcePosition, targetEntity, fallbackTargetPosition)
	if geometry == nil then
		return fallbackTargetPosition
	end

	return geometry.SurfacePosition or geometry.AimPosition or fallbackTargetPosition
end

return CombatTargetReadService

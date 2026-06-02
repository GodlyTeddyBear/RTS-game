--!strict

local CombatTargetReadService = {}
CombatTargetReadService.__index = CombatTargetReadService

function CombatTargetReadService.new()
	local self = setmetatable({}, CombatTargetReadService)
	self._entityContext = nil
	return self
end

function CombatTargetReadService:Configure(entityContext: any)
	self._entityContext = entityContext
end

function CombatTargetReadService:GetBoundModel(entity: number): Model?
	if self._entityContext == nil then
		return nil
	end
	local result = self._entityContext:GetBoundInstance(entity)
	local instance = if result.success then result.value else nil
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

return CombatTargetReadService

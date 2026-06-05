--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Orient = require(ReplicatedStorage.Utilities.Orient)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local MovementApplyBridgeService = {}
MovementApplyBridgeService.__index = MovementApplyBridgeService

function MovementApplyBridgeService.new()
	local self = setmetatable({}, MovementApplyBridgeService)
	self._actorReadService = nil
	self._entityContext = nil
	self._lockOnService = nil
	self._refsByEntity = {}
	return self
end

function MovementApplyBridgeService:Init(registry: any, _name: string)
	self._actorReadService = registry:Get("MovementActorReadService")
	self._lockOnService = registry:Get("LockOnService")
	assert(self._actorReadService ~= nil, "MovementApplyBridgeService missing MovementActorReadService in Init")
end

function MovementApplyBridgeService:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	assert(self._entityContext ~= nil, "MovementApplyBridgeService missing EntityContext in Start")
end

function MovementApplyBridgeService:Apply(entityFactory: any, entity: number, applyState: any): (boolean, string?)
	local profile = self._actorReadService:GetActorProfile(entityFactory, entity)
	if type(profile) == "table" and profile.ApplyMode == "Kinematic" then
		return self:_ApplyKinematic(entityFactory, entity, applyState)
	end
	local humanoid = self:_GetHumanoid(entity)
	if humanoid == nil then
		return false, "MissingHumanoid"
	end

	local speed = applyState.WalkSpeed
	if type(speed) ~= "number" then
		speed = self._actorReadService:GetCurrentMoveSpeed(entityFactory, entity)
	end
	if math.abs(humanoid.WalkSpeed - speed) > 0.05 then
		humanoid.WalkSpeed = speed
	end

	local targetPosition = applyState.TargetPosition
	local velocityXZ = if typeof(applyState.VelocityXZ) == "Vector2" then applyState.VelocityXZ else Vector2.zero
	if typeof(targetPosition) == "Vector3" then
		humanoid:MoveTo(targetPosition)
	else
		local rootPart = self:_GetRootPart(entity)
		if rootPart ~= nil then
			humanoid:MoveTo(rootPart.Position)
		else
			humanoid:Move(Vector3.zero)
		end
	end

	self:_SetFacing(entity, velocityXZ)
	return true, nil
end

function MovementApplyBridgeService:_ApplyKinematic(entityFactory: any, entity: number, applyState: any): (boolean, string?)
	local transformResult = entityFactory:Get(entity, "Transform", "Entity")
	local transform = if transformResult.success then transformResult.value else nil
	local targetPosition = applyState.TargetPosition
	if type(transform) ~= "table" or typeof(transform.CFrame) ~= "CFrame" or typeof(targetPosition) ~= "Vector3" then
		return false, "MissingKinematicTransform"
	end
	local speed = self._actorReadService:GetCurrentMoveSpeed(entityFactory, entity)
	local nextPosition = Orient.MoveTowards(transform.CFrame.Position, targetPosition, speed * ServerScheduler:GetDeltaTime())
	local nextCFrame = Orient.BuildLookAt(nextPosition, targetPosition) or CFrame.new(nextPosition)
	entityFactory:Set(entity, "Transform", { CFrame = nextCFrame }, "Entity")
	entityFactory:Add(entity, "DirtyTag", "Entity")
	return true, nil
end

function MovementApplyBridgeService:Stop(entity: number)
	local humanoid = self:_GetHumanoid(entity)
	if humanoid ~= nil then
		humanoid:Move(Vector3.zero)
		local rootPart = self:_GetRootPart(entity)
		if rootPart ~= nil then
			humanoid:MoveTo(rootPart.Position)
		end
	end
	self:_SetFacing(entity, Vector2.zero)
end

function MovementApplyBridgeService:Invalidate(entity: number)
	self._refsByEntity[entity] = nil
end

function MovementApplyBridgeService:CleanupAll()
	for entity in self._refsByEntity do
		self:Stop(entity)
	end
	table.clear(self._refsByEntity)
end

function MovementApplyBridgeService:_GetRefs(entity: number): any
	local refs = self._refsByEntity[entity]
	if refs == nil then
		refs = {}
		self._refsByEntity[entity] = refs
	end

	local model = self._actorReadService:GetBoundModel(self._entityContext, entity)
	if refs.Model ~= model then
		refs.Model = model
		refs.RootPart = nil
		refs.Humanoid = nil
	end
	return refs
end

function MovementApplyBridgeService:_GetRootPart(entity: number): BasePart?
	local refs = self:_GetRefs(entity)
	local rootPart = refs.RootPart
	if rootPart ~= nil and rootPart.Parent ~= nil then
		return rootPart
	end
	rootPart = if refs.Model ~= nil then refs.Model.PrimaryPart else nil
	refs.RootPart = rootPart
	return rootPart
end

function MovementApplyBridgeService:_GetHumanoid(entity: number): Humanoid?
	local refs = self:_GetRefs(entity)
	local humanoid = refs.Humanoid
	if humanoid ~= nil and humanoid.Parent ~= nil then
		return humanoid
	end
	humanoid = if refs.Model ~= nil then refs.Model:FindFirstChildWhichIsA("Humanoid") else nil
	refs.Humanoid = humanoid
	return humanoid
end

function MovementApplyBridgeService:_SetFacing(entity: number, velocityXZ: Vector2)
	local lockOnService = self._lockOnService
	if lockOnService == nil or type(lockOnService.SetBoidsFacingFlatForward) ~= "function" then
		return
	end
	local forward = if velocityXZ.Magnitude > 0 then Vector3.new(velocityXZ.X, 0, velocityXZ.Y).Unit else nil
	lockOnService:SetBoidsFacingFlatForward(entity, forward)
end

return MovementApplyBridgeService

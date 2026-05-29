--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Orient = require(ReplicatedStorage.Utilities.Orient)

--[=[
	@class LockOnService
	Owns orientation constraints that keep enemies facing their current target.
	@server
]=]
local LockOnService = {}
LockOnService.__index = LockOnService

--[=[
	@within LockOnService
	Creates a new lock-on service with no active constraints.
	@return LockOnService -- Service instance used to manage facing constraints.
]=]
function LockOnService.new()
	local self = setmetatable({}, LockOnService)
	self._boidsFacingFlatForward = {} :: { [number]: Vector3 }
	return self
end

--[=[
	@within LockOnService
	Resolves the entity factories used to read attacker and target transforms.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function LockOnService:Init(registry: any, _name: string)
	self._registry = registry
end

--[=[
	@within LockOnService
	Stores the combat factories needed to create and update facing constraints.
]=]
function LockOnService:Start()
end

function LockOnService:ConfigureFactories(
	enemyEntityFactory: any,
	structureEntityFactory: any,
	structureInstanceFactory: any,
	baseEntityFactory: any,
	baseInstanceFactory: any
)
	self._enemyEntityFactory = enemyEntityFactory
	self._structureEntityFactory = structureEntityFactory
	self._structureInstanceFactory = structureInstanceFactory
	self._baseEntityFactory = baseEntityFactory
	self._baseInstanceFactory = baseInstanceFactory
end

function LockOnService:SetBoidsFacingFlatForward(entity: number, flatForward: Vector3?)
	if flatForward == nil then
		self._boidsFacingFlatForward[entity] = nil
		return
	end
	self._boidsFacingFlatForward[entity] = flatForward
end

function LockOnService:CleanupAll()
	if self._enemyEntityFactory == nil then
		return
	end

	for _, entity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
		self:DetachConstraint(entity)
	end
end

local function _setHumanoidAutoRotate(humanoid: Humanoid?, enabled: boolean)
	if humanoid ~= nil then
		humanoid.AutoRotate = enabled
	end
end

function LockOnService:_GetHumanoid(_entity: number): Humanoid?
	return nil
end

--[=[
	@within LockOnService
	Creates and stores the orientation constraint used to keep an enemy facing its target.
	@param entity number -- Enemy entity id to attach the constraint to.
]=]
function LockOnService:AttachConstraint(entity: number)
	local existing = self._enemyEntityFactory:GetLockOn(entity)
	if existing ~= nil and existing.Constraint ~= nil and existing.Constraint.Parent ~= nil then
		return
	end

	return
end

--[=[
	@within LockOnService
	Tears down the orientation constraint and attachments for one enemy.
	@param entity number -- Enemy entity id to detach.
]=]
function LockOnService:DetachConstraint(entity: number)
	self._boidsFacingFlatForward[entity] = nil

	local lockOn = self._enemyEntityFactory:GetLockOn(entity)
	if lockOn == nil then
		return
	end

	_setHumanoidAutoRotate(self:_GetHumanoid(entity), true)

	if lockOn.Constraint ~= nil and lockOn.Constraint.Parent ~= nil then
		lockOn.Constraint:Destroy()
	end
	if lockOn.Attachment0 ~= nil and lockOn.Attachment0.Parent ~= nil then
		lockOn.Attachment0:Destroy()
	end
	if lockOn.Attachment1 ~= nil and lockOn.Attachment1.Parent ~= nil then
		lockOn.Attachment1:Destroy()
	end

	self._enemyEntityFactory:ClearLockOn(entity)
end

--[=[
	@within LockOnService
	Updates every active lock-on constraint to face the current target for the frame.
	@param entities { number } -- Enemy entity ids to update.
]=]
function LockOnService:UpdateAll(entities: { number })
	for _, entity in ipairs(entities) do
		local humanoid = self:_GetHumanoid(entity)
		local lockOn = self._enemyEntityFactory:GetLockOn(entity)
		if lockOn == nil then
			_setHumanoidAutoRotate(humanoid, true)
			continue
		end

		local constraint = lockOn.Constraint
		local attachment1 = lockOn.Attachment1
		if constraint == nil or constraint.Parent == nil or attachment1 == nil or attachment1.Parent == nil then
			_setHumanoidAutoRotate(humanoid, true)
			continue
		end

		local selfCFrame = self._enemyEntityFactory:GetEntityCFrame(entity)
		if selfCFrame == nil then
			constraint.Enabled = false
			_setHumanoidAutoRotate(humanoid, true)
			continue
		end

		local boidsForward = self._boidsFacingFlatForward[entity]
		local targetPosition = nil :: Vector3?
		local lookAt = nil :: CFrame?

		if boidsForward ~= nil then
			local flatUnit = Orient.SafeUnit(Vector3.new(boidsForward.X, 0, boidsForward.Z))
			if flatUnit ~= nil then
				lookAt = Orient.FromFlatLookVector(selfCFrame.Position, flatUnit)
			end
		else
		local target = self._enemyEntityFactory:GetTarget(entity)
		local targetEntity = target and target.TargetEntity or nil
		local targetKind = target and target.TargetKind or nil
		if targetKind == nil then
			constraint.Enabled = false
			_setHumanoidAutoRotate(humanoid, true)
			continue
		end

		if targetKind == "Base" then
			if self._baseEntityFactory == nil or not self._baseEntityFactory:IsActive() then
				constraint.Enabled = false
				_setHumanoidAutoRotate(humanoid, true)
				continue
			end

			local baseEntity = self._baseEntityFactory:GetBaseEntity()
			if baseEntity == nil or self._baseInstanceFactory == nil then
				constraint.Enabled = false
				_setHumanoidAutoRotate(humanoid, true)
				continue
			end

			local baseAnchor = self._baseInstanceFactory:GetBaseAnchor(baseEntity)
			if baseAnchor ~= nil then
				targetPosition = baseAnchor.Position
			else
				local baseInstance = self._baseInstanceFactory:GetBaseInstance(baseEntity)
				if baseInstance ~= nil then
					if baseInstance:IsA("BasePart") then
						targetPosition = baseInstance.Position
					else
						local baseModel = self._baseInstanceFactory:GetBaseModel(baseEntity)
						targetPosition = if baseModel ~= nil then baseModel:GetPivot().Position else nil
					end
				end
			end
		elseif targetKind == "Structure" then
			if targetEntity == nil then
				constraint.Enabled = false
				_setHumanoidAutoRotate(humanoid, true)
				continue
			end
			if not self._structureEntityFactory:IsTargetable(targetEntity) then
				constraint.Enabled = false
				_setHumanoidAutoRotate(humanoid, true)
				continue
			end
			local structureModel = if self._structureInstanceFactory ~= nil
				then self._structureInstanceFactory:GetInstance(targetEntity)
				else nil
			if structureModel ~= nil and structureModel:IsA("Model") then
				targetPosition = structureModel:GetPivot().Position
			else
				targetPosition = self._structureEntityFactory:GetPosition(targetEntity)
			end
		elseif targetKind == "Enemy" then
			if targetEntity == nil then
				constraint.Enabled = false
				_setHumanoidAutoRotate(humanoid, true)
				continue
			end
			if not self._enemyEntityFactory:IsAlive(targetEntity) then
				constraint.Enabled = false
				_setHumanoidAutoRotate(humanoid, true)
				continue
			end

			local targetCFrame = self._enemyEntityFactory:GetEntityCFrame(targetEntity)
			targetPosition = if targetCFrame then targetCFrame.Position else nil
		else
			constraint.Enabled = false
			_setHumanoidAutoRotate(humanoid, true)
			continue
		end
		end

		if boidsForward ~= nil then
			if lookAt == nil then
				constraint.Enabled = false
				_setHumanoidAutoRotate(humanoid, true)
				continue
			end

			attachment1.WorldCFrame = lookAt
			constraint.Enabled = true
			_setHumanoidAutoRotate(humanoid, false)
			continue
		end

		if targetPosition == nil then
			constraint.Enabled = false
			_setHumanoidAutoRotate(humanoid, true)
			continue
		end

		lookAt = Orient.BuildFlatLookAt(selfCFrame.Position, targetPosition)
		if lookAt == nil then
			constraint.Enabled = false
			_setHumanoidAutoRotate(humanoid, true)
			continue
		end

		attachment1.WorldCFrame = lookAt
		constraint.Enabled = true
		_setHumanoidAutoRotate(humanoid, false)
	end
end

return LockOnService

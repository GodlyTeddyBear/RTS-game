--!strict

local Workspace = game:GetService("Workspace")

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
	return setmetatable({}, LockOnService)
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
	self._enemyEntityFactory = self._registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = self._registry:Get("StructureEntityFactory")
end

-- Projects the target vector onto the ground plane so lock-on rotation stays horizontal.
local function _flatLookAt(fromPosition: Vector3, toPosition: Vector3): CFrame?
	local direction = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	if direction.Magnitude < 0.01 then
		return nil
	end

	return CFrame.lookAt(fromPosition, fromPosition + direction)
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

	local modelRef = self._enemyEntityFactory:GetModelRef(entity)
	if modelRef == nil or modelRef.Model == nil then
		return
	end

	local primaryPart = modelRef.Model.PrimaryPart
	if primaryPart == nil then
		return
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "LockOnAttachment0"
	attachment0.Parent = primaryPart

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "LockOnAttachment1"
	attachment1.Parent = Workspace.Terrain

	local constraint = Instance.new("AlignOrientation")
	constraint.Name = "LockOnConstraint"
	constraint.Attachment0 = attachment0
	constraint.Attachment1 = attachment1
	constraint.AlignType = Enum.AlignType.AllAxes
	constraint.RigidityEnabled = false
	constraint.MaxAngularVelocity = math.huge
	constraint.MaxTorque = math.huge
	constraint.Responsiveness = 200
	constraint.Enabled = false
	constraint.Parent = primaryPart

	self._enemyEntityFactory:SetLockOn(entity, {
		Attachment0 = attachment0,
		Attachment1 = attachment1,
		Constraint = constraint,
	})
end

--[=[
	@within LockOnService
	Tears down the orientation constraint and attachments for one enemy.
	@param entity number -- Enemy entity id to detach.
]=]
function LockOnService:DetachConstraint(entity: number)
	local lockOn = self._enemyEntityFactory:GetLockOn(entity)
	if lockOn == nil then
		return
	end

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
		local lockOn = self._enemyEntityFactory:GetLockOn(entity)
		if lockOn == nil then
			continue
		end

		local constraint = lockOn.Constraint
		local attachment1 = lockOn.Attachment1
		if constraint == nil or constraint.Parent == nil or attachment1 == nil or attachment1.Parent == nil then
			continue
		end

		local target = self._enemyEntityFactory:GetTarget(entity)
		local targetEntity = target and target.TargetEntity or nil
		local targetKind = target and target.TargetKind or nil
		if targetEntity == nil or targetKind == nil then
			constraint.Enabled = false
			continue
		end

		local selfCFrame = self._enemyEntityFactory:GetEntityCFrame(entity)
		if selfCFrame == nil then
			constraint.Enabled = false
			continue
		end

		local targetPosition = nil :: Vector3?
		if targetKind == "Structure" then
			if not self._structureEntityFactory:IsActive(targetEntity) then
				constraint.Enabled = false
				continue
			end
			targetPosition = self._structureEntityFactory:GetPosition(targetEntity)
		else
			if not self._enemyEntityFactory:IsAlive(targetEntity) then
				constraint.Enabled = false
				continue
			end

			local targetCFrame = self._enemyEntityFactory:GetEntityCFrame(targetEntity)
			targetPosition = if targetCFrame then targetCFrame.Position else nil
		end

		if targetPosition == nil then
			constraint.Enabled = false
			continue
		end

		local lookAt = _flatLookAt(selfCFrame.Position, targetPosition)
		if lookAt == nil then
			constraint.Enabled = false
			continue
		end

		attachment1.WorldCFrame = lookAt
		constraint.Enabled = true
	end
end

return LockOnService

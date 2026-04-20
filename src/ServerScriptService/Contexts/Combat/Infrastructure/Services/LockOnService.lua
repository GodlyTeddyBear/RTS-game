--!strict

--[=[
	@class LockOnService
	Manages per-NPC AlignOrientation constraints that rotate NPCs to face their
	current target on the horizontal plane (Y-axis only).

	One `AlignOrientation` is created per NPC model when `AttachConstraint` is
	called. The constraint is enabled only while the entity has a live target,
	and is disabled otherwise so SimplePath's natural facing applies during
	wandering and fleeing.

	`UpdateAll` is called each server frame by `CombatContext`'s scheduler tick.
	@server
]=]

local Workspace = game:GetService("Workspace")

local LockOnService = {}
LockOnService.__index = LockOnService

export type TLockOnService = typeof(setmetatable({} :: {
	NPCEntityFactory: any,
	Components: any,
}, LockOnService))

function LockOnService.new(): TLockOnService
	return setmetatable({} :: any, LockOnService)
end

function LockOnService:Init(registry: any)
	self.Registry = registry
end

function LockOnService:Start()
	self.NPCEntityFactory = self.Registry:Get("NPCEntityFactory")
	self.Components = self.Registry:Get("Components")
end

-- Compute a CFrame that faces `to` from `from`, ignoring vertical difference.
-- Returns nil if the two positions are too close to determine a direction.
local function FlatLookAt(from: Vector3, to: Vector3): CFrame?
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if dir.Magnitude < 0.01 then
		return nil
	end
	return CFrame.lookAt(from, from + dir)
end

--[=[
	Create and attach an `AlignOrientation` constraint to an NPC's `PrimaryPart`.
	Stores the constraint and its attachments in the entity's `LockOnComponent`.
	Must be called after the entity's model has been assigned via `SetModelRef`.
	@within LockOnService
	@param entity any -- JECS entity ID
]=]
function LockOnService:AttachConstraint(entity: any)
	local npc = self.NPCEntityFactory
	local modelRef = npc:GetModelRef(entity)
	if not modelRef or not modelRef.Instance then
		return
	end

	local primaryPart = modelRef.Instance.PrimaryPart
	if not primaryPart then
		return
	end

	-- Attachment on the NPC's PrimaryPart — AlignOrientation aligns this
	local att0 = Instance.new("Attachment")
	att0.Name = "LockOnAttachment0"
	att0.Parent = primaryPart

	-- World-space reference attachment parented to Workspace terrain
	local att1 = Instance.new("Attachment")
	att1.Name = "LockOnAttachment1"
	att1.Parent = Workspace.Terrain

	local constraint = Instance.new("AlignOrientation")
	constraint.Name = "LockOnConstraint"
	constraint.Attachment0 = att0
	constraint.Attachment1 = att1
	constraint.AlignType = Enum.AlignType.AllAxes
	constraint.RigidityEnabled = false
	constraint.MaxAngularVelocity = math.huge
	constraint.MaxTorque = math.huge
	constraint.Responsiveness = 200
	constraint.Enabled = false
	constraint.Parent = primaryPart

	npc:SetLockOn(entity, {
		Attachment0 = att0,
		Attachment1 = att1,
		Constraint = constraint,
	})
end

--[=[
	Destroy the `AlignOrientation` constraint and its attachments for an entity.
	Called when combat ends to prevent Instance leaks.
	@within LockOnService
	@param entity any -- JECS entity ID
]=]
function LockOnService:DetachConstraint(entity: any)
	local lockOn = self.NPCEntityFactory:GetLockOn(entity)
	if not lockOn then
		return
	end

	if lockOn.Constraint and lockOn.Constraint.Parent then
		lockOn.Constraint:Destroy()
	end
	if lockOn.Attachment0 and lockOn.Attachment0.Parent then
		lockOn.Attachment0:Destroy()
	end
	if lockOn.Attachment1 and lockOn.Attachment1.Parent then
		lockOn.Attachment1:Destroy()
	end
end

--[=[
	Update all lock-on constraints for a list of entities.
	Enables the constraint and aims at the target when one exists; disables it otherwise.
	Called each server Heartbeat tick by `CombatContext`.
	@within LockOnService
	@param entities { any } -- Array of JECS entity IDs to update
]=]
function LockOnService:UpdateAll(entities: { any })
	local npc = self.NPCEntityFactory

	for _, entity in ipairs(entities) do
		local lockOn = npc:GetLockOn(entity)
		if not lockOn then
			continue
		end

		local constraint = lockOn.Constraint
		if not constraint or not constraint.Parent then
			continue
		end

		-- Resolve current target
		local targetComp = npc:GetTarget(entity)
		local targetEntity = targetComp and targetComp.TargetEntity

		if not targetEntity or not npc:IsAlive(targetEntity) then
			constraint.Enabled = false
			continue
		end

		-- Fetch positions
		local selfPos = npc:GetPosition(entity)
		local targetPos = npc:GetPosition(targetEntity)
		if not selfPos or not targetPos then
			constraint.Enabled = false
			continue
		end

		local lookCFrame = FlatLookAt(selfPos.CFrame.Position, targetPos.CFrame.Position)
		if not lookCFrame then
			constraint.Enabled = false
			continue
		end

		-- Point the world-reference attachment in the desired facing direction,
		-- then enable the constraint so AlignOrientation drives the NPC toward it.
		lockOn.Attachment1.WorldCFrame = lookCFrame
		constraint.Enabled = true
	end
end

return LockOnService

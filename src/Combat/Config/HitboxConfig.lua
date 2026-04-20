--!strict

--[[
	HitboxConfig - Defines hitbox shapes and parameters per attack type.

	Each entry configures how MuchachoHitbox is created for that attack:
	- Shape: Block (box query) or Ball (radius query)
	- Size: Vector3 for Block, number (radius) for Ball
	- Offset: CFrame offset from the attacker's pivot (or target position for targeted hitboxes)
	- DetectionMode: How MuchachoHitbox tracks hits
	- MaxDuration: Seconds before the hitbox expires (attack whiffs)
]]

export type TDetectionMode = "Default" | "ConstantDetection" | "HitOnce" | "HitParts"

export type THitboxConfig = {
	Shape: Enum.PartType,
	Size: Vector3 | number,
	Offset: CFrame,
	DetectionMode: TDetectionMode,
	MaxDuration: number,
	Visualize: boolean,
}

local MeleeAttack: THitboxConfig = {
	Shape = Enum.PartType.Block,
	Size = Vector3.new(4, 4, 5),
	Offset = CFrame.new(0, 0, -2.5),
	DetectionMode = "Default",
	MaxDuration = 1.0,
	Visualize = true,
}

local RangedAttack: THitboxConfig = {
	Shape = Enum.PartType.Ball,
	Size = 3,
	Offset = CFrame.new(0, 0, 0),
	DetectionMode = "HitOnce",
	MaxDuration = 0.1,
	Visualize = true,
}

local SwordAttack: THitboxConfig = {
	Shape = Enum.PartType.Block,
	Size = Vector3.new(5, 4, 5),
	Offset = CFrame.new(0, 0, -2.5),
	DetectionMode = "Default",
	MaxDuration = 1.0,
	Visualize = true,
}

local DaggerAttack: THitboxConfig = {
	Shape = Enum.PartType.Block,
	Size = Vector3.new(3, 3, 4),
	Offset = CFrame.new(0, 0, -2),
	DetectionMode = "Default",
	MaxDuration = 0.6,
	Visualize = true,
}

local StaffAttack: THitboxConfig = {
	Shape = Enum.PartType.Ball,
	Size = 3,
	Offset = CFrame.new(0, 0, 0),
	DetectionMode = "HitOnce",
	MaxDuration = 0.1,
	Visualize = true,
}

local PunchAttack: THitboxConfig = {
	Shape = Enum.PartType.Block,
	Size = Vector3.new(3, 3, 3),
	Offset = CFrame.new(0, 0, -1.5),
	DetectionMode = "Default",
	MaxDuration = 0.8,
	Visualize = true,
}

return table.freeze({
	MeleeAttack = MeleeAttack,
	RangedAttack = RangedAttack,
	SwordAttack = SwordAttack,
	DaggerAttack = DaggerAttack,
	StaffAttack = StaffAttack,
	PunchAttack = PunchAttack,
})

--!strict

local HitboxConfig = {}

export type THitboxConfig = {
	DetectionMode: "Default" | "ConstantDetection" | "HitOnce" | "HitParts",
	Shape: Enum.PartType,
	Size: Vector3,
	Offset: CFrame,
	Visualize: boolean,
	MaxDuration: number,
}

HitboxConfig.AttackStructure = table.freeze({
	DetectionMode = "HitParts",
	Shape = Enum.PartType.Block,
	Size = Vector3.new(6, 5, 6),
	Offset = CFrame.new(0, 0, -3),
	Visualize = true,
	MaxDuration = 1,
} :: THitboxConfig)

HitboxConfig.StructureAttack = table.freeze({
	DetectionMode = "HitParts",
	Shape = Enum.PartType.Block,
	Size = Vector3.new(18, 18, 18),
	Offset = CFrame.new(),
	Visualize = true,
	MaxDuration = 1,
} :: THitboxConfig)

return table.freeze(HitboxConfig)

--!strict

--[[
    Component type definitions for Worker ECS system.
    These types define the shape of component data stored in JECS world.
]]

export type TWorkerComponent = {
	Id: string, -- Unique worker ID (for persistence mapping)
	UserId: number, -- Owner player ID
	Rank: string, -- Worker tier rank (see WorkerConfig): "Apprentice" | "Journeyman" | "Master"
	Level: number,
	Experience: number,
}

export type TAssignmentComponent = {
	Role: string, -- Worker role: "Undecided", "Forge", etc.
	TaskTarget: string?, -- Generic role-specific target (e.g. ore type for Miner)
	LastProductionTick: number,
	SlotIndex: number?, -- Radial mining slot index (0-6), nil = unassigned
}

export type TPositionComponent = {
	X: number,
	Y: number,
	Z: number,
	LookAtX: number?,
	LookAtY: number?,
	LookAtZ: number?,
}

export type TGameObjectComponent = {
	Instance: Model, -- Reference to Roblox model in workspace
}

export type TMiningStateComponent = {
	MiningStartTime: number, -- os.clock() when mining action began
	MiningDuration: number, -- seconds to complete one mine action
	TargetOreId: string, -- which ore is being mined
}

export type TEquipmentComponent = {
	ToolId: string, -- Tool asset ID (e.g. "Pickaxe")
	Slot: string, -- Equipment slot (e.g. "MainHand")
}

-- Tags (components with no data, used for filtering)
export type TDirtyTag = boolean -- Marks entity as needing GameObject sync

return {}

--!strict

--[[
    Command type definitions for the PlayerCommand system.
    Shared between server and client.
]]

export type TCommandPayload = {
	CommandType: string, -- "MoveToPosition" | "AttackTarget" | "HoldPosition" | "AttackNearest"
	NPCIds: { string }, -- List of NPCIds to command
	Data: { [string]: any }, -- Command-specific data
}

export type TToggleModePayload = {
	NPCIds: { string }, -- List of NPCIds to toggle
}

-- Valid command types
local CommandTypes = {
	MoveToPosition = "MoveToPosition",
	AttackTarget = "AttackTarget",
	HoldPosition = "HoldPosition",
	AttackNearest = "AttackNearest",
	Block = "Block",
	Parry = "Parry",
	UseSkill = "UseSkill", -- Data: { SkillId: string, TargetNPCId: string? }
}

-- Valid control modes
local ControlModes = {
	Auto = "Auto",
	Manual = "Manual",
}

return {
	CommandTypes = CommandTypes,
	ControlModes = ControlModes,
}

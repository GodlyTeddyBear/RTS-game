--!strict

--[[
    Combat Component type definitions for NPC/Combat ECS system.
    These types define the shape of component data stored in the combat JECS world.
]]

export type THealthComponent = {
	Current: number,
	Max: number,
}

export type TStatsComponent = {
	ATK: number,
	DEF: number,
}

export type TPositionComponent = {
	CFrame: CFrame,
}

export type TTeamComponent = {
	Team: "Adventurer" | "Enemy",
	UserId: number, -- Owning player
}

export type TTargetComponent = {
	TargetEntity: any?, -- JECS entity id of current target
}

-- Action state: what action the NPC is currently performing.
-- Drives AnimationState attribute → action animations on the client.
export type TCombatStateComponent = {
	State: "None" | "Attacking" | "Blocking" | "Parrying" | "Dead",
}

export type TBlockStateComponent = {
	IsBlocking: boolean,
	IsParrying: boolean,
	ParryWindowEnd: number, -- os.clock() timestamp when the parry window closes
}

-- Locomotion state: how the NPC is moving through the world.
-- Server-side only; SimpleAnimate handles walk/idle visually from Humanoid.
export type TLocomotionStateComponent = {
	State: "Idle" | "Moving" | "Fleeing" | "Wandering",
}

export type TModelRefComponent = {
	Instance: Model, -- Reference to Roblox model in workspace
}

export type TAttackCooldownComponent = {
	LastAttackTime: number,
	Cooldown: number,
}

export type TBehaviorTreeComponent = {
	TreeInstance: any, -- BehaviourTree instance
	LastTickTime: number,
	TickInterval: number, -- Staggered per NPC (0.2-0.5s)
}

export type TNPCIdentityComponent = {
	NPCId: string, -- adventurerId or generated enemyId
	NPCType: string, -- "Warrior", "Goblin", etc.
	DisplayName: string,
	IsAdventurer: boolean,
}

export type TDetectionComponent = {
	DetectionRadius: number,
	AttackRange: number,
}

export type TBehaviorConfigComponent = {
	AttackEnterRange: number,
	AttackExitRange: number,
	ChaseEnterRadius: number,
	ChaseExitRadius: number,
	MinAttackRange: number?,
	MaxAttackRange: number?,
	IsRanged: boolean,
	FleeHPThreshold: number,
	FleeEnabled: boolean,
	WanderRadius: number,
	WanderInterval: number,
	MoveSpeed: number,
	FleeDistance: number,
	ChaseRecomputeThreshold: number,
	FleeRecomputeThreshold: number,
}

export type TCombatActionComponent = {
	CurrentActionId: string?,
	PendingActionId: string?,
	-- None      : no action running
	-- Running   : action in progress, interruptible (Chase, Idle, Flee, Wander, pre-hitbox attack)
	-- Committed : hitbox activated — attack locked in, non-interruptible
	-- Cancelling: reserved
	ActionState: "None" | "Running" | "Committed" | "Cancelling",
	ActionStartTime: number,
	ActionData: { [string]: any }?,
	PendingActionData: { [string]: any }?,
	Interruptible: boolean?, -- False = TakingDamage won't cancel this action's animation
}

export type TPlayerCommandComponent = {
	CommandType: string?, -- "MoveToPosition" | "AttackTarget" | nil
	CommandData: { [string]: any }?, -- Command-specific payload | nil
	IssuedAt: number?, -- os.clock() when command was issued | nil
}

export type TWeaponCategoryComponent = {
	Category: string, -- "Sword" | "Dagger" | "Staff" | "Punch"
}

-- ControlMode: cached from the model's ControlMode attribute to avoid per-frame GetAttribute calls.
-- Updated by CombatContext via AttributeChanged when the attribute changes on the model.
export type TControlModeComponent = {
	Mode: "Auto" | "Manual",
}

export type TLockOnComponent = {
	Attachment0: Attachment, -- Attached to PrimaryPart; AlignOrientation reads this
	Attachment1: Attachment, -- World-space reference attachment parented to workspace
	Constraint: AlignOrientation,
}

export type TSkillSetComponent = {
	Skills: { string }, -- All active skill IDs (innate + equipment, merged at spawn)
}

export type TSkillCooldownsComponent = {
	ReadyAt: { [string]: number }, -- SkillId → os.clock() timestamp when skill becomes available; absent = ready
}

-- Tags (components with no data, used for filtering)
export type TAliveTag = boolean
export type TEnemyTag = boolean
export type TAdventurerTag = boolean
export type TDirtyTag = boolean

return {}

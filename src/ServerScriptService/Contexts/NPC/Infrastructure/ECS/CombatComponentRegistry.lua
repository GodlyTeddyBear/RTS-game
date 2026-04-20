--!strict

--[=[
	@class CombatComponentRegistry
	Registers and manages all ECS components used in the combat world (NPC entities, attacks, damage).
	@server
]=]

--[[
    CombatComponentRegistry - Defines all combat ECS components.

    Responsibilities:
    - Define component types in the combat JECS world
    - Provide component references to other services

    Pattern: Created once during NPCContext initialization
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)
local CombatComponentTypes = require(ReplicatedStorage.Contexts.NPC.Types.CombatComponentTypes)

export type THealthComponent = CombatComponentTypes.THealthComponent
export type TStatsComponent = CombatComponentTypes.TStatsComponent
export type TPositionComponent = CombatComponentTypes.TPositionComponent
export type TTeamComponent = CombatComponentTypes.TTeamComponent
export type TTargetComponent = CombatComponentTypes.TTargetComponent
export type TCombatStateComponent = CombatComponentTypes.TCombatStateComponent
export type TLocomotionStateComponent = CombatComponentTypes.TLocomotionStateComponent
export type TModelRefComponent = CombatComponentTypes.TModelRefComponent
export type TAttackCooldownComponent = CombatComponentTypes.TAttackCooldownComponent
export type TBehaviorTreeComponent = CombatComponentTypes.TBehaviorTreeComponent
export type TNPCIdentityComponent = CombatComponentTypes.TNPCIdentityComponent
export type TDetectionComponent = CombatComponentTypes.TDetectionComponent
export type TBehaviorConfigComponent = CombatComponentTypes.TBehaviorConfigComponent
export type TCombatActionComponent = CombatComponentTypes.TCombatActionComponent
export type TPlayerCommandComponent = CombatComponentTypes.TPlayerCommandComponent
export type TWeaponCategoryComponent = CombatComponentTypes.TWeaponCategoryComponent
export type TControlModeComponent = CombatComponentTypes.TControlModeComponent
export type TBlockStateComponent = CombatComponentTypes.TBlockStateComponent
export type TLockOnComponent = CombatComponentTypes.TLockOnComponent
export type TSkillSetComponent = CombatComponentTypes.TSkillSetComponent
export type TSkillCooldownsComponent = CombatComponentTypes.TSkillCooldownsComponent
export type TAliveTag = CombatComponentTypes.TAliveTag
export type TEnemyTag = CombatComponentTypes.TEnemyTag
export type TAdventurerTag = CombatComponentTypes.TAdventurerTag
export type TDirtyTag = CombatComponentTypes.TDirtyTag

local CombatComponentRegistry = {}
CombatComponentRegistry.__index = CombatComponentRegistry

export type TCombatComponentRegistry = typeof(setmetatable({} :: {
	World: any,
	HealthComponent: THealthComponent,
	StatsComponent: TStatsComponent,
	PositionComponent: TPositionComponent,
	TeamComponent: TTeamComponent,
	TargetComponent: TTargetComponent,
	CombatStateComponent: TCombatStateComponent,
	LocomotionStateComponent: TLocomotionStateComponent,
	ModelRefComponent: TModelRefComponent,
	AttackCooldownComponent: TAttackCooldownComponent,
	BehaviorTreeComponent: TBehaviorTreeComponent,
	NPCIdentityComponent: TNPCIdentityComponent,
	DetectionComponent: TDetectionComponent,
	BehaviorConfigComponent: TBehaviorConfigComponent,
	CombatActionComponent: TCombatActionComponent,
	PlayerCommandComponent: TPlayerCommandComponent,
	WeaponCategoryComponent: TWeaponCategoryComponent,
	ControlModeComponent: TControlModeComponent,
	BlockStateComponent: TBlockStateComponent,
	LockOnComponent: TLockOnComponent,
	SkillSetComponent: TSkillSetComponent,
	SkillCooldownsComponent: TSkillCooldownsComponent,
	AliveTag: TAliveTag,
	EnemyTag: TEnemyTag,
	AdventurerTag: TAdventurerTag,
	DirtyTag: TDirtyTag,
	EntityTag: any,
}, CombatComponentRegistry))

function CombatComponentRegistry.new(): TCombatComponentRegistry
	local self = setmetatable({}, CombatComponentRegistry)
	return self
end

--[=[
	Register all combat components in the JECS world.
	@within CombatComponentRegistry
	@param registry any -- Registry service with `:Get()` for "World"
	@yields
]=]
function CombatComponentRegistry:Init(registry: any)
	local world = registry:Get("World")
	self.World = world

	-- Data components
	self.HealthComponent = world:component() :: THealthComponent
	world:set(self.HealthComponent, JECS.Name, "Health")
	self.StatsComponent = world:component() :: TStatsComponent
	world:set(self.StatsComponent, JECS.Name, "Stats")
	self.PositionComponent = world:component() :: TPositionComponent
	world:set(self.PositionComponent, JECS.Name, "Position")
	self.TeamComponent = world:component() :: TTeamComponent
	world:set(self.TeamComponent, JECS.Name, "Team")
	self.TargetComponent = world:component() :: TTargetComponent
	world:set(self.TargetComponent, JECS.Name, "Target")
	self.CombatStateComponent = world:component() :: TCombatStateComponent
	world:set(self.CombatStateComponent, JECS.Name, "CombatState")
	self.LocomotionStateComponent = world:component() :: TLocomotionStateComponent
	world:set(self.LocomotionStateComponent, JECS.Name, "LocomotionState")
	self.ModelRefComponent = world:component() :: TModelRefComponent
	world:set(self.ModelRefComponent, JECS.Name, "ModelRef")
	self.AttackCooldownComponent = world:component() :: TAttackCooldownComponent
	world:set(self.AttackCooldownComponent, JECS.Name, "AttackCooldown")
	self.BehaviorTreeComponent = world:component() :: TBehaviorTreeComponent
	world:set(self.BehaviorTreeComponent, JECS.Name, "BehaviorTree")
	self.NPCIdentityComponent = world:component() :: TNPCIdentityComponent
	world:set(self.NPCIdentityComponent, JECS.Name, "NPCIdentity")
	self.DetectionComponent = world:component() :: TDetectionComponent
	world:set(self.DetectionComponent, JECS.Name, "Detection")
	self.BehaviorConfigComponent = world:component() :: TBehaviorConfigComponent
	world:set(self.BehaviorConfigComponent, JECS.Name, "BehaviorConfig")
	self.CombatActionComponent = world:component() :: TCombatActionComponent
	world:set(self.CombatActionComponent, JECS.Name, "CombatAction")
	self.PlayerCommandComponent = world:component() :: TPlayerCommandComponent
	world:set(self.PlayerCommandComponent, JECS.Name, "PlayerCommand")
	self.WeaponCategoryComponent = world:component() :: TWeaponCategoryComponent
	world:set(self.WeaponCategoryComponent, JECS.Name, "WeaponCategory")
	self.ControlModeComponent = world:component() :: TControlModeComponent
	world:set(self.ControlModeComponent, JECS.Name, "ControlMode")
	self.BlockStateComponent = world:component() :: TBlockStateComponent
	world:set(self.BlockStateComponent, JECS.Name, "BlockState")
	self.LockOnComponent = world:component() :: TLockOnComponent
	world:set(self.LockOnComponent, JECS.Name, "LockOn")
	self.SkillSetComponent = world:component() :: TSkillSetComponent
	world:set(self.SkillSetComponent, JECS.Name, "SkillSet")
	self.SkillCooldownsComponent = world:component() :: TSkillCooldownsComponent
	world:set(self.SkillCooldownsComponent, JECS.Name, "SkillCooldowns")

	-- Tag components (no data, used for filtering)
	self.AliveTag = world:component() :: TAliveTag
	world:set(self.AliveTag, JECS.Name, "Alive")
	self.EnemyTag = world:component() :: TEnemyTag
	world:set(self.EnemyTag, JECS.Name, "Enemy")
	self.AdventurerTag = world:component() :: TAdventurerTag
	world:set(self.AdventurerTag, JECS.Name, "Adventurer")
	self.DirtyTag = world:component() :: TDirtyTag
	world:set(self.DirtyTag, JECS.Name, "Dirty")
	self.EntityTag = world:component()
	world:set(self.EntityTag, JECS.Name, "Entity")
end

return CombatComponentRegistry

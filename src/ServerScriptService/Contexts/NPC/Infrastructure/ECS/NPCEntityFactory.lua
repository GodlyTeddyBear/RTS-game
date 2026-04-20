--!strict

--[=[
	@class NPCEntityFactory
	Creates, queries, and mutates NPC entities in the combat JECS world.
	Provides component accessors and bulk query operations for combat/animation sync systems.
	@server
]=]

--[[
    NPCEntityFactory - Creates and manipulates NPC entities in the combat JECS world.

    Responsibilities:
    - Create adventurer and enemy entities with components
    - Update NPC components (with immutability)
    - Query NPC entities by team, user, alive status
    - Delete NPC entities

    Pattern: Infrastructure layer service with dependency injection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

local NPCConfig = require(script.Parent.Parent.Parent.Config.NPCConfig)
local CombatComponentRegistry = require(script.Parent.CombatComponentRegistry)
local BehaviorDefaults = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorDefaults)
local SkillSetConfig = require(ReplicatedStorage.Contexts.Combat.Config.SkillSetConfig)
local WeaponCategoryConfig = require(ReplicatedStorage.Contexts.Combat.Config.WeaponCategoryConfig)

export type THealthComponent = CombatComponentRegistry.THealthComponent
export type TStatsComponent = CombatComponentRegistry.TStatsComponent
export type TPositionComponent = CombatComponentRegistry.TPositionComponent
export type TTeamComponent = CombatComponentRegistry.TTeamComponent
export type TTargetComponent = CombatComponentRegistry.TTargetComponent
export type TCombatStateComponent = CombatComponentRegistry.TCombatStateComponent
export type TLocomotionStateComponent = CombatComponentRegistry.TLocomotionStateComponent
export type TModelRefComponent = CombatComponentRegistry.TModelRefComponent
export type TAttackCooldownComponent = CombatComponentRegistry.TAttackCooldownComponent
export type TBehaviorTreeComponent = CombatComponentRegistry.TBehaviorTreeComponent
export type TNPCIdentityComponent = CombatComponentRegistry.TNPCIdentityComponent
export type TDetectionComponent = CombatComponentRegistry.TDetectionComponent
export type TBehaviorConfigComponent = CombatComponentRegistry.TBehaviorConfigComponent
export type TCombatActionComponent = CombatComponentRegistry.TCombatActionComponent
export type TPlayerCommandComponent = CombatComponentRegistry.TPlayerCommandComponent
export type TWeaponCategoryComponent = CombatComponentRegistry.TWeaponCategoryComponent
export type TControlModeComponent = CombatComponentRegistry.TControlModeComponent
export type TBlockStateComponent = CombatComponentRegistry.TBlockStateComponent
export type TLockOnComponent = CombatComponentRegistry.TLockOnComponent
export type TSkillSetComponent = CombatComponentRegistry.TSkillSetComponent
export type TSkillCooldownsComponent = CombatComponentRegistry.TSkillCooldownsComponent

local NPCEntityFactory = {}
NPCEntityFactory.__index = NPCEntityFactory

export type TNPCEntityFactory = typeof(setmetatable({} :: { World: any, Components: any }, NPCEntityFactory))

function NPCEntityFactory.new(): TNPCEntityFactory
	local self = setmetatable({}, NPCEntityFactory)
	return self
end

--[=[
	Initialize the factory with JECS world and component registry.
	@within NPCEntityFactory
	@param registry any -- Registry service with `:Get("World")` and `:Get("Components")`
]=]
function NPCEntityFactory:Init(registry: any)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
end

---
-- Entity Creation
---

-- Create all shared base components (Health, Stats, Position, etc.) and return a new entity.
-- Initializes combat/locomotion state and cooldown tracking.
function NPCEntityFactory:_CreateBaseNPCEntity(
	hp: number,
	atk: number,
	def: number,
	position: Vector3
): any
	local entity = self.World:entity()
	local world = self.World :: any

	-- Create entity and attach base stat/state components
	world:set(entity, self.Components.HealthComponent, {
		Current = hp,
		Max = hp,
	} :: THealthComponent)

	world:set(entity, self.Components.StatsComponent, {
		ATK = atk,
		DEF = def,
	} :: TStatsComponent)

	world:set(entity, self.Components.PositionComponent, {
		CFrame = CFrame.new(position),
	} :: TPositionComponent)

	world:set(entity, self.Components.TargetComponent, {
		TargetEntity = nil,
	} :: TTargetComponent)

	-- Initialize combat and locomotion state machines
	world:set(entity, self.Components.CombatStateComponent, {
		State = "None",
	} :: TCombatStateComponent)

	world:set(entity, self.Components.LocomotionStateComponent, {
		State = "Idle",
	} :: TLocomotionStateComponent)

	-- Set up detection and combat action tracking
	world:set(entity, self.Components.AttackCooldownComponent, {
		LastAttackTime = 0,
		Cooldown = NPCConfig.DEFAULT_ATTACK_COOLDOWN,
	} :: TAttackCooldownComponent)

	world:set(entity, self.Components.DetectionComponent, {
		DetectionRadius = NPCConfig.DEFAULT_DETECTION_RADIUS,
		AttackRange = NPCConfig.DEFAULT_ATTACK_RANGE,
	} :: TDetectionComponent)

	world:set(entity, self.Components.CombatActionComponent, {
		CurrentActionId = nil,
		PendingActionId = nil,
		ActionState = "None",
		ActionStartTime = 0,
		ActionData = nil,
		PendingActionData = nil,
	} :: TCombatActionComponent)

	-- Default control mode (adventurers may switch to Manual via player RTS commands)
	world:set(entity, self.Components.ControlModeComponent, {
		Mode = "Auto",
	} :: TControlModeComponent)

	-- Mark as alive and dirty (needs initial sync to models)
	world:add(entity, self.Components.AliveTag)
	world:add(entity, self.Components.DirtyTag)

	return entity
end

--[=[
	Create an adventurer NPC entity with combat components, team affiliation, and optional weapon category.
	@within NPCEntityFactory
	@param userId number -- Player ID who owns this adventurer
	@param adventurerId string -- Unique ID for this adventurer
	@param adventurerType string -- Archetype/model name (e.g., "Warrior", "Mage")
	@param effectiveHP number -- Current HP after equipment bonuses
	@param effectiveATK number -- Current ATK after equipment bonuses
	@param effectiveDEF number -- Current DEF after equipment bonuses
	@param position Vector3 -- Initial spawn location
	@param weaponCategory string? -- Weapon type for animation selection
	@return any -- JECS entity ID
]=]
function NPCEntityFactory:CreateAdventurer(
	userId: number,
	adventurerId: string,
	adventurerType: string,
	displayName: string,
	effectiveHP: number,
	effectiveATK: number,
	effectiveDEF: number,
	position: Vector3,
	weaponCategory: string?
): any
	local entity = self:_CreateBaseNPCEntity(effectiveHP, effectiveATK, effectiveDEF, position)
	local world = self.World :: any

	world:set(entity, self.Components.TeamComponent, {
		Team = "Adventurer",
		UserId = userId,
	} :: TTeamComponent)

	world:set(entity, self.Components.NPCIdentityComponent, {
		NPCId = adventurerId,
		NPCType = adventurerType,
		DisplayName = displayName,
		IsAdventurer = true,
	} :: TNPCIdentityComponent)

	world:set(entity, self.Components.WeaponCategoryComponent, {
		Category = weaponCategory or "Punch",
	} :: TWeaponCategoryComponent)

	self:_InitSkillComponents(entity, adventurerType, weaponCategory)

	world:add(entity, self.Components.AdventurerTag)
	world:set(entity, self.Components.EntityTag, `Adventurer:{adventurerId}`)
	world:set(entity, JECS.Name, `Adventurer:{adventurerId}`)

	return entity
end

--[=[
	Create an enemy NPC entity with combat components and team affiliation.
	@within NPCEntityFactory
	@param userId number -- Player ID who owns this enemy (for dungeon isolation)
	@param enemyId string -- Unique ID for this enemy instance
	@param enemyType string -- Enemy archetype from EnemyConfig
	@param baseHP number -- Base HP from config
	@param baseATK number -- Base ATK from config
	@param baseDEF number -- Base DEF from config
	@param position Vector3 -- Initial spawn location
	@return any -- JECS entity ID
]=]
function NPCEntityFactory:CreateEnemy(
	userId: number,
	enemyId: string,
	enemyType: string,
	displayName: string,
	baseHP: number,
	baseATK: number,
	baseDEF: number,
	position: Vector3
): any
	local entity = self:_CreateBaseNPCEntity(baseHP, baseATK, baseDEF, position)
	local world = self.World :: any

	world:set(entity, self.Components.TeamComponent, {
		Team = "Enemy",
		UserId = userId,
	} :: TTeamComponent)

	world:set(entity, self.Components.NPCIdentityComponent, {
		NPCId = enemyId,
		NPCType = enemyType,
		DisplayName = displayName,
		IsAdventurer = false,
	} :: TNPCIdentityComponent)

	self:_InitSkillComponents(entity, enemyType, nil)

	world:add(entity, self.Components.EnemyTag)
	world:set(entity, self.Components.EntityTag, `Enemy:{enemyId}`)
	world:set(entity, JECS.Name, `Enemy:{enemyId}`)

	return entity
end

---
-- Component Mutations (Immutable pattern)
---

--[=[
	Assign a Roblox Model instance to an NPC entity and mark it dirty for sync.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param model Model -- R6 model instance
]=]
function NPCEntityFactory:SetModelRef(entity: any, model: Model)
	self.World:set(entity, self.Components.ModelRefComponent, {
		Instance = model,
	} :: TModelRefComponent)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Set the combat target entity for an NPC (for ability targeting and AI state).
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param targetEntity any? -- Target entity, or nil to clear
]=]
function NPCEntityFactory:SetTarget(entity: any, targetEntity: any?)
	local target = self.World:get(entity, self.Components.TargetComponent)
	if not target then
		return
	end

	local updated = table.clone(target)
	updated.TargetEntity = targetEntity

	self.World:set(entity, self.Components.TargetComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Set the action/combat state for an NPC (drives action animations: Attack, Dead).
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param state string -- Action state ("None", "Attacking", "Dead")
]=]
function NPCEntityFactory:SetActionState(entity: any, state: string)
	local combatState = self.World:get(entity, self.Components.CombatStateComponent)
	if not combatState then
		return
	end

	local updated = table.clone(combatState)
	updated.State = state

	self.World:set(entity, self.Components.CombatStateComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Set the movement/locomotion state for an NPC (Idle, Moving, Fleeing, Wandering).
	Server-side only; client animation is driven by Humanoid state.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param state string -- Locomotion state
]=]
function NPCEntityFactory:SetLocomotionState(entity: any, state: string)
	local locoState = self.World:get(entity, self.Components.LocomotionStateComponent)
	if not locoState then
		return
	end

	local updated = table.clone(locoState)
	updated.State = state

	self.World:set(entity, self.Components.LocomotionStateComponent, updated)
end

--[=[
	Apply damage to an NPC. On death (HP <= 0), removes AliveTag and sets state to Dead.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param damage number -- Damage amount
	@return number -- New HP after damage
]=]
function NPCEntityFactory:ApplyDamage(entity: any, damage: number): number
	local health = self.World:get(entity, self.Components.HealthComponent)
	if not health then
		return 0
	end

	-- Clamp damage result to 0 (never let HP go negative)
	local newHP = math.max(0, health.Current - damage)

	-- Update health component immutably
	local updated = table.clone(health)
	updated.Current = newHP
	self.World:set(entity, self.Components.HealthComponent, updated)

	if newHP <= 0 then
		-- NPC is dead: remove from alive entities and set death animation
		self.World:remove(entity, self.Components.AliveTag)
		self:SetActionState(entity, "Dead")
		self:SetLocomotionState(entity, "Idle")
	end

	-- Mark dirty for sync to models
	self.World:add(entity, self.Components.DirtyTag)
	return newHP
end

function NPCEntityFactory:ApplyHealing(entity: any, amount: number): number
	local health = self.World:get(entity, self.Components.HealthComponent)
	if not health then
		return 0
	end

	local newHP = math.clamp(health.Current + amount, 0, health.Max)
	local updated = table.clone(health)
	updated.Current = newHP

	self.World:set(entity, self.Components.HealthComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)

	return newHP
end

--[=[
	Update the position component from a model's current CFrame (read from Humanoid/SimplePath).
	No DirtyTag added to avoid infinite sync loops.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param cframe CFrame -- New position and orientation
]=]
function NPCEntityFactory:UpdatePosition(entity: any, cframe: CFrame)
	self.World:set(entity, self.Components.PositionComponent, {
		CFrame = cframe,
	} :: TPositionComponent)
	-- No DirtyTag: position is polled every Heartbeat from the model.
	-- Adding DirtyTag here would cause infinite sync loops.
end

--[=[
	Update the last attack timestamp for attack cooldown tracking.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param lastAttackTime number -- Unix timestamp of last attack
]=]
function NPCEntityFactory:UpdateAttackCooldown(entity: any, lastAttackTime: number)
	local cooldown = self.World:get(entity, self.Components.AttackCooldownComponent)
	if not cooldown then
		return
	end

	local updated = table.clone(cooldown)
	updated.LastAttackTime = lastAttackTime

	self.World:set(entity, self.Components.AttackCooldownComponent, updated)
end

--[=[
	Assign a behavior tree instance and set up tick interval for BT evaluation.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param treeInstance any -- BehaviorTree instance
	@param tickInterval number -- Seconds between BT ticks (randomized per NPC)
]=]
function NPCEntityFactory:SetBehaviorTree(entity: any, treeInstance: any, tickInterval: number)
	self.World:set(entity, self.Components.BehaviorTreeComponent, {
		TreeInstance = treeInstance,
		LastTickTime = os.clock(),
		TickInterval = tickInterval,
	} :: TBehaviorTreeComponent)
end

--[=[
	Set a custom behavior configuration for an NPC.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param config TBehaviorConfigComponent -- Behavior parameters
]=]
function NPCEntityFactory:SetBehaviorConfig(entity: any, config: TBehaviorConfigComponent)
	self.World:set(entity, self.Components.BehaviorConfigComponent, config)
end

--[=[
	Load and set a behavior configuration from BehaviorDefaults based on NPC type.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param npcType string -- NPC type to look up in BehaviorDefaults
]=]
function NPCEntityFactory:SetBehaviorConfigFromDefaults(entity: any, npcType: string)
	local config = BehaviorDefaults[npcType] or BehaviorDefaults.DEFAULT
	self.World:set(entity, self.Components.BehaviorConfigComponent, config)
end

--[=[
	Get the behavior configuration component for an NPC.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TBehaviorConfigComponent? -- Behavior config, or nil
]=]
function NPCEntityFactory:GetBehaviorConfig(entity: any): TBehaviorConfigComponent?
	return self.World:get(entity, self.Components.BehaviorConfigComponent)
end

--[[
    Update the BT last tick time.
]]
function NPCEntityFactory:UpdateBTLastTickTime(entity: any, time: number)
	local bt = self.World:get(entity, self.Components.BehaviorTreeComponent)
	if not bt then
		return
	end

	local updated = table.clone(bt)
	updated.LastTickTime = time

	self.World:set(entity, self.Components.BehaviorTreeComponent, updated)
end

---
-- Queries
---

-- Query all entities matching components and filtered to a specific user.
-- Prevents mixing players' NPCs in multi-user dungeon isolation.
function NPCEntityFactory:_QueryEntitiesForUser(userId: number, ...): { any }
	local results = {}
	for entity in self.World:query(...) do
		local team = self.World:get(entity, self.Components.TeamComponent)
		-- Check team component to ensure this entity belongs to the requested userId
		if team and team.UserId == userId then
			table.insert(results, entity)
		end
	end
	return results
end

--[=[
	Query all alive enemy entities for a specific user.
	@within NPCEntityFactory
	@param userId number -- Player ID
	@return { any } -- Array of enemy entity IDs
]=]
function NPCEntityFactory:QueryAliveEnemies(userId: number): { any }
	return self:_QueryEntitiesForUser(userId,
		self.Components.EnemyTag,
		self.Components.AliveTag,
		self.Components.TeamComponent
	)
end

--[=[
	Query all alive adventurer entities for a specific user.
	@within NPCEntityFactory
	@param userId number -- Player ID
	@return { any } -- Array of adventurer entity IDs
]=]
function NPCEntityFactory:QueryAliveAdventurers(userId: number): { any }
	return self:_QueryEntitiesForUser(userId,
		self.Components.AdventurerTag,
		self.Components.AliveTag,
		self.Components.TeamComponent
	)
end

--[=[
	Query all entities (alive and dead) for a specific user.
	@within NPCEntityFactory
	@param userId number -- Player ID
	@return { any } -- Array of all entity IDs
]=]
function NPCEntityFactory:QueryAllEntities(userId: number): { any }
	return self:_QueryEntitiesForUser(userId, self.Components.TeamComponent)
end

--[=[
	Query all alive entities (both teams) for a specific user.
	@within NPCEntityFactory
	@param userId number -- Player ID
	@return { any } -- Array of alive entity IDs
]=]
function NPCEntityFactory:QueryAliveEntities(userId: number): { any }
	return self:_QueryEntitiesForUser(userId,
		self.Components.AliveTag,
		self.Components.TeamComponent
	)
end

--[=[
	Get the identity component (NPCId, NPCType, IsAdventurer) for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TNPCIdentityComponent? -- Identity component, or nil
]=]
function NPCEntityFactory:GetIdentity(entity: any): TNPCIdentityComponent?
	return self.World:get(entity, self.Components.NPCIdentityComponent)
end

--[=[
	Get the health component (Current, Max) for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return THealthComponent? -- Health component, or nil
]=]
function NPCEntityFactory:GetHealth(entity: any): THealthComponent?
	return self.World:get(entity, self.Components.HealthComponent)
end

--[=[
	Get the stats component (ATK, DEF) for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TStatsComponent? -- Stats component, or nil
]=]
function NPCEntityFactory:GetStats(entity: any): TStatsComponent?
	return self.World:get(entity, self.Components.StatsComponent)
end

--[=[
	Get the position component (CFrame) for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TPositionComponent? -- Position component, or nil
]=]
function NPCEntityFactory:GetPosition(entity: any): TPositionComponent?
	return self.World:get(entity, self.Components.PositionComponent)
end

--[=[
	Get the combat state component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TCombatStateComponent? -- Combat state component, or nil
]=]
function NPCEntityFactory:GetCombatState(entity: any): TCombatStateComponent?
	return self.World:get(entity, self.Components.CombatStateComponent)
end

--[=[
	Get the locomotion state component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TLocomotionStateComponent? -- Locomotion state component, or nil
]=]
function NPCEntityFactory:GetLocomotionState(entity: any): TLocomotionStateComponent?
	return self.World:get(entity, self.Components.LocomotionStateComponent)
end

--[=[
	Get the behavior tree component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TBehaviorTreeComponent? -- Behavior tree component, or nil
]=]
function NPCEntityFactory:GetBehaviorTree(entity: any): TBehaviorTreeComponent?
	return self.World:get(entity, self.Components.BehaviorTreeComponent)
end

--[=[
	Get the detection component (radius, attack range) for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TDetectionComponent? -- Detection component, or nil
]=]
function NPCEntityFactory:GetDetection(entity: any): TDetectionComponent?
	return self.World:get(entity, self.Components.DetectionComponent)
end

--[=[
	Get the attack cooldown component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TAttackCooldownComponent? -- Attack cooldown component, or nil
]=]
function NPCEntityFactory:GetAttackCooldown(entity: any): TAttackCooldownComponent?
	return self.World:get(entity, self.Components.AttackCooldownComponent)
end

--[=[
	Get the team component (Team, UserId) for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TTeamComponent? -- Team component, or nil
]=]
function NPCEntityFactory:GetTeam(entity: any): TTeamComponent?
	return self.World:get(entity, self.Components.TeamComponent)
end

--[=[
	Get the target component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TTargetComponent? -- Target component, or nil
]=]
function NPCEntityFactory:GetTarget(entity: any): TTargetComponent?
	return self.World:get(entity, self.Components.TargetComponent)
end

--[=[
	Get the model reference component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TModelRefComponent? -- Model reference component, or nil
]=]
function NPCEntityFactory:GetModelRef(entity: any): TModelRefComponent?
	return self.World:get(entity, self.Components.ModelRefComponent)
end

--[=[
	Get the combat action component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TCombatActionComponent? -- Combat action component, or nil
]=]
function NPCEntityFactory:GetCombatAction(entity: any): TCombatActionComponent?
	return self.World:get(entity, self.Components.CombatActionComponent)
end

--[=[
	Get the weapon category component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TWeaponCategoryComponent? -- Weapon category component, or nil
]=]
function NPCEntityFactory:GetWeaponCategory(entity: any): TWeaponCategoryComponent?
	return self.World:get(entity, self.Components.WeaponCategoryComponent)
end

--[=[
	Find an entity by its NPCId for a given user.
	@within NPCEntityFactory
	@param userId number -- Player ID
	@param npcId string -- NPC ID to search for
	@return any? -- Entity ID, or nil if not found
]=]
function NPCEntityFactory:GetEntityByNPCId(userId: number, npcId: string): any?
	for entity in self.World:query(
		self.Components.NPCIdentityComponent,
		self.Components.TeamComponent
	) do
		local team = self.World:get(entity, self.Components.TeamComponent)
		local identity = self.World:get(entity, self.Components.NPCIdentityComponent)
		if team and team.UserId == userId and identity and identity.NPCId == npcId then
			return entity
		end
	end
	return nil
end

--[=[
	Queue a pending action to be started on the next action transition phase.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param actionId string -- Action identifier
	@param actionData { [string]: any }? -- Optional action parameters
]=]
function NPCEntityFactory:SetPendingAction(entity: any, actionId: string, actionData: { [string]: any }?)
	local actionComp = self.World:get(entity, self.Components.CombatActionComponent)
	if not actionComp then
		return
	end

	local updated = table.clone(actionComp)
	updated.PendingActionId = actionId
	updated.PendingActionData = actionData

	self.World:set(entity, self.Components.CombatActionComponent, updated)
end

--[=[
	Start an action on an entity (transition from pending to running/committed).
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param actionId string -- Action identifier
	@param actionData { [string]: any }? -- Action parameters
	@param currentTime number -- Current game time (os.clock())
	@param options { Committed: boolean?, Interruptible: boolean? }? -- Action flags
]=]
function NPCEntityFactory:StartAction(
	entity: any,
	actionId: string,
	actionData: { [string]: any }?,
	currentTime: number,
	options: { Committed: boolean?, Interruptible: boolean? }?
)
	local opts = options or {}
	self.World:set(entity, self.Components.CombatActionComponent, {
		CurrentActionId = actionId,
		PendingActionId = nil,
		ActionState = if opts.Committed then "Committed" else "Running",
		ActionStartTime = currentTime,
		ActionData = actionData,
		PendingActionData = nil,
		Interruptible = opts.Interruptible == true,
	} :: TCombatActionComponent)
end

--[=[
	Reset action state to idle when an action completes or is cancelled.
	Clears CombatActionComponent and resets combat/locomotion state.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
]=]
function NPCEntityFactory:ResetActionState(entity: any)
	self.World:set(entity, self.Components.CombatActionComponent, {
		CurrentActionId = nil,
		PendingActionId = nil,
		ActionState = "None",
		ActionStartTime = 0,
		ActionData = nil,
		PendingActionData = nil,
	} :: TCombatActionComponent)
	self:SetActionState(entity, "None")
	self:SetLocomotionState(entity, "Idle")
end

--[=[
	Clear the current action component (internal action cleanup).
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
]=]
function NPCEntityFactory:ClearAction(entity: any)
	local actionComp = self.World:get(entity, self.Components.CombatActionComponent)
	if not actionComp then
		return
	end

	self.World:set(entity, self.Components.CombatActionComponent, {
		CurrentActionId = nil,
		PendingActionId = nil,
		ActionState = "None",
		ActionStartTime = 0,
		ActionData = nil,
		PendingActionData = nil,
	} :: TCombatActionComponent)
end

--[=[
	Check if an entity is alive (has AliveTag).
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return boolean -- True if alive, false otherwise
]=]
function NPCEntityFactory:IsAlive(entity: any): boolean
	return self.World:has(entity, self.Components.AliveTag)
end

---
-- Player Command
---

--[=[
	Set a player-issued command on an NPC (move, attack, etc.).
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param commandType string -- Command type ("Move", "Attack", etc.)
	@param commandData { [string]: any }? -- Command parameters
]=]
function NPCEntityFactory:SetPlayerCommand(entity: any, commandType: string, commandData: { [string]: any }?)
	self.World:set(entity, self.Components.PlayerCommandComponent, {
		CommandType = commandType,
		CommandData = commandData,
		IssuedAt = os.clock(),
	} :: TPlayerCommandComponent)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Get the player command component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TPlayerCommandComponent? -- Player command component, or nil
]=]
function NPCEntityFactory:GetPlayerCommand(entity: any): TPlayerCommandComponent?
	return self.World:get(entity, self.Components.PlayerCommandComponent)
end

--[=[
	Clear the player command component from an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
]=]
function NPCEntityFactory:ClearPlayerCommand(entity: any)
	if self.World:has(entity, self.Components.PlayerCommandComponent) then
		self.World:remove(entity, self.Components.PlayerCommandComponent)
		self.World:add(entity, self.Components.DirtyTag)
	end
end

--[=[
	Promote an attack action from "Attacking" to "Committed" when the hitbox activates.
	After this point the action cannot be interrupted by a new pending action.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
]=]
function NPCEntityFactory:PromoteToCommitted(entity: any)
	local actionComp = self.World:get(entity, self.Components.CombatActionComponent)
	if not actionComp or actionComp.ActionState ~= "Running" then
		return
	end

	local updated = table.clone(actionComp)
	updated.ActionState = "Committed"
	self.World:set(entity, self.Components.CombatActionComponent, updated)
end

--[=[
	Set the control mode for an adventurer NPC. Called by CombatContext when the
	model's ControlMode attribute changes, keeping the ECS in sync without polling.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param mode "Auto" | "Manual"
]=]
function NPCEntityFactory:SetControlMode(entity: any, mode: "Auto" | "Manual")
	self.World:set(entity, self.Components.ControlModeComponent, {
		Mode = mode,
	} :: TControlModeComponent)
	if mode == "Auto" then
		self:ClearPlayerCommand(entity)
		self:SetTarget(entity, nil)
	end
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Get the control mode component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TControlModeComponent? -- Control mode component, or nil
]=]
function NPCEntityFactory:GetControlMode(entity: any): TControlModeComponent?
	return self.World:get(entity, self.Components.ControlModeComponent)
end

--[=[
	Set the block/parry state for an NPC.
	Clears the component when neither blocking nor parrying.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param isBlocking boolean
	@param isParrying boolean
	@param parryWindowEnd number? -- os.clock() timestamp when parry window closes (required if isParrying)
]=]
function NPCEntityFactory:SetBlockState(entity: any, isBlocking: boolean, isParrying: boolean, parryWindowEnd: number?)
	if not isBlocking and not isParrying then
		if self.World:has(entity, self.Components.BlockStateComponent) then
			self.World:remove(entity, self.Components.BlockStateComponent)
		end
		return
	end

	self.World:set(entity, self.Components.BlockStateComponent, {
		IsBlocking = isBlocking,
		IsParrying = isParrying,
		ParryWindowEnd = parryWindowEnd or 0,
	} :: TBlockStateComponent)
end

--[=[
	Get the block state component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TBlockStateComponent? -- Block state, or nil if not blocking/parrying
]=]
function NPCEntityFactory:GetBlockState(entity: any): TBlockStateComponent?
	return self.World:get(entity, self.Components.BlockStateComponent)
end

--[=[
	Store AlignOrientation constraint refs on an NPC entity.
	Called once by LockOnService after the constraint is created for the model.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param component TLockOnComponent
]=]
function NPCEntityFactory:SetLockOn(entity: any, component: TLockOnComponent)
	self.World:set(entity, self.Components.LockOnComponent, component)
end

--[=[
	Get the lock-on component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TLockOnComponent? -- Lock-on component, or nil
]=]
function NPCEntityFactory:GetLockOn(entity: any): TLockOnComponent?
	return self.World:get(entity, self.Components.LockOnComponent)
end

---
-- Skills
---

--[=[
	Initialise skill components on a newly created entity.
	Merges innate skills (from SkillSetConfig keyed by npcType) with equipment skills
	(from WeaponCategoryConfig[weaponCategory].Skills) and sets both SkillSetComponent
	and SkillCooldownsComponent on the entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param npcType string -- "Warrior", "Goblin", etc.
	@param weaponCategory string? -- Optional weapon category for equipment skill merging
]=]
function NPCEntityFactory:_InitSkillComponents(entity: any, npcType: string, weaponCategory: string?)
	local innateSet = SkillSetConfig[npcType] or SkillSetConfig.DEFAULT
	local skills: { string } = {}

	for _, skillId in innateSet.Skills do
		table.insert(skills, skillId)
	end

	if weaponCategory then
		local weaponProfile = WeaponCategoryConfig[weaponCategory]
		if weaponProfile and weaponProfile.Skills then
			for _, skillId in weaponProfile.Skills do
				-- Avoid duplicates
				local found = false
				for _, existing in skills do
					if existing == skillId then
						found = true
						break
					end
				end
				if not found then
					table.insert(skills, skillId)
				end
			end
		end
	end

	self.World:set(entity, self.Components.SkillSetComponent, {
		Skills = skills,
	} :: TSkillSetComponent)

	self.World:set(entity, self.Components.SkillCooldownsComponent, {
		ReadyAt = {},
	} :: TSkillCooldownsComponent)
end

--[=[
	Get the skill set component for an entity.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@return TSkillSetComponent? -- Skill set component, or nil
]=]
function NPCEntityFactory:GetSkillSet(entity: any): TSkillSetComponent?
	return self.World:get(entity, self.Components.SkillSetComponent)
end

--[=[
	Check whether a specific skill is off cooldown for an entity.
	Returns true if the entity has no cooldown record for the skill or the cooldown has expired.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param skillId string -- Skill identifier matching a SkillConfig key
	@return boolean -- True if the skill can be used
]=]
function NPCEntityFactory:IsSkillReady(entity: any, skillId: string): boolean
	local cooldowns = self.World:get(entity, self.Components.SkillCooldownsComponent)
	if not cooldowns then
		return true
	end
	local readyAt = cooldowns.ReadyAt[skillId]
	return readyAt == nil or os.clock() >= readyAt
end

--[=[
	Record that a skill was just used, starting its independent cooldown timer.
	The skill will become ready again after `cooldown` seconds.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID
	@param skillId string -- Skill identifier
	@param cooldown number -- Duration in seconds before the skill is ready again
]=]
function NPCEntityFactory:SetSkillCooldown(entity: any, skillId: string, cooldown: number)
	local existing = self.World:get(entity, self.Components.SkillCooldownsComponent)
	local updated = if existing then table.clone(existing) else { ReadyAt = {} }
	updated.ReadyAt = table.clone(updated.ReadyAt)
	updated.ReadyAt[skillId] = os.clock() + cooldown
	self.World:set(entity, self.Components.SkillCooldownsComponent, updated :: TSkillCooldownsComponent)
end

---
-- Deletion
---

--[=[
	Delete an NPC entity from the JECS world.
	Note: Model cleanup should happen before calling this.
	@within NPCEntityFactory
	@param entity any -- JECS entity ID to delete
]=]
function NPCEntityFactory:DeleteEntity(entity: any)
	self.World:delete(entity)
end

return NPCEntityFactory

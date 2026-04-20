--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess
local Catch = Result.Catch
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)
local NPCTypes = require(ReplicatedStorage.Contexts.NPC.Types.NPCTypes)
local WeaponCategoryConfig = require(ReplicatedStorage.Contexts.Combat.Config.WeaponCategoryConfig)

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices
type TNPCIdentityComponent = NPCTypes.TNPCIdentityComponent

--[=[
	@class ProcessCombatTick
	Application command that executes one combat frame for a user.

	Called every Heartbeat by the Planck scheduler via `CombatContext`.
	Each phase is isolated with its own `Catch` boundary so a single entity
	failure does not halt processing for the rest of the session.

	Phase order:
	1. **BT Tick** — policy-gated per entity, staggered by tick interval
	2. **Action Transition** — cancel current, start pending action
	3. **Action Tick** — run active actions, handle completion
	4. **Dead-entity sweep** — cancel hitboxes on entities that died this frame
	5. **Event flush** — send batched events to the owning player
	6. **Wave/Party check** — emit `WaveComplete` or `AllAdventurersDead`
	@server
]=]
local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick

export type TProcessCombatTick = typeof(setmetatable({}, ProcessCombatTick))

function ProcessCombatTick.new(): TProcessCombatTick
	return setmetatable({}, ProcessCombatTick)
end

function ProcessCombatTick:Init(registry: any, _name: string)
	self.Registry = registry
	self.DamageCalculator = registry:Get("DamageCalculator")
	self.TargetSelector = registry:Get("TargetSelector")
	self.ExecutorRegistry = registry:Get("ExecutorRegistry")
	self.CombatPerceptionService = registry:Get("CombatPerceptionService")
	self.HitboxService = registry:Get("HitboxService")
	self.BehaviorTreeTickPolicy = registry:Get("BehaviorTreeTickPolicy")
	self.WaveCompletionPolicy = registry:Get("WaveCompletionPolicy")
	self.OnFlushEvents = nil :: ((userId: number, events: { any }) -> ())?
end

function ProcessCombatTick:Start()
	self.NPCEntityFactory = self.Registry:Get("NPCEntityFactory")
	self.World = self.Registry:Get("World")
	self.Components = self.Registry:Get("Components")
	self.DungeonContext = self.Registry:Get("DungeonContext")
end

--[=[
	Process one combat frame for a user.
	@within ProcessCombatTick
	@param userId number
	@param deltaTime number -- Seconds since the last frame
]=]
function ProcessCombatTick:Execute(userId: number, deltaTime: number)
	local currentTime = os.clock()
	local aliveEntities = self.NPCEntityFactory:QueryAliveEntities(userId)
	local actionServices = self:_BuildActionServices(userId, currentTime)

	-- Phase 1: Behavior tree ticks
	-- Policy-gated by tick interval; entities only tick if enough time has passed
	for _, entity in ipairs(aliveEntities) do
		Catch(function()
			return self:_TickBehaviorTree(entity, userId, currentTime)
		end, "Combat:ProcessCombatTick:BTTick")
	end

	-- Phase 2: Action transitions
	-- Process pending action swaps; cancel current and start pending if eligible
	for _, entity in ipairs(aliveEntities) do
		Catch(function()
			return self:_ProcessActionTransition(entity, actionServices)
		end, "Combat:ProcessCombatTick:ActionTransition")
	end

	-- Phase 3: Action execution
	-- Tick all running actions; fire completion handlers on terminal state (Success/Fail)
	for _, entity in ipairs(aliveEntities) do
		Catch(function()
			return self:_ProcessActionTick(entity, deltaTime, actionServices)
		end, "Combat:ProcessCombatTick:ActionTick")
	end

	-- Phase 4: Dead-entity cleanup
	-- Cancel hitboxes from entities that died before Phase 3 ran but are in the alive list
	self:_CancelActionsOnDeadEntities(userId, actionServices)

	-- Phase 5: Event flush
	-- Send all Damaged/Died events from this frame to the owning player
	if #actionServices.EventBuffer > 0 and self.OnFlushEvents then
		self.OnFlushEvents(userId, actionServices.EventBuffer)
	end

	-- Phase 6: Completion checks
	-- Emit WaveComplete or AllAdventurersDead if conditions met
	self:_CheckWaveCompletion(userId)
end

function ProcessCombatTick:_BuildActionServices(userId: number, currentTime: number): TActionServices
	return {
		NPCEntityFactory = self.NPCEntityFactory,
		DamageCalculator = self.DamageCalculator,
		HitboxService = self.HitboxService,
		World = self.World,
		Components = self.Components,
		CurrentTime = currentTime,
		EventBuffer = {},
		DungeonContext = self.DungeonContext,
		UserId = userId,
	}
end

-- Check if entity's behavior tree tick interval has elapsed, then run BT or resolve player command.
function ProcessCombatTick:_TickBehaviorTree(entity: Entity, userId: number, currentTime: number)
	-- Policy gates ticks by interval; skips if not enough time has passed since last tick
	local policyResult = self.BehaviorTreeTickPolicy:Check(entity, currentTime)
	if not policyResult.success then
		return
	end

	local ctx = policyResult.value
	-- Manual mode adventurers execute player commands instead of their behavior tree
	if ctx.IsManualAdventurer and ctx.PlayerCommand then
		self:_ResolvePlayerCommand(entity, ctx.PlayerCommand, userId)
	elseif ctx.BehaviorTree then
		self:_RunBehaviorTree(entity, ctx.BehaviorTree, currentTime)
	end
end

-- Execute one behavior tree tick with full perception context (facts snapshot).
function ProcessCombatTick:_RunBehaviorTree(entity: Entity, bt: any, currentTime: number)
	-- Build perception snapshot (targets, nearby enemies, self state, etc.)
	local perceptionContext = {
		Entity = entity,
		PerceptionService = self.CombatPerceptionService,
		NPCEntityFactory = self.NPCEntityFactory,
		World = self.World,
		Components = self.Components,
		CurrentTime = currentTime,
		Facts = self.CombatPerceptionService:BuildSnapshot(entity, currentTime),
	}

	-- Run the BT instance; guard with pcall to prevent tree errors from stopping the tick
	pcall(function()
		bt.TreeInstance:run(perceptionContext)
	end)

	-- Record when this entity last ticked for interval gating on next frame
	self.NPCEntityFactory:UpdateBTLastTickTime(entity, currentTime)
end

--- @within ProcessCombatTick
--- @private
function ProcessCombatTick:_CancelActionsOnDeadEntities(userId: number, actionServices: TActionServices)
	-- Catches any NPC that died this tick (or between ticks) while holding an active hitbox.
	-- aliveEntities was snapped at the start of the frame, so any NPC that died during
	-- Phase 3 is still in the list and their executor already returned "Fail" (Layer 1).
	-- This sweep handles NPCs that died *before* Phase 3 ran (killed in a previous frame
	-- but whose Cancel was never called because they left the alive list).
	local allEntities = self.NPCEntityFactory:QueryAllEntities(userId)
	for _, entity in ipairs(allEntities) do
		if not self.NPCEntityFactory:IsAlive(entity) then
			self:_CancelAndClearAction(entity, actionServices)
		end
	end
end

--- @within ProcessCombatTick
--- @private
function ProcessCombatTick:_CancelAndClearAction(entity: Entity, actionServices: TActionServices)
	local actionComp = self.NPCEntityFactory:GetCombatAction(entity)
	-- Always cancel if a CurrentActionId is recorded, even if ActionState was already
	-- reset to "None" — the executor may still hold per-entity state (e.g. _EntityState
	-- in attack executors) that must be cleaned up to avoid memory leaks.
	if not actionComp or not actionComp.CurrentActionId then
		return
	end

	local currentAction = self.ExecutorRegistry:Get(actionComp.CurrentActionId)
	if currentAction then
		pcall(function()
			currentAction:Cancel(entity, actionServices)
		end)
	end
	self.NPCEntityFactory:ClearAction(entity)
end

--- @within ProcessCombatTick
--- @private
function ProcessCombatTick:_CheckWaveCompletion(userId: number)
	local completionResult = self.WaveCompletionPolicy:Check(userId)

	if completionResult.Status == "WaveComplete" then
		GameEvents.Bus:Emit(Events.Combat.WaveComplete, userId)
	elseif completionResult.Status == "PartyWiped" then
		GameEvents.Bus:Emit(Events.Combat.AllAdventurersDead, userId)
	end
end

--- @within ProcessCombatTick
--- @private
function ProcessCombatTick:_ResolvePlayerCommand(entity: Entity, cmdComp: any, userId: number)
	local ct = cmdComp.CommandType
	local cd = cmdComp.CommandData

	-- AttackTarget and AttackNearest are persistent targeting commands: they are NOT
	-- cleared after execution so that the Manual-mode path re-evaluates them every tick
	-- (Chase while out of range, WeaponAttack once in range — mirroring Auto BT behaviour).
	-- All other commands are one-shots that clear immediately after being dispatched.
	local isPersistent = ct == "AttackTarget" or ct == "AttackNearest"

	if ct == "HoldPosition" then
		self.NPCEntityFactory:SetPendingAction(entity, "Idle", nil)
	elseif ct == "AttackNearest" then
		self:_ResolveAttackNearest(entity, userId)
	elseif ct == "MoveToPosition" then
		self.NPCEntityFactory:SetPendingAction(entity, "MoveToPosition", cd)
	elseif ct == "AttackTarget" then
		self:_ResolveAttackTarget(entity, cd)
	elseif ct == "Block" then
		self.NPCEntityFactory:SetPendingAction(entity, "Block", nil)
	elseif ct == "Parry" then
		self.NPCEntityFactory:SetPendingAction(entity, "Parry", nil)
	elseif ct == "UseSkill" then
		local skillId = cd and cd.SkillId
		if skillId then
			self.NPCEntityFactory:SetPendingAction(entity, skillId, {
				TargetEntity = cd.TargetEntity,
			})
		end
	end

	if not isPersistent then
		self.NPCEntityFactory:ClearPlayerCommand(entity)
	end
end

--- @within ProcessCombatTick
--- @private
function ProcessCombatTick:_ResolveAttackNearest(entity: Entity, userId: number)
	local aliveEnemies = self.NPCEntityFactory:QueryAliveEnemies(userId)
	if #aliveEnemies == 0 then
		return
	end

	local nearest = self:_FindNearestEnemy(entity, aliveEnemies)
	if not nearest then
		return
	end

	self.NPCEntityFactory:SetTarget(entity, nearest)
	self:_QueueAttackOrChase(entity, nearest)
end

--- @within ProcessCombatTick
--- @private
function ProcessCombatTick:_ResolveAttackTarget(entity: Entity, cd: any)
	local targetNPCId = cd and cd.TargetNPCId
	if not targetNPCId then
		return
	end

	local team = self.NPCEntityFactory:GetTeam(entity)
	local targetUserId = team and team.UserId or 0
	local targetEntity = self.NPCEntityFactory:GetEntityByNPCId(targetUserId, targetNPCId)
	if not targetEntity or not self.NPCEntityFactory:IsAlive(targetEntity) then
		return
	end

	self.NPCEntityFactory:SetTarget(entity, targetEntity)
	self:_QueueAttackOrChase(entity, targetEntity)
end

--- @within ProcessCombatTick
--- @private
-- Queues WeaponAttack if entity is in attack range, otherwise queues Chase.
-- Mirrors the Auto BT path (InAttackRangeCondition → WeaponAttack vs Chase).
function ProcessCombatTick:_QueueAttackOrChase(entity: Entity, targetEntity: Entity)
	local behaviorConfig = self.NPCEntityFactory:GetBehaviorConfig(entity)
	local myPos = self.NPCEntityFactory:GetPosition(entity)
	local targetPos = self.CombatPerceptionService:GetTargetPosition(targetEntity)

	if behaviorConfig and myPos and targetPos then
		local dist = (targetPos - myPos.CFrame.Position).Magnitude
		if dist <= behaviorConfig.AttackEnterRange then
			local weaponComp = self.NPCEntityFactory:GetWeaponCategory(entity)
			local category = weaponComp and weaponComp.Category or "Punch"
			local profile = WeaponCategoryConfig[category] or WeaponCategoryConfig.Punch
			self.NPCEntityFactory:SetPendingAction(entity, profile.ActionId, { TargetEntity = targetEntity })
			return
		end
	end

	self.NPCEntityFactory:SetPendingAction(entity, "Chase", {
		TargetEntity = targetEntity,
		MoveTarget = targetPos,
	})
end

function ProcessCombatTick:_FindNearestEnemy(entity: Entity, aliveEnemies: { Entity }): Entity?
	local modelRef = self.NPCEntityFactory:GetModelRef(entity)
	if not modelRef or not modelRef.Instance or not modelRef.Instance.PrimaryPart then
		return nil
	end
	local myPos = modelRef.Instance.PrimaryPart.Position

	local nearest: Entity? = nil
	local nearestDist = math.huge
	for _, enemy in ipairs(aliveEnemies) do
		local enemyRef = self.NPCEntityFactory:GetModelRef(enemy)
		if enemyRef and enemyRef.Instance and enemyRef.Instance.PrimaryPart then
			local dist = (enemyRef.Instance.PrimaryPart.Position - myPos).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = enemy
			end
		end
	end

	return nearest
end

-- Handle action queue: if a new action was queued (PendingActionId set), process the transition.
function ProcessCombatTick:_ProcessActionTransition(entity: Entity, services: TActionServices)
	local actionComp = self.NPCEntityFactory:GetCombatAction(entity)
	if not actionComp then
		return
	end

	local pendingId = actionComp.PendingActionId
	if not pendingId then
		return
	end

	-- Same action re-queued: update data (e.g., new chase target) and continue
	if pendingId == actionComp.CurrentActionId then
		self:_ResolveSameActionPending(entity, actionComp)
		return
	end

	-- Current action is committed (cannot be interrupted): discard pending and keep running
	if actionComp.ActionState == "Committed" then
		self:_ClearPending(entity, actionComp)
		return
	end

	-- Transition to new action: cancel current, start pending
	self:_TransitionToNewAction(entity, actionComp, pendingId, services)
end

-- Same action re-queued: update ActionData (e.g., new chase target) and clear pending flag.
function ProcessCombatTick:_ResolveSameActionPending(entity: Entity, actionComp: any)
	local updated = table.clone(actionComp)
	-- If new data was provided, update it (e.g., new chase target position)
	if actionComp.PendingActionData then
		updated.ActionData = actionComp.PendingActionData
	end
	-- Clear pending flags so next frame doesn't see a queued action
	updated.PendingActionId = nil
	updated.PendingActionData = nil
	self.World:set(entity, self.Components.CombatActionComponent, updated)
end

-- Current action is committed and cannot be interrupted: discard the pending action.
function ProcessCombatTick:_ClearPending(entity: Entity, actionComp: any)
	local updated = table.clone(actionComp)
	updated.PendingActionId = nil
	updated.PendingActionData = nil
	self.World:set(entity, self.Components.CombatActionComponent, updated)
end

--- @within ProcessCombatTick
--- @private
function ProcessCombatTick:_TransitionToNewAction(
	entity: Entity,
	actionComp: any,
	pendingId: string,
	services: TActionServices
)
	-- Cancel current action if one is running
	if actionComp.CurrentActionId and actionComp.ActionState ~= "None" then
		local currentAction = self.ExecutorRegistry:Get(actionComp.CurrentActionId)
		if currentAction then
			pcall(function()
				currentAction:Cancel(entity, services)
			end)
		end
	end

	local pendingAction = self.ExecutorRegistry:Get(pendingId)
	if not pendingAction then
		self.NPCEntityFactory:ClearAction(entity)
		return
	end

	local ok, actionStarted = pcall(function()
		return pendingAction:Start(entity, actionComp.PendingActionData, services)
	end)

	if not ok or not actionStarted then
		self.NPCEntityFactory:ClearAction(entity)
		return
	end

	self.NPCEntityFactory:StartAction(
		entity,
		pendingId,
		actionComp.PendingActionData,
		services.CurrentTime,
		{ Committed = pendingAction.Config.IsCommitted, Interruptible = pendingAction.Config.IsInterruptible }
	)

	local identity: TNPCIdentityComponent? = self.NPCEntityFactory:GetIdentity(entity)
	local npcLabel: string
	if identity then
		npcLabel = identity.NPCType .. "_" .. identity.NPCId
	else
		npcLabel = tostring(entity)
	end
	MentionSuccess(
		"Combat:ProcessCombatTick:ActionTransition",
		"[NPC:" .. npcLabel .. "] " .. (actionComp.CurrentActionId or "None") .. " -> " .. pendingId
	)
end

-- Tick the active action; if it completes, call Complete and reset state.
function ProcessCombatTick:_ProcessActionTick(entity: Entity, deltaTime: number, services: TActionServices)
	local actionComp = self.NPCEntityFactory:GetCombatAction(entity)
	if not actionComp then
		return
	end

	-- Only tick actions in Running or Committed state (not "None" or other states)
	if actionComp.ActionState ~= "Running" and actionComp.ActionState ~= "Committed" then
		return
	end

	-- Get the executor for the active action
	local currentAction = self.ExecutorRegistry:Get(actionComp.CurrentActionId)
	if not currentAction then
		self.NPCEntityFactory:ClearAction(entity)
		return
	end

	-- Call Tick on the executor; pcall to protect against executor errors
	local ok, result = pcall(function()
		return currentAction:Tick(entity, deltaTime, services)
	end)

	-- If executor errored, clear and bail
	if not ok then
		self.NPCEntityFactory:ClearAction(entity)
		return
	end

	-- If action completed (Success or Fail), fire completion handler and reset state
	if result == "Success" or result == "Fail" then
		pcall(function()
			currentAction:Complete(entity, services)
		end)

		local identity = self.NPCEntityFactory:GetIdentity(entity)
		local npcLabel = identity and (identity.NPCType .. "_" .. identity.NPCId) or tostring(entity)
		MentionSuccess(
			"Combat:ProcessCombatTick:ActionTick",
			"[NPC:" .. npcLabel .. "] " .. actionComp.CurrentActionId .. " -> " .. result
		)

		self.NPCEntityFactory:ResetActionState(entity)
	end
	-- result == "Running" → action continues next frame; do nothing
end

return ProcessCombatTick

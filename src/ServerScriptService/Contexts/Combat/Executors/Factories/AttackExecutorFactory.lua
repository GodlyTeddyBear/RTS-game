--!strict

--[[
	AttackExecutorFactory - Produces committed attack executor classes.

	All attack executors share identical logic: validate target alive,
	check cooldown, set Attacking state, then wait for the client to
	signal hitbox activation via an animation callback before spawning
	the hitbox and checking for hits.

	Flow:
	  Start()          → validate target/cooldown → set Attacking state (NO hitbox yet)
	  ActivateHitbox() → called by CombatContext when client sends animation callback
	                     → spawns hitbox via HitboxService
	  Tick()           → if hitbox not activated, wait for callback
	                   → on timeout, attempt server fallback activation once
	                   → fallback failure → "Fail"
	                   → if hitbox active, check HitboxService:DidHitTarget()
	                     → YES: apply damage via _ExecuteAttackTick → "Success"
	                     → NO + within MaxDuration: → "Running"
	                     → NO + past MaxDuration: → "Fail" (whiff)
	  Complete()/Cancel() → destroy hitbox

	Usage:
		local MeleeAttackExecutor = AttackExecutorFactory({ ActionId = "MeleeAttack" })
		local RangedAttackExecutor = AttackExecutorFactory({ ActionId = "RangedAttack" })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseExecutor = require(script.Parent.Parent.Base.BaseExecutor)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)
local HitboxConfig = require(ReplicatedStorage.Contexts.Combat.Config.HitboxConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionError = Result.MentionError
local MentionSuccess = Result.MentionSuccess

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices

type TAttackExecutorConfig = {
	ActionId: string,
	DamageMultiplier: number?,
	IsInterruptible: boolean?, -- Default false: taking damage won't cancel this attack's animation
	ActivationTimeout: number?, -- Optional override for callback wait time
}

local function AttackExecutorFactory(config: TAttackExecutorConfig)
	local Executor = setmetatable({}, { __index = BaseExecutor })
	Executor.__index = Executor

	type THitboxActivationResult = {
		success: boolean,
		reason: string,
		source: string,
	}

	type TPerEntityState = {
		HitboxHandle: any?,
		HitboxStartTime: number?,
		HitboxActivated: boolean,
		HitLanded: boolean,
		AttackStartTime: number,
		MaxDuration: number,
		ActivationTimedOut: boolean,
	}

	-- Max time to wait for client marker callback before server fallback activation.
	local ACTIVATION_TIMEOUT = config.ActivationTimeout or 2

	function Executor.new()
		local self = BaseExecutor.new({
			ActionId = config.ActionId,
			IsCommitted = false, -- Starts as Running (interruptible); promoted to Committed on ActivateHitbox
			Duration = nil,
			IsInterruptible = if config.IsInterruptible == true then true else false,
		})
		self._EntityState = {} :: { [any]: TPerEntityState }
		return setmetatable(self :: any, Executor)
	end

	local function _getAttackerLabel(npc: any, entity: Entity): string
		local identity = npc:GetIdentity(entity)
		return identity and (identity.NPCType .. "_" .. identity.NPCId) or tostring(entity)
	end

	local function _destroyHitboxIfPresent(services: TActionServices, hitboxHandle: any?)
		if hitboxHandle then
			services.HitboxService:DestroyHitbox(hitboxHandle)
		end
	end

	local function _activationResult(success: boolean, reason: string, source: string): THitboxActivationResult
		return {
			success = success,
			reason = reason,
			source = source,
		}
	end

	local function _activateHitboxInternal(
		self: any,
		entity: Entity,
		services: TActionServices,
		reason: string
	): THitboxActivationResult
		local npc = services.NPCEntityFactory
		local attacker = _getAttackerLabel(npc, entity)
		local state = self._EntityState[entity]

		if not state then
			MentionError("Combat:Attack:ActivateHitbox", "Rejected — no entity state", {
				action = config.ActionId,
				attacker = attacker,
				source = reason,
			}, "MissingEntityState")
			return _activationResult(false, "MissingEntityState", reason)
		end

		if state.HitboxActivated then
			MentionError("Combat:Attack:ActivateHitbox", "Rejected — already activated", {
				action = config.ActionId,
				attacker = attacker,
				source = reason,
			}, "AlreadyActivated")
			return _activationResult(false, "AlreadyActivated", reason)
		end

		local hitboxCfg = HitboxConfig[config.ActionId]
		if not hitboxCfg then
			MentionError("Combat:Attack:ActivateHitbox", "Rejected — missing HitboxConfig", {
				action = config.ActionId,
				attacker = attacker,
				source = reason,
			}, "MissingHitboxConfig")
			return _activationResult(false, "MissingHitboxConfig", reason)
		end

		local hitboxResult = services.HitboxService:CreateAttackHitbox(entity, hitboxCfg)
		if not hitboxResult.success then
			MentionError("Combat:Attack:ActivateHitbox", "Rejected — hitbox creation failed", {
				action = config.ActionId,
				attacker = attacker,
				source = reason,
				failureReason = hitboxResult.reason,
			}, hitboxResult.reason or "HitboxCreationFailed")
			return _activationResult(false, hitboxResult.reason or "HitboxCreationFailed", reason)
		end

		local handle = hitboxResult.handle
		state.HitboxHandle = handle
		state.HitboxStartTime = services.CurrentTime
		state.HitboxActivated = true

		-- Promote ActionState from "Running" to "Committed" once hitbox is live.
		npc:PromoteToCommitted(entity)
		return _activationResult(true, "Activated", reason)
	end

	function Executor:Start(
		entity: Entity,
		actionData: { [string]: any }?,
		services: TActionServices
	): (boolean, string?)
		if not actionData or not actionData.TargetEntity then
			return false, "No target entity for " .. config.ActionId
		end

		local npc = services.NPCEntityFactory
		local targetEntity: Entity = actionData.TargetEntity

		if not npc:IsAlive(targetEntity) then
			return false, "Target is not alive"
		end

		local cooldown = npc:GetAttackCooldown(entity)
		if cooldown and (services.CurrentTime - cooldown.LastAttackTime < cooldown.Cooldown) then
			return false, "Attack on cooldown"
		end

		-- Validate hitbox config exists (but do NOT spawn hitbox yet — wait for client callback)
		local hitboxCfg = HitboxConfig[config.ActionId]
		if not hitboxCfg then
			return false, "No hitbox config for " .. config.ActionId
		end

		self._EntityState[entity] = {
			HitboxHandle = nil,
			HitboxStartTime = nil,
			HitboxActivated = false,
			HitLanded = false,
			AttackStartTime = services.CurrentTime,
			MaxDuration = hitboxCfg.MaxDuration,
			ActivationTimedOut = false,
		}

		-- CombatStateComponent = "Attacking" (drives animation)
		-- CombatActionComponent.ActionState = "Running" (interruptible until hitbox activates)
		npc:SetActionState(entity, "Attacking")
		npc:SetTarget(entity, targetEntity)

		return true, nil
	end

	--[[
	    Called by CombatContext when the client sends an AnimationCallback
	    with callbackType "ActivateHitbox". Spawns the hitbox.
	    Returns true if activation succeeded, false if already activated or invalid.
	]]
	function Executor:ActivateHitbox(entity: Entity, services: TActionServices): THitboxActivationResult
		return _activateHitboxInternal(self, entity, services, "AnimationCallback")
	end

	function Executor:TryActivateHitboxFromTimeout(entity: Entity, services: TActionServices): THitboxActivationResult
		return _activateHitboxInternal(self, entity, services, "ServerTimeoutFallback")
	end

	function Executor:Tick(entity: Entity, _: number, services: TActionServices): string
		local state = self._EntityState[entity]
		if not state then
			return "Fail"
		end

		local npc = services.NPCEntityFactory

		-- Failsafe: if the attacker died mid-attack, abort immediately
		if not npc:IsAlive(entity) then
			return "Fail"
		end

		-- Get target from action data
		local actionComp = npc:GetCombatAction(entity)
		if not actionComp or not actionComp.ActionData then
			return "Fail"
		end

		local targetEntity = actionComp.ActionData.TargetEntity
		if not targetEntity then
			return "Fail"
		end

		local identity = npc:GetIdentity(entity)
		local attacker = identity and (identity.NPCType .. "_" .. identity.NPCId) or tostring(entity)

		-- If callback did not activate hitbox in time, fallback to server activation once.
		if not state.HitboxActivated then
			local waitedSeconds = services.CurrentTime - state.AttackStartTime
			if waitedSeconds > ACTIVATION_TIMEOUT and not state.ActivationTimedOut then
				state.ActivationTimedOut = true

				local activationResult = self:TryActivateHitboxFromTimeout(entity, services)
				if not activationResult.success then
					MentionError("Combat:Attack:Tick", "Server fallback activation failed", {
						action = config.ActionId,
						attacker = attacker,
						failureReason = activationResult.reason,
						source = activationResult.source,
					}, activationResult.reason)
					return "Fail"
				end
			end
			return "Running"
		end

		-- Hitbox is active — apply damage once when the hit is confirmed
		if
			not state.HitLanded
			and state.HitboxHandle
			and services.HitboxService:DidHitTarget(state.HitboxHandle, targetEntity)
		then
			local result = self:_ExecuteAttackTick(entity, services, config.ActionId, config.DamageMultiplier)
			if result == "Success" then
				state.HitLanded = true
				-- Keep hitbox active until MaxDuration elapses.
				MentionSuccess("Combat:Attack:Tick", "Hit confirmed", {
					action = config.ActionId,
					attacker = attacker,
				})
			elseif result == "Fail" then
				return "Fail"
			end
		end

		-- Hold "Running" until MaxDuration expires so the attack animation finishes
		if state.HitboxStartTime and (services.CurrentTime - state.HitboxStartTime) > state.MaxDuration then
			_destroyHitboxIfPresent(services, state.HitboxHandle)
			state.HitboxHandle = nil
			return if state.HitLanded then "Success" else "Fail"
		end

		return "Running"
	end

	local function _clearEntityState(self: any, entity: Entity, services: TActionServices)
		local state = self._EntityState[entity]
		if state then
			_destroyHitboxIfPresent(services, state.HitboxHandle)
		end
		self._EntityState[entity] = nil
	end

	function Executor:Complete(entity: Entity, services: TActionServices)
		_clearEntityState(self, entity, services)
	end

	function Executor:Cancel(entity: Entity, services: TActionServices)
		_clearEntityState(self, entity, services)
	end

	return Executor
end

return AttackExecutorFactory

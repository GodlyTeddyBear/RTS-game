--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)
local HitboxConfig = require(ReplicatedStorage.Contexts.Combat.Config.HitboxConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local ACTIVATION_TIMEOUT_SECONDS = 0.35
local FLOW_CURSOR_KEY = "AttackBaseFlow"
local HITBOX_QUEUE_KEY = "AttackBaseHitboxActivation"
local HITBOX_QUEUE_CAPACITY = 8

type THitboxActivationResult = {
	success: boolean,
	reason: string,
	source: string,
}

--[=[
	@class AttackBaseExecutor
	Drives enemy base attacks, hitbox activation, and cleanup for the combat behavior tree.
	@server
]=]
local AttackBaseExecutor = {}
AttackBaseExecutor.__index = AttackBaseExecutor
setmetatable(AttackBaseExecutor, BaseExecutor)

--[=[
	@within AttackBaseExecutor
	Creates a combat executor configured to attack the base target.
	@return AttackBaseExecutor -- Executor instance used by the behavior tree.
]=]
function AttackBaseExecutor.new()
	local self = BaseExecutor.new({
		ActionId = "AttackBase",
		IsCommitted = false,
	})
	return setmetatable(self, AttackBaseExecutor)
end

-- Converts an activation attempt into a stable result payload for the runtime.
local function _activationResult(success: boolean, reason: string, source: string): THitboxActivationResult
	return {
		success = success,
		reason = reason,
		source = source,
	}
end

local function _mentionExecutorMilestone(label: string, message: string, entity: number, services: any, extra: { [string]: any }?)
	local payload = {
		Entity = entity,
		CurrentTime = services.CurrentTime,
	}

	local modelRef = services.EnemyEntityFactory:GetModelRef(entity)
	if modelRef ~= nil and modelRef.Model ~= nil then
		payload.Model = modelRef.Model:GetFullName()
	end

	if extra ~= nil then
		for key, value in pairs(extra) do
			payload[key] = value
		end
	end

	Result.MentionEvent(label, message, payload)
end

local function _mentionExecutorStateChange(
	self: any,
	entity: number,
	services: any,
	key: string,
	value: string,
	message: string,
	extra: { [string]: any }?
)
	if self:GetEntityValue(entity, key) == value then
		return
	end

	self:SetEntityValue(entity, key, value)
	_mentionExecutorMilestone("Enemy:AttackBaseExecutor", message, entity, services, extra)
end

-- Records where the activation came from so debugging and fallback timing stay visible in Studio.
local function _recordActivationSource(entity: number, services: any, source: string)
	local modelRef = services.EnemyEntityFactory:GetModelRef(entity)
	if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
		return
	end

	modelRef.Model:SetAttribute("LastHitboxActivationSource", source)
	modelRef.Model:SetAttribute("LastHitboxActivatedAt", services.CurrentTime)
end

-- Checks whether the attacker can currently reach the base target.
local function _isTargetInRange(entity: number, services: any): boolean
	local enemyPosition = services.EnemyEntityFactory:GetPosition(entity)
	local role = services.EnemyEntityFactory:GetRole(entity)
	if enemyPosition == nil or role == nil then
		return false
	end

	local attackRange = role.AttackRange
	if type(attackRange) ~= "number" then
		return false
	end

	return services.CombatPerceptionService:IsTargetInRange(enemyPosition.CFrame.Position, attackRange, "Base", nil)
end

local function _cleanupAttackBaseState(self: any, entity: number, services: any)
	local activeHitboxHandle = self:GetEntityValue(entity, "ActiveHitboxHandle")
	if type(activeHitboxHandle) == "string" then
		services.HitboxService:DestroyHitbox(activeHitboxHandle)
		services.CombatHitResolutionService:ClearResolvedHits(activeHitboxHandle)
	end

	self:ClearEntityValue(entity, "ActiveHitboxHandle")
	self:ClearEntityValue(entity, "HitboxStartedAt")
	self:ClearEntityValue(entity, "AwaitingHitboxActivation")
	self:ClearEntityValue(entity, "HitboxActivated")
	self:ClearEntityValue(entity, "HitboxActivationTimedOut")
	self:ClearEntityValue(entity, "AttackStartedAt")
	self:ClearEntityValue(entity, "HitLanded")
	self:ClearEntityValue(entity, "PendingHitboxActivation")
	self:ClearEntityValue(entity, "PendingHitboxActivationSource")
	self:ClearEntityValue(entity, "DebugCanStartReason")
	services.EnemyEntityFactory:ClearTarget(entity)
end

--[=[
	@within AttackBaseExecutor
	Verifies the base is active and in range before the executor starts.
	@param entity number -- Enemy entity id being evaluated.
	@param _data any? -- Unused action payload.
	@param services any -- Shared runtime services for the executor tick.
	@return boolean -- Whether the executor can start.
	@return string? -- Failure reason when the executor cannot start.
]=]
function AttackBaseExecutor:CanStart(entity: number, _data: any?, services: any): (boolean, string?)
	if not services.BaseEntityFactory:IsActive() then
		_mentionExecutorStateChange(self, entity, services, "DebugCanStartReason", "InactiveBase", "Base attack start blocked", {
			Reason = "InactiveBase",
		})
		return false, "InactiveBase"
	end

	if not _isTargetInRange(entity, services) then
		_mentionExecutorStateChange(self, entity, services, "DebugCanStartReason", "BaseOutOfRange", "Base attack start blocked", {
			Reason = "BaseOutOfRange",
		})
		return false, "BaseOutOfRange"
	end

	self:ClearEntityValue(entity, "DebugCanStartReason")
	_mentionExecutorMilestone("Enemy:AttackBaseExecutor", "Base attack executor can start", entity, services, nil)
	return true, nil
end

--[=[
	@within AttackBaseExecutor
	Clears per-attack runtime state and points the enemy at the base.
	@param entity number -- Enemy entity id being started.
	@param _data any? -- Unused action payload.
	@param services any -- Shared runtime services for the executor tick.
]=]
function AttackBaseExecutor:OnStart(entity: number, _data: any?, services: any)
	services.EnemyEntityFactory:SetTarget(entity, nil, "Base")
	self:SetEntityValue(entity, "AwaitingHitboxActivation", false)
	self:SetEntityValue(entity, "HitboxActivated", false)
	self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
	self:SetEntityValue(entity, "AttackStartedAt", nil)
	self:SetEntityValue(entity, "HitLanded", false)
	self:SetEntityValue(entity, "ActiveHitboxHandle", nil)
	self:SetEntityValue(entity, "HitboxStartedAt", nil)
	self:SetEntityValue(entity, "PendingHitboxActivation", false)
	self:SetEntityValue(entity, "PendingHitboxActivationSource", nil)
	self:BeginCursor(entity, FLOW_CURSOR_KEY, {
		Phase = "Cooldown",
		Index = 1,
		BatchSize = 1,
		IsDone = false,
		Data = {},
		Meta = {},
	})
	self:ClearEntityValue(entity, "DebugCanStartReason")
	_mentionExecutorMilestone("Enemy:AttackBaseExecutor", "Base attack executor started", entity, services, nil)
end

--[=[
	@within AttackBaseExecutor
	Keeps the attack branch alive only while the base remains reachable or the hitbox is already live.
	@param entity number -- Enemy entity id being evaluated.
	@param services any -- Shared runtime services for the executor tick.
	@return boolean -- Whether the executor can continue.
	@return string? -- Failure reason when the executor can no longer continue.
]=]
function AttackBaseExecutor:CanContinue(entity: number, services: any): (boolean, string?)
	if self:GetEntityValue(entity, "HitboxActivated") == true then
		return true, nil
	end

	return self:RunGuards(entity, services, {
		{
			Reason = "InactiveBase",
			Check = function(_guardEntity: number, guardServices: any): boolean
				return guardServices.BaseEntityFactory:IsActive()
			end,
		},
		{
			Reason = "BaseOutOfRange",
			Check = function(guardEntity: number, guardServices: any): boolean
				return _isTargetInRange(guardEntity, guardServices)
			end,
		},
	})
end

-- Creates the base hitbox after the animation or server timeout opens the activation window.
local function _markActivationReady(
	self: any,
	entity: number,
	services: any,
	source: string
): THitboxActivationResult
	local activated = self:GetEntityValue(entity, "HitboxActivated")
	if activated == true then
		return _activationResult(false, "AlreadyActivated", source)
	end

	local pendingSource = self:GetEntityValue(entity, "PendingHitboxActivationSource")
	if self:GetEntityValue(entity, "PendingHitboxActivation") == true then
		return _activationResult(true, "AlreadyQueuedForActivation", if type(pendingSource) == "string" then pendingSource else source)
	end

	if self:GetEntityValue(entity, "AwaitingHitboxActivation") ~= true then
		self:SetEntityValue(entity, "PendingHitboxActivation", true)
		self:SetEntityValue(entity, "PendingHitboxActivationSource", source)
		return _activationResult(true, "QueuedBeforeActivationWindow", source)
	end

	self:SetEntityValue(entity, "PendingHitboxActivation", true)
	self:SetEntityValue(entity, "PendingHitboxActivationSource", source)
	self:SetEntityValue(entity, "HitboxActivationTimedOut", source == "ServerTimeoutFallback")
	if self:GetCursorPhase(entity, FLOW_CURSOR_KEY) == "WaitingForActivationWindow" then
		self:SetCursorPhase(entity, FLOW_CURSOR_KEY, "WaitingForHitboxSlot")
	end

	return _activationResult(true, "ReadyForQueuedActivation", source)
end

local function _createGrantedHitbox(
	self: any,
	entity: number,
	services: any
): THitboxActivationResult
	local source = self:GetEntityValue(entity, "PendingHitboxActivationSource")
	if type(source) ~= "string" or source == "" then
		source = "UnknownActivationSource"
	end

	local activatedHitbox = services.HitboxService:CreateAttackHitbox(entity, "Enemy", HitboxConfig.AttackStructure)
	if not activatedHitbox.success or activatedHitbox.handle == nil then
		return _activationResult(false, activatedHitbox.reason or "HitboxCreateFailed", source)
	end

	self:SetEntityValue(entity, "ActiveHitboxHandle", activatedHitbox.handle)
	self:SetEntityValue(entity, "HitboxStartedAt", services.CurrentTime)
	self:SetEntityValue(entity, "HitboxActivated", true)
	self:SetEntityValue(entity, "HitboxActivationTimedOut", source == "ServerTimeoutFallback")
	self:SetEntityValue(entity, "AwaitingHitboxActivation", false)
	self:SetEntityValue(entity, "AttackStartedAt", nil)
	self:SetEntityValue(entity, "PendingHitboxActivation", false)
	self:SetEntityValue(entity, "PendingHitboxActivationSource", nil)
	services.EnemyEntityFactory:SetLastAttackTime(entity, services.CurrentTime)
	services.EnemyEntityFactory:PromoteToCommitted(entity)
	_recordActivationSource(entity, services, source)
	_mentionExecutorMilestone("Enemy:AttackBaseExecutor", "Base attack hitbox activated", entity, services, {
		Source = source,
		HitboxHandle = activatedHitbox.handle,
	})

	return _activationResult(true, "Activated", source)
end

--[=[
	@within AttackBaseExecutor
	Activates the hitbox from the server timeout fallback when the animation callback never arrives.
	@param entity number -- Enemy entity id to activate.
	@param services any -- Shared runtime services for the executor tick.
	@return THitboxActivationResult -- Activation result for the timeout fallback.
]=]
function AttackBaseExecutor:TryActivateHitboxFromTimeout(entity: number, services: any): THitboxActivationResult
	return _markActivationReady(self, entity, services, "ServerTimeoutFallback")
end

--[=[
	@within AttackBaseExecutor
	Activates the hitbox from the animation callback when the attack marker fires on time.
	@param entity number -- Enemy entity id to activate.
	@param services any -- Shared runtime services for the executor tick.
	@return THitboxActivationResult -- Activation result for the animation callback.
]=]
function AttackBaseExecutor:ActivateHitbox(entity: number, services: any): THitboxActivationResult
	return _markActivationReady(self, entity, services, "AnimationCallback")
end

--[=[
	@within AttackBaseExecutor
	Advances the attack state machine, resolves hit damage, and retires the hitbox when it expires.
	@param entity number -- Enemy entity id being ticked.
	@param _dt number -- Frame delta time for the current tick.
	@param services any -- Shared runtime services for the executor tick.
	@return string -- Executor status string.
]=]
function AttackBaseExecutor:OnTick(entity: number, _dt: number, services: any): string
	local role = services.EnemyEntityFactory:GetRole(entity)
	local cooldown = services.EnemyEntityFactory:GetAttackCooldown(entity)
	if role == nil or cooldown == nil then
		return self:Fail(entity, "MissingAttackState")
	end

	local damage = role.Damage
	if type(damage) ~= "number" or damage <= 0 then
		return self:Fail(entity, "InvalidAttackDamage")
	end

	return self:TickPartial(entity, FLOW_CURSOR_KEY, _dt, services, {
		Run = function(cursor, tickServices, _partialDt)
			if cursor.Phase == "Cooldown" then
				if tickServices.CurrentTime - cooldown.LastAttackTime < cooldown.Cooldown then
					return "Running"
				end

				self:SetEntityValue(entity, "AwaitingHitboxActivation", true)
				self:SetEntityValue(entity, "HitboxActivationTimedOut", false)
				self:SetEntityValue(entity, "AttackStartedAt", tickServices.CurrentTime)

				if self:GetEntityValue(entity, "PendingHitboxActivation") == true then
					self:SetCursorPhase(entity, FLOW_CURSOR_KEY, "WaitingForHitboxSlot")
				else
					self:SetCursorPhase(entity, FLOW_CURSOR_KEY, "WaitingForActivationWindow")
				end

				return "Running"
			end

			if cursor.Phase == "WaitingForActivationWindow" then
				local activationWindowStartedAt = self:GetEntityValue(entity, "AttackStartedAt")
				if type(activationWindowStartedAt) ~= "number" then
					return "Fail", "MissingAttackStartTime"
				end

				if self:GetEntityValue(entity, "PendingHitboxActivation") == true then
					self:SetCursorPhase(entity, FLOW_CURSOR_KEY, "WaitingForHitboxSlot")
					return "Running"
				end

				local timedOut = self:GetEntityValue(entity, "HitboxActivationTimedOut") == true
				if not timedOut and tickServices.CurrentTime - activationWindowStartedAt >= ACTIVATION_TIMEOUT_SECONDS then
					local activation = self:TryActivateHitboxFromTimeout(entity, tickServices)
					if not activation.success then
						return "Fail", activation.reason
					end
				end

				return "Running"
			end

			if cursor.Phase == "WaitingForHitboxSlot" then
				if self:GetEntityValue(entity, "PendingHitboxActivation") ~= true then
					return "Fail", "MissingPendingHitboxActivation"
				end

				return self:RunQueued(entity, HITBOX_QUEUE_KEY, tickServices, {
					CapacityPerTick = HITBOX_QUEUE_CAPACITY,
					Metadata = {
						EnqueuedAt = tickServices.CurrentTime,
					},
					DroppedStatus = function(_queuedEntity: number, _queuedServices: any, reason: string?): string
						return self:Fail(entity, reason or "HitboxQueueDropped")
					end,
					Run = function(grantedEntity: number, grantedServices: any, _metadata: any): string
						local activation = _createGrantedHitbox(self, grantedEntity, grantedServices)
						if not activation.success then
							return self:Fail(grantedEntity, activation.reason)
						end

						self:SetCursorPhase(grantedEntity, FLOW_CURSOR_KEY, "ActiveHitbox")
						return self:Running()
					end,
				})
			end

			if cursor.Phase == "ActiveHitbox" then
				local activeHitboxHandle = self:GetEntityValue(entity, "ActiveHitboxHandle")
				if type(activeHitboxHandle) ~= "string" then
					return "Fail", "MissingHitboxHandle"
				end

				local resolutionResult =
					tickServices.CombatHitResolutionService:ResolveEnemyMeleeHits(activeHitboxHandle, entity, damage)
				if not resolutionResult.success then
					_mentionExecutorMilestone("Enemy:AttackBaseExecutor", "Base attack damage resolution failed", entity, tickServices, {
						Reason = "ApplyDamageFailed",
					})
					return "Fail", "ApplyDamageFailed"
				end
				if resolutionResult.value.AppliedHits > 0 then
					self:SetEntityValue(entity, "HitLanded", true)
					_mentionExecutorMilestone("Enemy:AttackBaseExecutor", "Base attack applied hit", entity, tickServices, {
						AppliedHits = resolutionResult.value.AppliedHits,
						HitboxHandle = activeHitboxHandle,
					})
				end

				local startedAt = self:GetEntityValue(entity, "HitboxStartedAt")
				if type(startedAt) ~= "number" then
					return "Fail", "MissingHitboxStartTime"
				end

				if tickServices.CurrentTime - startedAt >= HitboxConfig.AttackStructure.MaxDuration then
					tickServices.HitboxService:DestroyHitbox(activeHitboxHandle)
					tickServices.CombatHitResolutionService:ClearResolvedHits(activeHitboxHandle)
					self:ClearEntityValue(entity, "ActiveHitboxHandle")
					self:ClearEntityValue(entity, "HitboxStartedAt")
					if self:GetEntityValue(entity, "HitLanded") == true then
						_mentionExecutorMilestone(
							"Enemy:AttackBaseExecutor",
							"Base attack executor completed successfully",
							entity,
							tickServices,
							{
								HitboxHandle = activeHitboxHandle,
							}
						)
						self:MarkCursorDone(entity, FLOW_CURSOR_KEY)
						return "Success"
					end
					_mentionExecutorMilestone("Enemy:AttackBaseExecutor", "Base attack executor expired without a hit", entity, tickServices, {
						HitboxHandle = activeHitboxHandle,
					})
					return "Fail", "HitboxExpired"
				end

				return "Running"
			end

			return "Fail", "UnknownAttackBasePhase"
		end,
	})
end

--[=[
	@within AttackBaseExecutor
	Tears down any live hitbox and clears transient attack state when the executor is canceled.
	@param entity number -- Enemy entity id being canceled.
	@param services any -- Shared runtime services for the executor tick.
]=]
function AttackBaseExecutor:OnCancel(entity: number, services: any)
	_cleanupAttackBaseState(self, entity, services)
end

--[=[
	@within AttackBaseExecutor
	Reuses the cancel path so completed attacks leave no stale state behind.
	@param entity number -- Enemy entity id being completed.
	@param services any -- Shared runtime services for the executor tick.
]=]
function AttackBaseExecutor:OnComplete(entity: number, services: any)
	_cleanupAttackBaseState(self, entity, services)
end

function AttackBaseExecutor:OnDeath(entity: number, services: any)
	_cleanupAttackBaseState(self, entity, services)
end

return AttackBaseExecutor

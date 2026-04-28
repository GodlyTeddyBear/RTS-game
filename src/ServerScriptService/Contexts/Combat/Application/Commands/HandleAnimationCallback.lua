--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Err = Result.Err

local SUPPORTED_CALLBACK_TYPE = "ActivateHitbox"

local ATTACK_ACTIONS = table.freeze({
	AttackBase = true,
	AttackStructure = true,
	StructureAttack = true,
})

--[=[
	@class HandleAnimationCallback
	Validates and routes animation marker callbacks to combat executors.
	@server
]=]
local HandleAnimationCallback = {}
HandleAnimationCallback.__index = HandleAnimationCallback
setmetatable(HandleAnimationCallback, BaseCommand)

function HandleAnimationCallback.new()
	local self = BaseCommand.new("Combat", "HandleAnimationCallback")
	return setmetatable(self, HandleAnimationCallback)
end

function HandleAnimationCallback:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_runtimeService = "CombatBehaviorRuntimeService",
		_hitboxService = "HitboxService",
		_projectileService = "ProjectileService",
		_handleGoalReached = "HandleGoalReached",
	})
end

function HandleAnimationCallback:Start(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_enemyEntityFactory = "EnemyEntityFactory",
		_structureEntityFactory = "StructureEntityFactory",
		_baseEntityFactory = "BaseEntityFactory",
		_enemyContext = "EnemyContext",
		_structureContext = "StructureContext",
		_baseContext = "BaseContext",
	})
end

local function _resolveActorEntity(self: any, actorId: string, actorKind: string?): (any, number?, string)
	if actorKind == "Structure" then
		local structureEntity = self._structureEntityFactory:GetEntityByStructureId(actorId)
		if structureEntity == nil then
			return nil, nil, "EntityNotFound"
		end
		if not self._structureEntityFactory:IsActive(structureEntity) then
			return nil, nil, "EntityNotActive"
		end
		return self._structureEntityFactory, structureEntity, "Ready"
	end

	local enemyEntity = self._enemyEntityFactory:GetEntityByEnemyId(actorId)
	if enemyEntity == nil then
		return nil, nil, "EntityNotFound"
	end
	if not self._enemyEntityFactory:IsAlive(enemyEntity) then
		return nil, nil, "EntityNotAlive"
	end
	return self._enemyEntityFactory, enemyEntity, "Ready"
end

local function _resolveActiveCombatOwnerUserId(self: any): number?
	local primaryPlayer = Players:GetPlayers()[1]
	if primaryPlayer == nil then
		return nil
	end
	if not self._loopService:IsActive(primaryPlayer.UserId) then
		return nil
	end
	return primaryPlayer.UserId
end

function HandleAnimationCallback:Execute(
	player: Player,
	actorId: string,
	callbackType: string,
	actorKind: "Enemy" | "Structure"?
): Result.Result<boolean>
	return Result.Catch(function()
		-- Reject malformed callback payloads before touching any combat state.
		if type(actorId) ~= "string" or actorId == "" then
			return Err("InvalidActorId", "Animation callback actorId must be a non-empty string")
		end
		if callbackType ~= SUPPORTED_CALLBACK_TYPE then
			return Err("UnsupportedCallbackType", "Animation callback type is not supported", {
				CallbackType = callbackType,
			})
		end
		if not self._loopService:IsActive(player.UserId) then
			return Err("CombatInactive", "Combat is not active for callback sender", {
				UserId = player.UserId,
			})
		end

		-- Confirm the callback sender owns the active combat session.
		local activeOwnerUserId = _resolveActiveCombatOwnerUserId(self)
		if activeOwnerUserId == nil then
			return Err("CombatOwnerNotActive", "Combat callback owner is not available", {
				UserId = player.UserId,
			})
		end
		if activeOwnerUserId ~= player.UserId then
			return Err("UnauthorizedCallbackSender", "Combat callback sender does not own the active combat session", {
				UserId = player.UserId,
				ActiveOwnerUserId = activeOwnerUserId,
			})
		end

		-- Resolve the actor entity and confirm the current action can accept hitbox activation.
		local factory, entity, resolutionReason = _resolveActorEntity(self, actorId, actorKind)
		if factory == nil or entity == nil then
			return Err(resolutionReason, "Callback actor resolution failed", {
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end

		-- Skip duplicate callbacks once the action has already committed.
		local action = factory:GetCombatAction(entity)
		if action == nil or type(action.CurrentActionId) ~= "string" then
			return Err("MissingCurrentActionId", "Callback actor has no running action", {
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end
		if ATTACK_ACTIONS[action.CurrentActionId] ~= true then
			return Err("UnsupportedActionId", "Current action cannot receive hitbox callbacks", {
				ActionId = action.CurrentActionId,
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end

		-- Attack executors promote themselves to Committed immediately after a successful
		-- activation. Late duplicate animation markers or client fallback callbacks should
		-- become harmless no-ops instead of noisy warnings.
		if action.ActionState == "Committed" then
			return Ok(true)
		end

		-- Route the callback into the executor only while the action is still running.
		if action.ActionState ~= "Running" then
			return Err("ActionStateNotRunning", "Callback actor is not in callback-eligible action state", {
				ActionState = action.ActionState,
				ActionId = action.CurrentActionId,
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end

		-- Build the runtime service bag once so activation sees the same dependencies as the tick loop.
		local executor = self._runtimeService:GetExecutor(action.CurrentActionId)
		if executor == nil or type(executor.ActivateHitbox) ~= "function" then
			return Err("ExecutorCannotActivateHitbox", "Current action executor does not expose ActivateHitbox", {
				ActionId = action.CurrentActionId,
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end

		-- Ask the executor to activate the hitbox and normalize its response for the caller.
		local activation = executor:ActivateHitbox(entity, {
			EnemyEntityFactory = self._enemyEntityFactory,
			StructureEntityFactory = self._structureEntityFactory,
			BaseEntityFactory = self._baseEntityFactory,
			EnemyContext = self._enemyContext,
			StructureContext = self._structureContext,
			BaseContext = self._baseContext,
			CurrentTime = os.clock(),
			HandleGoalReached = self._handleGoalReached,
			HitboxService = self._hitboxService,
			ProjectileService = self._projectileService,
		})

		if type(activation) ~= "table" or activation.success ~= true then
			local reason = if type(activation) == "table" then activation.reason else "ActivationFailed"
			return Err(reason, "Executor rejected hitbox activation callback", {
				ActionId = action.CurrentActionId,
				ActorId = actorId,
				ActorKind = actorKind,
				Source = if type(activation) == "table" then activation.source else nil,
			})
		end

		return Ok(true)
	end, self:_Label())
end

return HandleAnimationCallback

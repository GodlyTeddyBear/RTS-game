--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err

local SUPPORTED_CALLBACK_TYPE = "ActivateHitbox"

local ATTACK_ACTIONS = table.freeze({
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

function HandleAnimationCallback.new()
	return setmetatable({}, HandleAnimationCallback)
end

function HandleAnimationCallback:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._runtimeService = registry:Get("CombatBehaviorRuntimeService")
	self._hitboxService = registry:Get("HitboxService")
	self._projectileService = registry:Get("ProjectileService")
	self._handleGoalReached = registry:Get("HandleGoalReached")
end

function HandleAnimationCallback:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
	self._enemyContext = registry:Get("EnemyContext")
	self._structureContext = registry:Get("StructureContext")
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

		local factory, entity, resolutionReason = _resolveActorEntity(self, actorId, actorKind)
		if factory == nil or entity == nil then
			return Err(resolutionReason, "Callback actor resolution failed", {
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end

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
		if action.ActionState ~= "Running" then
			return Err("ActionStateNotRunning", "Callback actor is not in callback-eligible action state", {
				ActionState = action.ActionState,
				ActionId = action.CurrentActionId,
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end

		local executor = self._runtimeService:GetExecutor(action.CurrentActionId)
		if executor == nil or type(executor.ActivateHitbox) ~= "function" then
			return Err("ExecutorCannotActivateHitbox", "Current action executor does not expose ActivateHitbox", {
				ActionId = action.CurrentActionId,
				ActorId = actorId,
				ActorKind = actorKind,
			})
		end

		local activation = executor:ActivateHitbox(entity, {
			EnemyEntityFactory = self._enemyEntityFactory,
			StructureEntityFactory = self._structureEntityFactory,
			EnemyContext = self._enemyContext,
			StructureContext = self._structureContext,
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
	end, "Combat:HandleAnimationCallback")
end

return HandleAnimationCallback

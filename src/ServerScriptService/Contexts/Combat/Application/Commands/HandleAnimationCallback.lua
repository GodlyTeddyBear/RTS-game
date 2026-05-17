--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Err = Result.Err

local SUPPORTED_CALLBACK_TYPE = "ActivateHitbox"

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
		_actorRegistryService = "CombatActorRegistryService",
	})
end

local function _ResolveActiveCombatOwnerUserId(self: any): number?
	local primaryPlayer = Players:GetPlayers()[1]
	if primaryPlayer == nil then
		return nil
	end
	if not self._loopService:CanAcceptAnimationCallbacks(primaryPlayer.UserId) then
		return nil
	end
	return primaryPlayer.UserId
end

local function _ActivateRegisteredActor(self: any, actorHandle: string): Result.Result<boolean>
	local record = self._actorRegistryService:GetRecordByHandle(actorHandle)
	if record == nil then
		return Err("UnknownActorHandle", "Animation callback actor handle is not registered", {
			ActorHandle = actorHandle,
		})
	end

	local action = self._actorRegistryService:GetActionState(record.RuntimeId)
	if action == nil or type(action.CurrentActionId) ~= "string" then
		return Err("MissingCurrentActionId", "Callback actor has no running action", {
			ActorHandle = actorHandle,
			ActorType = record.ActorType,
		})
	end

	if action.ActionState == "Committed" then
		return Ok(true)
	end

	if action.ActionState ~= "Running" then
		return Err("ActionStateNotRunning", "Callback actor is not in callback-eligible action state", {
			ActionState = action.ActionState,
			ActionId = action.CurrentActionId,
			ActorHandle = actorHandle,
			ActorType = record.ActorType,
		})
	end

	local executor = self._runtimeService:GetExecutor(action.CurrentActionId)
	if executor == nil or type(executor.ActivateHitbox) ~= "function" then
		return Err("ExecutorCannotActivateHitbox", "Current action executor does not expose ActivateHitbox", {
			ActionId = action.CurrentActionId,
			ActorHandle = actorHandle,
			ActorType = record.ActorType,
		})
	end

	local currentTime = os.clock()
	local tickId = self._loopService:GetCurrentTickId()
	local services = self._actorRegistryService:BuildServices(record.RuntimeId, currentTime, tickId)
	services.CurrentTime = services.CurrentTime or currentTime
	services.TickId = services.TickId or tickId
	services.ActionState = action

	local activation = executor:ActivateHitbox(record.RuntimeId, services)
	if type(activation) ~= "table" or activation.success ~= true then
		local reason = if type(activation) == "table" then activation.reason else "ActivationFailed"
		return Err(reason, "Executor rejected hitbox activation callback", {
			ActionId = action.CurrentActionId,
			ActorHandle = actorHandle,
			ActorType = record.ActorType,
			Source = if type(activation) == "table" then activation.source else nil,
		})
	end

	return Ok(true)
end

function HandleAnimationCallback:Execute(
	player: Player,
	actorHandle: string,
	callbackType: string,
	_actorKind: "Enemy" | "Structure"?
): Result.Result<boolean>
	return Result.Catch(function()
		if type(actorHandle) ~= "string" or actorHandle == "" then
			return Err("InvalidActorHandle", "Animation callback actor handle must be a non-empty string")
		end
		if callbackType ~= SUPPORTED_CALLBACK_TYPE then
			return Err("UnsupportedCallbackType", "Animation callback type is not supported", {
				CallbackType = callbackType,
			})
		end
		if not self._loopService:CanAcceptAnimationCallbacks(player.UserId) then
			return Err("CombatInactive", "Combat is not active for callback sender", {
				UserId = player.UserId,
			})
		end

		local activeOwnerUserId = _ResolveActiveCombatOwnerUserId(self)
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

		return _ActivateRegisteredActor(self, actorHandle)
	end, self:_Label())
end

return HandleAnimationCallback

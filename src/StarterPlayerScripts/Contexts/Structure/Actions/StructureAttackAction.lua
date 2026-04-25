--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)

local STRIKE_FALLBACK_TIME_SECONDS = 1 / 3

local StructureAttackAction = {}
StructureAttackAction.__index = StructureAttackAction
setmetatable(StructureAttackAction, BaseAction)

StructureAttackAction.AnimationKey = "StructureAttack"
StructureAttackAction.Looped = false

StructureAttackAction.Events = {
	Strike = { ServerCallback = "ActivateHitbox" },
}

function StructureAttackAction.new()
	local self = BaseAction.new() :: any
	self._activationStateByActorId = {}
	return setmetatable(self, StructureAttackAction)
end

local function _getActorId(context: any): string?
	local actorId = context.ActorId
	if type(actorId) == "string" and actorId ~= "" then
		return actorId
	end

	return nil
end

function StructureAttackAction:OnStart(_track: AnimationTrack, context: any)
	local actorId = _getActorId(context)
	if actorId == nil then
		return
	end

	local token = tostring(os.clock())
	self._activationStateByActorId[actorId] = {
		Token = token,
		Fired = false,
	}

	task.delay(STRIKE_FALLBACK_TIME_SECONDS, function()
		local state = self._activationStateByActorId[actorId]
		if state == nil or state.Token ~= token or state.Fired == true then
			return
		end

		state.Fired = true
		state.Token = nil
		self:_RequestServerCallback("ActivateHitbox", context)
	end)
end

function StructureAttackAction:OnEvent(name: string, context: any)
	local actorId = _getActorId(context)
	if actorId ~= nil and name == "Strike" then
		local state = self._activationStateByActorId[actorId]
		if state ~= nil then
			state.Token = nil
			if state.Fired == true then
				return
			end
			state.Fired = true
		end
	end

	BaseAction.OnEvent(self, name, context)
end

function StructureAttackAction:OnStop(context: any)
	local actorId = _getActorId(context)
	if actorId == nil then
		return
	end

	self._activationStateByActorId[actorId] = nil
end

return StructureAttackAction

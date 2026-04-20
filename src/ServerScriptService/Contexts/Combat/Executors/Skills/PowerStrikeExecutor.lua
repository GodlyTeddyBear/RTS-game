--!strict

--[=[
	@class PowerStrikeExecutor
	Executor for the "PowerStrike" skill — a heavy melee hit dealing 2.5× normal damage.

	On `Start`, validates target + cooldown, records the per-skill cooldown immediately
	(so cancel still consumes it), then enters a short windup. On the first tick after the
	windup expires, `_ExecuteAttackTick` fires the damage and the action completes.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseExecutor = require(script.Parent.Parent.Base.BaseExecutor)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)
local SkillConfig = require(ReplicatedStorage.Contexts.Combat.Config.SkillConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices

local SKILL_ID = "PowerStrike"
local WINDUP_DURATION = 0.5 -- seconds before the hit lands

local PowerStrikeExecutor = setmetatable({}, { __index = BaseExecutor })
PowerStrikeExecutor.__index = PowerStrikeExecutor

export type TPowerStrikeExecutor = typeof(setmetatable({} :: {
	Config: any,
	_StartTime: { [any]: number },
}, PowerStrikeExecutor))

function PowerStrikeExecutor.new(): TPowerStrikeExecutor
	local self = BaseExecutor.new({
		ActionId = SKILL_ID,
		IsCommitted = false,
		IsInterruptible = false,
	})
	self._StartTime = {} :: { [any]: number }
	return setmetatable(self :: any, PowerStrikeExecutor)
end

function PowerStrikeExecutor:Start(
	entity: Entity,
	actionData: { [string]: any }?,
	services: TActionServices
): (boolean, string?)
	local npc = services.NPCEntityFactory

	local target = actionData and actionData.TargetEntity
	if not target or not npc:IsAlive(target) then
		return false, "PowerStrike: no valid target"
	end

	if not npc:IsSkillReady(entity, SKILL_ID) then
		return false, "PowerStrike: skill on cooldown"
	end

	-- Record cooldown on Start so cancel still consumes the charge
	npc:SetSkillCooldown(entity, SKILL_ID, SkillConfig.PowerStrike.Cooldown)
	self._StartTime[entity] = services.CurrentTime
	npc:SetActionState(entity, "Attacking")

	local identity = npc:GetIdentity(entity)
	MentionSuccess("Combat:PowerStrike:Start", "PowerStrike started", {
		entity = identity and (identity.NPCType .. "_" .. identity.NPCId) or tostring(entity),
	})
	return true, nil
end

function PowerStrikeExecutor:Tick(entity: Entity, _deltaTime: number, services: TActionServices): string
	local startTime = self._StartTime[entity]
	if not startTime then
		return "Fail"
	end

	if (services.CurrentTime - startTime) < WINDUP_DURATION then
		return "Running"
	end

	return self:_ExecuteAttackTick(entity, services, SKILL_ID, SkillConfig.PowerStrike.DamageMultiplier)
end

local function _clearState(self: any, entity: Entity)
	self._StartTime[entity] = nil
end

function PowerStrikeExecutor:Complete(entity: Entity, _services: TActionServices)
	_clearState(self, entity)
end

function PowerStrikeExecutor:Cancel(entity: Entity, _services: TActionServices)
	_clearState(self, entity)
end

return PowerStrikeExecutor

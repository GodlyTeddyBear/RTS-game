--!strict

--[=[
	@class ParryExecutor
	Executor for the "Parry" action — fully negates one incoming hit within a tight timing window.

	On `Start`, sets `BlockStateComponent.IsParrying = true` with a `ParryWindowEnd`
	timestamp of `now + PARRY_WINDOW` seconds and transitions `CombatStateComponent`
	to `"Parrying"`. Once the parry window elapses the action completes and the entity
	returns to idle. `Complete` and `Cancel` both clear the parry state.

	Damage interception is handled in `BaseExecutor:_ExecuteAttackTick` — any hit that
	lands while `IsParrying = true` and `CurrentTime <= ParryWindowEnd` is fully negated.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseExecutor = require(script.Parent.Parent.Base.BaseExecutor)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices

local PARRY_WINDOW = 0.4 -- seconds of active parry window

local ParryExecutor = setmetatable({}, { __index = BaseExecutor })
ParryExecutor.__index = ParryExecutor

export type TParryExecutor = typeof(setmetatable({} :: {
	Config: any,
	_ParryWindowEnd: { [any]: number },
}, ParryExecutor))

function ParryExecutor.new(): TParryExecutor
	local self = BaseExecutor.new({
		ActionId = "Parry",
		IsCommitted = false,
		Duration = PARRY_WINDOW,
		IsInterruptible = false,
	})
	self._ParryWindowEnd = {} :: { [any]: number }
	return setmetatable(self :: any, ParryExecutor)
end

function ParryExecutor:Start(entity: Entity, _actionData: { [string]: any }?, services: TActionServices): (boolean, string?)
	local npc = services.NPCEntityFactory
	local windowEnd = services.CurrentTime + PARRY_WINDOW
	self._ParryWindowEnd[entity] = windowEnd
	npc:SetBlockState(entity, false, true, windowEnd)
	npc:SetActionState(entity, "Parrying")

	local identity = npc:GetIdentity(entity)
	MentionSuccess("Combat:Parry:Start", "Parry started", {
		entity = identity and (identity.NPCType .. "_" .. identity.NPCId) or tostring(entity),
		windowEnd = windowEnd,
	})
	return true, nil
end

function ParryExecutor:Tick(entity: Entity, _deltaTime: number, services: TActionServices): string
	local windowEnd = self._ParryWindowEnd[entity]
	if not windowEnd then
		return "Fail"
	end

	if services.CurrentTime > windowEnd then
		return "Success"
	end

	return "Running"
end

local function _clearParry(self: any, entity: Entity, services: TActionServices)
	services.NPCEntityFactory:SetBlockState(entity, false, false, nil)
	self._ParryWindowEnd[entity] = nil
end

function ParryExecutor:Complete(entity: Entity, services: TActionServices)
	_clearParry(self, entity, services)
end

function ParryExecutor:Cancel(entity: Entity, services: TActionServices)
	_clearParry(self, entity, services)
end

return ParryExecutor

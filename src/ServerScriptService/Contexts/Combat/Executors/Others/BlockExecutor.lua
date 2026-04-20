--!strict

--[=[
	@class BlockExecutor
	Executor for the "Block" action — reduces incoming damage by 50% for a fixed duration.

	On `Start`, sets `BlockStateComponent.IsBlocking = true` and transitions
	`CombatStateComponent` to `"Blocking"`. Holds the `"Running"` state for
	`BLOCK_DURATION` seconds, then completes and returns the entity to idle.
	`Complete` and `Cancel` both clear the block state so subsequent hits deal full damage.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseExecutor = require(script.Parent.Parent.Base.BaseExecutor)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices

local BLOCK_DURATION = 3.0 -- seconds the NPC holds block before returning to idle

local BlockExecutor = setmetatable({}, { __index = BaseExecutor })
BlockExecutor.__index = BlockExecutor

export type TBlockExecutor = typeof(setmetatable({} :: {
	Config: any,
	_StartTime: { [any]: number },
}, BlockExecutor))

function BlockExecutor.new(): TBlockExecutor
	local self = BaseExecutor.new({
		ActionId = "Block",
		IsCommitted = false,
		Duration = BLOCK_DURATION,
		IsInterruptible = false,
	})
	self._StartTime = {} :: { [any]: number }
	return setmetatable(self :: any, BlockExecutor)
end

function BlockExecutor:Start(entity: Entity, _actionData: { [string]: any }?, services: TActionServices): (boolean, string?)
	local npc = services.NPCEntityFactory
	self._StartTime[entity] = services.CurrentTime
	npc:SetBlockState(entity, true, false, nil)
	npc:SetActionState(entity, "Blocking")

	local identity = npc:GetIdentity(entity)
	MentionSuccess("Combat:Block:Start", "Block started", {
		entity = identity and (identity.NPCType .. "_" .. identity.NPCId) or tostring(entity),
	})
	return true, nil
end

function BlockExecutor:Tick(entity: Entity, _deltaTime: number, services: TActionServices): string
	local startTime = self._StartTime[entity]
	if not startTime then
		return "Fail"
	end

	if (services.CurrentTime - startTime) >= BLOCK_DURATION then
		return "Success"
	end

	return "Running"
end

local function _clearBlock(self: any, entity: Entity, services: TActionServices)
	services.NPCEntityFactory:SetBlockState(entity, false, false, nil)
	self._StartTime[entity] = nil
end

function BlockExecutor:Complete(entity: Entity, services: TActionServices)
	_clearBlock(self, entity, services)
end

function BlockExecutor:Cancel(entity: Entity, services: TActionServices)
	_clearBlock(self, entity, services)
end

return BlockExecutor

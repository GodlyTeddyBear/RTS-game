--!strict

--[=[
	@class BaseExecutor
	Base class for combat executors providing default no-op `IExecutor` implementations.

	Concrete executors inherit via `setmetatable(Executor, { __index = BaseExecutor })`
	and override only the methods they need. `_ExecuteAttackTick` is a shared helper
	for all attack-type executors — it applies damage, updates cooldown, and emits
	events to the client event buffer.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices
type TExecutorConfig = ExecutorTypes.TExecutorConfig

local BaseExecutor = {}
BaseExecutor.__index = BaseExecutor

export type TBaseExecutor = typeof(setmetatable({} :: { Config: TExecutorConfig }, BaseExecutor))

function BaseExecutor.new(config: TExecutorConfig): TBaseExecutor
	local self = setmetatable({}, BaseExecutor)
	self.Config = table.freeze(config)
	return self
end

--[=[
	Start an action for an entity. Default returns success immediately.
	@within BaseExecutor
	@param _entity Entity
	@param _actionData { [string]: any }?
	@param _services TActionServices
	@return boolean -- Whether the action started successfully
	@return string? -- Failure reason if false
]=]
function BaseExecutor:Start(_entity: Entity, _actionData: { [string]: any }?, _services: TActionServices): (boolean, string?)
	return true, nil
end

--[=[
	Tick an active action. Default completes immediately with `"Success"`.
	@within BaseExecutor
	@param _entity Entity
	@param _deltaTime number
	@param _services TActionServices
	@return string -- `"Running"`, `"Success"`, or `"Fail"`
]=]
function BaseExecutor:Tick(_entity: Entity, _deltaTime: number, _services: TActionServices): string
	return "Success"
end

--[=[
	Cancel the action, cleaning up any state. No-op by default.
	@within BaseExecutor
	@param _entity Entity
	@param _services TActionServices
]=]
function BaseExecutor:Cancel(_entity: Entity, _services: TActionServices) end

--[=[
	Called when an action ends with `"Success"` or `"Fail"`. No-op by default.
	@within BaseExecutor
	@param _entity Entity
	@param _services TActionServices
]=]
function BaseExecutor:Complete(_entity: Entity, _services: TActionServices) end

--[=[
	Shared helper: apply damage for one attack tick.

	Reads `ActionData.TargetEntity`, calculates damage via `DamageCalculator`,
	applies it, updates the attack cooldown, and appends `Damaged`/`Died`
	events to `services.EventBuffer`.
	@within BaseExecutor
	@param entity Entity
	@param services TActionServices
	@param attackLabel string -- Used in debug log only
	@param damageMultiplier number? -- Multiplied after ATK-DEF subtraction (default 1.0)
	@return string -- `"Success"` or `"Fail"`
	@private
]=]
--[=[
	Shared helper: apply damage for one attack tick and emit events.

	Reads target from ActionData, calculates damage via DamageCalculator,
	applies it, updates cooldown, and appends Damaged/Died events to the
	event buffer for transmission to the client.

	:::tip
	Used by all attack executors (Melee, Ranged, Sword, etc.) — eliminates
	damage calculation duplication while allowing per-weapon customization
	via damageMultiplier.
	:::
	@within BaseExecutor
	@param entity Entity -- Attacker
	@param services TActionServices
	@param attackLabel string -- Human-readable label for debug logs
	@param damageMultiplier number? -- Applied after ATK-DEF subtraction (default 1.0)
	@return string -- `"Success"` on hit, `"Fail"` on validation error
	@private
]=]
function BaseExecutor:_ExecuteAttackTick(entity: Entity, services: TActionServices, attackLabel: string, damageMultiplier: number?): string
	local npc = services.NPCEntityFactory

	-- Validate action data exists and contains a target
	local actionComp = npc:GetCombatAction(entity)
	if not actionComp or not actionComp.ActionData then
		return "Fail"
	end

	local targetEntity = actionComp.ActionData.TargetEntity
	if not targetEntity then
		return "Fail"
	end

	-- Target already dead: count as success (cleanup will happen on next check)
	if not npc:IsAlive(targetEntity) then
		return "Success"
	end

	-- Fetch both attacker and defender stats for damage formula
	local attackerStats = npc:GetStats(entity)
	local defenderStats = npc:GetStats(targetEntity)
	if not attackerStats or not defenderStats then
		return "Fail"
	end

	-- Calculate base damage: formula = (ATK - DEF) × multiplier, minimum 1
	local baseDamage = services.DamageCalculator:Calculate(attackerStats.ATK, defenderStats.DEF)
	local damage = math.max(1, math.floor(baseDamage * (damageMultiplier or 1.0)))

	-- Check if the defender is blocking or parrying
	local blockState = npc:GetBlockState(targetEntity)
	if blockState then
		local targetIdentityForBlock = npc:GetIdentity(targetEntity)
		local targetIdLabel = targetIdentityForBlock and targetIdentityForBlock.NPCId or tostring(targetEntity)

		if blockState.IsParrying and services.CurrentTime <= blockState.ParryWindowEnd then
			-- Parry: fully negate this hit
			local attackerIdentityForBlock = npc:GetIdentity(entity)
			table.insert(services.EventBuffer, {
				EventType = "Parried",
				SourceNPCId = attackerIdentityForBlock and attackerIdentityForBlock.NPCId or nil,
				TargetNPCId = targetIdLabel,
				Position = (function()
					local ref = npc:GetModelRef(targetEntity)
					return ref and ref.Instance and ref.Instance.PrimaryPart and ref.Instance.PrimaryPart.Position or nil
				end)(),
			})
			MentionSuccess("Combat:ProcessCombatTick:Damage", "[NPC:" .. targetIdLabel .. "] Parried hit from " .. tostring(entity))
			return "Success"
		elseif blockState.IsBlocking then
			-- Block: 50% damage reduction
			damage = math.max(1, math.floor(damage * 0.5))
		end
	end

	local isBlocked = blockState ~= nil and blockState.IsBlocking
	local newHP = npc:ApplyDamage(targetEntity, damage)

	-- Update attacker state: reset cooldown and mark as Attacking
	npc:UpdateAttackCooldown(entity, services.CurrentTime)
	npc:SetActionState(entity, "Attacking")

	-- Emit damage events to client and game event bus
	local attackerIdentity = npc:GetIdentity(entity)
	local targetIdentity = npc:GetIdentity(targetEntity)
	if targetIdentity then
		local team = npc:GetTeam(entity)
		-- Emit global damage event (used by dungeon, quest, etc.)
		GameEvents.Bus:Emit(Events.Combat.NPCDamaged, team and team.UserId or 0, targetIdentity.NPCId, damage, newHP)

		-- Append Damaged event to client event buffer (batched with other events this frame)
		local targetModelRef = npc:GetModelRef(targetEntity)
		local targetModel = targetModelRef and targetModelRef.Instance
		table.insert(services.EventBuffer, {
			EventType = "Damaged",
			SourceNPCId = attackerIdentity and attackerIdentity.NPCId or nil,
			TargetNPCId = targetIdentity.NPCId,
			Damage = damage,
			NewHP = newHP,
			MaxHP = defenderStats.HP,
			Position = targetModel and targetModel.PrimaryPart and targetModel.PrimaryPart.Position or nil,
			IsBlocked = isBlocked,
		})

		local aLabel = attackerIdentity and (attackerIdentity.NPCType .. "_" .. attackerIdentity.NPCId)
			or tostring(entity)
		MentionSuccess(
			"Combat:ProcessCombatTick:Damage",
			"[NPC:"
				.. aLabel
				.. "] "
				.. attackLabel
				.. " -> "
				.. targetIdentity.NPCId
				.. " for "
				.. damage
				.. " dmg (HP: "
				.. newHP
				.. ")"
		)
	end

	-- If target died from this hit, emit death events
	if newHP <= 0 then
		local identity = npc:GetIdentity(targetEntity)
		local team = npc:GetTeam(targetEntity)
		if identity and team then
			-- Emit global death event (triggers wave completion checks, quest completion, etc.)
			GameEvents.Bus:Emit(Events.Combat.NPCDied, team.UserId, identity.NPCId, identity.NPCType, team.Team)

			-- Append Died event to client event buffer (for UI death animations, sfx, etc.)
			local diedModelRef = npc:GetModelRef(targetEntity)
			local diedModel = diedModelRef and diedModelRef.Instance
			table.insert(services.EventBuffer, {
				EventType = "Died",
				SourceNPCId = attackerIdentity and attackerIdentity.NPCId or nil,
				TargetNPCId = identity.NPCId,
				Position = diedModel and diedModel.PrimaryPart and diedModel.PrimaryPart.Position or nil,
				Custom = { NPCType = identity.NPCType, Team = team.Team },
			})
		end
	end

	return "Success"
end

return BaseExecutor

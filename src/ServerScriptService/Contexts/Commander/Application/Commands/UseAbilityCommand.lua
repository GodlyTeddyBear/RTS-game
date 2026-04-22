--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure
local fromNilable = Result.fromNilable

type SlotKey = CommanderTypes.SlotKey
--[=[
	@interface UseAbilityResult
	@within UseAbilityCommand
	.slotKey SlotKey -- The commander slot that was accepted.
]=]
type UseAbilityResult = {
	slotKey: SlotKey,
}

--[=[
	@class UseAbilityCommand
	Validates and applies commander ability usage through authoritative ECS state.
	@server
]=]
local UseAbilityCommand = {}
UseAbilityCommand.__index = UseAbilityCommand

--[=[
	Creates a new ability-use command.
	@within UseAbilityCommand
	@return UseAbilityCommand -- The new command instance.
]=]
function UseAbilityCommand.new()
	return setmetatable({}, UseAbilityCommand)
end

--[=[
	Initializes the ability, cooldown, and sync dependencies.
	@within UseAbilityCommand
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function UseAbilityCommand:Init(registry: any, _name: string)
	self._abilityService = registry:Get("AbilityService")
	self._cooldownService = registry:Get("CooldownService")
	self._entityFactory = registry:Get("CommanderEntityFactory")
	self._syncService = registry:Get("CommanderSyncService")
end

--[=[
	Validates and executes a commander ability use.
	@within UseAbilityCommand
	@param player Player -- The player using the ability.
	@param slotKey SlotKey -- The ability slot key to activate.
	@return Result.Result<UseAbilityResult> -- The accepted slot key.
]=]
function UseAbilityCommand:Execute(player: Player, slotKey: SlotKey): Result.Result<UseAbilityResult>
	local userId = player.UserId

	-- Resolve the live commander state before doing any slot validation.
	Try(fromNilable(
		self._entityFactory:GetCommanderState(userId),
		"CommanderNotFound",
		Errors.COMMANDER_NOT_FOUND,
		{ userId = userId }
	))

	-- Resolve the slot definition once so the rest of the command can operate on a frozen record.
	local slot = Try(fromNilable(
		self._abilityService:GetSlot(slotKey),
		"InvalidSlot",
		Errors.INVALID_SLOT,
		{ slotKey = tostring(slotKey) }
	))

	-- Reject active cooldowns before any energy-affordability checks or side effects.
	Ensure(
		self._cooldownService:IsReady(userId, slot.Key),
		"AbilityOnCooldown",
		Errors.ABILITY_ON_COOLDOWN,
		{ userId = userId, slotKey = slot.Key }
	)

	-- Keep the energy check before execution so a future EconomyContext spend can slot in here.
	Ensure(
		self._abilityService:CanAffordAbility(userId, slot.Key),
		"InsufficientEnergy",
		Errors.INSUFFICIENT_ENERGY,
		{ userId = userId, slotKey = slot.Key, energyCost = slot.EnergyCost }
	)

	-- Execute the stub effect and stamp the new cooldown atomically through the sync service.
	self._abilityService:ExecuteStub(userId, slot.Key)
	self._entityFactory:SetCooldown(userId, slot.Key, slot.CooldownDuration)
	self._syncService:SyncCommanderState(userId)

	-- Return the accepted slot key so callers can mirror the successful action.
	return Ok({
		slotKey = slot.Key,
	})
end

return UseAbilityCommand

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
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
setmetatable(UseAbilityCommand, BaseCommand)

local function _GetCommanderRootCFrame(player: Player): CFrame?
	local character = player.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart.CFrame
end

--[=[
	Creates a new ability-use command.
	@within UseAbilityCommand
	@return UseAbilityCommand -- The new command instance.
]=]
function UseAbilityCommand.new()
	local self = BaseCommand.new("Commander", "UseAbilityCommand")
	return setmetatable(self, UseAbilityCommand)
end

--[=[
	Initializes local command dependencies.
	@within UseAbilityCommand
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function UseAbilityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_abilityService = "AbilityService",
		_cooldownService = "CooldownService",
		_abilityUsePolicy = "AbilityUsePolicy",
		_entityFactory = "CommanderEntityFactory",
		_syncService = "CommanderSyncService",
	})
end

-- Resolves cross-context dependencies after external services are registered in KnitStart.
function UseAbilityCommand:Start(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_economyContext = "EconomyContext",
		_runContext = "RunContext",
		_summonContext = "SummonContext",
	})
end

--[=[
	Validates and executes a commander ability use.
	@within UseAbilityCommand
	@param player Player -- The player using the ability.
	@param slotKey SlotKey -- The ability slot key to activate.
	@return Result.Result<UseAbilityResult> -- The accepted slot key.
]=]
function UseAbilityCommand:Execute(player: Player, slotKey: SlotKey): Result.Result<UseAbilityResult>
	return Result.Catch(function()
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

		-- Reject active cooldowns before any side effects.
		Ensure(
			self._cooldownService:IsReady(userId, slot.Key),
			"AbilityOnCooldown",
			Errors.ABILITY_ON_COOLDOWN,
			{ userId = userId, slotKey = slot.Key }
		)

		local runStateResult = self._runContext:GetState()
		local runState = Try(runStateResult)
		Try(self._abilityUsePolicy:CheckCanUseInRunState(slot.Key, runState))

		if slot.Key == "SummonA" then
			local castOriginCFrame = Try(fromNilable(
				_GetCommanderRootCFrame(player),
				"CommanderRootMissing",
				Errors.COMMANDER_ROOT_MISSING,
				{ userId = userId }
			))

			Try(self._economyContext:SpendEnergy(player, slot.EnergyCost))

			local spawnResult = self._summonContext:SpawnSwarmDrones(player, slot.Metadata, castOriginCFrame)
			if not spawnResult.success then
				local refundResult = self._economyContext:AddResource(player, "Energy", slot.EnergyCost)
				if not refundResult.success then
					Result.MentionError("Commander:UseAbility", "Failed to refund energy after summon spawn failure", {
						UserId = userId,
						SlotKey = slot.Key,
						CauseType = refundResult.type,
						CauseMessage = refundResult.message,
					}, refundResult.type)
				end
			end
			Try(spawnResult)
		else
			-- Non-summon slots remain stubbed until their phase implementations are in scope.
			self._abilityService:ExecuteStub(userId, slot.Key)
		end

		self._entityFactory:SetCooldown(userId, slot.Key, slot.CooldownDuration)
		self._syncService:SyncCommanderState(userId)

		self:_EmitContextEvent("AbilityUsed", userId, slot.Key)

		-- Return the accepted slot key so callers can mirror the successful action.
		return Ok({
			slotKey = slot.Key,
		})
	end, self:_Label())
end

return UseAbilityCommand

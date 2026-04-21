--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local CommanderConfig = require(ReplicatedStorage.Contexts.Commander.Config.CommanderConfig)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type AbilitySlotDef = CommanderTypes.AbilitySlotDef
type CommanderAtomState = CommanderTypes.CommanderAtomState
type CommanderState = CommanderTypes.CommanderState
type ResourceAtom = EconomyTypes.ResourceAtom
type ResourceWallet = EconomyTypes.ResourceWallet

export type TAbilitySlotHudData = {
	key: string,
	displayName: string,
	energyCost: number,
	cooldownDuration: number,
	cooldownRemaining: number,
	cooldownProgress: number,
	canAfford: boolean,
	isOnCooldown: boolean,
}

local abilityAtom: (() -> CommanderAtomState)? = nil
local resourceAtom: (() -> ResourceAtom)? = nil
local DEFAULT_COMMANDER_STATE: CommanderAtomState = table.freeze({})
local DEFAULT_RESOURCE_STATE: ResourceAtom = table.freeze({})

local function _GetCommanderAtom(): () -> CommanderAtomState
	if abilityAtom == nil then
		local commanderController = Knit.GetController("CommanderController")
		abilityAtom = commanderController:GetAtom()
	end
	return abilityAtom
end

local function _GetResourceAtom(): () -> ResourceAtom
	if resourceAtom == nil then
		local economyController = Knit.GetController("EconomyController")
		resourceAtom = economyController:GetAtom()
	end
	return resourceAtom
end

local function _GetLocalCommanderState(allCommanderState: CommanderAtomState): CommanderState?
	return allCommanderState[Players.LocalPlayer.UserId]
end

local function _GetEnergy(wallets: ResourceAtom): number
	local wallet: ResourceWallet? = wallets[Players.LocalPlayer.UserId]
	if wallet == nil then
		return 0
	end
	return wallet.energy
end

local function _BuildSlotData(
	slot: AbilitySlotDef,
	commanderState: CommanderState?,
	energy: number,
	now: number
): TAbilitySlotHudData
	local cooldownRemaining = 0
	local cooldownProgress = 0
	local isOnCooldown = false

	if commanderState then
		local cooldownEntry = commanderState.cooldowns[slot.key]
		if cooldownEntry then
			local duration = slot.cooldownDuration
			if duration > 0 then
				local remaining = (cooldownEntry.startedAt + duration) - now
				cooldownRemaining = math.clamp(remaining, 0, duration)
				cooldownProgress = cooldownRemaining / duration
				isOnCooldown = cooldownRemaining > 0
			end
		end
	end

	return table.freeze({
		key = slot.key,
		displayName = slot.displayName,
		energyCost = slot.energyCost,
		cooldownDuration = slot.cooldownDuration,
		cooldownRemaining = cooldownRemaining,
		cooldownProgress = cooldownProgress,
		canAfford = energy >= slot.energyCost,
		isOnCooldown = isOnCooldown,
	} :: TAbilitySlotHudData)
end

local function useAbilityBarHud(): { slots: { TAbilitySlotHudData } }
	local commanderState = ReactCharm.useAtom(_GetCommanderAtom()) or DEFAULT_COMMANDER_STATE
	local wallets = ReactCharm.useAtom(_GetResourceAtom()) or DEFAULT_RESOURCE_STATE
	local now, setNow = React.useState(function()
		return Workspace:GetServerTimeNow()
	end)

	React.useEffect(function()
		local isMounted = true
		task.spawn(function()
			while isMounted do
				setNow(Workspace:GetServerTimeNow())
				task.wait(0.25)
			end
		end)

		return function()
			isMounted = false
		end
	end, {})

	local localCommanderState = _GetLocalCommanderState(commanderState)
	local energy = _GetEnergy(wallets)

	local slots = table.create(#CommanderConfig.SLOTS)
	for index, slot in CommanderConfig.SLOTS do
		slots[index] = _BuildSlotData(slot, localCommanderState, energy, now)
	end

	return table.freeze({
		slots = table.freeze(slots),
	})
end

return useAbilityBarHud

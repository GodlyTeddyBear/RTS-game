--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local CommanderConfig = require(ReplicatedStorage.Contexts.Commander.Config.CommanderConfig)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local ResourceHudViewModel = require(script.Parent.Parent.ViewModels.ResourceHudViewModel)

type AbilitySlotDef = CommanderTypes.AbilitySlotDef
type CommanderClientState = CommanderTypes.CommanderClientState
type ResourceClientState = EconomyTypes.ResourceClientState

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

local abilityAtom: (() -> CommanderClientState)? = nil
local resourceAtom: (() -> ResourceClientState)? = nil

local function _GetCommanderAtom(): () -> CommanderClientState
	if abilityAtom == nil then
		local commanderController = Knit.GetController("CommanderController")
		abilityAtom = commanderController:GetAtom()
	end
	return abilityAtom
end

local function _GetResourceAtom(): () -> ResourceClientState
	if resourceAtom == nil then
		local economyController = Knit.GetController("EconomyController")
		resourceAtom = economyController:GetAtom()
	end
	return resourceAtom
end

local function _GetEnergy(wallet: ResourceClientState): number
	return ResourceHudViewModel.getEnergy(wallet)
end

local function _BuildSlotData(
	slot: AbilitySlotDef,
	commanderState: CommanderClientState,
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
	local commanderState = ReactCharm.useAtom(_GetCommanderAtom()) :: CommanderClientState
	local wallet = ReactCharm.useAtom(_GetResourceAtom()) :: ResourceClientState
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

	local energy = _GetEnergy(wallet)

	local slots = table.create(#CommanderConfig.SLOTS)
	for index, slot in CommanderConfig.SLOTS do
		slots[index] = _BuildSlotData(slot, commanderState, energy, now)
	end

	return table.freeze({
		slots = table.freeze(slots),
	})
end

return useAbilityBarHud

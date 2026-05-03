--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type CommanderClientState = CommanderTypes.CommanderClientState

export type TCommanderHudData = {
	Hp: number,
	MaxHp: number,
}

local DEFAULT_COMMANDER_HUD: TCommanderHudData = table.freeze({
	Hp = 0,
	MaxHp = 100,
})

local commanderAtom: (() -> CommanderClientState)? = nil

local function _GetCommanderAtom(): () -> CommanderClientState
	if commanderAtom == nil then
		local commanderController = Knit.GetController("CommanderController")
		commanderAtom = commanderController:GetAtom()
	end
	return commanderAtom
end

local function _ToHudData(state: CommanderClientState): TCommanderHudData
	if state == nil then
		return DEFAULT_COMMANDER_HUD
	end
	return {
		Hp = state.Hp,
		MaxHp = state.MaxHp,
	}
end

local function useCommanderHud(): TCommanderHudData
	local commanderState = ReactCharm.useAtom(_GetCommanderAtom()) :: CommanderClientState
	return _ToHudData(commanderState)
end

return useCommanderHud

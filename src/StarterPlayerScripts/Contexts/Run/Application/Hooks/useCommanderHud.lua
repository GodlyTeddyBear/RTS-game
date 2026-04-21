--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type CommanderAtomState = CommanderTypes.CommanderAtomState
type CommanderState = CommanderTypes.CommanderState

export type TCommanderHudData = {
	hp: number,
	maxHp: number,
}

local DEFAULT_COMMANDER_HUD: TCommanderHudData = table.freeze({
	hp = 0,
	maxHp = 100,
})

local commanderAtom: (() -> CommanderAtomState)? = nil

local function _GetCommanderAtom(): () -> CommanderAtomState
	if commanderAtom == nil then
		local commanderController = Knit.GetController("CommanderController")
		commanderAtom = commanderController:GetAtom()
	end
	return commanderAtom
end

local function _ToHudData(state: CommanderState?): TCommanderHudData
	if state == nil then
		return DEFAULT_COMMANDER_HUD
	end
	return {
		hp = state.hp,
		maxHp = state.maxHp,
	}
end

local function useCommanderHud(): TCommanderHudData
	local allCommanderState = ReactCharm.useAtom(_GetCommanderAtom())
	local playerState = allCommanderState[Players.LocalPlayer.UserId]
	return _ToHudData(playerState)
end

return useCommanderHud

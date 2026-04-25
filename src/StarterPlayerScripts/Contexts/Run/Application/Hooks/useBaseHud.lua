--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)
local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)

type BaseState = BaseTypes.BaseState

export type TBaseHudData = {
	hp: number,
	maxHp: number,
}

local DEFAULT_BASE_HUD: TBaseHudData = table.freeze({
	hp = 0,
	maxHp = BaseConfig.MAX_HP,
})

local baseAtom: (() -> BaseState?)? = nil

local function _GetBaseAtom(): () -> BaseState?
	if baseAtom == nil then
		local baseController = Knit.GetController("BaseController")
		baseAtom = baseController:GetAtom()
	end
	return baseAtom
end

local function _ToHudData(state: BaseState?): TBaseHudData
	if state == nil then
		return DEFAULT_BASE_HUD
	end

	return {
		hp = state.hp,
		maxHp = state.maxHp,
	}
end

local function useBaseHud(): TBaseHudData
	local baseState = ReactCharm.useAtom(_GetBaseAtom()) :: BaseState?
	return _ToHudData(baseState)
end

return useBaseHud

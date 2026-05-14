--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

type BaseState = BaseTypes.BaseState

local baseAtom: (() -> BaseState?)? = nil

local function _GetBaseAtom(): () -> BaseState?
	if baseAtom == nil then
		local baseController = Knit.GetController("BaseController")
		baseAtom = baseController:GetAtom()
	end
	return baseAtom
end

local function useBaseState(): BaseState?
	return ReactCharm.useAtom(_GetBaseAtom()) :: BaseState?
end

return useBaseState

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local getBaseProductionAtom = require(script.Parent.Parent.Parent.Infrastructure.BaseProductionAtom)

type TBaseProductionState = getBaseProductionAtom.TBaseProductionState

local function useBaseProduction(): TBaseProductionState
	return ReactCharm.useAtom(getBaseProductionAtom()) :: TBaseProductionState
end

return useBaseProduction

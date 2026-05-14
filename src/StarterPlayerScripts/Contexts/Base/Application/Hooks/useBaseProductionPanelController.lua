--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local React = require(ReplicatedStorage.Packages.React)

local useBaseProduction = require(script.Parent.useBaseProduction)
local useBaseProductionActions = require(script.Parent.useBaseProductionActions)
local useBaseState = require(script.Parent.useBaseState)

type TBaseProductionState = useBaseProduction.TBaseProductionState
type TBaseProductionActions = useBaseProductionActions.TBaseProductionActions

export type TBaseProductionPanelController = {
	state: TBaseProductionState,
	actions: TBaseProductionActions,
}

local function useBaseProductionPanelController(): TBaseProductionPanelController
	local baseState = useBaseState()
	local state = useBaseProduction()
	local actions = useBaseProductionActions()

	React.useEffect(function()
		local baseController = Knit.GetController("BaseController")
		local connection = baseController.BaseClicked:Connect(function()
			actions.open()
		end)

		return function()
			connection:Disconnect()
		end
	end, { actions })

	React.useEffect(function()
		if baseState ~= nil then
			return
		end

		actions.close()
	end, { baseState, actions })

	React.useEffect(function()
		return function()
			actions.close()
		end
	end, { actions })

	return table.freeze({
		state = state,
		actions = actions,
	} :: TBaseProductionPanelController)
end

return useBaseProductionPanelController

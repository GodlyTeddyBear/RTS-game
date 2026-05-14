--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useBaseProductionPanelController = require(script.Parent.Parent.Parent.Application.Hooks.useBaseProductionPanelController)
local BaseProductionViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.BaseProductionViewModel)
local BaseProductionPanelView = require(script.Parent.Parent.Organisms.BaseProductionPanelView)

local function BaseProductionPanel()
	local controller = useBaseProductionPanelController()
	local viewModel = React.useMemo(function()
		return BaseProductionViewModel.fromUnitConfig(controller.state.selectedUnitId)
	end, { controller.state.selectedUnitId })

	if not controller.state.isOpen then
		return nil
	end

	return e(BaseProductionPanelView, {
		viewModel = viewModel,
		onClose = controller.actions.close,
		onSelectUnit = controller.actions.selectUnit,
		onProduce = controller.actions.produceUnit,
	})
end

return BaseProductionPanel

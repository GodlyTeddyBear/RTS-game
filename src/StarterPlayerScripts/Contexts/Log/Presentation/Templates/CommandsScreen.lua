--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useCommandsScreenController = require(script.Parent.Parent.Parent.Application.Hooks.useCommandsScreenController)
local CommandsListOrganism = require(script.Parent.Parent.Organisms.CommandsListOrganism)

local function CommandsScreen()
	local controller = useCommandsScreenController()

	return e(CommandsListOrganism, {
		groupedCommands = controller.groupedCommands,
		expandedCommands = controller.expandedCommands,
		paramValues = controller.paramValues,
		executionResults = controller.executionResults,
		isExecuting = controller.isExecuting,
		onToggleExpand = controller.onToggleExpand,
		onParamChange = controller.onParamChange,
		onExecute = controller.onExecute,
	})
end

return CommandsScreen

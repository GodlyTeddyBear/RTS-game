--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useNPCCommandScreenController =
	require(script.Parent.Parent.Parent.Application.Hooks.useNPCCommandScreenController)
local NPCCommandScreenView = require(script.Parent.NPCCommandScreenView)

local function NPCCommandScreen()
	local controller = useNPCCommandScreenController()

	if not controller.isInExpedition then
		return nil
	end

	return e(NPCCommandScreenView, {
		rosterNPCs = controller.rosterNPCs,
		consumables = controller.consumables,
		selectedNpcIds = controller.selectedNpcIds,
		onToggleRosterUnit = controller.onToggleRosterUnit,
		onIssueCommand = controller.onIssueCommand,
		onUseConsumable = controller.onUseConsumable,
		onSetActiveMode = controller.onSetActiveMode,
		onToggleMode = controller.onToggleMode,
		onClearTargetedHighlights = controller.onClearTargetedHighlights,
	})
end

return NPCCommandScreen

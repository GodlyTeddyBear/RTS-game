--!strict

local useNPCCommandState = require(script.Parent.useNPCCommandState)
local useNPCCommandActions = require(script.Parent.useNPCCommandActions)
local NPCCommandTypes = require(script.Parent.Parent.Parent.Types.NPCCommandTypes)

export type TNPCCommandScreenController = {
	rosterNPCs: { NPCCommandTypes.TNPCEntry },
	consumables: { NPCCommandTypes.TConsumableEntry },
	selectedNpcIds: { string },
	selectedCount: number,
	recentOrders: { NPCCommandTypes.TOrderEntry },
	isPickingTarget: boolean,
	isInExpedition: boolean,
	onIssueCommand: (commandType: NPCCommandTypes.TCommandType) -> (),
	onUseConsumable: (slotIndex: number, targetNpcId: string) -> any,
	onSetActiveMode: (key: string?) -> (),
	onToggleMode: () -> (),
	onClearTargetedHighlights: () -> (),
	onClose: () -> (),
	onSelectAll: () -> (),
	onToggleRosterUnit: (npcId: string) -> (),
	onSelectOnly: (npcId: string) -> (),
	onDeselectNPC: (npcId: string) -> (),
}

local function useNPCCommandScreenController(): TNPCCommandScreenController
	local state = useNPCCommandState()
	local actions = useNPCCommandActions()

	return {
		rosterNPCs = state.rosterNPCs,
		consumables = state.consumables,
		selectedNpcIds = state.selectedNpcIds,
		selectedCount = state.selectedCount,
		recentOrders = state.recentOrders,
		isPickingTarget = state.isPickingTarget,
		isInExpedition = state.isInExpedition,
		onIssueCommand = actions.issueCommand,
		onUseConsumable = actions.useConsumable,
		onSetActiveMode = actions.setActiveMode,
		onToggleMode = actions.toggleMode,
		onClearTargetedHighlights = actions.clearTargetedHighlights,
		onClose = actions.closePanel,
		onSelectAll = actions.selectAll,
		onToggleRosterUnit = actions.toggleRosterUnit,
		onSelectOnly = actions.selectOnly,
		onDeselectNPC = actions.deselectNPC,
	}
end

return useNPCCommandScreenController

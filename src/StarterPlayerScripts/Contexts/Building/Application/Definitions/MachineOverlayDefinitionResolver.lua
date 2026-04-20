--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeId = require(ReplicatedStorage.Contexts.Forge.Types.RecipeId)

type TActionVariant = "primary" | "secondary" | "ghost" | "danger"
type TEnableRule = "machinePresent" | "hasFuelSupport" | "hasOutput"
type TRequestKind = "addFuel" | "queueRecipe" | "claimOutput"

--[=[
	@type TMachineOverlayActionDefinition
	@within MachineOverlayDefinitionResolver
	.key string -- Unique action identifier
	.layoutOrder number -- Display order (lower numbers first)
	.text string -- Button label
	.variant TActionVariant -- Enabled button color variant
	.disabledVariant TActionVariant -- Disabled button color variant
	.capabilityKey string -- Capability flag name
	.enableRule TEnableRule -- Logic for when action is enabled
	.requestKind TRequestKind -- Type of server request to make
	.requestValue any? -- Optional parameter for the request
]=]
export type TMachineOverlayActionDefinition = {
	key: string,
	layoutOrder: number,
	text: string,
	variant: TActionVariant,
	disabledVariant: TActionVariant,
	capabilityKey: string,
	enableRule: TEnableRule,
	requestKind: TRequestKind,
	requestValue: any?,
}

--[=[
	@type TMachineOverlayCopy
	@within MachineOverlayDefinitionResolver
	.statusTitleText string -- "Status" heading
	.statusMetricLabelText string -- "Fuel Remaining" label
	.queueTitleText string -- "Queue" heading
	.queueEmptyText string -- Message when queue is empty
	.actionsTitleText string -- "Actions" heading
	.actionPopupTitleText string -- "Select Action" popup heading
	.outputPopupTitleText string -- "Machine Outputs" popup heading
	.outputPopupEmptyText string -- Message when outputs are empty
	.openActionMenuText string -- "Open Action Menu" button text
	.actionMenuOpenText string -- "Action Menu Open" button text (when open)
	.outputButtonText string -- "View Outputs" button text
	.outputButtonEmptyText string -- "View Outputs (None)" button text
]=]
export type TMachineOverlayCopy = {
	statusTitleText: string,
	statusMetricLabelText: string,
	queueTitleText: string,
	queueEmptyText: string,
	actionsTitleText: string,
	actionPopupTitleText: string,
	outputPopupTitleText: string,
	outputPopupEmptyText: string,
	openActionMenuText: string,
	actionMenuOpenText: string,
	outputButtonText: string,
	outputButtonEmptyText: string,
}

--[=[
	@type TMachineOverlayDefinition
	@within MachineOverlayDefinitionResolver
	.copy TMachineOverlayCopy -- All UI text labels and messages
	.actionDefinitions { TMachineOverlayActionDefinition } -- Actions available for this machine type
]=]
export type TMachineOverlayDefinition = {
	copy: TMachineOverlayCopy,
	actionDefinitions: { TMachineOverlayActionDefinition },
}

local DEFAULT_COPY: TMachineOverlayCopy = table.freeze({
	statusTitleText = "Status",
	statusMetricLabelText = "Fuel Remaining",
	queueTitleText = "Queue",
	queueEmptyText = "No recipes queued",
	actionsTitleText = "Actions",
	actionPopupTitleText = "Select Action",
	outputPopupTitleText = "Machine Outputs",
	outputPopupEmptyText = "No output available",
	openActionMenuText = "Open Action Menu",
	actionMenuOpenText = "Action Menu Open",
	outputButtonText = "View Outputs",
	outputButtonEmptyText = "View Outputs (None)",
})

--[=[
	@class MachineOverlayDefinitionResolver
	Resolves UI definitions for machines based on their type (copy, actions, etc).
]=]

-- Base actions available to all machines (add fuel, claim output)
local function _createBaseActions(): { TMachineOverlayActionDefinition }
	return {
		{
			key = "addFuel",
			layoutOrder = 1,
			text = "Add Fuel",
			variant = "secondary",
			disabledVariant = "danger",
			capabilityKey = "canAddFuel",
			enableRule = "hasFuelSupport",
			requestKind = "addFuel",
			requestValue = 1,
		},
		{
			key = "claimOutput",
			layoutOrder = 99,
			text = "Collect Output",
			variant = "secondary",
			disabledVariant = "danger",
			capabilityKey = "canClaimOutput",
			enableRule = "hasOutput",
			requestKind = "claimOutput",
		},
	}
end

-- Creates Smelter-specific definition with copper and iron plate recipes
local function _createSmelterDefinition(): TMachineOverlayDefinition
	local actions = _createBaseActions()
	table.insert(actions, 2, {
		key = "queueCopper",
		layoutOrder = 2,
		text = "Queue Copper Plate",
		variant = "primary",
		disabledVariant = "danger",
		capabilityKey = "canQueueCopper",
		enableRule = "machinePresent",
		requestKind = "queueRecipe",
		requestValue = RecipeId.CopperPlate,
	})
	table.insert(actions, 3, {
		key = "queueIron",
		layoutOrder = 3,
		text = "Queue Iron Plate",
		variant = "primary",
		disabledVariant = "danger",
		capabilityKey = "canQueueIron",
		enableRule = "machinePresent",
		requestKind = "queueRecipe",
		requestValue = RecipeId.IronPlate,
	})
	return table.freeze({
		copy = DEFAULT_COPY,
		actionDefinitions = table.freeze(actions),
	})
end

-- Creates Lumberjack Machine-specific definition with charcoal recipe
local function _createLumberjackMachineDefinition(): TMachineOverlayDefinition
	local actions = _createBaseActions()
	table.insert(actions, 2, {
		key = "queueCharcoal",
		layoutOrder = 2,
		text = "Queue Charcoal",
		variant = "primary",
		disabledVariant = "danger",
		capabilityKey = "canQueueCharcoal",
		enableRule = "machinePresent",
		requestKind = "queueRecipe",
		requestValue = RecipeId.Charcoal,
	})
	return table.freeze({
		copy = DEFAULT_COPY,
		actionDefinitions = table.freeze(actions),
	})
end

local DEFAULT_DEFINITION: TMachineOverlayDefinition = table.freeze({
	copy = DEFAULT_COPY,
	actionDefinitions = table.freeze(_createBaseActions()),
})

local DEFINITIONS_BY_BUILDING_TYPE: { [string]: TMachineOverlayDefinition } = table.freeze({
	Smelter = _createSmelterDefinition(),
	LumberjackMachine = _createLumberjackMachineDefinition(),
})

local MachineOverlayDefinitionResolver = {}

--[=[
	Resolves the UI definition for a machine based on its building type.
	Falls back to default definition if building type is unknown.
	@within MachineOverlayDefinitionResolver
	@param machineView any -- Current machine state (or nil)
	@return TMachineOverlayDefinition -- UI definition with copy and actions
]=]
function MachineOverlayDefinitionResolver.resolve(machineView: any): TMachineOverlayDefinition
	local buildingType = if machineView then machineView.buildingType else nil
	if buildingType == nil then
		return DEFAULT_DEFINITION
	end

	return DEFINITIONS_BY_BUILDING_TYPE[buildingType] or DEFAULT_DEFINITION
end

return MachineOverlayDefinitionResolver

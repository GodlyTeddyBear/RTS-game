--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)
local MachineOverlayDefinitionResolver = require(script.Parent.Parent.Definitions.MachineOverlayDefinitionResolver)

--[=[
	@type TQueueRow
	@within MachineOverlayViewModel
	.key string -- Stable key for row rendering
	.index number -- Queue position (1-based)
	.name string -- Display name with index (e.g., "1. Copper Plate")
	.progressLabel string -- Progress display (e.g., "2.5s / 5.0s")
]=]
export type TQueueRow = {
	key: string,
	index: number,
	name: string,
	progressLabel: string,
}

--[=[
	@type TOutputEntry
	@within MachineOverlayViewModel
	.key string -- Unique identifier for the output entry
	.label string -- Display label (e.g., "Copper Ore x5")
	.source string -- Source description (e.g., "Buffered Output")
]=]
export type TOutputEntry = {
	key: string,
	label: string,
	source: string,
}

--[=[
	@type TMachineOverlayDerived
	@within MachineOverlayViewModel
	.titleText string -- Building type name
	.subtitleText string -- Zone name and slot location
	.fuelSeconds number -- Remaining fuel time in seconds
	.fuelRatio number -- Fuel burn progress ratio (0-1)
	.fuelLabel string -- Fuel item display name
	.actionCapabilities { [string]: boolean } -- Which actions are available
	.statusTitleText string -- "Status" label
	.statusMetricLabelText string -- "Fuel Remaining" label
	.queueTitleText string -- "Queue" label
	.queueEmptyText string -- Empty queue message
	.actionsTitleText string -- "Actions" label
	.actionPopupTitleText string -- "Select Action" label
	.outputPopupTitleText string -- "Machine Outputs" label
	.outputPopupEmptyText string -- Empty outputs message
	.openActionMenuText string -- "Open Action Menu" button text
	.actionMenuOpenText string -- "Action Menu Open" button text
	.outputButtonText string -- "View Outputs" button text
	.outputButtonEmptyText string -- "View Outputs (None)" button text
	.queueRows { TQueueRow } -- Queued recipes for display
	.outputEntries { TOutputEntry } -- Available outputs for display
]=]
export type TMachineOverlayDerived = {
	titleText: string,
	subtitleText: string,
	fuelSeconds: number,
	fuelRatio: number,
	fuelLabel: string,
	actionCapabilities: { [string]: boolean },
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
	queueRows: { TQueueRow },
	outputEntries: { TOutputEntry },
}

--[=[
	@class MachineOverlayViewModel
	Transforms machine state into UI-ready display data for the overlay.
]=]
local MachineOverlayViewModel = {}

-- Converts camelCase recipe IDs to spaced names (e.g., "copperPlate" → "Copper Plate")
local function _formatRecipeName(recipeId: string): string
	return recipeId:gsub("(%l)(%u)", "%1 %2")
end

-- Formats seconds with one decimal place (e.g., 2.5 → "2.5s")
local function _formatSeconds(seconds: number): string
	if seconds <= 0 then
		return "0.0s"
	end
	return string.format("%.1fs", seconds)
end

local function _getFuelBurnDuration(zoneName: string, buildingType: string?): number
	if buildingType == nil then
		return 0
	end

	local zoneDef = BuildingConfig[zoneName]
	local buildingDef = zoneDef and zoneDef.Buildings[buildingType]
	local duration = buildingDef and buildingDef.FuelBurnDurationSeconds
	if duration == nil or duration <= 0 then
		return 0
	end

	return duration
end

local function _getFuelItemId(zoneName: string, buildingType: string?): string?
	if buildingType == nil then
		return nil
	end

	local zoneDef = BuildingConfig[zoneName]
	local buildingDef = zoneDef and zoneDef.Buildings[buildingType]
	return if buildingDef then buildingDef.FuelItemId else nil
end

local function _buildQueueRows(machineView: any): { TQueueRow }
	local queueRows: { TQueueRow } = {}
	if machineView and machineView.queue and #machineView.queue > 0 then
		for index, job in ipairs(machineView.queue) do
			local duration = job.processDurationSeconds or 0
			local progressLabel = if duration > 0
				then string.format("%s / %s", _formatSeconds(job.progressSeconds), _formatSeconds(duration))
				else _formatSeconds(job.progressSeconds)

			table.insert(queueRows, {
				key = "queue_" .. tostring(index),
				index = index,
				name = string.format("%d. %s", index, _formatRecipeName(job.recipeId)),
				progressLabel = progressLabel,
			})
		end
	end
	return queueRows
end

local function _buildOutputEntries(machineView: any): { TOutputEntry }
	local outputEntries: { TOutputEntry } = {}
	if machineView and machineView.outputItemId and (machineView.outputQuantity or 0) > 0 then
		table.insert(outputEntries, {
			key = "buffered",
			label = string.format("%s x%d", machineView.outputItemId, machineView.outputQuantity),
			source = "Buffered Output",
		})
	end
	if machineView and machineView.queue then
		for index, job in ipairs(machineView.queue) do
			local recipe = RecipeConfig[job.recipeId]
			if recipe then
				local queuedLabel = string.format("%s x%d", recipe.OutputItemId, recipe.OutputQuantity)
				local queuedSource = string.format("Queued #%d (%s)", index, _formatRecipeName(job.recipeId))
				table.insert(outputEntries, {
					key = "queue_" .. tostring(index),
					label = queuedLabel,
					source = queuedSource,
				})
			end
		end
	end
	return outputEntries
end

local function _buildActionCapabilities(
	actionDefinitions: { MachineOverlayDefinitionResolver.TMachineOverlayActionDefinition },
	machineView: any,
	hasFuelSupport: boolean,
	hasOutput: boolean
): { [string]: boolean }
	local capabilities: { [string]: boolean } = {}
	for _, actionDefinition in ipairs(actionDefinitions) do
		local isEnabled = false
		if actionDefinition.enableRule == "machinePresent" then
			isEnabled = machineView ~= nil
		elseif actionDefinition.enableRule == "hasFuelSupport" then
			isEnabled = machineView ~= nil and hasFuelSupport
		elseif actionDefinition.enableRule == "hasOutput" then
			isEnabled = hasOutput
		end
		capabilities[actionDefinition.capabilityKey] = isEnabled
	end
	return capabilities
end

--[=[
	Transforms raw machine state into UI-ready derived data.
	@within MachineOverlayViewModel
	@param machineView any -- Current machine state from server
	@param zoneName string? -- Zone containing the machine
	@param slotIndex number? -- Slot index of the machine
	@param definition MachineOverlayDefinitionResolver.TMachineOverlayDefinition -- UI definition with copy and actions
	@return TMachineOverlayDerived -- Immutable, display-ready machine data
]=]
function MachineOverlayViewModel.fromMachineState(
	machineView: any,
	zoneName: string?,
	slotIndex: number?,
	definition: MachineOverlayDefinitionResolver.TMachineOverlayDefinition
): TMachineOverlayDerived
	local fuelSeconds = if machineView then machineView.fuelSecondsRemaining else 0
	local buildingType = if machineView then machineView.buildingType else nil
	local fuelDuration = if zoneName then _getFuelBurnDuration(zoneName, buildingType) else 0
	local fuelItemId = if zoneName then _getFuelItemId(zoneName, buildingType) else nil
	local fuelRatio = if fuelDuration > 0 then math.clamp(fuelSeconds / fuelDuration, 0, 1) else 0
	local hasOutput = machineView ~= nil and machineView.outputItemId ~= nil and (machineView.outputQuantity or 0) > 0
	local actionCapabilities = _buildActionCapabilities(definition.actionDefinitions, machineView, fuelDuration > 0, hasOutput)

	return table.freeze({
		titleText = if machineView and machineView.buildingType then machineView.buildingType else "Machine",
		subtitleText = if zoneName and slotIndex then string.format("%s  Slot %d", zoneName, slotIndex) else "Machine",
		fuelSeconds = fuelSeconds,
		fuelRatio = fuelRatio,
		fuelLabel = fuelItemId or "Fuel",
		actionCapabilities = actionCapabilities,
		statusTitleText = definition.copy.statusTitleText,
		statusMetricLabelText = definition.copy.statusMetricLabelText,
		queueTitleText = definition.copy.queueTitleText,
		queueEmptyText = definition.copy.queueEmptyText,
		actionsTitleText = definition.copy.actionsTitleText,
		actionPopupTitleText = definition.copy.actionPopupTitleText,
		outputPopupTitleText = definition.copy.outputPopupTitleText,
		outputPopupEmptyText = definition.copy.outputPopupEmptyText,
		openActionMenuText = definition.copy.openActionMenuText,
		actionMenuOpenText = definition.copy.actionMenuOpenText,
		outputButtonText = definition.copy.outputButtonText,
		outputButtonEmptyText = definition.copy.outputButtonEmptyText,
		queueRows = _buildQueueRows(machineView),
		outputEntries = _buildOutputEntries(machineView),
	} :: TMachineOverlayDerived)
end

return MachineOverlayViewModel

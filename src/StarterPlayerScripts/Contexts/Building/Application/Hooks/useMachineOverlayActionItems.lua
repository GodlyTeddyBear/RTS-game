--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local MachineOverlayDefinitionResolver = require(script.Parent.Parent.Definitions.MachineOverlayDefinitionResolver)

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState

local ACTION_ERROR_FLASH_SECONDS = 0.45

type TActionVariant = "primary" | "secondary" | "ghost" | "danger"

--[=[
	@type TActionItem
	@within useMachineOverlayActionItems
	.key string -- Unique action identifier
	.layoutOrder number -- Display order in action menu
	.text string -- Button label text
	.variant TActionVariant -- Button color variant
	.onActivated () -> () -- Callback when button is clicked
]=]
export type TActionItem = {
	key: string,
	layoutOrder: number,
	text: string,
	variant: TActionVariant,
	onActivated: () -> (),
}

type TUseMachineOverlayActionItemsParams = {
	buildingContext: any,
	zoneName: string?,
	slotIndex: number?,
	actionDefinitions: { MachineOverlayDefinitionResolver.TMachineOverlayActionDefinition },
	actionCapabilities: { [string]: boolean },
	fuelLabel: string,
}

--[=[
	@type TMachineOverlayActionItemsState
	@within useMachineOverlayActionItems
	.actionItems { TActionItem } -- Displayable action items with enabled/disabled state
	.errorActionKey string -- Key of the action currently showing error flash
	.errorFlashGeneration number -- Counter to trigger error animation re-runs
]=]
export type TMachineOverlayActionItemsState = {
	actionItems: { TActionItem },
	errorActionKey: string,
	errorFlashGeneration: number,
}

--[=[
	Builds action items from definitions with enabled/disabled state tracking.
	Manages error flash animations when actions fail.
	@within useMachineOverlayActionItems
	@param params TUseMachineOverlayActionItemsParams -- Configuration with context, definitions, and state
	@return TMachineOverlayActionItemsState -- Action items and error flash state
	@yields
]=]
local function useMachineOverlayActionItems(params: TUseMachineOverlayActionItemsParams): TMachineOverlayActionItemsState
	local errorActionKey, setErrorActionKey = useState("")
	local errorFlashGeneration, setErrorFlashGeneration = useState(0)
	local actionFlashIdRef = useRef(0)
	local actionFlashThreadRef = useRef(nil :: thread?)

	-- Clean up any pending flash animation on unmount
	useEffect(function()
		return function()
			local pendingFlashThread = actionFlashThreadRef.current
			if pendingFlashThread then
				task.cancel(pendingFlashThread)
				actionFlashThreadRef.current = nil
			end
		end
	end, {})

	-- Triggers error flash animation for an action, auto-clearing after timeout
	local function flashActionError(actionKey: string)
		actionFlashIdRef.current += 1
		local flashId = actionFlashIdRef.current
		setErrorFlashGeneration(function(n: number)
			return n + 1
		end)
		setErrorActionKey(actionKey)

		local pendingFlashThread = actionFlashThreadRef.current
		if pendingFlashThread then
			task.cancel(pendingFlashThread)
		end

		-- Auto-clear error after animation duration
		actionFlashThreadRef.current = task.delay(ACTION_ERROR_FLASH_SECONDS, function()
			if actionFlashIdRef.current == flashId then
				setErrorActionKey("")
			end
			actionFlashThreadRef.current = nil
		end)
	end

	-- Executes an action request and handles success/failure
	local function runAction(actionKey: string, isValid: boolean, requestFn: () -> any)
		if not isValid then
			flashActionError(actionKey)
			return
		end

		local requestPromise = requestFn()
		if requestPromise == nil then
			flashActionError(actionKey)
			return
		end

		requestPromise:andThen(function(result: any)
			if result ~= nil and type(result) == "table" and result.success == false then
				flashActionError(actionKey)
				return
			end
			setErrorActionKey("")
		end):catch(function()
			flashActionError(actionKey)
		end)
	end

	-- Builds action button text, appending fuel amount for fuel actions
	local function _buildActionText(actionDefinition: MachineOverlayDefinitionResolver.TMachineOverlayActionDefinition): string
		if actionDefinition.requestKind == "addFuel" then
			local amount = actionDefinition.requestValue
			if amount ~= nil and type(amount) == "number" then
				return string.format("%s (%d %s)", actionDefinition.text, amount, params.fuelLabel)
			end
		end
		return actionDefinition.text
	end

	-- Builds the server request based on action type and context
	local function _buildRequest(actionDefinition: MachineOverlayDefinitionResolver.TMachineOverlayActionDefinition): any
		if not params.zoneName or not params.slotIndex then
			return nil
		end

		if actionDefinition.requestKind == "addFuel" then
			local amount = actionDefinition.requestValue
			if amount == nil or type(amount) ~= "number" then
				return nil
			end
			return params.buildingContext:MachineAddFuel(params.zoneName, params.slotIndex, amount)
		end

		if actionDefinition.requestKind == "queueRecipe" then
			local recipeId = actionDefinition.requestValue
			if recipeId == nil then
				return nil
			end
			return params.buildingContext:MachineQueueRecipe(params.zoneName, params.slotIndex, recipeId)
		end

		if actionDefinition.requestKind == "claimOutput" then
			return params.buildingContext:MachineClaimOutput(params.zoneName, params.slotIndex)
		end

		return nil
	end

	local actionItems = useMemo(function()
		local items: { TActionItem } = {}
		for _, actionDefinition in ipairs(params.actionDefinitions) do
			local isEnabled = params.actionCapabilities[actionDefinition.capabilityKey] == true
			local isErrored = errorActionKey == actionDefinition.key
			local variant = if not isEnabled or isErrored then actionDefinition.disabledVariant else actionDefinition.variant

			table.insert(items, {
				key = actionDefinition.key,
				layoutOrder = actionDefinition.layoutOrder,
				text = _buildActionText(actionDefinition),
				variant = variant,
				onActivated = function()
					runAction(actionDefinition.key, isEnabled, function()
						return _buildRequest(actionDefinition)
					end)
				end,
			})
		end
		return items
	end, {
		params.actionDefinitions,
		params.actionCapabilities,
		params.fuelLabel,
		params.zoneName,
		params.slotIndex,
		params.buildingContext,
		errorActionKey,
	} :: { any })

	return {
		actionItems = actionItems,
		errorActionKey = errorActionKey,
		errorFlashGeneration = errorFlashGeneration,
	}
end

return useMachineOverlayActionItems

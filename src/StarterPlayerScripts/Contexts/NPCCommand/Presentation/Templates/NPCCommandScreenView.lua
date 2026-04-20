--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useState = React.useState

local ControlAreaPanel = require(script.Parent.Parent.Organisms.ControlAreaPanel)
local OptionAreaPanel = require(script.Parent.Parent.Organisms.OptionAreaPanel)
local UnitListPanel = require(script.Parent.Parent.Organisms.UnitListPanel)
local NPCCommandTypes = require(script.Parent.Parent.Parent.Types.NPCCommandTypes)

type TTabDef = {
	label: string,
	key: string,
	secondaryText: string?,
	quantityText: string?,
	disabled: boolean?,
	slotIndex: number?,
}

local CONTROL_TABS: { TTabDef } = {
	{ label = "ATTACK", key = "ATTACK" },
	{ label = "MOVE",   key = "MOVE" },
	{ label = "HOLD",   key = "HOLD" },
	{ label = "SKILLS", key = "SKILLS" },
	{ label = "CONSUMABLES", key = "CONSUMABLES" },
}

local OPTION_MAP: { [string]: { TTabDef } } = {
	ATTACK = {
		{ label = "NEAREST", key = "ATTACK_NEAREST" },
		{ label = "FOCUS",   key = "ATTACK_FOCUS" },
		{ label = "AUTO",    key = "ATTACK_AUTO" },
	},
	MOVE = {
		{ label = "RIGHT-CLICK", key = "MOVE_RIGHTCLICK" },
	},
	HOLD = {
		{ label = "STAND BY", key = "HOLD_STANDBY" },
	},
	SKILLS = {
		{ label = "USE SKILL", key = "SKILLS_USE" },
	},
}

-- Options that fire immediately and do not persist as an active mode
local ONE_SHOT_OPTIONS: { [string]: boolean } = {
	ATTACK_NEAREST = true,
	ATTACK_AUTO = true,
	HOLD_STANDBY = true,
}

export type TNPCCommandScreenViewProps = {
	rosterNPCs: { NPCCommandTypes.TNPCEntry },
	consumables: { NPCCommandTypes.TConsumableEntry },
	selectedNpcIds: { string },
	onToggleRosterUnit: (npcId: string) -> (),
	onIssueCommand: (commandType: NPCCommandTypes.TCommandType) -> (),
	onUseConsumable: (slotIndex: number, targetNpcId: string) -> any,
	onSetActiveMode: (key: string?) -> (),
	onToggleMode: () -> (),
	onClearTargetedHighlights: () -> (),
}

local function NPCCommandScreenView(props: TNPCCommandScreenViewProps)
	local selectedControlTab, setSelectedControlTab = useState(nil :: string?)
	local selectedOption, setSelectedOption = useState(nil :: string?)
	local isUsingConsumable, setIsUsingConsumable = useState(false)
	-- Tracks which one-shot key is currently "lit" (yellow) after firing
	local activeShotKey, setActiveShotKey = useState(nil :: string?)

	local function buildConsumableOptions(): { TTabDef }
		local selectedCount = #props.selectedNpcIds
		if #props.consumables == 0 then
			return {
				{
					label = "No consumables",
					key = "CONSUMABLES_EMPTY",
					secondaryText = "Brew or buy potions first",
					disabled = true,
				},
			}
		end

		local options: { TTabDef } = {}
		for _, entry in ipairs(props.consumables) do
			local disabled = isUsingConsumable or not entry.IsHealing or selectedCount ~= 1
			local statusText = if not entry.IsHealing
				then "Not usable"
				elseif isUsingConsumable then "Using..."
				elseif selectedCount == 0 then "Select one adventurer"
				elseif selectedCount > 1 then "Select only one adventurer"
				else "+" .. tostring(entry.HealAmount) .. " HP"

			table.insert(options, {
				label = entry.ItemName,
				key = "CONSUMABLE_" .. tostring(entry.SlotIndex),
				secondaryText = statusText,
				quantityText = "x" .. tostring(entry.Quantity),
				disabled = disabled,
				slotIndex = entry.SlotIndex,
			})
		end

		return options
	end

	local currentOptions = if selectedControlTab == "CONSUMABLES"
		then buildConsumableOptions()
		elseif selectedControlTab then OPTION_MAP[selectedControlTab] or {}
		else {}

	local function findOption(key: string): TTabDef?
		for _, option in ipairs(currentOptions) do
			if option.key == key then
				return option
			end
		end
		return nil
	end

	local function handleConsumableSelected(option: TTabDef): boolean
		if selectedControlTab ~= "CONSUMABLES" or option.disabled or not option.slotIndex then
			return false
		end

		local targetNpcId = props.selectedNpcIds[1]
		if not targetNpcId then
			return true
		end

		setIsUsingConsumable(true)
		local result = props.onUseConsumable(option.slotIndex, targetNpcId)
		if result and result.andThen and result.catch then
			result:andThen(function()
				setIsUsingConsumable(false)
			end):catch(function()
				setIsUsingConsumable(false)
			end)
		else
			setIsUsingConsumable(false)
		end
		return true
	end

	local function handleControlTabSelected(key: string)
		if selectedControlTab == key then
			setSelectedControlTab(nil)
			setSelectedOption(nil)
			setActiveShotKey(nil)
			setIsUsingConsumable(false)
			props.onSetActiveMode(nil)
		else
			setSelectedControlTab(key)
			setSelectedOption(nil)
			setActiveShotKey(nil)
			setIsUsingConsumable(false)
			props.onSetActiveMode(nil)
		end
	end

	local function handleOptionSelected(key: string)
		local option = findOption(key)
		if option and handleConsumableSelected(option) then
			setSelectedOption(nil)
			setActiveShotKey(nil)
			props.onSetActiveMode(nil)
			return
		end

		if selectedOption == key then
			-- Deselect: clear persistent mode
			setSelectedOption(nil)
			setActiveShotKey(nil)
			props.onSetActiveMode(nil)
			return
		end

		if ONE_SHOT_OPTIONS[key] then
			-- Fire immediately, do not persist as selected option
			if key == "ATTACK_NEAREST" then
				props.onIssueCommand("ATTACK" :: NPCCommandTypes.TCommandType)
				props.onClearTargetedHighlights()
				setActiveShotKey("ATTACK_NEAREST")
			elseif key == "ATTACK_AUTO" then
				props.onToggleMode()
				props.onClearTargetedHighlights()
				setActiveShotKey("ATTACK_AUTO")
			elseif key == "HOLD_STANDBY" then
				props.onIssueCommand("HOLD" :: NPCCommandTypes.TCommandType)
			end
			setSelectedOption(nil)
			props.onSetActiveMode(nil)
		else
			-- Persistent mode: select and activate; clear any one-shot indicator
			setSelectedOption(key)
			setActiveShotKey(nil)
			props.onSetActiveMode(key)
		end
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		ControlArea = e(ControlAreaPanel, {
			tabs = CONTROL_TABS,
			selectedKey = selectedControlTab,
			onTabSelected = handleControlTabSelected,
		}),
		OptionArea = e(OptionAreaPanel, {
			options = currentOptions,
			selectedKey = selectedOption,
			activeShotKey = activeShotKey,
			onOptionSelected = handleOptionSelected,
		}),
		UnitList = e(UnitListPanel, {
			rosterNPCs = props.rosterNPCs,
			onToggleRosterUnit = props.onToggleRosterUnit,
		}),
	})
end

return NPCCommandScreenView

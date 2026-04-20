--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo

local useBuildingSounds = require(script.Parent.Sounds.useBuildingSounds)

local useBuildings = require(script.Parent.useBuildings)
local useBuildingActions = require(script.Parent.useBuildingActions)
local useGold = require(script.Parent.Parent.Parent.Parent.Shop.Application.Hooks.useGold)
local ZoneViewModel = require(script.Parent.Parent.ViewModels.ZoneViewModel)
local SlotViewModel = require(script.Parent.Parent.ViewModels.SlotViewModel)
local BuildingPickerViewModel = require(script.Parent.Parent.ViewModels.BuildingPickerViewModel)
local useUnlockState = require(script.Parent.Parent.Parent.Parent.Unlock.Application.Hooks.useUnlockState)

local BuildingPickerPanel = require(script.Parent.Parent.Parent.Presentation.Organisms.BuildingPickerPanel)
local BuildingDetailPanel = require(script.Parent.Parent.Parent.Presentation.Organisms.BuildingDetailPanel)

type TPanelMode = "grid" | "pick" | "detail"

--[=[
	@type TBuildingScreenController
	@within useBuildingScreenController
	.selectedZone string -- Currently selected zone
	.onSelectZone (zoneName: string) -> () -- Zone tab selection callback
	.buildings { [string]: any } -- Player buildings map
	.selectedSlot number? -- Currently selected slot index
	.onSelectSlot (slotIndex: number) -> () -- Slot selection callback
	.rightPanel any? -- Rendered detail or picker panel element, or nil
]=]
export type TBuildingScreenController = {
	selectedZone: string,
	onSelectZone: (zoneName: string) -> (),
	buildings: { [string]: any },
	selectedSlot: number?,
	onSelectSlot: (slotIndex: number) -> (),
	rightPanel: any?,
}

local function _defaultZone(): string
	local flatZones = ZoneViewModel.buildFlatZoneList()
	return if #flatZones > 0 then flatZones[1].Name else "Forge"
end

local function _findSlotData(
	slots: { SlotViewModel.TSlotData },
	slotIndex: number
): SlotViewModel.TSlotData?
	for _, s in slots do
		if s.SlotIndex == slotIndex then
			return s
		end
	end
	return nil
end

--[=[
	Orchestrates building screen state: zone selection, slot selection, panel mode,
	construction/upgrade actions, and right-panel element construction.
	@within useBuildingScreenController
	@return TBuildingScreenController -- State and callbacks for BuildingScreen
]=]
local function useBuildingScreenController(): TBuildingScreenController
	local buildings = useBuildings()
	local unlockState = useUnlockState()
	local buildingActions = useBuildingActions()
	local gold = useGold()
	local sounds = useBuildingSounds()

	local selectedZone, setSelectedZone = useState(_defaultZone())
	local selectedSlot, setSelectedSlot = useState(nil :: number?)
	local panelMode, setPanelMode = useState("grid" :: TPanelMode)
	local isLoading, setIsLoading = useState(false)
	local errorMessage, setErrorMessage = useState(nil :: string?)

	useEffect(function()
		setSelectedSlot(nil)
		setPanelMode("grid")
	end, { selectedZone } :: { any })

	local function handleClose()
		setSelectedSlot(nil)
		setPanelMode("grid")
	end

	local function handleZoneSelect(zoneName: string)
		sounds.onZoneSwitch(zoneName)
		setSelectedZone(zoneName)
	end

	local function handleSlotSelect(slotIndex: number)
		sounds.onSlotSelect()
		local zoneSlots = buildings[selectedZone]
		local slotData = zoneSlots and zoneSlots[slotIndex]
		setSelectedSlot(slotIndex)
		if slotData then
			setPanelMode("detail")
		else
			setPanelMode("pick")
		end
	end

	local function handlePickConfirm(buildingType: string)
		if not selectedSlot then
			return
		end
		setIsLoading(true)
		setErrorMessage(nil)
		local promise = buildingActions.constructBuilding(selectedZone, selectedSlot, buildingType)
		if promise then
			promise
				:andThen(function()
					sounds.onBuildConfirm()
					setIsLoading(false)
					setSelectedSlot(nil)
					setPanelMode("grid")
				end)
				:catch(function(err)
					sounds.onError()
					setIsLoading(false)
					setErrorMessage(err.message or "Construction failed.")
				end)
		else
			setIsLoading(false)
			setSelectedSlot(nil)
			setPanelMode("grid")
		end
	end

	local rightPanel = useMemo(function(): any?
		if panelMode == "pick" and selectedSlot then
			local viewData = BuildingPickerViewModel.fromZone(selectedZone, unlockState, gold)
			return e(BuildingPickerPanel, {
				SlotIndex = selectedSlot,
				ViewData = viewData,
				IsLoading = isLoading,
				ErrorMessage = errorMessage,
				OnConfirm = handlePickConfirm,
				OnCancel = handleClose,
			})
		elseif panelMode == "detail" and selectedSlot then
			local slots = SlotViewModel.buildSlotGrid(selectedZone, buildings)
			local slotData = _findSlotData(slots, selectedSlot)
			if slotData and not slotData.IsEmpty then
				return e(BuildingDetailPanel, {
					ZoneName = selectedZone,
					SlotData = slotData,
					OnUpgrade = function()
						if selectedSlot then
							sounds.onUpgrade()
							local result = buildingActions.upgradeBuilding(selectedZone, selectedSlot)
							if result then
								result:catch(function()
									sounds.onError()
								end)
							end
						end
						handleClose()
					end,
					OnClose = handleClose,
				})
			end
		end
		return nil
	end, { panelMode, selectedSlot, selectedZone, buildings, unlockState, gold, isLoading, errorMessage } :: { any })

	return {
		selectedZone = selectedZone,
		onSelectZone = handleZoneSelect,
		buildings = buildings,
		selectedSlot = selectedSlot,
		onSelectSlot = handleSlotSelect,
		rightPanel = rightPanel,
	}
end

return useBuildingScreenController

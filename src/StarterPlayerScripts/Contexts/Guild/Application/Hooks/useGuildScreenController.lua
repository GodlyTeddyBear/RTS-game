--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useMemo = React.useMemo
local useState = React.useState

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local useGuildActions = require(script.Parent.useGuildActions)
local GuildDetailPanel = require(script.Parent.Parent.Parent.Presentation.Organisms.GuildDetailPanel)

-- Shared type for selected item across both tabs
export type TSelectedItem = {
	Id: string?,
	Name: string,
	Type: string,
	Description: string,
	StatsLabel: string,
	CostLabel: string?,
	CostDisplay: string?,
	Tab: "roster" | "hire",
}

export type TGuildScreenController = {
	activeTab: string,
	selectedItem: TSelectedItem?,
	onTabSelect: (tab: string) -> (),
	onSelectRosterItem: (vm: {
		Id: string,
		TypeLabel: string,
		Type: string,
		Description: string,
		StatsLabel: string,
	}) -> (),
	onSelectHireItem: (vm: {
		DisplayName: string,
		Type: string,
		Description: string,
		StatsLabel: string,
		HireCost: number,
		CostDisplay: string,
	}) -> (),
	detailProps: GuildDetailPanel.TGuildDetailPanelProps,
}

local function _BuildDetailProps(
	selectedItem: TSelectedItem?,
	guildActions: typeof(useGuildActions()),
	navActions: typeof(useNavigationActions()),
	soundActions: typeof(useSoundActions())
): GuildDetailPanel.TGuildDetailPanelProps
	-- Guard: no selection = empty detail panel
	if not selectedItem then
		return {}
	end

	-- Build base panel props (name, description, stats)
	local props: GuildDetailPanel.TGuildDetailPanelProps = {
		Name = selectedItem.Name,
		Type = selectedItem.Type,
		StatsLabel = selectedItem.StatsLabel,
		Description = selectedItem.Description,
		CostLabel = selectedItem.CostLabel,
	}

	-- Configure action button based on selected tab
	if selectedItem.Tab == "hire" then
		props.ActionLabel = "Hire"
		props.ActionGradient = GradientTokens.GREEN_BUTTON_GRADIENT
		props.ActionStroke = GradientTokens.GREEN_BUTTON_STROKE
		props.OnAction = function()
			soundActions.playButtonClick("hire")
			local result = guildActions.hireAdventurer(selectedItem.Type)
			if result then
				result:catch(function()
					soundActions.playError()
				end)
			end
		end
	elseif selectedItem.Tab == "roster" and selectedItem.Id then
		local adventurerId = selectedItem.Id
		props.ActionLabel = "View"
		props.ActionGradient = GradientTokens.ASSIGN_BUTTON_GRADIENT
		props.ActionStroke = GradientTokens.ASSIGN_BUTTON_STROKE
		props.OnAction = function()
			soundActions.playButtonClick()
			navActions.navigate("AdventurerDetail", { adventurerId = adventurerId })
		end
	end

	return props
end

local function useGuildScreenController(): TGuildScreenController
	local guildActions = useGuildActions()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()

	local activeTab, setActiveTab = useState("roster" :: string)
	local selectedItem, setSelectedItem = useState(nil :: TSelectedItem?)

	local onTabSelect = useMemo(function()
		return function(tab: string)
			-- Navigate to external screens (commission/adventure are separate contexts)
			if tab == "commission" then
				soundActions.playTabSwitch(tab)
				navActions.navigate("CommissionBoard")
				return
			end
			if tab == "adventure" then
				soundActions.playTabSwitch(tab)
				navActions.navigate("QuestBoard")
				return
			end
			-- Handle local tabs (roster/hire): stay in Guild context
			soundActions.playTabSwitch(tab)
			setActiveTab(tab)
			setSelectedItem(nil)
		end
	end, {})

	local onSelectRosterItem = useMemo(function()
		return function(vm: {
			Id: string,
			TypeLabel: string,
			Type: string,
			Description: string,
			StatsLabel: string,
		})
			soundActions.playButtonClick()
			setSelectedItem({
				Id = vm.Id,
				Name = vm.TypeLabel,
				Type = vm.Type,
				Description = vm.Description,
				StatsLabel = vm.StatsLabel,
				Tab = "roster",
			})
		end
	end, {})

	local onSelectHireItem = useMemo(function()
		return function(vm: {
			DisplayName: string,
			Type: string,
			Description: string,
			StatsLabel: string,
			HireCost: number,
			CostDisplay: string,
		})
			soundActions.playButtonClick()
			setSelectedItem({
				Name = vm.DisplayName,
				Type = vm.Type,
				Description = vm.Description,
				StatsLabel = vm.StatsLabel,
				CostLabel = "Cost: " .. tostring(vm.HireCost),
				CostDisplay = vm.CostDisplay,
				Tab = "hire",
			})
		end
	end, {})

	local detailProps = useMemo(function()
		return _BuildDetailProps(selectedItem, guildActions, navActions, soundActions)
	end, { selectedItem } :: { any })

	return {
		activeTab = activeTab,
		selectedItem = selectedItem,
		onTabSelect = onTabSelect,
		onSelectRosterItem = onSelectRosterItem,
		onSelectHireItem = onSelectHireItem,
		detailProps = detailProps,
	}
end

return useGuildScreenController

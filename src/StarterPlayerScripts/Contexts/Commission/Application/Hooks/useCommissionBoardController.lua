--!strict
local React = require(game:GetService("ReplicatedStorage").Packages.React)

local useCommissionActions = require(script.Parent.useCommissionActions)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

--[=[
	@function useCommissionBoardController
	@within CommissionBoardScreen
	Manage commission board state and actions including tab selection and user interactions. Integrates sound effects for user actions.
	@return table -- Controller table with activeTab, onTabSelect, onAccept, onDeliver, onAbandon, onRefresh, onUnlock
	@tag ViewModel Hook
]=]
local function useCommissionBoardController()
	local actions = useCommissionActions()
	local soundActions = useSoundActions()
	-- Track which tab is active (available commissions vs active commissions)
	local activeTab, setActiveTab = React.useState("available" :: "available" | "active")

	-- Handle tab selection, play switch sound before changing tab
	local function onTabSelect(tab: "available" | "active")
		soundActions.playTabSwitch(tab)
		setActiveTab(tab)
	end

	-- Handle accepting a commission with sound feedback
	local function onAccept(commissionId: string)
		soundActions.playButtonClick("commission_accept")
		actions.acceptCommission(commissionId)
	end

	-- Handle delivering a commission with two sound effects (click + delivery)
	local function onDeliver(commissionId: string)
		soundActions.playButtonClick("commission_deliver")
		soundActions.playCommissionDeliver()
		actions.deliverCommission(commissionId)
	end

	return {
		activeTab = activeTab,
		onTabSelect = onTabSelect,
		onAccept = onAccept,
		onDeliver = onDeliver,
		onAbandon = actions.abandonCommission,
		onRefresh = actions.refreshBoard,
		onUnlock = actions.unlockTier,
	}
end

return useCommissionBoardController

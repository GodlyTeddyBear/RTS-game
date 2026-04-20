--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local React = require(ReplicatedStorage.Packages.React)

local useGold = require(script.Parent.Parent.Parent.Parent.Shop.Application.Hooks.useGold)
local useUnlockState = require(script.Parent.Parent.Parent.Parent.Unlock.Application.Hooks.useUnlockState)
local useRemoteLotActions = require(script.Parent.useRemoteLotActions)
local RemoteLotAreaViewModel = require(script.Parent.Parent.ViewModels.RemoteLotAreaViewModel)

export type TLandCustomizerController = {
	Rows: { RemoteLotAreaViewModel.TRemoteLotAreaRow },
	PendingAreaId: string?,
	ErrorMessage: string?,
	OnPurchaseArea: (areaId: string) -> (),
}

local function useLandCustomizerController(): TLandCustomizerController
	local unlockState = useUnlockState()
	local gold = useGold()
	local actions = useRemoteLotActions()
	local pendingAreaId, setPendingAreaId = React.useState(nil :: string?)
	local errorMessage, setErrorMessage = React.useState(nil :: string?)

	React.useEffect(function()
		local unlockController = Knit.GetController("UnlockController")
		local shopController = Knit.GetController("ShopController")
		if unlockController then
			unlockController:RequestUnlockState()
		end
		if shopController then
			shopController:RequestGoldState()
		end
	end, {})

	local rows = React.useMemo(function()
		return RemoteLotAreaViewModel.fromState(unlockState, gold)
	end, { unlockState, gold })

	local function handlePurchaseArea(areaId: string)
		if pendingAreaId then
			return
		end

		setPendingAreaId(areaId)
		setErrorMessage(nil)

		local promise = actions.purchaseAreaExpansion(areaId)
		if not promise then
			setPendingAreaId(nil)
			setErrorMessage("Unable to contact the remote lot service.")
			return
		end

		promise
			:andThen(function()
				setPendingAreaId(nil)
			end)
			:catch(function(err)
				setPendingAreaId(nil)
				setErrorMessage(err.message or "Expansion purchase failed.")
			end)
	end

	return {
		Rows = rows,
		PendingAreaId = pendingAreaId,
		ErrorMessage = errorMessage,
		OnPurchaseArea = handlePurchaseArea,
	}
end

return useLandCustomizerController

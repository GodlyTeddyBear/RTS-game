--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@function useCommissionActions
	@within CommissionBoardScreen
	Get commission mutation functions. Does not subscribe to atoms, so calling these will not cause re-renders.
	@return table -- Table of action functions: acceptCommission, deliverCommission, abandonCommission, unlockTier, refreshBoard
	@tag Write Hook
]=]
local function useCommissionActions()
	return {
		acceptCommission = function(commissionId: string)
			return Knit.GetController("CommissionController"):AcceptCommission(commissionId)
		end,

		deliverCommission = function(commissionId: string)
			return Knit.GetController("CommissionController"):DeliverCommission(commissionId)
		end,

		abandonCommission = function(commissionId: string)
			return Knit.GetController("CommissionController"):AbandonCommission(commissionId)
		end,

		unlockTier = function()
			return Knit.GetController("CommissionController"):UnlockTier()
		end,

		refreshBoard = function()
			return Knit.GetController("CommissionController"):RefreshBoard()
		end,
	}
end

return useCommissionActions

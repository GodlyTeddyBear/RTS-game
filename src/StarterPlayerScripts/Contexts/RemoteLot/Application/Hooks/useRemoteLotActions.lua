--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

export type TRemoteLotActions = {
	purchaseAreaExpansion: (areaId: string) -> any?,
}

local function useRemoteLotActions(): TRemoteLotActions
	local remoteLotContext = Knit.GetService("RemoteLotContext")
	local shopController = Knit.GetController("ShopController")

	return {
		purchaseAreaExpansion = function(areaId: string): any?
			if not remoteLotContext then
				warn("useRemoteLotActions: RemoteLotContext not available")
				return nil
			end

			return remoteLotContext:PurchaseAreaExpansion(areaId)
				:andThen(function(result)
					if shopController then
						shopController:RequestGoldState()
					end
					return result
				end)
		end,
	}
end

return useRemoteLotActions

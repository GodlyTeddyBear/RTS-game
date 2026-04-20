--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@function useUpgradeActions
	Write hook exposing upgrade mutation actions. Does NOT subscribe to any atom.
	@return { purchase: (upgradeId: string) -> any }
]=]
local function useUpgradeActions()
	return {
		purchase = function(upgradeId: string)
			return Knit.GetController("UpgradeController"):PurchaseUpgrade(upgradeId)
		end,
	}
end

return useUpgradeActions

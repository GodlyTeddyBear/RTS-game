--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

--[=[
	@function useCommissionState
	@within CommissionBoardScreen
	Subscribe to the commissions atom and get the current commission state. Components will re-render when state changes.
	@return any -- Current commission state from the atom
	@tag Read Hook
]=]
local function useCommissionState()
	local commissionController = Knit.GetController("CommissionController")
	local commissionsAtom = commissionController:GetCommissionsAtom()
	return useAtom(commissionsAtom)
end

return useCommissionState

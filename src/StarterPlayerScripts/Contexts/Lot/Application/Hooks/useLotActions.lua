--!strict

--[[
	useLotActions - Write hook for lot mutation actions

	Exposes lot action functions (spawn lot).
	Does NOT subscribe to any atoms - no component re-renders from this hook.

	@return { spawnLot: () -> () }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local function useLotActions()
	return {
		spawnLot = function()
			return Knit.GetController("LotController"):SpawnLot(game.Players.LocalPlayer)
		end,
	}
end

return useLotActions

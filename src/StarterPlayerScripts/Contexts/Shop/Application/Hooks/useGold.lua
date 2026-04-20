--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

--[=[
	@function useGold
	@within ShopController
	Subscribe to the player's current gold balance reactively. Hydration is handled by the screen controller on mount.
	@return number -- Current gold amount
]=]
local function useGold(): number
	local shopController = Knit.GetController("ShopController")
	if not shopController then
		warn("useGold: ShopController not available")
		return 0
	end
	local goldAtom = shopController:GetGoldAtom()
	return useAtom(goldAtom)
end

return useGold

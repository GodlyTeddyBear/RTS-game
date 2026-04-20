--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[[
	Write hook that exposes tailoring mutation actions.
	Does NOT subscribe to any atom — no re-renders from this hook.

	@return { tailItem: (recipeId: string) -> () }
]]
local function useTailoringActions()
	return {
		tailItem = function(recipeId: string)
			return Knit.GetController("TailoringController"):TailItem(recipeId)
		end,
	}
end

return useTailoringActions

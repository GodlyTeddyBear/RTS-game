--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@function useBreweryActions
	Write hook that exposes brewery mutation actions. Does NOT subscribe to any atom — no re-renders from this hook.
	@return { brewItem: (recipeId: string) -> Result<any> } -- Table with brewItem action
]=]
local function useBreweryActions()
	return {
		brewItem = function(recipeId: string)
			return Knit.GetController("BreweryController"):BrewItem(recipeId)
		end,
	}
end

return useBreweryActions

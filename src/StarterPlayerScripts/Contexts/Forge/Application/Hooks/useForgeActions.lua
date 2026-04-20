--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@function useForgeActions
	Write hook that exposes forge mutation actions. Does not subscribe to any state — use for action invocation only.
	@return { craftItem: (recipeId: string) -> Result<void> } -- Craft action
]=]
local function useForgeActions()
	return {
		craftItem = function(recipeId: string)
			return Knit.GetController("ForgeController"):CraftItem(recipeId)
		end,
	}
end

return useForgeActions

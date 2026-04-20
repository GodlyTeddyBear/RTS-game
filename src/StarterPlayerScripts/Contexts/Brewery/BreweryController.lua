--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

--[=[
	@class BreweryController
	Knit controller managing client-side brewery operations and recipe interactions.
	@client
]=]
local BreweryController = Knit.CreateController({
	Name = "BreweryController",
})

---
-- Knit Lifecycle
---

--[=[
	Initialize the registry and local state.
	@within BreweryController
]=]
function BreweryController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	registry:InitAll()
end

--[=[
	Register the server BreweryContext service and establish cross-context dependencies.
	@within BreweryController
]=]
function BreweryController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local BreweryContext = Knit.GetService("BreweryContext")
	registry:Register("BreweryContext", BreweryContext)

	self.BreweryContext = BreweryContext
end

--[=[
	Brew an item by recipe ID and propagate any errors to the console.
	@within BreweryController
	@param recipeId string -- The ID of the recipe to brew
	@return Result<any> -- Success or error from the brew operation
]=]
function BreweryController:BrewItem(recipeId: string)
	return self.BreweryContext:BrewItem(recipeId)
		:catch(function(err)
			warn("[BreweryController:BrewItem]", err.type, err.message)
		end)
end

--[=[
	Fetch all available brewery recipes from the server and propagate any errors to the console.
	@within BreweryController
	@return Result<any> -- Available recipes or error from the server
]=]
function BreweryController:GetBreweryRecipes()
	return self.BreweryContext:GetBreweryRecipes()
		:catch(function(err)
			warn("[BreweryController:GetBreweryRecipes]", err.type, err.message)
		end)
end

return BreweryController

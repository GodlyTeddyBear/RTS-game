--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

--[=[
	@class ForgeController
	Client controller for the Forge feature; manages crafting and recipe discovery.
	@client
]=]
local ForgeController = Knit.CreateController({
	Name = "ForgeController",
})

---
-- Knit Lifecycle
---

--[=[
	Initialize the controller's dependency registry and eagerly load all context modules.
	@within ForgeController
]=]
function ForgeController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	registry:InitAll()

	--print("ForgeController initialized")
end

--[=[
	Resolve server Forge service after all controllers and services are loaded.
	@within ForgeController
]=]
function ForgeController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local ForgeContext = Knit.GetService("ForgeContext")
	registry:Register("ForgeContext", ForgeContext)

	self.ForgeContext = ForgeContext

	--print("ForgeController started")
end

---
-- Public API Methods
---

--[=[
	Craft an item by recipe ID.
	@within ForgeController
	@param recipeId string -- The recipe to craft
	@return Result<void> -- Result of the craft operation
	@yields
]=]
function ForgeController:CraftItem(recipeId: string)
	return self.ForgeContext:CraftItem(recipeId)
		:catch(function(err)
			warn("[ForgeController:CraftItem]", err.type, err.message)
		end)
end

--[=[
	Fetch all available recipes from the server.
	@within ForgeController
	@return Result<{any}> -- List of recipe data
	@yields
]=]
function ForgeController:GetRecipes()
	return self.ForgeContext:GetRecipes()
		:catch(function(err)
			warn("[ForgeController:GetRecipes]", err.type, err.message)
		end)
end

return ForgeController

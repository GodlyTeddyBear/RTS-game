--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local BreweryRecipeConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryRecipeConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Catch = Result.Catch
local Err = Result.Err

-- Domain Policies
local BrewPolicy = require(script.Parent.BreweryDomain.Policies.BrewPolicy)

-- Application Services
local BrewItem = require(script.Parent.Application.Commands.BrewItem)

--[=[
	@class BreweryContext
	Knit service orchestrating potion brewing operations.
	Delegates recipe validation to BrewPolicy and item execution to BrewItem command.
	@server
]=]
local BreweryContext = Knit.CreateService({
	Name = "BreweryContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function BreweryContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Domain Policies
	registry:Register("BrewPolicy", BrewPolicy.new(), "Domain")

	-- Application Services
	registry:Register("BrewItem", BrewItem.new(), "Application")

	registry:InitAll()
end

function BreweryContext:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies (must happen after all services init)
	local InventoryContext = Knit.GetService("InventoryContext")
	self.InventoryContext = InventoryContext
	registry:Register("InventoryContext", InventoryContext)
	registry:Register("UnlockContext", Knit.GetService("UnlockContext"))

	registry:StartOrdered({ "Domain", "Application" })

	-- Cache refs for event handlers
	self.BrewItem = registry:Get("BrewItem")

	print("BreweryContext started")
end

---
-- Server-to-Server API Methods
---

--[=[
	Brew a recipe for a player by user ID.
	@within BreweryContext
	@param userId number -- Player's user ID
	@param recipeId string -- Recipe to brew
	@return Result -- Ok with output item ID, or Err if validation fails
	@error PlayerNotFound -- Player is no longer in the game
]=]
function BreweryContext:BrewItemForPlayer(userId: number, recipeId: string): Result.Result<any>
	return Catch(function()
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		if not player then
			return Err("PlayerNotFound", "Player not found", { userId = userId })
		end
		return self.BrewItem:Execute(player, userId, recipeId)
	end, "Brewery:BrewItemForPlayer")
end

---
-- Client API Methods
---

--[=[
	Brew a recipe for the requesting player.
	@within BreweryContext
	@param recipeId string -- Recipe to brew
	@return Result -- Ok with output item ID, or Err if validation fails
]=]
function BreweryContext.Client:BrewItem(player: Player, recipeId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.BrewItem:Execute(player, userId, recipeId)
	end, "Brewery.Client:BrewItem")
end

--[=[
	Fetch all available brewery recipes.
	@within BreweryContext
	@return table -- Recipe configuration keyed by recipe ID
]=]
function BreweryContext.Client:GetBreweryRecipes(_player: Player): any
	return BreweryRecipeConfig
end

WrapContext(BreweryContext, "BreweryContext")

return BreweryContext

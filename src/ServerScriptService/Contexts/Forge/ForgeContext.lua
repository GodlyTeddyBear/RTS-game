--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Catch = Result.Catch
local Err = Result.Err

-- Domain Policies
local CraftPolicy = require(script.Parent.ForgeDomain.Policies.CraftPolicy)

-- Application Services
local CraftItem = require(script.Parent.Application.Commands.CraftItem)

--[=[
	@class ForgeContext
	Manages crafting operations and recipe execution. Provides both server-to-server and client APIs for item crafting.
	@server
]=]
local ForgeContext = Knit.CreateService({
	Name = "ForgeContext",
	Client = {},
})

--[=[
	@method KnitInit
	@within ForgeContext
	Initialize the Forge context: create registry and register domain policies and application services.
]=]
function ForgeContext:KnitInit()
	-- Create registry and store reference for service lifecycle management
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Register domain policies and application services
	registry:Register("CraftPolicy", CraftPolicy.new(), "Domain")
	registry:Register("CraftItem", CraftItem.new(), "Application")

	-- Initialize all registered services
	registry:InitAll()
end

--[=[
	@method KnitStart
	@within ForgeContext
	Start the Forge context: resolve cross-context dependencies, start services, and cache service references.
]=]
function ForgeContext:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependency (must happen after all services init)
	local InventoryContext = Knit.GetService("InventoryContext")
	local UnlockContext = Knit.GetService("UnlockContext")
	local BuildingContext = Knit.GetService("BuildingContext")
	self.InventoryContext = InventoryContext
	registry:Register("InventoryContext", InventoryContext)
	registry:Register("UnlockContext", UnlockContext)
	registry:Register("BuildingContext", BuildingContext)

	-- Start services in layered order: domain policies before application commands
	registry:StartOrdered({ "Domain", "Application" })

	-- Cache service reference for direct access in event handlers
	self.CraftItem = registry:Get("CraftItem")

	print("ForgeContext started")
end

--[=[
	@method CraftItemForPlayer
	@within ForgeContext
	Craft an item for a player by user ID. Looks up the player, executes the craft, and returns the crafted item ID or error.
	@param userId number -- The player's user ID
	@param recipeId string -- The recipe to craft
	@return Result<string> -- Ok with crafted item ID, or Err with failure reason
]=]
function ForgeContext:CraftItemForPlayer(userId: number, recipeId: string): Result.Result<any>
	return Catch(function()
		-- Resolve player from user ID
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		if not player then
			return Err("PlayerNotFound", "Player not found", { userId = userId })
		end
		return self.CraftItem:Execute(player, userId, recipeId)
	end, "Forge:CraftItemForPlayer")
end

--[=[
	@method CraftItem
	@within ForgeContext
	@tag client
	Craft an item for the requesting player. Executes the craft command with the player context.
	@param player Player -- The player requesting the craft
	@param recipeId string -- The recipe to craft
	@return Result<string> -- Ok with crafted item ID, or Err with failure reason
]=]
function ForgeContext.Client:CraftItem(player: Player, recipeId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.CraftItem:Execute(player, userId, recipeId)
	end, "Forge.Client:CraftItem")
end

--[=[
	@method GetRecipes
	@within ForgeContext
	@tag client
	Fetch all available recipes. Returns the entire recipe configuration for client-side UI population.
	@param player Player -- The requesting player (unused, required by Knit signature)
	@return any -- The complete RecipeConfig table
]=]
function ForgeContext.Client:GetRecipes(_player: Player): any
	return RecipeConfig
end

WrapContext(ForgeContext, "ForgeContext")

return ForgeContext

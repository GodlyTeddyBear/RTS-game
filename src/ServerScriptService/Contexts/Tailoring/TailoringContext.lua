--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local TailoringRecipeConfig = require(ReplicatedStorage.Contexts.Tailoring.Config.TailoringRecipeConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Catch = Result.Catch
local Try = Result.Try
local fromNilable = Result.fromNilable
local MentionSuccess = Result.MentionSuccess

-- Domain Policies
local TailPolicy = require(script.Parent.TailoringDomain.Policies.TailPolicy)

-- Application Services
local TailItem = require(script.Parent.Application.Commands.TailItem)

--[=[
	@class TailoringContext
	Knit service for tailoring recipes and producing output items from ingredients.
	@server
]=]
local TailoringContext = Knit.CreateService({
	Name = "TailoringContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function TailoringContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Domain Policies
	registry:Register("TailPolicy", TailPolicy.new(), "Domain")

	-- Application Services
	registry:Register("TailItem", TailItem.new(), "Application")

	registry:InitAll()
end

function TailoringContext:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies (must happen after all services init)
	local InventoryContext = Knit.GetService("InventoryContext")
	self.InventoryContext = InventoryContext
	registry:Register("InventoryContext", InventoryContext)
	registry:Register("UnlockContext", Knit.GetService("UnlockContext"))

	registry:StartOrdered({ "Domain", "Application" })

	-- Cache refs for event handlers
	self.TailItem = registry:Get("TailItem")

	MentionSuccess("TailoringContext:KnitStart", "TailoringContext started")
end

---
-- Server-to-Server API Methods
---

--[=[
	Tail an item for a player by recipe ID. Fetches the player and delegates to TailItem command.
	@within TailoringContext
	@param userId number -- Player's UserId
	@param recipeId string -- The tailoring recipe to execute
	@return Result<string> -- Success returns the output item ID
	@error "PlayerNotFound" -- Player is not in the game
]=]
function TailoringContext:TailItemForPlayer(userId: number, recipeId: string): Result.Result<any>
	return Catch(function()
		local player = Try(fromNilable(
			game:GetService("Players"):GetPlayerByUserId(userId),
			"PlayerNotFound",
			"Player not found",
			{ userId = userId }
		))
		return self.TailItem:Execute(player, userId, recipeId)
	end, "Tailoring:TailItemForPlayer")
end

---
-- Client API Methods
---

--[=[
	Tail an item for the connected player by recipe ID.
	@within TailoringContext
	@param player Player -- The player making the request
	@param recipeId string -- The tailoring recipe to execute
	@return Result<string> -- Success returns the output item ID
]=]
function TailoringContext.Client:TailItem(player: Player, recipeId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.TailItem:Execute(player, userId, recipeId)
	end, "Tailoring.Client:TailItem")
end

--[=[
	Fetch all available tailoring recipes.
	@within TailoringContext
	@param _player Player -- The player making the request
	@return any -- All tailoring recipe configurations
]=]
function TailoringContext.Client:GetTailoringRecipes(_player: Player): any
	return TailoringRecipeConfig
end

WrapContext(TailoringContext, "TailoringContext")

return TailoringContext

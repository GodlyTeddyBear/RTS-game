--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local Errors = require(script.Parent.Errors)
local CraftPolicy = require(script.Parent.ForgeDomain.Policies.CraftPolicy)
local CraftItem = require(script.Parent.Application.Commands.CraftItem)

local Catch = Result.Catch
local Ensure = Result.Ensure
local Ok = Result.Ok

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "CraftPolicy",
		Module = CraftPolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "CraftItem",
		Module = CraftItem,
		CacheAs = "_craftItemCommand",
	},
}

local ForgeModules: BaseContext.TModuleLayers = {
	Domain = DomainModules,
	Application = ApplicationModules,
}

local ForgeContext = Knit.CreateService({
	Name = "ForgeContext",
	Client = {},
	Modules = ForgeModules,
	ExternalServices = {
		{ Name = "InventoryContext", CacheAs = "_inventoryContext" },
	},
})

local ForgeBaseContext = BaseContext.new(ForgeContext)

function ForgeContext:KnitInit()
	ForgeBaseContext:KnitInit()
end

function ForgeContext:KnitStart()
	ForgeBaseContext:KnitStart()
end

function ForgeContext:CraftItemForPlayer(userId: number, recipeId: string): Result.Result<string>
	return Catch(function()
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		Ensure(player, "PlayerNotFound", Errors.PLAYER_NOT_FOUND, {
			userId = userId,
		})

		return self._craftItemCommand:Execute(player, userId, recipeId)
	end, "Forge:CraftItemForPlayer")
end

function ForgeContext:GetRecipes(): Result.Result<any>
	return Ok(RecipeConfig)
end

function ForgeContext.Client:CraftItem(player: Player, recipeId: string): Result.Result<string>
	return Catch(function()
		return self.Server._craftItemCommand:Execute(player, player.UserId, recipeId)
	end, "Forge.Client:CraftItem")
end

function ForgeContext.Client:GetRecipes(_player: Player): Result.Result<any>
	return self.Server:GetRecipes()
end

return ForgeContext

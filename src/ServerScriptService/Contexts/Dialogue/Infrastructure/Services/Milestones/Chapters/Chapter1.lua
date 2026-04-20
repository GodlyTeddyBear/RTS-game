--!strict

--[=[
	@class Chapter1
	Milestone definitions for Chapter 1. Sets economy and progression flags based on guide events.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)
local SubscriptionFactory = require(script.Parent.Parent.SubscriptionFactory)

type TMilestoneContext = {
	Events: any,
	setMilestone: (userId: number, flagName: string) -> (),
	getFlagsReadOnly: (userId: number) -> { [string]: any }?,
	getPlayerByUserId: (userId: number) -> Player?,
	getProfileData: (player: Player) -> any,
	mentionChapterAdvanced: (userId: number, newChapter: number) -> (),
}

local SMELTER_COST: number = BuildingConfig.Forge.Buildings.Smelter.Cost.Gold

local Chapter1 = {}

--[=[
	Build Chapter 1 milestone subscriptions from event definitions.
	@within Chapter1
	@param context table -- Milestone context providing utilities and event bus
	@return table -- Subscriptions organized by category
]=]
function Chapter1.Build(context: TMilestoneContext): { [string]: { SubscriptionFactory.TSubscription } }
	return SubscriptionFactory.Build({
		economyMilestones = {
			{
				eventName = context.Events.Inventory.ItemSold,
				handler = function(ctx: TMilestoneContext, userId: number, _itemId: string, _qty: number, _revenue: number)
					ctx.setMilestone(userId, "Ch1_ShopOpen")
				end,
			},
			{
				eventName = context.Events.Inventory.ItemSold,
				handler = function(ctx: TMilestoneContext, userId: number, _itemId: string, _qty: number, _revenue: number)
					local flags = ctx.getFlagsReadOnly(userId)
					if not flags or flags["Ch1_SmelterAffordable"] then
						return
					end

					local player = ctx.getPlayerByUserId(userId)
					if not player then
						return
					end

					local data = ctx.getProfileData(player)
					if data and (data.Gold or 0) >= SMELTER_COST then
						ctx.setMilestone(userId, "Ch1_SmelterAffordable")
					end
				end,
			},
		},
		progressionMilestones = {
			{
				eventName = context.Events.Guide.MinerHired,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch1_MinerHired")
				end,
			},
			{
				eventName = context.Events.Guide.LumberjackHired,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch1_LumberjackHired")
				end,
			},
			{
				eventName = context.Events.Guide.CharcoalCrafted,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch1_CharcoalCrafted")
				end,
			},
			{
				eventName = context.Events.Guide.SmelterPlaced,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch1_SmelterPlaced")
				end,
			},
		},
		chapterObservers = {
			{
				eventName = context.Events.Chapter.ChapterAdvanced,
				handler = function(ctx: TMilestoneContext, userId: number, newChapter: number)
					ctx.mentionChapterAdvanced(userId, newChapter)
				end,
			},
		},
	}, context)
end

return table.freeze(Chapter1)

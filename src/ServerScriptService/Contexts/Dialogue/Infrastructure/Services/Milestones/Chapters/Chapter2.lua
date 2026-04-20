--!strict

--[=[
	@class Chapter2
	Milestone definitions for Chapter 2. Sets expedition and combat flags based on guide events.
	@server
]=]

local SubscriptionFactory = require(script.Parent.Parent.SubscriptionFactory)

type TMilestoneContext = {
	Events: any,
	setMilestone: (userId: number, flagName: string) -> (),
}

local Chapter2 = {}

--[=[
	Build Chapter 2 milestone subscriptions from event definitions.
	@within Chapter2
	@param context table -- Milestone context providing utilities and event bus
	@return table -- Subscriptions organized by category
]=]
function Chapter2.Build(context: TMilestoneContext): { [string]: { SubscriptionFactory.TSubscription } }
	return SubscriptionFactory.Build({
		chapter2Milestones = {
			{
				eventName = context.Events.Guide.Ch2IntroReady,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch2_IntroSeen")
				end,
			},
			{
				eventName = context.Events.Guide.Ch2ExpeditionLaunched,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch2_IntroSeen")
					ctx.setMilestone(userId, "Ch2_ExpeditionLaunched")
				end,
			},
			{
				eventName = context.Events.Guide.Ch2OutcomeVictory,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch2_OutcomeVictory")
					ctx.setMilestone(userId, "Ch2_FirstVictory")
				end,
			},
			{
				eventName = context.Events.Guide.Ch2OutcomeDefeat,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch2_OutcomeDefeat")
				end,
			},
			{
				eventName = context.Events.Guide.Ch2OutcomeFled,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch2_OutcomeFled")
				end,
			},
		},
	}, context)
end

return table.freeze(Chapter2)

--!strict

--[=[
	@class Chapter3
	Milestone definitions for Chapter 3. Sets brewery and expedition flags based on guide events.
	@server
]=]

local SubscriptionFactory = require(script.Parent.Parent.SubscriptionFactory)

type TMilestoneContext = {
	Events: any,
	setMilestone: (userId: number, flagName: string) -> (),
}

local Chapter3 = {}

--[=[
	Build Chapter 3 milestone subscriptions from event definitions.
	@within Chapter3
	@param context table -- Milestone context providing utilities and event bus
	@return table -- Subscriptions organized by category
]=]
function Chapter3.Build(context: TMilestoneContext): { [string]: { SubscriptionFactory.TSubscription } }
	return SubscriptionFactory.Build({
		chapter3Milestones = {
			{
				eventName = context.Events.Guide.Ch3IntroReady,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch3_IntroSeen")
				end,
			},
			{
				eventName = context.Events.Guide.Ch3BrewerHired,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch3_BrewerHired")
				end,
			},
			{
				eventName = context.Events.Guide.Ch3ExpeditionLaunched,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch3_ExpeditionLaunched")
				end,
			},
			{
				eventName = context.Events.Guide.Ch3OutcomeVictory,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch3_OutcomeVictory")
				end,
			},
			{
				eventName = context.Events.Guide.Ch3OutcomeDefeat,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch3_OutcomeDefeat")
				end,
			},
			{
				eventName = context.Events.Guide.Ch3OutcomeFled,
				handler = function(ctx: TMilestoneContext, userId: number)
					ctx.setMilestone(userId, "Ch3_OutcomeFled")
				end,
			},
		},
	}, context)
end

return table.freeze(Chapter3)

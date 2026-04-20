--!strict

--[=[
	@class SubscriptionFactory
	Utility factory to convert subscription definitions into bound subscriptions for event listeners.
	@server
]=]

--[=[
	@interface Subscription
	Represents a bound event subscription ready to register.
	.eventName string -- The event name to listen to
	.callback function -- The handler to invoke
]=]
export type TSubscription = {
	eventName: string,
	callback: (...any) -> (),
}

export type TSubscriptionDefinition<TContext> = {
	eventName: string,
	handler: (context: TContext, ...any) -> (),
}

export type TSubscriptionDefinitions<TContext> = {
	[string]: { TSubscriptionDefinition<TContext> },
}

local SubscriptionFactory = {}

--[=[
	Build subscriptions from definitions, binding each handler with the provided context.
	@within SubscriptionFactory
	@param definitionsByCategory table -- Categorized definitions mapping category names to handler lists
	@param context any -- The context to bind to each handler
	@return table -- Subscriptions organized by category
]=]
function SubscriptionFactory.Build<TContext>(
	definitionsByCategory: TSubscriptionDefinitions<TContext>,
	context: TContext
): { [string]: { TSubscription } }
	local subscriptionsByCategory: { [string]: { TSubscription } } = {}

	for categoryName, definitions in definitionsByCategory do
		local subscriptions: { TSubscription } = {}

		for _, definition in definitions do
			table.insert(subscriptions, {
				eventName = definition.eventName,
				callback = function(...: any)
					definition.handler(context, ...)
				end,
			})
		end

		subscriptionsByCategory[categoryName] = subscriptions
	end

	return subscriptionsByCategory
end

return table.freeze(SubscriptionFactory)

--!strict

local UnitServiceProxyResolverFactory = {}

function UnitServiceProxyResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
	MovementProxyResolver: any?,
	GetRuntimeOwner: (() -> any)?,
}): any
	return table.freeze({
		BuildFacts = function(entity: number): { [string]: any }
			local pathState = dependencies.UnitEntityFactory:GetPathState(entity)
			return {
				HasGoalTarget = pathState ~= nil and pathState.GoalPosition ~= nil,
			}
		end,
		BuildServices = function(entity: number, currentTime: number, tickId: number?): { [string]: any }
			local services = {
				CurrentTime = currentTime,
				UnitEntityFactory = dependencies.UnitEntityFactory,
			}

			if dependencies.MovementProxyResolver ~= nil then
				services.MovementService = dependencies.MovementProxyResolver.CreateProxy(entity)
			end
			if type(tickId) == "number" then
				services.TickId = tickId
			end
			if dependencies.GetRuntimeOwner ~= nil then
				services.UnitContext = dependencies.GetRuntimeOwner()
			end

			return services
		end,
	})
end

return table.freeze(UnitServiceProxyResolverFactory)

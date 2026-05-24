--!strict

local UnitServiceProxyResolverFactory = {}

function UnitServiceProxyResolverFactory.Create(dependencies: {
	UnitEntityFactory: any,
	MovementProxyResolver: any?,
	GetRuntimeOwner: (() -> any)?,
}): any
	return table.freeze({
		BuildServices = function(entity: number, currentTime: number, tickId: number?): { [string]: any }
			local unitEntityFactory = dependencies.UnitEntityFactory
			local services = {
				CurrentTime = currentTime,
				UnitEntityFactory = {
					ResolveRuntimeEntity = function(_proxy: any, _runtimeId: number): number
						return entity
					end,
					IsActive = function(_proxy: any, _runtimeId: number): boolean
						return unitEntityFactory:IsActive(entity)
					end,
					GetPathState = function(_proxy: any, _runtimeId: number)
						return unitEntityFactory:GetPathState(entity)
					end,
					SetGoalPosition = function(_proxy: any, _runtimeId: number, goalPosition: Vector3)
						unitEntityFactory:SetGoalPosition(entity, goalPosition)
					end,
					ClearGoalPosition = function(_proxy: any, _runtimeId: number)
						unitEntityFactory:ClearGoalPosition(entity)
					end,
					SetPathMoving = function(_proxy: any, _runtimeId: number, isMoving: boolean)
						unitEntityFactory:SetPathMoving(entity, isMoving)
					end,
				},
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

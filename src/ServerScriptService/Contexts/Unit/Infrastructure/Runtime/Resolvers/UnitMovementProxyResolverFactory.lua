--!strict

local UnitMovementProxyResolverFactory = {}

function UnitMovementProxyResolverFactory.Create(dependencies: {
	MovementService: any,
}): any
	return table.freeze({
		CreateProxy = function(entity: number): any
			return {
				StartUnitMove = function(_proxy: any, _runtimeId: number): (boolean, string?)
					return dependencies.MovementService:StartUnitMove(entity)
				end,
				StepUnitMove = function(_proxy: any, _runtimeId: number): (boolean, string?)
					return dependencies.MovementService:StepUnitMove(entity)
				end,
				StopUnitMovement = function(_proxy: any, _runtimeId: number)
					dependencies.MovementService:StopUnitMovement(entity)
				end,
			}
		end,
	})
end

return table.freeze(UnitMovementProxyResolverFactory)

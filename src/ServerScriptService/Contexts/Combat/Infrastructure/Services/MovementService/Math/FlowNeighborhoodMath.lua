--!strict
--!optimize 2
--!native

local MovementTypes = require(script.Parent.Parent.Types)

type TFlowFrameStateHandle = MovementTypes.TFlowFrameStateHandle

local FlowNeighborhoodMath = {}

function FlowNeighborhoodMath.ResolveCellWidthForEntityIndices(
	frameState: TFlowFrameStateHandle,
	entityIndices: { number }
): number
	local maxRadius = 0
	for _, entityIndex in ipairs(entityIndices) do
		local radius = frameState:GetRadius(entityIndex)
		if radius then
			maxRadius = math.max(maxRadius, radius)
		end
	end
	return math.max(4, maxRadius * 2)
end

return table.freeze(FlowNeighborhoodMath)

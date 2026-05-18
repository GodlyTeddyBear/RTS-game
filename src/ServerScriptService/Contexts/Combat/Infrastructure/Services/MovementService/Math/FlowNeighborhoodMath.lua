--!strict
--!optimize 2
--!native

local MovementMath = require(script.Parent.MovementMath)
local MovementTypes = require(script.Parent.Parent.Types)

type TFlowFrameInput = MovementTypes.TFlowFrameInput

local FlowNeighborhoodMath = {}

function FlowNeighborhoodMath.ResolveCellWidthForInputs(inputs: { TFlowFrameInput }): number
	local maxRadius = 0
	for _, input in ipairs(inputs) do
		maxRadius = math.max(maxRadius, input.Radius)
	end
	return math.max(4, maxRadius * 2)
end

function FlowNeighborhoodMath.BuildGoalNeighborhoodData(
	inputs: { TFlowFrameInput },
	entityIndexByEntity: { [number]: number },
	clumpTouchPaddingStuds: number
): ({ [number]: boolean }, { number }, { number }, { number })
	local cellWidthStuds = FlowNeighborhoodMath.ResolveCellWidthForInputs(inputs)
	local bucketsByCell: { [number]: { number } } = {}
	local inputByEntityIndex: { [number]: TFlowFrameInput } = {}
	local gxByEntityIndex: { [number]: number } = {}
	local gzByEntityIndex: { [number]: number } = {}
	local touchedSettledNeighborByEntity: { [number]: boolean } = {}
	local neighborStartIndex: { number } = {}
	local neighborCount: { number } = {}
	local neighborEntityIndex: { number } = {}

	for _, input in ipairs(inputs) do
		local entityIndex = entityIndexByEntity[input.Entity]
		if entityIndex ~= nil then
			local gx, gz = MovementMath.FlatPositionToCell(input.FlatPosition, cellWidthStuds)
			inputByEntityIndex[entityIndex] = input
			gxByEntityIndex[entityIndex] = gx
			gzByEntityIndex[entityIndex] = gz
			local key = MovementMath.PackedSeparationCellKey(gx, gz)
			local bucket = bucketsByCell[key]
			if bucket == nil then
				bucket = {}
				bucketsByCell[key] = bucket
			end
			table.insert(bucket, entityIndex)
		end
	end

	for _, input in ipairs(inputs) do
		local entityIndex = entityIndexByEntity[input.Entity]
		if entityIndex ~= nil then
			local gx = gxByEntityIndex[entityIndex]
			local gz = gzByEntityIndex[entityIndex]
			local seenNeighborIndex: { [number]: boolean } = {}
			local startIndex = #neighborEntityIndex + 1

			for dx = -1, 1 do
				for dz = -1, 1 do
					local bucket = bucketsByCell[MovementMath.PackedSeparationCellKey(gx + dx, gz + dz)]
					if bucket ~= nil then
						for _, otherEntityIndex in ipairs(bucket) do
							if otherEntityIndex ~= entityIndex and seenNeighborIndex[otherEntityIndex] ~= true then
								local otherInput = inputByEntityIndex[otherEntityIndex]
								seenNeighborIndex[otherEntityIndex] = true
								table.insert(neighborEntityIndex, otherEntityIndex)

								if input.IsSettled and otherInput ~= nil and not otherInput.IsSettled then
									local touchDistance = input.Radius + otherInput.Radius + clumpTouchPaddingStuds
									if (input.FlatPosition - otherInput.FlatPosition).Magnitude <= touchDistance then
										touchedSettledNeighborByEntity[otherInput.Entity] = true
									end
								end
							end
						end
					end
				end
			end

			neighborStartIndex[entityIndex] = startIndex
			neighborCount[entityIndex] = #neighborEntityIndex - startIndex + 1
		end
	end

	return touchedSettledNeighborByEntity, neighborStartIndex, neighborCount, neighborEntityIndex
end

return table.freeze(FlowNeighborhoodMath)

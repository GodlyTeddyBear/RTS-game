--!strict

--[=[
	@class PieceAlignmentCalculator
	Pure CFrame math for aligning modular dungeon pieces without side effects.
	@server
]=]

local PieceAlignmentCalculator = {}
PieceAlignmentCalculator.__index = PieceAlignmentCalculator

export type TPieceAlignmentCalculator = typeof(setmetatable({}, PieceAlignmentCalculator))

function PieceAlignmentCalculator.new(): TPieceAlignmentCalculator
	local self = setmetatable({}, PieceAlignmentCalculator)
	return self
end

--[=[
	Calculate the CFrame where the next piece's Floor should be placed, aligning it flush with the current piece's front edge.
	@within PieceAlignmentCalculator
	@param currentFloorCFrame CFrame -- The current piece's Floor CFrame
	@param currentFloorSize Vector3 -- The current piece's Floor Size
	@param nextFloorSize Vector3 -- The next piece's Floor Size
	@return CFrame -- The target CFrame for the next piece's Floor center
]=]
function PieceAlignmentCalculator:CalculateNextPieceCFrame(
	currentFloorCFrame: CFrame,
	currentFloorSize: Vector3,
	nextFloorSize: Vector3
): CFrame
	-- Distance from current Floor center to its front edge
	local currentFrontOffset = currentFloorSize.Z / 2

	-- Distance from next Floor center to its back edge
	local nextBackOffset = nextFloorSize.Z / 2

	-- Total forward offset along the current Floor's forward direction (-Z in local space)
	local totalOffset = currentFrontOffset + nextBackOffset

	return currentFloorCFrame * CFrame.new(0, 0, -totalOffset)
end

--[=[
	Calculate the base offset CFrame for a player's dungeon, spaced along the X-axis to prevent overlap.
	@within PieceAlignmentCalculator
	@param playerIndex number -- Unique incrementing index per player dungeon
	@param offsetSpacing number -- Studs between each dungeon on the X-axis
	@return CFrame -- The base position for this player's dungeon
]=]
function PieceAlignmentCalculator:CalculateBaseOffset(playerIndex: number, offsetSpacing: number): CFrame
	return CFrame.new(playerIndex * offsetSpacing, 0, 0)
end

return PieceAlignmentCalculator

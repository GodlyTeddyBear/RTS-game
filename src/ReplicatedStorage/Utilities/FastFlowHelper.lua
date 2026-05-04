--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastFlow = require(ReplicatedStorage.Utilities.FastFlow)

local ZERO_STEERING_EPSILON_SQUARED = 1e-6

export type TFlowGridMapping = {
	OriginWorld: Vector3,
	CellWidthStuds: number,
	GridHalfSize: number,
}

type TFastFlowPathfinder = any
type TFastFlowFlowfield = any

local FastFlowHelper = {}

local function _IsCellInBounds(cell: Vector2, mapping: TFlowGridMapping): boolean
	local halfSize = mapping.GridHalfSize
	return math.abs(cell.X) <= halfSize and math.abs(cell.Y) <= halfSize
end

-- Grid cell (0, 0) maps to OriginWorld.XZ and each cell step is CellWidthStuds.
function FastFlowHelper.WorldXZToGridCell(world: Vector3, mapping: TFlowGridMapping): Vector2
	local cellWidthStuds = mapping.CellWidthStuds
	if cellWidthStuds <= 0 then
		return Vector2.zero
	end

	local relative = world - mapping.OriginWorld
	return Vector2.new(math.round(relative.X / cellWidthStuds), math.round(relative.Z / cellWidthStuds))
end

function FastFlowHelper.GridCellToWorldXZ(cell: Vector2, mapping: TFlowGridMapping, yLevel: number?): Vector3
	local originWorld = mapping.OriginWorld
	local y = if yLevel ~= nil then yLevel else originWorld.Y
	local cellWidthStuds = mapping.CellWidthStuds
	return Vector3.new(originWorld.X + cell.X * cellWidthStuds, y, originWorld.Z + cell.Y * cellWidthStuds)
end

function FastFlowHelper.CreatePathfinderFromWalls(
	walls: FastFlow.Grid,
	chunkSize: number?,
	omitPreprocessing: boolean?
): TFastFlowPathfinder
	return FastFlow.NewPathfinder(walls, chunkSize, omitPreprocessing)
end

function FastFlowHelper.GenerateFlowfieldWorld(
	pathfinder: TFastFlowPathfinder,
	goalWorld: Vector3,
	mapping: TFlowGridMapping,
	startPositionsWorld: { Vector3 }?
): TFastFlowFlowfield?
	local goalCell = pathfinder:FindOpenCell(FastFlowHelper.WorldXZToGridCell(goalWorld, mapping))
	if goalCell == nil then
		return nil
	end

	local startCells = nil

	if startPositionsWorld ~= nil then
		startCells = {}
		for _, startWorld in ipairs(startPositionsWorld) do
			local openStartCell = pathfinder:FindOpenCell(FastFlowHelper.WorldXZToGridCell(startWorld, mapping))
			if openStartCell ~= nil then
				table.insert(startCells, openStartCell)
			end
		end
		if #startCells == 0 then
			startCells = nil
		end
	end

	return pathfinder:GenerateFlowfield(goalCell, startCells)
end

function FastFlowHelper.MergeFlowfieldWorld(
	pathfinder: TFastFlowPathfinder,
	flowfield: TFastFlowFlowfield,
	startWorld: Vector3,
	mapping: TFlowGridMapping
): TFastFlowFlowfield?
	local startCell = FastFlowHelper.WorldXZToGridCell(startWorld, mapping)
	local openStartCell = pathfinder:FindOpenCell(startCell)
	if openStartCell == nil then
		return nil
	end

	return pathfinder:MergeFlowfield(flowfield, openStartCell)
end

function FastFlowHelper.FindOpenCellWorld(
	pathfinder: TFastFlowPathfinder,
	worldPosition: Vector3,
	mapping: TFlowGridMapping,
	yLevel: number?
): Vector3?
	local openCell = pathfinder:FindOpenCell(FastFlowHelper.WorldXZToGridCell(worldPosition, mapping))
	if openCell == nil then
		return nil
	end

	return FastFlowHelper.GridCellToWorldXZ(openCell, mapping, yLevel)
end

function FastFlowHelper.GetSteeringWorldXZ(
	flowfield: TFastFlowFlowfield,
	unitWorld: Vector3,
	mapping: TFlowGridMapping
): Vector3?
	local cell = FastFlowHelper.WorldXZToGridCell(unitWorld, mapping)
	if not _IsCellInBounds(cell, mapping) then
		return nil
	end

	local flowDirection = flowfield:GetDirection(cell)
	if flowDirection == nil then
		return nil
	end

	local magnitudeSquared = flowDirection.X * flowDirection.X + flowDirection.Y * flowDirection.Y
	if magnitudeSquared <= ZERO_STEERING_EPSILON_SQUARED then
		return nil
	end

	local inverseMagnitude = 1 / math.sqrt(magnitudeSquared)
	return Vector3.new(flowDirection.X * inverseMagnitude, 0, flowDirection.Y * inverseMagnitude)
end

function FastFlowHelper.ApplyHumanoidMove(
	humanoid: Humanoid,
	flowfield: TFastFlowFlowfield,
	unitWorld: Vector3,
	mapping: TFlowGridMapping
): (boolean, Vector3?)
	local steering = FastFlowHelper.GetSteeringWorldXZ(flowfield, unitWorld, mapping)
	if steering == nil then
		humanoid:Move(Vector3.zero)
		return false, nil
	end

	humanoid:Move(steering)
	return true, steering
end

return FastFlowHelper

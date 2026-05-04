--[[
	Parameters you can play around with:
]]

local NUM_UNITS = 200
local UNIT_SPEED = 25 -- in terms of studs/sec
local SHOW_WALLS = true
local SHOW_CHUNKS = true
local SHOW_GRID = true
local SHOW_HPA = false

--[[
	Constants and Functions
]]

local RunService = game:GetService("RunService")
local Storage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local FastFlow = require(Storage.FastFlow)
local Player = Players.LocalPlayer
local Grid = FastFlow.Grid

local newCFrameAngles = CFrame.Angles
local newCFrame = CFrame.new
local newVector2 = Vector2.new
local newVector3 = Vector3.new
local random = math.random
local round = math.round
local sqrt = math.sqrt
local ceil = math.ceil
local min = math.min
local max = math.max
local abs = math.abs
local waitOneFrame = task.wait
local insert = table.insert
local sort = table.sort

local vector3ToGridCoord = function(pos, width)
	return newVector2(round(pos.X / width), round(pos.Z / width))
end
local vector2ToGridCoord = function(pos, width)
	return newVector2(round(pos.X / width), round(pos.Y / width))
end
local vector3ToVector2 = function(pos)
	return newVector2(pos.X, pos.Z)
end
local forBox = function(corner1, corner2, funct)
	for x = corner1.X, corner2.X, 1 do
		for y = corner1.Y, corner2.Y, 1 do
			funct(newVector2(x, y))
		end
	end
end
local maxMagnitude = function(vec, maxMagnitude)
	local magnitude = vec.Magnitude
	if magnitude > maxMagnitude then
		vec *= maxMagnitude / magnitude
	end
	return vec
end

local UNIT_RAD = 3 -- in terms of studs
local UNIT_HEIGHT = 3 -- in terms of studs
local MAX_COORD = 25 -- in terms of cells
local CHUNK_SIZE = 2 -- in terms of cells
local CELL_WIDTH = 6 -- in terms of studs
local K_FORCE = 100
local VEL_ALPHA = 0.15
local MAX_DT = 0.1 -- in terms of seconds
local EPSILON = 10e-5
local PI = 3.1415

local CIRCLE_TO_HEX = 6 / PI / sqrt(3)
local CLUMP_RAD = UNIT_RAD * sqrt(NUM_UNITS * CIRCLE_TO_HEX)
local UNIT_ORIENTATION = newCFrameAngles(0, 0, PI / 2)
local WALLS = Grid.New(MAX_COORD)

--[[
	Setup Pathfinder
]]

local wallFolder = workspace.Walls
repeat
	waitOneFrame()
until #wallFolder:GetChildren() >= wallFolder:GetAttribute("NumWalls")

for _, wall in wallFolder:GetChildren() do
	local pos = wall.CFrame.Position
	local size = wall.Size / 2

	forBox(vector3ToGridCoord(pos - size, CELL_WIDTH), vector3ToGridCoord(pos + size, CELL_WIDTH), function(pos)
		WALLS:SetCell(pos, true)
	end)
end

local pathfinder = FastFlow.NewPathfinder(WALLS, CHUNK_SIZE)
pathfinder:Visualize(CELL_WIDTH, 0, SHOW_WALLS, SHOW_GRID, SHOW_CHUNKS, SHOW_HPA)

--[[
	Create Units
]]

local unitFolder = workspace.Units
local unitParts = {}
local unitPos = {}
local unitVel = {}
local unitIdle = {}

for i = 1, NUM_UNITS, 1 do
	local newUnit = Storage.Unit:Clone()
	newUnit.Parent = unitFolder

	-- essentially Vector2.zero with a slight offset to jumpstart the physics (random() ranges from 0.0 to 1.0)
	insert(unitPos, newVector2(random(), random()))
	insert(unitVel, newVector2(0, 0))
	insert(unitParts, newUnit)
end

--[[
	Simulate and Move Units
]]

local physicsGridSize = ceil(MAX_COORD * CELL_WIDTH / UNIT_RAD / 2)
local physicsGrid = Grid.New(physicsGridSize)
local unitSize = newVector2(UNIT_RAD, UNIT_RAD)
local axes = { newVector2(1, 0), newVector2(0, 1) }

local forPhysicsGrid = function(pos, funct)
	forBox(
		vector2ToGridCoord(pos - unitSize, UNIT_RAD * 2),
		vector2ToGridCoord(pos + unitSize, UNIT_RAD * 2),
		function(pos)
			funct(pos, physicsGrid:GetCell(pos) or {})
		end
	)
end

local lastGoal = newVector2(0, 0)
local flowfield = pathfinder:GenerateFlowfield(lastGoal, { lastGoal })

RunService.Heartbeat:Connect(function(dt)
	local root = Player.Character and Player.Character.HumanoidRootPart
	if not root then
		return
	end

	-- Setup physics grid, start positions, and goal
	local unitCells = {}
	physicsGrid:ClearGrid()

	for id, myPos in unitPos do
		unitCells[id] = vector2ToGridCoord(myPos, CELL_WIDTH)
		forPhysicsGrid(myPos, function(gridPos, unitsInCell)
			insert(unitsInCell, id)
			physicsGrid:SetCell(gridPos, unitsInCell)
		end)
	end

	local goal = pathfinder:FindOpenCell(vector3ToVector2(root.CFrame.Position / CELL_WIDTH)) or newVector2(0, 0)
	if goal ~= lastGoal then
		unitIdle = {}
		lastGoal = goal
		flowfield = pathfinder:GenerateFlowfield(goal, unitCells)
	end

	-- Simulate physics and move units
	local movePos = {}
	local moveParts = {}

	for id, myPos in unitPos do
		-- Calculate velocity from flowfield
		local vel = newVector2(0, 0)
		local cell = unitCells[id]
		if not unitIdle[id] then
			local dir = flowfield:GetDirection(cell)
			if dir then
				vel = dir * UNIT_SPEED
			else
				pathfinder:MergeFlowfield(flowfield, cell)
			end
		end

		-- Simulate collisions with other units
		local collided = {}
		forPhysicsGrid(myPos, function(_, unitsInCell)
			for _, otherUnit in unitsInCell do
				if not collided[otherUnit] then
					local displacement = myPos - unitPos[otherUnit]
					local distance = displacement.Magnitude
					local penetration = UNIT_RAD * 2 - distance
					collided[otherUnit] = true

					if penetration > 0 and distance > 0 then
						vel += K_FORCE * displacement / distance * penetration * penetration
					end
				end
			end
		end)

		vel = maxMagnitude(vel, UNIT_SPEED)
		vel = unitVel[id] * (1 - VEL_ALPHA) + vel * VEL_ALPHA

		-- Simulate collisions with walls
		for _, axis in axes do
			local testVel = vel:Dot(axis) * axis
			local testCell = vector2ToGridCoord(myPos + testVel * dt, CELL_WIDTH)
			if WALLS:GetCell(testCell) then
				vel -= testVel
			end
		end

		local testCell = vector2ToGridCoord(myPos + vel * dt, CELL_WIDTH)
		if WALLS:GetCell(testCell) then
			local cornerDisplacement = testCell * CELL_WIDTH - myPos
			if abs(cornerDisplacement.Y / cornerDisplacement.X) > abs(vel.Y / vel.X) then
				vel = newVector2(vel.X, 0)
			else
				vel = newVector2(0, vel.Y)
			end
		end

		-- Check if destination reached
		if not unitIdle[id] then
			if goal == cell then
				unitIdle[id] = true
			elseif flowfield:GetDistance(cell) * CELL_WIDTH < CLUMP_RAD then
				for otherUnit, _ in collided do
					if unitIdle[otherUnit] then
						unitIdle[id] = true
						break
					end
				end
			end
		end

		-- Update position and velocity
		local newPos = myPos + vel * dt
		unitPos[id] = newPos
		unitVel[id] = vel

		insert(movePos, newCFrame(newPos.X, UNIT_HEIGHT / 2, newPos.Y) * UNIT_ORIENTATION)
		insert(moveParts, unitParts[id])
	end

	workspace:BulkMoveTo(moveParts, movePos, Enum.BulkMoveMode.FireCFrameChanged)
end)

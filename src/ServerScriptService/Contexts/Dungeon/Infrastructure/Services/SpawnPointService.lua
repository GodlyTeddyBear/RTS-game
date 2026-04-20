--!strict

--[=[
	@class SpawnPointService
	Extracts spawn point data from dungeon area models' SpawnLocations folders.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DungeonTypes = require(ReplicatedStorage.Contexts.Dungeon.Types.DungeonTypes)

type TSpawnPoint = DungeonTypes.TSpawnPoint

local SpawnPointService = {}
SpawnPointService.__index = SpawnPointService

export type TSpawnPointService = typeof(setmetatable({}, SpawnPointService))

function SpawnPointService.new(): TSpawnPointService
	local self = setmetatable({}, SpawnPointService)
	return self
end

--[=[
	Extract spawn points from an area model's SpawnLocations folder, treating each part as a spawn zone.
	@within SpawnPointService
	@param areaModel Model -- The area model containing a SpawnLocations folder
	@return { TSpawnPoint } -- Array of spawn point data
]=]
function SpawnPointService:ExtractSpawnPoints(areaModel: Model): { TSpawnPoint }
	local spawnPoints = {}

	local spawnLocations = areaModel:FindFirstChild("SpawnLocations")
	if not spawnLocations then
		warn("[Dungeon:SpawnPointService] No SpawnLocations folder in area model:", areaModel.Name)
		return spawnPoints
	end

	for _, spawnPart in ipairs(spawnLocations:GetChildren()) do
		if spawnPart:IsA("BasePart") then
			table.insert(spawnPoints, table.freeze({
				Position = self:GetRandomPositionInPart(spawnPart),
				SpawnPartSize = spawnPart.Size,
				SpawnPartCFrame = spawnPart.CFrame,
			}))
		end
	end

	return spawnPoints
end

--[=[
	Get a random world-space position within a part's bounding box at the part's Y level.
	@within SpawnPointService
	@param part BasePart -- The spawn zone part
	@return Vector3 -- A random position within the part's bounds
]=]
function SpawnPointService:GetRandomPositionInPart(part: BasePart): Vector3
	local size = part.Size
	local localOffset = Vector3.new(
		(math.random() - 0.5) * size.X,
		0, -- Keep Y at part's Y level
		(math.random() - 0.5) * size.Z
	)
	return (part.CFrame * CFrame.new(localOffset)).Position
end

return SpawnPointService

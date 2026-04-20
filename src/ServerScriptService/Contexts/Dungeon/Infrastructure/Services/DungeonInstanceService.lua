--!strict

--[=[
	@class DungeonInstanceService
	Manages physical dungeon models in Workspace: cloning, aligning, tracking, and cleanup.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DungeonConfig = require(ReplicatedStorage.Contexts.Dungeon.Config.DungeonConfig)

--[=[
	@interface TActiveDungeon
	@within DungeonInstanceService
	.Folder Folder -- Root folder in Workspace.Dungeons for this player
	.ZoneId string -- Zone ID of the active dungeon
	.CurrentAreaModel Model? -- The currently active area piece (for barrier destruction)
	.LastFloorCFrame CFrame -- Floor CFrame of the last placed piece (alignment anchor)
	.LastFloorSize Vector3 -- Floor Size of the last placed piece (alignment calculation)
	.Pieces { Model } -- Array of all placed pieces in this dungeon
]=]

export type TActiveDungeon = {
	Folder: Folder,
	ZoneId: string,
	CurrentAreaModel: Model?,
	LastFloorCFrame: CFrame,
	LastFloorSize: Vector3,
	Pieces: { Model },
}

local DungeonInstanceService = {}
DungeonInstanceService.__index = DungeonInstanceService

export type TDungeonInstanceService = typeof(setmetatable({} :: {
	Calculator: any,
	ActiveDungeons: { [number]: TActiveDungeon },
}, DungeonInstanceService))

function DungeonInstanceService.new(): TDungeonInstanceService
	local self = setmetatable({}, DungeonInstanceService)
	self.ActiveDungeons = {} :: { [number]: TActiveDungeon }
	return self
end

function DungeonInstanceService:Init(registry: any)
	self.Calculator = registry:Get("PieceAlignmentCalculator")
end

--[=[
	Create the Workspace folder structure for a player's dungeon.
	@within DungeonInstanceService
	@param userId number -- The player's user ID
	@param zoneId string -- The zone ID
	@param baseOffset CFrame -- The base position for this dungeon (X-offset for isolation)
	@return Folder -- The created folder under Workspace.Dungeons
]=]
function DungeonInstanceService:CreateDungeon(userId: number, zoneId: string, baseOffset: CFrame): Folder
	-- Create or get Dungeons root folder
	local dungeonsRoot = workspace:FindFirstChild("Dungeons") :: Folder?
	if not dungeonsRoot then
		dungeonsRoot = Instance.new("Folder")
		dungeonsRoot.Name = "Dungeons"
		dungeonsRoot.Parent = workspace
	end

	-- Create per-player folder
	local playerFolder = Instance.new("Folder")
	playerFolder.Name = tostring(userId)
	playerFolder.Parent = dungeonsRoot

	-- Track active dungeon
	self.ActiveDungeons[userId] = {
		Folder = playerFolder,
		ZoneId = zoneId,
		CurrentAreaModel = nil,
		LastFloorCFrame = baseOffset,
		LastFloorSize = Vector3.zero,
		Pieces = {},
	}

	return playerFolder
end

--[=[
	Clone and align the Start piece at the base offset position.
	@within DungeonInstanceService
	@param userId number -- The player's user ID
	@param zoneId string -- The zone ID
	@return Model, CFrame -- The cloned Start model and its Floor CFrame
]=]
function DungeonInstanceService:PlaceStartPiece(userId: number, zoneId: string): (Model, CFrame)
	local dungeon = self.ActiveDungeons[userId]
	assert(dungeon, "No active dungeon for userId: " .. tostring(userId))

	local endPointsFolder = self:_GetEndPointsFolder(zoneId)
	local startTemplate = endPointsFolder:FindFirstChild("Start") :: Model
	if not startTemplate then
		warn("[Dungeon:InstanceService] No Start model in EndPoints for zone '" .. zoneId .. "', using Default")
		local defaultEndPoints = self:_GetDefaultEndPointsFolder()
		startTemplate = defaultEndPoints:FindFirstChild("Start") :: Model
		assert(startTemplate, "Default EndPoints is missing a Start model")
	end

	local startModel = startTemplate:Clone()
	startModel.Name = "Start"
	startModel.Parent = dungeon.Folder

	-- Find Floor part and align
	local floor = startModel:FindFirstChild("Floor") :: BasePart
	assert(floor, "Start piece missing Floor part")

	-- Position the Start piece so its Floor is at the base offset
	self:_AlignPieceFloorTo(startModel, floor, dungeon.LastFloorCFrame)

	-- Update tracking: the front edge is the Floor CFrame after placement
	dungeon.LastFloorCFrame = floor.CFrame
	dungeon.LastFloorSize = floor.Size
	table.insert(dungeon.Pieces, startModel)

	return startModel, floor.CFrame
end

--[=[
	Clone and align an area piece using weighted random variant selection.
	@within DungeonInstanceService
	@param userId number -- The player's user ID
	@param zoneId string -- The zone ID
	@return Model, CFrame -- The cloned area model and its Floor CFrame
]=]
function DungeonInstanceService:PlaceAreaPiece(userId: number, zoneId: string): (Model, CFrame)
	local dungeon = self.ActiveDungeons[userId]
	assert(dungeon, "No active dungeon for userId: " .. tostring(userId))

	local areasFolder = self:_GetAreasFolder(zoneId)

	-- Select variant by weighted random
	local variantName = self:_SelectAreaVariant(zoneId)
	local areaTemplate = areasFolder:FindFirstChild(variantName) :: Model
	if not areaTemplate then
		-- Fallback to first available area in the same folder
		areaTemplate = areasFolder:FindFirstChildOfClass("Model") :: Model
	end
	if not areaTemplate then
		-- Fallback to Default Areas folder
		warn("[Dungeon:InstanceService] No area models found in zone '" .. zoneId .. "', using Default")
		local defaultAreas = self:_GetDefaultAreasFolder()
		areaTemplate = defaultAreas:FindFirstChildOfClass("Model") :: Model
		assert(areaTemplate, "Default Areas folder has no area models")
	end

	local areaModel = areaTemplate:Clone()
	areaModel.Name = "Area_" .. #dungeon.Pieces
	areaModel.Parent = dungeon.Folder

	-- Find Floor part and calculate alignment
	local floor = areaModel:FindFirstChild("Floor") :: BasePart
	assert(floor, "Area piece missing Floor part")

	-- Calculate where this piece's Floor should go
	local targetCFrame = self.Calculator:CalculateNextPieceCFrame(
		dungeon.LastFloorCFrame,
		dungeon.LastFloorSize,
		floor.Size
	)

	-- Align the piece
	self:_AlignPieceFloorTo(areaModel, floor, targetCFrame)

	-- Update tracking
	dungeon.LastFloorCFrame = floor.CFrame
	dungeon.LastFloorSize = floor.Size
	dungeon.CurrentAreaModel = areaModel
	table.insert(dungeon.Pieces, areaModel)

	return areaModel, floor.CFrame
end

--[=[
	Clone and align the End piece after the final wave area.
	@within DungeonInstanceService
	@param userId number -- The player's user ID
	@param zoneId string -- The zone ID
	@return Model -- The cloned End model
]=]
function DungeonInstanceService:PlaceEndPiece(userId: number, zoneId: string): Model
	local dungeon = self.ActiveDungeons[userId]
	assert(dungeon, "No active dungeon for userId: " .. tostring(userId))

	local endPointsFolder = self:_GetEndPointsFolder(zoneId)
	local endTemplate = endPointsFolder:FindFirstChild("End") :: Model
	if not endTemplate then
		warn("[Dungeon:InstanceService] No End model in EndPoints for zone '" .. zoneId .. "', using Default")
		local defaultEndPoints = self:_GetDefaultEndPointsFolder()
		endTemplate = defaultEndPoints:FindFirstChild("End") :: Model
		assert(endTemplate, "Default EndPoints is missing an End model")
	end

	local endModel = endTemplate:Clone()
	endModel.Name = "End"
	endModel.Parent = dungeon.Folder

	-- Find Floor part and calculate alignment
	local floor = endModel:FindFirstChild("Floor") :: BasePart
	assert(floor, "End piece missing Floor part")

	local targetCFrame = self.Calculator:CalculateNextPieceCFrame(
		dungeon.LastFloorCFrame,
		dungeon.LastFloorSize,
		floor.Size
	)

	self:_AlignPieceFloorTo(endModel, floor, targetCFrame)

	-- Update tracking
	dungeon.LastFloorCFrame = floor.CFrame
	dungeon.LastFloorSize = floor.Size
	table.insert(dungeon.Pieces, endModel)

	return endModel
end

--[=[
	Destroy the Barrier part in the current area model (warns if not found).
	@within DungeonInstanceService
	@param userId number -- The player's user ID
	@return boolean -- Whether a barrier was found and destroyed
]=]
function DungeonInstanceService:DestroyBarrier(userId: number): boolean
	local dungeon = self.ActiveDungeons[userId]
	if not dungeon or not dungeon.CurrentAreaModel then
		return false
	end

	local barrier = dungeon.CurrentAreaModel:FindFirstChild("Barrier")
	if not barrier then
		warn("[Dungeon:InstanceService] No Barrier found in current area for userId:", userId)
		return false
	end

	barrier:Destroy()
	return true
end

--[=[
	Destroy the Barrier part on a specific piece model (e.g. for the Start piece).
	@within DungeonInstanceService
	@param pieceModel Model -- The piece model containing the barrier
	@return boolean -- Whether a barrier was found and destroyed
]=]
function DungeonInstanceService:DestroyBarrierOnPiece(pieceModel: Model): boolean
	local barrier = pieceModel:FindFirstChild("Barrier")
	if not barrier then
		warn("[Dungeon:InstanceService] No Barrier found on piece:", pieceModel.Name)
		return false
	end

	barrier:Destroy()
	return true
end

--[=[
	Get the current area model for a player's dungeon (used for barrier destruction and enemy spawning).
	@within DungeonInstanceService
	@param userId number -- The player's user ID
	@return Model? -- The current area model, or nil if not found
]=]
function DungeonInstanceService:GetCurrentAreaModel(userId: number): Model?
	local dungeon = self.ActiveDungeons[userId]
	return dungeon and dungeon.CurrentAreaModel or nil
end

--[=[
	Check if a player has an active dungeon instance.
	@within DungeonInstanceService
	@param userId number -- The player's user ID
	@return boolean -- Whether the player has an active dungeon
]=]
function DungeonInstanceService:HasActiveDungeon(userId: number): boolean
	return self.ActiveDungeons[userId] ~= nil
end

--[=[
	Destroy the entire dungeon folder and clear tracking state.
	@within DungeonInstanceService
	@param userId number -- The player's user ID
]=]
function DungeonInstanceService:DestroyDungeon(userId: number)
	local dungeon = self.ActiveDungeons[userId]
	if not dungeon then
		return
	end

	-- Destroy the entire folder (cascades to all children)
	if dungeon.Folder and dungeon.Folder.Parent then
		dungeon.Folder:Destroy()
	end

	-- Clear tracking
	self.ActiveDungeons[userId] = nil
end

-- Resolve the EndPoints folder for a zone, with Default fallback
function DungeonInstanceService:_GetEndPointsFolder(zoneId: string): Folder
	local zoneFolder = self:_GetZoneAssetsFolder(zoneId)
	local endPointsFolder = zoneFolder:FindFirstChild("EndPoints") :: Folder?
	if not endPointsFolder then
		warn("[Dungeon:InstanceService] No EndPoints folder in zone '" .. zoneId .. "', using Default")
		return self:_GetDefaultEndPointsFolder()
	end
	return endPointsFolder
end

--- Resolve the Default zone's EndPoints folder (must exist)
function DungeonInstanceService:_GetDefaultEndPointsFolder(): Folder
	local defaultZone = self:_GetZoneAssetsFolder("Default")
	local endPointsFolder = defaultZone:FindFirstChild("EndPoints") :: Folder?
	assert(endPointsFolder, "Default zone is missing an EndPoints folder")
	return endPointsFolder
end

--- Resolve the Areas folder for a zone, with Default fallback
function DungeonInstanceService:_GetAreasFolder(zoneId: string): Folder
	local zoneFolder = self:_GetZoneAssetsFolder(zoneId)
	local areasFolder = zoneFolder:FindFirstChild("Areas") :: Folder?
	if not areasFolder then
		warn("[Dungeon:InstanceService] No Areas folder in zone '" .. zoneId .. "', using Default")
		return self:_GetDefaultAreasFolder()
	end
	return areasFolder
end

--- Resolve the Default zone's Areas folder (must exist)
function DungeonInstanceService:_GetDefaultAreasFolder(): Folder
	local defaultZone = self:_GetZoneAssetsFolder("Default")
	local areasFolder = defaultZone:FindFirstChild("Areas") :: Folder?
	assert(areasFolder, "Default zone is missing an Areas folder")
	return areasFolder
end

--- Resolve the zone assets folder with Default fallback
function DungeonInstanceService:_GetZoneAssetsFolder(zoneId: string): Folder
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	assert(assetsFolder, "ReplicatedStorage.Assets not found")

	local questsFolder = assetsFolder:FindFirstChild("Quests")
	assert(questsFolder, "ReplicatedStorage.Assets.Quests not found")

	local zoneFolder = questsFolder:FindFirstChild(zoneId) :: Folder?
	if not zoneFolder then
		warn("[Dungeon:InstanceService] Zone '" .. zoneId .. "' not found in Assets, using Default")
		zoneFolder = questsFolder:FindFirstChild("Default") :: Folder?
		assert(zoneFolder, "Default zone folder is missing from Assets.Quests")
	end

	return zoneFolder :: Folder
end

--- Align a model so its Floor part lands at the target CFrame
function DungeonInstanceService:_AlignPieceFloorTo(model: Model, floor: BasePart, targetFloorCFrame: CFrame)
	-- Compute the offset from model pivot to floor center
	local modelPivot = model:GetPivot()
	local pivotToFloor = modelPivot:Inverse() * floor.CFrame

	-- Position the model so its Floor ends up at targetFloorCFrame
	-- modelNewPivot * pivotToFloor = targetFloorCFrame
	-- modelNewPivot = targetFloorCFrame * pivotToFloor:Inverse()
	local newPivot = targetFloorCFrame * pivotToFloor:Inverse()
	model:PivotTo(newPivot)
end

--- Weighted random selection of an area variant name
function DungeonInstanceService:_SelectAreaVariant(zoneId: string): string
	local weights = DungeonConfig.AreaVariantWeights[zoneId]
		or DungeonConfig.AreaVariantWeights.Default

	local totalWeight = 0
	for _, entry in ipairs(weights) do
		totalWeight += entry.Weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, entry in ipairs(weights) do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry.VariantName
		end
	end

	-- Fallback to first variant
	return weights[1].VariantName
end

return DungeonInstanceService

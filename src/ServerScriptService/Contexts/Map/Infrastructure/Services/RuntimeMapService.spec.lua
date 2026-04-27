--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Result = require(ReplicatedStorage.Utilities.Result)
local MapConfig = require(ReplicatedStorage.Contexts.Map.Config.MapConfig)
local RuntimeMapService = require(script.Parent.RuntimeMapService)

local POSITION_EPSILON = 1e-4
local ROTATION_EPSILON = 1e-5

local function expectVectorClose(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude <= POSITION_EPSILON).to.equal(true)
end

local function expectRotationClose(actual: CFrame, expected: CFrame)
	local _, _, _, ar00, ar01, ar02, ar10, ar11, ar12, ar20, ar21, ar22 = actual:GetComponents()
	local _, _, _, er00, er01, er02, er10, er11, er12, er20, er21, er22 = expected:GetComponents()

	expect(math.abs(ar00 - er00) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar01 - er01) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar02 - er02) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar10 - er10) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar11 - er11) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar12 - er12) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar20 - er20) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar21 - er21) <= ROTATION_EPSILON).to.equal(true)
	expect(math.abs(ar22 - er22) <= ROTATION_EPSILON).to.equal(true)
end

local function createMinimalTemplateModel(): Model
	local model = Instance.new("Model")
	model.Name = "Default"

	local environment = Instance.new("Folder")
	environment.Name = "Environment"
	environment.Parent = model

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = environment

	local function addZone(name: string)
		local zoneModel = Instance.new("Model")
		zoneModel.Name = name
		zoneModel.Parent = zones

		local part = Instance.new("Part")
		part.Name = if name == "Spawns" then "Spawn" else name
		part.Anchored = true
		part.Size = Vector3.new(4, 1, 4)
		part.CFrame = CFrame.new(0, 5, 0)
		part.Parent = zoneModel
	end

	addZone("Spawns")
	addZone("PlacementGrids")
	addZone("Lanes")
	addZone("SidePockets")
	addZone("Resources")
	addZone("PlacementProhibited")

	return model
end

describe("RuntimeMapService", function()
	it("returns error when runtime map target position is invalid", function()
		local service = RuntimeMapService.new()
		local result = service:_ResolveRuntimeMapTargetPosition("invalid")

		expect(result.success).to.equal(false)
		expect(result.type).to.equal("InvalidRuntimeMapTargetPosition")
	end)

	it("relocates map to target position while preserving rotation", function()
		local service = RuntimeMapService.new()
		local mapModel = Instance.new("Model")

		local rootPart = Instance.new("Part")
		rootPart.Name = "Root"
		rootPart.Anchored = true
		rootPart.Size = Vector3.new(6, 2, 6)
		rootPart.CFrame = CFrame.new(20, 10, -30) * CFrame.Angles(math.rad(15), math.rad(40), math.rad(10))
		rootPart.Parent = mapModel
		mapModel.PrimaryPart = rootPart

		local beforePivot = mapModel:GetPivot()
		local targetPosition = Vector3.new(125, 8, -90)

		service._ResolveRuntimeMapTargetPosition = function(_self: any): Result.Result<Vector3>
			return Result.Ok(targetPosition)
		end

		local relocateResult = service:_RelocateRuntimeMap(mapModel)
		expect(relocateResult.success).to.equal(true)

		local afterPivot = mapModel:GetPivot()
		expectVectorClose(afterPivot.Position, targetPosition)
		expectRotationClose(afterPivot, beforePivot)

		mapModel:Destroy()
	end)

	it("creates runtime map and applies configured relocation before entity registration", function()
		local service = RuntimeMapService.new()
		local createdMapModel: Model? = nil

		service._entityFactory = {
			CreateMapRoot = function(_mapId: string, _templateName: string, mapModel: Model, _zonesByName: { [string]: Instance })
				createdMapModel = mapModel
				return 1
			end,
			DeleteActiveMap = function()
				return true
			end,
		}

		local mapContainer = Instance.new("Folder")
		mapContainer.Name = MapConfig.WORKSPACE_MAP_CONTAINER_NAME
		mapContainer.Parent = Workspace

		local gameContainer = Instance.new("Folder")
		gameContainer.Name = MapConfig.WORKSPACE_GAME_CONTAINER_NAME
		gameContainer.Parent = mapContainer

		local assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "Assets"
		assetsFolder.Parent = ReplicatedStorage

		local mapsFolder = Instance.new("Folder")
		mapsFolder.Name = "Maps"
		mapsFolder.Parent = assetsFolder

		local templateModel = createMinimalTemplateModel()
		templateModel.Parent = mapsFolder

		local createResult = service:CreateOrReplaceRuntimeMap()
		expect(createResult.success).to.equal(true)
		expect(createdMapModel == nil).to.equal(false)
		expectVectorClose((createdMapModel :: Model):GetPivot().Position, MapConfig.RUNTIME_MAP_TARGET_POSITION)

		service:CleanupRuntimeMap()
		assetsFolder:Destroy()
		mapContainer:Destroy()
	end)
end)

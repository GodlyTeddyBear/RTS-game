--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[=[
	@class BuildingModelFactory
	Creates and updates building models for lot zone slots.
	@server
]=]
local BuildingModelFactory = {}
BuildingModelFactory.__index = BuildingModelFactory

export type TBuildingModelFactory = typeof(setmetatable(
	{} :: {
		_buildingRegistry: any,
	},
	BuildingModelFactory
))

--[=[
	Create a model factory with lazy-initialized asset registry state.
	@within BuildingModelFactory
	@return TBuildingModelFactory -- New building model factory instance.
]=]
function BuildingModelFactory.new(): TBuildingModelFactory
	local self = setmetatable({}, BuildingModelFactory)
	self._buildingRegistry = nil :: any
	return self
end

--[=[
	Initialize asset registry bindings used to clone building and companion models.
	@within BuildingModelFactory
	@param _registry any -- Unused registry dependency.
	@param _name string -- Unused registration name.
]=]
function BuildingModelFactory:Init(_registry: any, _name: string)
	local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
	self._buildingRegistry = AssetFetcher.CreateBuildingRegistry(
		ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Buildings")
	)
end

-- Resolve slot transform and floor Y by BuildSlot naming convention, warning when missing.
function BuildingModelFactory:_GetSlotPlacement(
	zoneFolder: Folder,
	slotIndex: number,
	zoneName: string,
	buildingType: string
): (CFrame?, number?)
	local slotName = "BuildSlot_" .. slotIndex
	local slotAnchor = zoneFolder:FindFirstChild(slotName)
	if not slotAnchor then
		warn(
			"[BuildingModelFactory] Missing build slot anchor '"
				.. slotName
				.. "' for zone='"
				.. zoneName
				.. "', buildingType='"
				.. buildingType
				.. "'. Model will spawn without slot placement."
		)
		return nil, nil
	end

	if slotAnchor:IsA("BasePart") then
		local slotBottomY = slotAnchor.Position.Y - (slotAnchor.Size.Y * 0.5)
		return slotAnchor.CFrame, slotBottomY
	end
	if slotAnchor:IsA("Attachment") then
		return slotAnchor.WorldCFrame, slotAnchor.WorldPosition.Y
	end
	if slotAnchor:IsA("Model") then
		local pivot = slotAnchor:GetPivot()
		return pivot, pivot.Position.Y
	end

	warn(
		"[BuildingModelFactory] Unsupported build slot anchor class '"
			.. slotAnchor.ClassName
			.. "' for slot='"
			.. slotName
			.. "', zone='"
			.. zoneName
			.. "', buildingType='"
			.. buildingType
			.. "'. Model will spawn without slot placement."
	)
	return nil, nil
end

-- Place a model at slot transform, then align model bottom to slot floor Y.
function BuildingModelFactory:_PlaceModelAtSlot(
	model: Model,
	slotCFrame: CFrame,
	targetBottomY: number,
	zoneName: string,
	slotIndex: number,
	modelType: string
)
	if model.PrimaryPart then
		-- Preserve PrimaryPart alignment without using deprecated SetPrimaryPartCFrame.
		local pivotCFrame = model:GetPivot()
		local pivotToPrimary = pivotCFrame:ToObjectSpace(model.PrimaryPart.CFrame)
		model:PivotTo(slotCFrame * pivotToPrimary:Inverse())
	else
		-- No PrimaryPart: snap pivot first before bottom correction.
		model:PivotTo(slotCFrame)
	end

	local gotBounds, boundsCFrame, boundsSize = pcall(function()
		return model:GetBoundingBox()
	end)

	if gotBounds and typeof(boundsSize) == "Vector3" and boundsSize.Magnitude > 0 then
		local modelBottomY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
		local deltaY = targetBottomY - modelBottomY
		if math.abs(deltaY) > 0.0001 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, deltaY, 0))
		end
		return
	end

	warn(
		"[BuildingModelFactory] Cannot place model '"
			.. model.Name
			.. "' (type='"
			.. modelType
			.. "') in zone='"
			.. zoneName
			.. "', slotIndex="
			.. slotIndex
			.. ": no PrimaryPart and failed to compute a non-zero bounding box for Y alignment."
	)
end

--[=[
	Clone and place a building model at the target slot anchor.
	@within BuildingModelFactory
	@param buildingType string -- Building type key for the model lookup.
	@param _level number -- Building level value reserved for future model variants.
	@param zoneFolder Folder -- Folder that contains slot anchors and spawned models.
	@param slotIndex number -- One-based build slot index.
	@param companionModel string? -- Optional companion model key to spawn.
	@param companionFolder string? -- Optional zone subfolder for companion placement.
	@param zoneName string -- Zone name for registry lookups.
	@return Model? -- Spawned model, or `nil` when no template exists.
]=]
function BuildingModelFactory:CreateBuildingModel(
	buildingType: string,
	_level: number,
	zoneFolder: Folder,
	slotIndex: number,
	companionModel: string?,
	companionFolder: string?,
	zoneName: string
): Model?
	local model = self._buildingRegistry:GetBuildingModel(zoneName, buildingType) :: Model?
	if not model then
		return nil
	end

	local slotCFrame, targetBottomY = self:_GetSlotPlacement(zoneFolder, slotIndex, zoneName, buildingType)

	if slotCFrame and targetBottomY ~= nil then
		self:_PlaceModelAtSlot(model, slotCFrame, targetBottomY, zoneName, slotIndex, buildingType)
	end

	model.Parent = zoneFolder

	if companionModel and companionFolder then
		local companion = self._buildingRegistry:GetCompanionModel(zoneName, companionModel) :: Model?
		if companion then
			if slotCFrame and targetBottomY ~= nil then
				self:_PlaceModelAtSlot(companion, slotCFrame, targetBottomY, zoneName, slotIndex, companionModel)
			end
			local targetFolder = zoneFolder:FindFirstChild(companionFolder) :: Folder?
			companion.Parent = targetFolder or zoneFolder
		end
	end

	return model
end

--[=[
	Apply level-dependent visual updates for an existing building model.
	@within BuildingModelFactory
	@param model Model -- Existing spawned model instance.
	@param level number -- New level to present on visual labels.
]=]
function BuildingModelFactory:UpdateBuildingLevel(model: Model, level: number)
	-- Update optional in-model text marker until richer visual upgrades are implemented.
	local levelLabel = model:FindFirstChild("LevelLabel", true)
	if levelLabel and levelLabel:IsA("StringValue") then
		levelLabel.Value = "Lv " .. level
	end
end

--[=[
	Destroy a spawned building model instance.
	@within BuildingModelFactory
	@param model Model -- Model instance to remove from workspace.
]=]
function BuildingModelFactory:DestroyBuildingModel(model: Model)
	model:Destroy()
end

return BuildingModelFactory

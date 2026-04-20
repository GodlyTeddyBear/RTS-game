--!strict

--[=[
	@class RemoteLotModelFactory
	Clones and positions remote lot template models.
	@server
]=]

--[[
	Clones the remote lot template model and positions it in the remote terrain area.
	Template lives at: workspace.TerrainHelper.TemplateBounds (Model child)

	The template model structure mirrors the village lot but only contains remote zones:
	  Model/
	  ├── Base            ← anchor Part
	  ├── Farm/
	  │   ├── BuildSlot_1 → BuildSlot_4
	  ├── Garden/
	  │   ├── BuildSlot_1 → BuildSlot_4
	  ├── Forest/
	  │   ├── BuildSlot_1 → BuildSlot_3
	  └── Mines/
	      ├── BuildSlot_1 → BuildSlot_3
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECSRevealApplier = require(ServerScriptService.Infrastructure.ECSRevealApplier)
local TargetRevealBuilder = require(ReplicatedStorage.Contexts.Targeting.TargetRevealBuilder)
local TargetZoneBindings = require(ReplicatedStorage.Contexts.Targeting.Config.TargetZoneBindings)

local RemoteLotModelFactory = {}
RemoteLotModelFactory.__index = RemoteLotModelFactory

export type TRemoteLotModelFactory = typeof(setmetatable(
	{} :: {
		_templateFolder: BasePart,
		_remoteLotFolder: Folder,
		_baseFromTemplateCenter: CFrame,
	},
	RemoteLotModelFactory
))

function RemoteLotModelFactory.new(remoteLotFolder: Folder): TRemoteLotModelFactory
	local self = setmetatable({}, RemoteLotModelFactory)
	self._templateFolder = nil :: any
	self._remoteLotFolder = remoteLotFolder
	self._baseFromTemplateCenter = nil :: any
	return self
end

function RemoteLotModelFactory:Init(registry: any, _name: string)
	local boundsPart = workspace.TerrainHelper.TemplateBounds :: BasePart
	self._templateFolder = boundsPart

	local template = boundsPart:FindFirstChildWhichIsA("Model") :: Model
	assert(template, "[RemoteLotModelFactory] No Model inside workspace.TerrainHelper.TemplateBounds")

	local base = template:FindFirstChild("Base", true) :: BasePart?
	assert(base, "[RemoteLotModelFactory] Template model is missing a Base part")

	-- Use the terrain template's snapped center as the reference point so model
	-- placement matches exactly what StampTerrain uses.
	local terrainTemplate = registry:Get("RemoteLotTerrainTemplate")
	local snappedCenter = terrainTemplate:GetTemplateCenter()
	self._baseFromTemplateCenter = CFrame.new(snappedCenter):ToObjectSpace(base.CFrame)
end

--[=[
	Clones the remote lot template and positions it at the given CFrame.
	Uses the same Base-anchor positioning as GameObjectFactory.
	@within RemoteLotModelFactory
	@param userId number
	@param cframe CFrame
	@return Model -- The cloned and positioned remote lot model
]=]
function RemoteLotModelFactory:CreateRemoteLotModel(userId: number, cframe: CFrame): Model
	-- Step 1: Load the template from TemplateBounds
	local template = self:_LoadTemplate()
	-- Step 2: Clone and name the model for this player
	local model = self:_CloneAndName(template, userId)
	-- Step 3: Stamp target components for Targeting context integration
	self:_StampTargetTags(model, model.Name)
	-- Step 4: Position the model at the destination with proper anchor alignment
	self:_PositionModel(model, cframe)
	return model
end

-- Loads the remote lot template from workspace.TerrainHelper.TemplateBounds.
function RemoteLotModelFactory:_LoadTemplate(): Model
	local template = self._templateFolder:FindFirstChildWhichIsA("Model")
	assert(template, "[RemoteLotModelFactory] No Model inside workspace.TerrainHelper.TemplateBounds")
	return template :: Model
end

-- Clones the template and sets it up as a new remote lot for the player.
function RemoteLotModelFactory:_CloneAndName(template: Model, userId: number): Model
	local model = template:Clone() :: Model
	model.Name = "RemoteLot_" .. userId
	model.Parent = self._remoteLotFolder
	return model
end

-- Positions the model using Base-anchor alignment to match terrain snapping.
function RemoteLotModelFactory:_PositionModel(model: Model, destinationCenter: CFrame)
	local base = model:FindFirstChild("Base", true) :: BasePart?
	assert(base, "[RemoteLotModelFactory] Cloned remote lot model is missing Base")

	-- Compute target Base position from the destination center and template offset
	local targetBaseCFrame = destinationCenter * self._baseFromTemplateCenter
	-- Preserve the pivot-to-Base offset when repositioning
	local pivotCFrame = model:GetPivot()
	local pivotToBase = pivotCFrame:ToObjectSpace(base.CFrame)
	-- Pivot to the new location, preserving the internal model structure
	model:PivotTo(targetBaseCFrame * pivotToBase:Inverse())
end

-- Stamps target components on build slots for Targeting context integration.
function RemoteLotModelFactory:_StampTargetTags(model: Model, scopeId: string)
	for _, binding in TargetZoneBindings do
		local zone = model:FindFirstChild(binding.ZoneName, true)
		if zone then
			local container = zone:FindFirstChild(binding.ContainerName)
			if container then
				-- Stamp each build slot found in the container
				for sourceId, _ in binding.Config do
					local targetInstance = container:FindFirstChild(sourceId)
					if targetInstance then
						local _, revealState = TargetRevealBuilder.Build({
							TargetType = binding.TargetType,
							SourceId = sourceId,
							ScopeId = scopeId,
						})
						ECSRevealApplier.Apply(targetInstance, revealState)
					end
				end
			end
		end
	end
end

--[=[
	Destroys a remote lot model.
	@within RemoteLotModelFactory
	@param model Model
]=]
function RemoteLotModelFactory:DestroyRemoteLotModel(model: Model)
	model:Destroy()
end

return RemoteLotModelFactory

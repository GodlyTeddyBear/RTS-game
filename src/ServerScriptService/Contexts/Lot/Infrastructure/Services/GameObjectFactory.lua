--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECSRevealApplier = require(ServerScriptService.Infrastructure.ECSRevealApplier)
local TargetRevealBuilder = require(ReplicatedStorage.Contexts.Targeting.TargetRevealBuilder)
local TargetZoneBindings = require(ReplicatedStorage.Contexts.Targeting.Config.TargetZoneBindings)

--[[
	Lot GameObject Factory - Create and manage Roblox lot model instances

	Responsibility: Clone lot models from templates, manage visuals.
	Handles Roblox-side operations for lot rendering.
]]

--[=[
	@class GameObjectFactory
	Creates and manages Roblox lot model instances from templates.
	@server
]=]

local GameObjectFactory = {}
GameObjectFactory.__index = GameObjectFactory

--[=[
	Create a new GameObjectFactory instance.
	@within GameObjectFactory
	@param lotsFolder Folder -- The workspace folder to parent lot models under
	@return GameObjectFactory -- Service instance
]=]
function GameObjectFactory.new(lotsFolder: Folder)
	local self = setmetatable({}, GameObjectFactory)
	self.LotsFolder = lotsFolder
	return self
end

--[=[
	Initialize with injected dependencies.
	@within GameObjectFactory
	@param registry any -- Registry to resolve dependencies from
]=]
function GameObjectFactory:Init(registry: any)
	self.LotRegistry = registry:Get("LotRegistry")
end

--[=[
	Create a lot model instance from template and stamp targeting tags.
	@within GameObjectFactory
	@param lotType string -- Type of lot (e.g., "Default")
	@param lotId string -- Unique lot identifier
	@return Model -- The created lot model
]=]
function GameObjectFactory:CreateLotModel(lotType: string, lotId: string): Model
	local model = self.LotRegistry:GetLotModel(lotType)
	model.Name = "Lot_" .. lotId
	self:_StampTargetTags(model, model.Name)
	model.Parent = self.LotsFolder
	return model
end

-- Stamp target zone bindings on lot zones for the targeting system. Traverses zone hierarchy and applies TargetStamp to matching containers.
function GameObjectFactory:_StampTargetTags(model: Model, scopeId: string)
	for _, binding in TargetZoneBindings do
		local zone = model:FindFirstChild(binding.ZoneName, true)
		if zone then
			local container = zone:FindFirstChild(binding.ContainerName)
			if container then
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
	Update lot model CFrame by positioning the Base part at the target CFrame.
	Accounts for offset between model pivot and Base to ensure correct world positioning.
	@within GameObjectFactory
	@param model Model -- The lot model to update
	@param cframe CFrame -- New world CFrame (from LotArea Part)
]=]
function GameObjectFactory:UpdateLotCFrame(model: Model, cframe: CFrame)
	local base = model:FindFirstChild("Base", true)
	if not base then
		warn("[GameObjectFactory] No 'Base' found in lot model, falling back to direct pivot")
		model:PivotTo(cframe)
		return
	end

	-- Compute offset from model pivot to Base
	local pivotCFrame = model:GetPivot()
	local offset = pivotCFrame:ToObjectSpace((base :: BasePart).CFrame)

	-- Position model so Base lands exactly on the LotArea CFrame
	model:PivotTo(cframe * offset:Inverse())
end

--[=[
	Destroy lot model instance and remove from workspace.
	@within GameObjectFactory
	@param model Model -- The lot model to destroy
]=]
function GameObjectFactory:DestroyLotModel(model: Model)
	model:Destroy()
end

return GameObjectFactory

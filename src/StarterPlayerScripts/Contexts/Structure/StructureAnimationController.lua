--!strict

--[[
	Module: StructureAnimationController
	Purpose: Tracks placed structure models on the client and attaches animation drivers as they appear.
	Used In System: Started by Knit on the client and driven by Workspace placement replication.
	High-Level Flow: Register structure attack action -> track placed models -> attach animation setup -> untrack on removal.
	Boundaries: Owns client structure animation attachment only; does not own placement, targeting, or combat logic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ActionRegistry = require(ReplicatedStorage.Utilities.ActionSystem.ActionRegistry)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)

local AnimateStructureModule = require(script.Parent.AnimateStructureModule)
local StructureAttackAction = require(script.Parent.Actions.StructureAttackAction)

type TTrackedEntry = {
	Cleanup: (() -> ())?,
	AncestryConnection: RBXScriptConnection?,
	TargetEnemyId: string?,
	TargetModel: Model?,
}

local StructureAnimationController = Knit.CreateController({
	Name = "StructureAnimationController",
})

local ENEMIES_FOLDER_NAME = "Enemies"
local ANIMATED_ENEMY_TAG = "AnimatedEnemy"

local function _IsStructureModel(instance: Instance): boolean
	return instance:IsA("Model") and type(instance:GetAttribute("PlacementInstanceId")) == "number"
end

function StructureAnimationController:KnitInit()
	local structureAttackAction = StructureAttackAction.new()
	ActionRegistry.Register("StructureAttack", structureAttackAction)

	self._tracked = {} :: { [Model]: TTrackedEntry }
	self._placementsFolderConnectionAdded = nil :: RBXScriptConnection?
	self._placementsFolderConnectionRemoved = nil :: RBXScriptConnection?
	self._workspaceChildAddedConnection = nil :: RBXScriptConnection?
	self._combatService = nil
end

function StructureAnimationController:_TrackModel(model: Model)
	if self._tracked[model] ~= nil then
		return
	end

	local entry: TTrackedEntry = {
		Cleanup = nil,
		AncestryConnection = nil,
		TargetEnemyId = nil,
		TargetModel = nil,
	}
	self._tracked[model] = entry

	entry.AncestryConnection = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			self:_UntrackModel(model)
		end
	end)

	local function buildContext(): any
		local combatService = self._combatService
		local base = {
			Model = model,
			CombatService = combatService,
			ActorKind = "Structure",
			GetTargetWorldPosition = function(): Vector3?
				return self:_GetTargetWorldPosition(model)
			end,
		}

		return setmetatable(base, {
			__index = function(_, key)
				if key == "ActorId" then
					local placementInstanceId = model:GetAttribute("PlacementInstanceId")
					return if type(placementInstanceId) == "number" then tostring(placementInstanceId) else nil
				end
				return nil
			end,
		})
	end

	AnimateStructureModule.setup(model, buildContext())
		:andThen(function(cleanup)
			local tracked = self._tracked[model]
			if tracked == nil then
				if cleanup then
					cleanup()
				end
				return
			end

			tracked.Cleanup = cleanup
		end)
		:catch(function()
			self:_UntrackModel(model)
		end)
end

function StructureAnimationController:_UntrackModel(model: Model)
	local entry = self._tracked[model]
	if entry == nil then
		return
	end

	if entry.AncestryConnection ~= nil then
		entry.AncestryConnection:Disconnect()
		entry.AncestryConnection = nil
	end

	if entry.Cleanup ~= nil then
		entry.Cleanup()
		entry.Cleanup = nil
	end

	entry.TargetEnemyId = nil
	entry.TargetModel = nil

	self._tracked[model] = nil
end

function StructureAnimationController:_GetTargetWorldPosition(model: Model): Vector3?
	local entry = self._tracked[model]
	if entry == nil then
		return nil
	end

	local targetEnemyId = model:GetAttribute("TargetEnemyId")
	if type(targetEnemyId) ~= "string" or targetEnemyId == "" then
		entry.TargetEnemyId = nil
		entry.TargetModel = nil
		return nil
	end

	if entry.TargetEnemyId ~= targetEnemyId or entry.TargetModel == nil or entry.TargetModel.Parent == nil then
		entry.TargetEnemyId = targetEnemyId
		entry.TargetModel = self:_ResolveEnemyModelById(targetEnemyId)
	end

	if entry.TargetModel == nil or entry.TargetModel.Parent == nil then
		return nil
	end

	return entry.TargetModel:GetPivot().Position
end

function StructureAnimationController:_ResolveEnemyModelById(enemyId: string): Model?
	local enemiesFolder = Workspace:FindFirstChild(ENEMIES_FOLDER_NAME)
	if enemiesFolder ~= nil and enemiesFolder:IsA("Folder") then
		for _, child in ipairs(enemiesFolder:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("EnemyId") == enemyId then
				return child
			end
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(ANIMATED_ENEMY_TAG)) do
		if instance:IsA("Model") and instance:GetAttribute("EnemyId") == enemyId then
			return instance
		end
	end

	return nil
end

function StructureAnimationController:_ConnectPlacementsFolder(placementsFolder: Folder)
	if self._placementsFolderConnectionAdded ~= nil then
		self._placementsFolderConnectionAdded:Disconnect()
	end
	if self._placementsFolderConnectionRemoved ~= nil then
		self._placementsFolderConnectionRemoved:Disconnect()
	end

	self._placementsFolderConnectionAdded = placementsFolder.ChildAdded:Connect(function(child)
		if _IsStructureModel(child) then
			self:_TrackModel(child :: Model)
		end
	end)

	self._placementsFolderConnectionRemoved = placementsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			self:_UntrackModel(child)
		end
	end)

	for _, child in placementsFolder:GetChildren() do
		if _IsStructureModel(child) then
			self:_TrackModel(child :: Model)
		end
	end
end

function StructureAnimationController:KnitStart()
	self._combatService = Knit.GetService("CombatContext")

	local placementsFolder = Workspace:FindFirstChild(PlacementConfig.PLACEMENT_FOLDER_NAME)
	if placementsFolder and placementsFolder:IsA("Folder") then
		self:_ConnectPlacementsFolder(placementsFolder)
	end

	self._workspaceChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == PlacementConfig.PLACEMENT_FOLDER_NAME and child:IsA("Folder") then
			self:_ConnectPlacementsFolder(child)
		end
	end)
end

function StructureAnimationController:Destroy()
	if self._placementsFolderConnectionAdded ~= nil then
		self._placementsFolderConnectionAdded:Disconnect()
		self._placementsFolderConnectionAdded = nil
	end
	if self._placementsFolderConnectionRemoved ~= nil then
		self._placementsFolderConnectionRemoved:Disconnect()
		self._placementsFolderConnectionRemoved = nil
	end
	if self._workspaceChildAddedConnection ~= nil then
		self._workspaceChildAddedConnection:Disconnect()
		self._workspaceChildAddedConnection = nil
	end

	for model in self._tracked do
		self:_UntrackModel(model)
	end
end

return StructureAnimationController

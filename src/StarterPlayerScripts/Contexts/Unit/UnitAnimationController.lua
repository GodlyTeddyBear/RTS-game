--!strict

--[[
	Module: UnitAnimationController
	Purpose: Tracks replicated unit models on the client and attaches animation drivers as they appear.
	Used In System: Started by Knit on the client and driven by CollectionService tags and the Workspace unit folder.
	High-Level Flow: Track tagged or foldered unit models -> attach animation setup -> untrack on removal.
	Boundaries: Owns client unit animation attachment only; does not own unit spawning, replication, or model creation.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AnimateUnitModule = require(script.Parent.AnimateUnitModule)
local UnitReplicationClient = require(script.Parent.Infrastructure.Persistence.UnitReplicationClient)

local ANIMATED_UNIT_TAG = "CombatUnit"
local UNITS_FOLDER_NAME = "Units"

type TTrackedEntry = {
	Cleanup: (() -> ())?,
	AncestryConnection: RBXScriptConnection?,
}

local UnitAnimationController = Knit.CreateController({
	Name = "UnitAnimationController",
})

local function _IsUnitModel(instance: Instance): boolean
	if not instance:IsA("Model") then
		return false
	end

	local unitGuid = instance:GetAttribute("UnitGuid")
	return type(unitGuid) == "string" and unitGuid ~= ""
end

local function _BuildUnitActorHandle(model: Model): string?
	local unitGuid = model:GetAttribute("UnitGuid")
	if type(unitGuid) == "string" and unitGuid ~= "" then
		return "Unit:" .. unitGuid
	end

	return nil
end

function UnitAnimationController:KnitInit()
	self._tracked = {} :: { [Model]: TTrackedEntry }
	self._unitsFolderConnectionAdded = nil :: RBXScriptConnection?
	self._unitsFolderConnectionRemoved = nil :: RBXScriptConnection?
	self._workspaceChildAddedConnection = nil :: RBXScriptConnection?
	self._tagAddedConnection = nil :: RBXScriptConnection?
	self._tagRemovedConnection = nil :: RBXScriptConnection?
	self._combatService = nil
	self._unitReplicationClient = UnitReplicationClient.new()
end

function UnitAnimationController:_TrackModel(model: Model)
	if self._tracked[model] ~= nil then
		return
	end

	local entry: TTrackedEntry = {
		Cleanup = nil,
		AncestryConnection = nil,
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
		}

		return setmetatable(base, {
			__index = function(_, key)
				if key == "ActorId" or key == "NPCId" then
					return _BuildUnitActorHandle(model)
				end
				return nil
			end,
		})
	end

	AnimateUnitModule.setup(model, buildContext(), self._unitReplicationClient)
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

function UnitAnimationController:_UntrackModel(model: Model)
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

	self._tracked[model] = nil
end

function UnitAnimationController:_ConnectUnitsFolder(unitsFolder: Folder)
	if self._unitsFolderConnectionAdded ~= nil then
		self._unitsFolderConnectionAdded:Disconnect()
	end
	if self._unitsFolderConnectionRemoved ~= nil then
		self._unitsFolderConnectionRemoved:Disconnect()
	end

	self._unitsFolderConnectionAdded = unitsFolder.ChildAdded:Connect(function(child)
		if _IsUnitModel(child) then
			self:_TrackModel(child :: Model)
		end
	end)

	self._unitsFolderConnectionRemoved = unitsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			self:_UntrackModel(child)
		end
	end)

	for _, child in unitsFolder:GetChildren() do
		if _IsUnitModel(child) then
			self:_TrackModel(child :: Model)
		end
	end
end

function UnitAnimationController:KnitStart()
	self._combatService = Knit.GetService("CombatContext")
	self._unitReplicationClient:Init()
	self._unitReplicationClient:Start()

	self._tagAddedConnection = CollectionService:GetInstanceAddedSignal(ANIMATED_UNIT_TAG):Connect(function(instance)
		if _IsUnitModel(instance) then
			self:_TrackModel(instance :: Model)
		end
	end)

	self._tagRemovedConnection = CollectionService:GetInstanceRemovedSignal(ANIMATED_UNIT_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			self:_UntrackModel(instance)
		end
	end)

	for _, instance in CollectionService:GetTagged(ANIMATED_UNIT_TAG) do
		if _IsUnitModel(instance) then
			self:_TrackModel(instance :: Model)
		end
	end

	local unitsFolder = Workspace:FindFirstChild(UNITS_FOLDER_NAME)
	if unitsFolder ~= nil and unitsFolder:IsA("Folder") then
		self:_ConnectUnitsFolder(unitsFolder)
	end

	self._workspaceChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == UNITS_FOLDER_NAME and child:IsA("Folder") then
			self:_ConnectUnitsFolder(child)
		end
	end)
end

function UnitAnimationController:Destroy()
	if self._tagAddedConnection ~= nil then
		self._tagAddedConnection:Disconnect()
		self._tagAddedConnection = nil
	end
	if self._tagRemovedConnection ~= nil then
		self._tagRemovedConnection:Disconnect()
		self._tagRemovedConnection = nil
	end
	if self._unitsFolderConnectionAdded ~= nil then
		self._unitsFolderConnectionAdded:Disconnect()
		self._unitsFolderConnectionAdded = nil
	end
	if self._unitsFolderConnectionRemoved ~= nil then
		self._unitsFolderConnectionRemoved:Disconnect()
		self._unitsFolderConnectionRemoved = nil
	end
	if self._workspaceChildAddedConnection ~= nil then
		self._workspaceChildAddedConnection:Disconnect()
		self._workspaceChildAddedConnection = nil
	end

	for model in self._tracked do
		self:_UntrackModel(model)
	end

	if self._unitReplicationClient ~= nil then
		self._unitReplicationClient:Destroy()
		self._unitReplicationClient = nil
	end
end

return UnitAnimationController

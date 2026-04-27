--!strict

--[[
	Module: EnemyAnimationController
	Purpose: Tracks replicated enemy models on the client and attaches animation drivers as they appear.
	Used In System: Started by Knit on the client and driven by CollectionService tags and the Workspace enemy folder.
	High-Level Flow: Register client registry -> track tagged or foldered enemy models -> attach animation setup -> untrack on removal.
	Boundaries: Owns client animation attachment only; does not own enemy spawning, replication, or model creation.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local ActionRegistry = require(ReplicatedStorage.Utilities.ActionSystem.ActionRegistry)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

local AnimateEnemyModule = require(script.Parent.AnimateEnemyModule)
local NPCBillboardService = require(script.Parent.Infrastructure.NPCBillboardService)
local AttackAction = require(script.Parent.Actions.AttackAction)

local TAG = "[EnemyAnimation]"
local ANIMATED_ENEMY_TAG = "AnimatedEnemy"
local ENEMIES_FOLDER_NAME = "Enemies"

type TTrackedEntry = {
	Cleanup: (() -> ())?,
	AncestryConnection: RBXScriptConnection?,
	BillboardId: string?,
}

-- [Dependencies]
--[=[
	@class EnemyAnimationController
	Tracks replicated enemy models and attaches the shared locomotion animation setup on the client.
	@client
]=]
local EnemyAnimationController = Knit.CreateController({
	Name = "EnemyAnimationController",
})

-- [Private Helpers]

-- Returns true when the instance is a replicated enemy model with the identity attribute the animation layer expects.
local function _IsEnemyModel(instance: Instance): boolean
	return instance:IsA("Model") and type(instance:GetAttribute("EnemyId")) == "string"
end

local function _ResolveDisplayName(model: Model): string
	local enemyRole = model:GetAttribute("EnemyRole")
	if type(enemyRole) == "string" then
		local roleConfig = EnemyConfig.ROLES[enemyRole]
		if roleConfig and type(roleConfig.displayName) == "string" then
			return roleConfig.displayName
		end
		return enemyRole
	end

	return model.Name
end

-- [Public API]

--[=[
	@within EnemyAnimationController
	Initializes the client registry and tracking state before any enemy models are observed.
]=]
function EnemyAnimationController:KnitInit()
	local attackAction = AttackAction.new()
	ActionRegistry.Register("AttackStructure", attackAction)
	ActionRegistry.Register("AttackBase", attackAction)

	local registry = Registry.new("Client")
	self.Registry = registry

	self._tracked = {} :: { [Model]: TTrackedEntry }
	self._enemyFolderConnectionAdded = nil :: RBXScriptConnection?
	self._enemyFolderConnectionRemoved = nil :: RBXScriptConnection?
	self._workspaceChildAddedConnection = nil :: RBXScriptConnection?
	self._tagAddedConnection = nil :: RBXScriptConnection?
	self._tagRemovedConnection = nil :: RBXScriptConnection?
	self._npcBillboardService = NPCBillboardService.new()
	self._combatService = nil

	registry:Register("NPCBillboardService", self._npcBillboardService, "Infrastructure")

	registry:InitAll()
end

-- Tracks a single enemy model and wires cleanup so the animation driver stops with the model.
function EnemyAnimationController:_TrackModel(model: Model)
	if self._tracked[model] then
		return
	end

	-- Remember the model first so duplicate signals do not reinitialize it.
	local entry: TTrackedEntry = {
		Cleanup = nil,
		AncestryConnection = nil,
		BillboardId = nil,
	}
	self._tracked[model] = entry

	local enemyId = model:GetAttribute("EnemyId")
	if type(enemyId) == "string" then
		local displayName = _ResolveDisplayName(model)
		self._npcBillboardService:Mount(enemyId, model, displayName)
		entry.BillboardId = enemyId
	end

	-- Untrack automatically when the model leaves the DataModel.
	entry.AncestryConnection = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			self:_UntrackModel(model)
		end
	end)

	local function buildContext(): any
		local combatService = self._combatService
		local base = {
			Model = nil,
			CombatService = combatService,
			ActorKind = "Enemy",
		}

		return setmetatable(base, {
			__index = function(_, key)
				if key == "ActorId" or key == "NPCId" then
					local resolvedEnemyId = model:GetAttribute("EnemyId")
					return if type(resolvedEnemyId) == "string" then resolvedEnemyId else nil
				end
				return nil
			end,
		})
	end

	-- Attach the shared enemy locomotion animation driver and retain its cleanup handle.
	AnimateEnemyModule.setup(model, buildContext())
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
		:catch(function(err)
			warn(TAG, model.Name, "- setup failed:", tostring(err))
			self:_UntrackModel(model)
		end)
end

-- Disconnects model-level listeners and releases animation cleanup for a tracked enemy model.
function EnemyAnimationController:_UntrackModel(model: Model)
	local entry = self._tracked[model]
	if not entry then
		return
	end

	if entry.AncestryConnection then
		entry.AncestryConnection:Disconnect()
		entry.AncestryConnection = nil
	end

	if entry.Cleanup then
		entry.Cleanup()
		entry.Cleanup = nil
	end

	if entry.BillboardId then
		self._npcBillboardService:Unmount(entry.BillboardId)
		entry.BillboardId = nil
	end

	self._tracked[model] = nil
end

-- Starts tracking enemy models that live inside the Workspace.Enemies folder.
function EnemyAnimationController:_ConnectEnemiesFolder(enemiesFolder: Folder)
	if self._enemyFolderConnectionAdded then
		self._enemyFolderConnectionAdded:Disconnect()
	end
	if self._enemyFolderConnectionRemoved then
		self._enemyFolderConnectionRemoved:Disconnect()
	end

	self._enemyFolderConnectionAdded = enemiesFolder.ChildAdded:Connect(function(child)
		if _IsEnemyModel(child) then
			self:_TrackModel(child :: Model)
		end
	end)

	self._enemyFolderConnectionRemoved = enemiesFolder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			self:_UntrackModel(child)
		end
	end)

	for _, child in enemiesFolder:GetChildren() do
		if _IsEnemyModel(child) then
			self:_TrackModel(child :: Model)
		end
	end
end

--[=[
	@within EnemyAnimationController
	Connects tag and folder listeners so newly replicated enemies get animated automatically.
]=]
function EnemyAnimationController:KnitStart()
	local registry = self.Registry
	self._combatService = Knit.GetService("CombatContext")

	-- Track enemies that arrive through the replicated animation tag.
	self._tagAddedConnection = CollectionService:GetInstanceAddedSignal(ANIMATED_ENEMY_TAG):Connect(function(instance)
		if _IsEnemyModel(instance) then
			self:_TrackModel(instance :: Model)
		end
	end)

	-- Stop tracking when the animation tag is removed from a model.
	self._tagRemovedConnection = CollectionService:GetInstanceRemovedSignal(ANIMATED_ENEMY_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			self:_UntrackModel(instance)
		end
	end)

	-- Attach to any tagged models that already exist before the controller starts.
	for _, instance in CollectionService:GetTagged(ANIMATED_ENEMY_TAG) do
		if _IsEnemyModel(instance) then
			self:_TrackModel(instance :: Model)
		end
	end

	-- Attach to the replicated enemy folder if it already exists in Workspace.
	local enemiesFolder = Workspace:FindFirstChild(ENEMIES_FOLDER_NAME)
	if enemiesFolder and enemiesFolder:IsA("Folder") then
		self:_ConnectEnemiesFolder(enemiesFolder)
	end

	-- Watch for a late-spawned enemy folder so client animation still boots correctly.
	self._workspaceChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == ENEMIES_FOLDER_NAME and child:IsA("Folder") then
			self:_ConnectEnemiesFolder(child)
		end
	end)

	-- Start the client registry after all listeners are wired.
	registry:StartOrdered({ "Infrastructure" })
end

--[=[
	@within EnemyAnimationController
	Disconnects listeners and clears tracked animation state during client shutdown.
]=]
function EnemyAnimationController:Destroy()
	-- Disconnect global listeners first so no new models are scheduled while teardown runs.
	if self._tagAddedConnection then
		self._tagAddedConnection:Disconnect()
		self._tagAddedConnection = nil
	end
	if self._tagRemovedConnection then
		self._tagRemovedConnection:Disconnect()
		self._tagRemovedConnection = nil
	end
	if self._enemyFolderConnectionAdded then
		self._enemyFolderConnectionAdded:Disconnect()
		self._enemyFolderConnectionAdded = nil
	end
	if self._enemyFolderConnectionRemoved then
		self._enemyFolderConnectionRemoved:Disconnect()
		self._enemyFolderConnectionRemoved = nil
	end
	if self._workspaceChildAddedConnection then
		self._workspaceChildAddedConnection:Disconnect()
		self._workspaceChildAddedConnection = nil
	end

	-- Release any model-specific animation cleanup after the global listeners are gone.
	for model in self._tracked do
		self:_UntrackModel(model)
	end
end

return EnemyAnimationController

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderVisualReplacementConfig =
	require(ReplicatedStorage.Contexts.Render.Config.RenderVisualReplacementConfig)

local RenderVisualReplacementService = {}
RenderVisualReplacementService.__index = RenderVisualReplacementService

function RenderVisualReplacementService.new()
	local self = setmetatable({}, RenderVisualReplacementService)
	self._janitor = Janitor.new()
	self._trueVisualsRoot = nil
	self._restoredInstancesByVisualReplacementRoot = {} :: { [Instance]: true }
	self._pendingInstancesByVisualReplacementRoot = {} :: { [Instance]: true }
	return self
end

function RenderVisualReplacementService:Start()
	self._trueVisualsRoot = self:_EnsureTrueVisualsRoot()
	self:_TrackWorkspaceInstances()
	self:_TrackTrueVisualProfiles()
	self:_ScanWorkspaceInstances()
end

function RenderVisualReplacementService:Destroy()
	table.clear(self._restoredInstancesByVisualReplacementRoot)
	table.clear(self._pendingInstancesByVisualReplacementRoot)
	self._trueVisualsRoot = nil
	self._janitor:Destroy()
end

function RenderVisualReplacementService:_EnsureTrueVisualsRoot(): Folder
	local trueVisualsRoot = ReplicatedStorage:WaitForChild(RenderVisualReplacementConfig.TrueVisualsFolderName)
	assert(trueVisualsRoot:IsA("Folder"), "RenderVisualReplacementService: true visuals root must be a Folder")
	return trueVisualsRoot
end

function RenderVisualReplacementService:_TrackWorkspaceInstances()
	self._janitor:Add(Workspace.DescendantAdded:Connect(function(instance: Instance)
		self:_TrackVisualReplacementRoot(instance)
	end), "Disconnect")
	self._janitor:Add(Workspace.DescendantRemoving:Connect(function(instance: Instance)
		self._restoredInstancesByVisualReplacementRoot[instance] = nil
		self._pendingInstancesByVisualReplacementRoot[instance] = nil
	end), "Disconnect")
end

function RenderVisualReplacementService:_TrackTrueVisualProfiles()
	self._janitor:Add(self._trueVisualsRoot.DescendantAdded:Connect(function(_instance: Instance)
		self:_RetryPendingVisualReplacementRoots()
	end), "Disconnect")
end

function RenderVisualReplacementService:_ScanWorkspaceInstances()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		self:_TrackVisualReplacementRoot(descendant)
	end
end

function RenderVisualReplacementService:_RetryPendingVisualReplacementRoots()
	local pendingVisualReplacementRoots = {}
	for visualReplacementRoot in self._pendingInstancesByVisualReplacementRoot do
		table.insert(pendingVisualReplacementRoots, visualReplacementRoot)
	end

	for _, visualReplacementRoot in ipairs(pendingVisualReplacementRoots) do
		self._pendingInstancesByVisualReplacementRoot[visualReplacementRoot] = nil
		self:_TrackVisualReplacementRoot(visualReplacementRoot)
	end
end

function RenderVisualReplacementService:_TrackVisualReplacementRoot(instance: Instance)
	if not self:_IsVisualReplacementRoot(instance) then
		return
	end
	if self._restoredInstancesByVisualReplacementRoot[instance] == true then
		return
	end

	local didRestore = self:_RestoreVisualReplacementRoot(instance)
	if didRestore then
		self._restoredInstancesByVisualReplacementRoot[instance] = true
		self._pendingInstancesByVisualReplacementRoot[instance] = nil
		return
	end

	self._pendingInstancesByVisualReplacementRoot[instance] = true
end

function RenderVisualReplacementService:_RestoreVisualReplacementRoot(visualReplacementRoot: Instance): boolean
	local categoryConfig = RenderVisualReplacementConfig.GetCategoryConfigForInstance(visualReplacementRoot)
	if categoryConfig == nil or not RenderVisualReplacementConfig.RequiresClientRestore(categoryConfig) then
		return false
	end

	local visualId = RenderVisualReplacementConfig.GetVisualReplacementId(visualReplacementRoot)
	if visualId == nil then
		return false
	end

	local trueVisualFolder = self:_ResolveTrueVisualFolder(visualId)
	if trueVisualFolder == nil then
		return false
	end

	local restoredChildren = {}
	for _, trueVisualChild in ipairs(trueVisualFolder:GetChildren()) do
		table.insert(restoredChildren, trueVisualChild:Clone())
	end

	for _, restoredChild in ipairs(restoredChildren) do
		restoredChild.Parent = visualReplacementRoot
	end

	return true
end

function RenderVisualReplacementService:_ResolveTrueVisualFolder(visualId: string): Folder?
	local trueVisualFolder = self._trueVisualsRoot:FindFirstChild(visualId)
	if trueVisualFolder == nil or not trueVisualFolder:IsA("Folder") then
		return nil
	end

	return trueVisualFolder
end

function RenderVisualReplacementService:_IsVisualReplacementRoot(instance: Instance): boolean
	local categoryConfig = RenderVisualReplacementConfig.GetCategoryConfigForInstance(instance)
	if categoryConfig == nil then
		return false
	end

	if not RenderVisualReplacementConfig.RequiresClientRestore(categoryConfig) then
		return false
	end

	return RenderVisualReplacementConfig.GetVisualReplacementId(instance) ~= nil
end

return RenderVisualReplacementService

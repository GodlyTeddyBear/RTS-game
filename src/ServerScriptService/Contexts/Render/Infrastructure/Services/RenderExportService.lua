--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderExportConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderExportConfig)
local RenderVisualReplacementConfig =
	require(ReplicatedStorage.Contexts.Render.Config.RenderVisualReplacementConfig)
local RenderVisualReplacementBuilder = require(script.Parent.RenderVisualReplacementBuilder)

local RenderExportService = {}
RenderExportService.__index = RenderExportService

function RenderExportService.new()
	local self = setmetatable({}, RenderExportService)
	self._janitor = Janitor.new()
	self._hiddenFolder = nil
	self._trueVisualsRoot = nil
	self._visualReplacementBuilder = RenderVisualReplacementBuilder.new()
	return self
end

function RenderExportService:Init(_registry: any, _name: string)
	self._trueVisualsRoot = self._visualReplacementBuilder:EnsureTrueVisualsRoot()
	self:_PreprocessConfiguredAssets()
end

function RenderExportService:Start()
	self._hiddenFolder = self:_EnsureHiddenFolder()
	self:_HideConfiguredWorkspaceFolders()
end

function RenderExportService:Destroy()
	self._trueVisualsRoot = nil
	self._hiddenFolder = nil
	self._janitor:Destroy()
end

function RenderExportService:_EnsureHiddenFolder(): Folder
	local hiddenFolder = ServerStorage:FindFirstChild(RenderVisualReplacementConfig.HiddenFolderName)
	if hiddenFolder ~= nil then
		assert(
			hiddenFolder:IsA("Folder"),
			`RenderExportService: ServerStorage.{RenderVisualReplacementConfig.HiddenFolderName} must be a Folder`
		)
		return hiddenFolder
	end

	hiddenFolder = Instance.new("Folder")
	hiddenFolder.Name = RenderVisualReplacementConfig.HiddenFolderName
	hiddenFolder.Parent = ServerStorage
	return hiddenFolder
end

function RenderExportService:_HideConfiguredWorkspaceFolders()
	for _, folderName in ipairs(RenderExportConfig.FolderNames) do
		local workspaceFolder = Workspace:FindFirstChild(folderName)
		if workspaceFolder == nil or not workspaceFolder:IsA("Folder") then
			warn(`RenderExportService: Workspace is missing configured folder "{folderName}"`)
			continue
		end

		local existingHiddenFolder = self._hiddenFolder:FindFirstChild(workspaceFolder.Name)
		if existingHiddenFolder ~= nil then
			existingHiddenFolder:Destroy()
		end

		workspaceFolder.Parent = self._hiddenFolder
	end
end

function RenderExportService:_PreprocessConfiguredAssets()
	local assetsRoot = ReplicatedStorage:FindFirstChild(RenderVisualReplacementConfig.SourceAssetsRootName)
	if assetsRoot == nil or not assetsRoot:IsA("Folder") then
		warn(
			`RenderExportService: ReplicatedStorage.{RenderVisualReplacementConfig.SourceAssetsRootName} is missing`
		)
		return
	end

	self._visualReplacementBuilder:PreprocessAssets({
		AssetsRoot = assetsRoot,
		TrueVisualsRoot = self._trueVisualsRoot,
	})
end

return RenderExportService

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderExportConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderExportConfig)

local EXPORTED_FOLDER_NAME = "Exported"

local RenderExportService = {}
RenderExportService.__index = RenderExportService

function RenderExportService.new()
	local self = setmetatable({}, RenderExportService)
	self._janitor = Janitor.new()
	self._exportedFolder = nil
	return self
end

function RenderExportService:Init(_registry: any, _name: string)
end

function RenderExportService:Start()
	self._exportedFolder = self:_EnsureExportedFolder()
	self:_ExportConfiguredFolders()
end

function RenderExportService:Destroy()
	self._exportedFolder = nil
	self._janitor:Destroy()
end

function RenderExportService:_EnsureExportedFolder(): Folder
	local exportedFolder = ServerStorage:FindFirstChild(EXPORTED_FOLDER_NAME)
	if exportedFolder ~= nil then
		assert(exportedFolder:IsA("Folder"), `RenderExportService: ServerStorage.{EXPORTED_FOLDER_NAME} must be a Folder`)
		return exportedFolder
	end

	exportedFolder = Instance.new("Folder")
	exportedFolder.Name = EXPORTED_FOLDER_NAME
	exportedFolder.Parent = ServerStorage
	return exportedFolder
end

function RenderExportService:_ExportConfiguredFolders()
	for _, folderName in ipairs(RenderExportConfig.FolderNames) do
		local workspaceFolder = Workspace:FindFirstChild(folderName)
		if workspaceFolder == nil or not workspaceFolder:IsA("Folder") then
			warn(`RenderExportService: Workspace is missing configured folder "{folderName}"`)
			continue
		end

		local targetName = self:_BuildUniqueExportName(folderName)
		workspaceFolder.Name = targetName
		workspaceFolder.Parent = self._exportedFolder
	end
end

function RenderExportService:_BuildUniqueExportName(baseName: string): string
	if self._exportedFolder:FindFirstChild(baseName) == nil then
		return baseName
	end

	local suffix = 1
	while true do
		local candidateName = `{baseName}_{suffix}`
		if self._exportedFolder:FindFirstChild(candidateName) == nil then
			return candidateName
		end
		suffix += 1
	end
end

return RenderExportService

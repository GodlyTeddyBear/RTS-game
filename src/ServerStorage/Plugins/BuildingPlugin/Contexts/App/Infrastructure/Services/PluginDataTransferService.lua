--!strict

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginActionResult = PluginTypes.TPluginActionResult

local DATA_FOLDER_NAME = "__Data__"
local OLD_FOLDER_NAME = "__Old__"
local CURRENT_FOLDER_NAME = "__Current__"
local TAB_SETTINGS = "Settings"
local TAB_ASSETS = "Assets"
local TAB_WAYPOINTS = "Waypoints"
local REQUIRED_TABS = { TAB_SETTINGS, TAB_ASSETS, TAB_WAYPOINTS }

local PluginDataTransferService = {}
PluginDataTransferService.__index = PluginDataTransferService

function PluginDataTransferService.new(settingsService)
	local self = setmetatable({}, PluginDataTransferService)
	self.Settings = settingsService
	return self
end

function PluginDataTransferService:GetSnapshotNames(): { string }
	local dataFolder = self:_GetDataFolder()
	if dataFolder == nil then
		return {}
	end

	local snapshotNames = {}
	for _, child in dataFolder:GetChildren() do
		if child:IsA("Folder") and child.Name ~= OLD_FOLDER_NAME and child.Name ~= CURRENT_FOLDER_NAME then
			table.insert(snapshotNames, child.Name)
		end
	end

	table.sort(snapshotNames, function(leftName, rightName)
		return leftName > rightName
	end)

	return snapshotNames
end

function PluginDataTransferService:ExportCurrentData(): TPluginActionResult
	local dataFolder = self:_EnsureDataFolder()
	local snapshotFolder = self:_CreateSnapshotFolder(dataFolder)
	local payloadByTab = self.Settings:GetDataTransferPayloadByTab()

	self:_WritePayload(snapshotFolder, payloadByTab)

	return self:_CreateResult(true, "Exported saved data to ServerStorage." .. DATA_FOLDER_NAME .. "/" .. snapshotFolder.Name .. ".")
end

function PluginDataTransferService:ImportSnapshot(snapshotName: string): TPluginActionResult
	local dataFolder = self:_GetDataFolder()
	if dataFolder == nil then
		return self:_CreateResult(false, "No saved snapshots found in ServerStorage." .. DATA_FOLDER_NAME .. ".")
	end

	local sourceSnapshot = dataFolder:FindFirstChild(snapshotName)
	if sourceSnapshot == nil or not sourceSnapshot:IsA("Folder") or sourceSnapshot.Name == OLD_FOLDER_NAME or sourceSnapshot.Name == CURRENT_FOLDER_NAME then
		return self:_CreateResult(false, "Selected snapshot was not found.")
	end

	local oldFolder = self:_EnsureOldFolder()
	local oldSnapshot = self:_CreateSnapshotFolder(oldFolder)
	self:_WritePayload(oldSnapshot, self.Settings:GetDataTransferPayloadByTab())

	local decodeSuccess, decodedOrError = self:_DecodePayloadFromFolder(sourceSnapshot)
	if not decodeSuccess then
		return self:_CreateResult(false, decodedOrError)
	end

	local applySuccess, applyMessage = self.Settings:ApplyDataTransferPayloadByTab(decodedOrError)
	if not applySuccess then
		return self:_CreateResult(false, applyMessage)
	end

	self:SyncCurrentData()

	return self:_CreateResult(true, "Imported snapshot " .. snapshotName .. ". Previous data was backed up to " .. oldSnapshot.Name .. ".")
end

function PluginDataTransferService:EnsureCurrentDataOnStart(): TPluginActionResult
	self:_EnsureDataFolder()
	local currentFolder = self:_GetCurrentFolder()

	if currentFolder == nil then
		local createdCurrentFolder = self:_EnsureCurrentFolder()
		self:_WritePayload(createdCurrentFolder, self.Settings:GetDataTransferPayloadByTab())
		return self:_CreateResult(true, "Created ServerStorage." .. DATA_FOLDER_NAME .. "/" .. CURRENT_FOLDER_NAME .. ".")
	end

	local decodeSuccess, decodedOrError = self:_DecodePayloadFromFolder(currentFolder)
	if decodeSuccess then
		local applySuccess, applyMessage = self.Settings:ApplyDataTransferPayloadByTab(decodedOrError)
		if applySuccess then
			return self:_CreateResult(true, "Loaded current data from ServerStorage." .. DATA_FOLDER_NAME .. "/" .. CURRENT_FOLDER_NAME .. ".")
		end

		local syncResult = self:SyncCurrentData()
		return self:_CreateResult(false, "Failed to apply current data (" .. applyMessage .. "). " .. syncResult.Message)
	end

	local syncResult = self:SyncCurrentData()
	return self:_CreateResult(false, decodedOrError .. " " .. syncResult.Message)
end

function PluginDataTransferService:SyncCurrentData(): TPluginActionResult
	local currentFolder = self:_EnsureCurrentFolder()
	local payloadByTab = self.Settings:GetDataTransferPayloadByTab()
	self:_WritePayload(currentFolder, payloadByTab)
	return self:_CreateResult(true, "Synced ServerStorage." .. DATA_FOLDER_NAME .. "/" .. CURRENT_FOLDER_NAME .. ".")
end

function PluginDataTransferService:_EnsureDataFolder(): Folder
	local existing = self:_GetDataFolder()
	if existing ~= nil then
		return existing
	end

	local dataFolder = Instance.new("Folder")
	dataFolder.Name = DATA_FOLDER_NAME
	dataFolder.Parent = ServerStorage
	return dataFolder
end

function PluginDataTransferService:_GetDataFolder(): Folder?
	local dataFolder = ServerStorage:FindFirstChild(DATA_FOLDER_NAME)
	if dataFolder and dataFolder:IsA("Folder") then
		return dataFolder
	end

	return nil
end

function PluginDataTransferService:_EnsureOldFolder(): Folder
	local dataFolder = self:_EnsureDataFolder()
	local oldFolder = dataFolder:FindFirstChild(OLD_FOLDER_NAME)
	if oldFolder and oldFolder:IsA("Folder") then
		return oldFolder
	end

	local createdOldFolder = Instance.new("Folder")
	createdOldFolder.Name = OLD_FOLDER_NAME
	createdOldFolder.Parent = dataFolder
	return createdOldFolder
end

function PluginDataTransferService:_GetCurrentFolder(): Folder?
	local dataFolder = self:_GetDataFolder()
	if dataFolder == nil then
		return nil
	end

	local currentFolder = dataFolder:FindFirstChild(CURRENT_FOLDER_NAME)
	if currentFolder and currentFolder:IsA("Folder") then
		return currentFolder
	end

	return nil
end

function PluginDataTransferService:_EnsureCurrentFolder(): Folder
	local dataFolder = self:_EnsureDataFolder()
	local currentFolder = dataFolder:FindFirstChild(CURRENT_FOLDER_NAME)
	if currentFolder and currentFolder:IsA("Folder") then
		return currentFolder
	end

	local createdCurrentFolder = Instance.new("Folder")
	createdCurrentFolder.Name = CURRENT_FOLDER_NAME
	createdCurrentFolder.Parent = dataFolder
	return createdCurrentFolder
end

function PluginDataTransferService:_CreateSnapshotFolder(parentFolder: Folder): Folder
	local baseName = os.date("%Y-%m-%d_%H-%M-%S")
	local name = baseName
	local suffix = 2

	while parentFolder:FindFirstChild(name) ~= nil do
		name = baseName .. "_" .. tostring(suffix)
		suffix = suffix + 1
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parentFolder
	return folder
end

function PluginDataTransferService:_WritePayload(snapshotFolder: Folder, payloadByTab: { [string]: any })
	for tabName, tabPayload in payloadByTab do
		snapshotFolder:SetAttribute(tabName, HttpService:JSONEncode(tabPayload))
	end
end

function PluginDataTransferService:_DecodePayloadFromFolder(snapshotFolder: Folder): (boolean, any)
	local payloadByTab = {}

	for _, tabName in REQUIRED_TABS do
		local encodedValue = snapshotFolder:GetAttribute(tabName)
		if type(encodedValue) ~= "string" or encodedValue == "" then
			return false, "Snapshot is missing required tab attribute: " .. tabName .. "."
		end

		local decodeSuccess, decodedValue = pcall(function()
			return HttpService:JSONDecode(encodedValue)
		end)
		if not decodeSuccess or type(decodedValue) ~= "table" then
			return false, "Snapshot contains invalid JSON for tab: " .. tabName .. "."
		end

		payloadByTab[tabName] = decodedValue
	end

	return true, payloadByTab
end

function PluginDataTransferService:_CreateResult(success: boolean, message: string): TPluginActionResult
	return {
		Success = success,
		ChangedCount = if success then 1 else 0,
		SkippedCount = 0,
		Message = message,
	}
end

return PluginDataTransferService

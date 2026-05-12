--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local MapConfig = require(ReplicatedStorage.Contexts.Map.Config.MapConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Ensure = Result.Ensure

local function _ResolvePath(root: Instance, path: string): Instance?
	local current = root
	for segment in string.gmatch(path, "[^%.]+") do
		local child = current:FindFirstChild(segment)
		if child == nil then
			return nil
		end
		current = child
	end

	return current
end

local function _ExtractModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	end

	if instance:IsA("Folder") then
		return instance:FindFirstChildWhichIsA("Model")
	end

	return nil
end

local function _ResolveAnchorBasePart(instance: Instance?): BasePart?
	if instance == nil then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		local primaryPart = instance.PrimaryPart
		if primaryPart ~= nil then
			return primaryPart
		end

		return instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function _ResolveInstanceCFrame(instance: Instance): CFrame
	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	if instance:IsA("Model") then
		return ModelPlus.GetPivot(instance)
	end

	local anchor = _ResolveAnchorBasePart(instance)
	assert(anchor ~= nil, "AuthoredMapLookupService: expected a BasePart or Model-backed marker")
	return anchor.CFrame
end

local AuthoredMapLookupService = {}
AuthoredMapLookupService.__index = AuthoredMapLookupService

function AuthoredMapLookupService.new()
	local self = setmetatable({}, AuthoredMapLookupService)
	return self
end

function AuthoredMapLookupService:Init(_registry: any, _name: string)
end

function AuthoredMapLookupService:GetLobbyInstance(): Model?
	local lobbyContainer = self:_GetLobbyContainer()
	if lobbyContainer == nil then
		return nil
	end

	return _ExtractModel(lobbyContainer)
end

function AuthoredMapLookupService:GetLobbySpawnInstance(): BasePart?
	local lobbyContainer = self:_GetLobbyContainer()
	if lobbyContainer == nil then
		return nil
	end

	local marker = self:_ResolveMarkerFromContainer(
		lobbyContainer,
		MapConfig.LOBBY_SPAWN_PATH,
		MapConfig.LOBBY_SPAWN_MARKER_NAME
	)
	return _ResolveAnchorBasePart(marker)
end

function AuthoredMapLookupService:GetLobbySpawnCFrame(): Result.Result<CFrame>
	return self:_ResolveMarkerCFrameFromLobby(MapConfig.LOBBY_SPAWN_PATH, MapConfig.LOBBY_SPAWN_MARKER_NAME)
end

function AuthoredMapLookupService:GetRunEntryInstance(): BasePart?
	local gameContainer = self:_GetGameContainer()
	if gameContainer == nil then
		return nil
	end

	local marker = self:_ResolveMarkerFromContainer(gameContainer, MapConfig.RUN_ENTRY_PATH, MapConfig.RUN_ENTRY_MARKER_NAME)
	return _ResolveAnchorBasePart(marker)
end

function AuthoredMapLookupService:GetRunEntryCFrame(): Result.Result<CFrame>
	return self:_ResolveMarkerCFrameFromGame(MapConfig.RUN_ENTRY_PATH, MapConfig.RUN_ENTRY_MARKER_NAME)
end

function AuthoredMapLookupService:_ResolveMarkerCFrameFromLobby(path: string, markerName: string): Result.Result<CFrame>
	return self:_ResolveMarkerCFrame(
		self:_GetLobbyContainer(),
		path,
		markerName,
		"MissingWorkspaceLobbyContainer",
		Errors.MISSING_WORKSPACE_LOBBY_CONTAINER,
		"LobbySpawnNotFound",
		Errors.LOBBY_SPAWN_NOT_FOUND
	)
end

function AuthoredMapLookupService:_ResolveMarkerCFrameFromGame(path: string, markerName: string): Result.Result<CFrame>
	return self:_ResolveMarkerCFrame(
		self:_GetGameContainer(),
		path,
		markerName,
		"MissingWorkspaceGameContainer",
		Errors.MISSING_WORKSPACE_GAME_CONTAINER,
		"RunEntryNotFound",
		Errors.RUN_ENTRY_NOT_FOUND
	)
end

function AuthoredMapLookupService:_ResolveMarkerCFrame(
	container: Instance?,
	path: string,
	markerName: string,
	missingContainerType: string,
	missingContainerMessage: string,
	missingMarkerType: string,
	missingMarkerMessage: string
): Result.Result<CFrame>
	Ensure(container ~= nil, missingContainerType, missingContainerMessage)
	local resolvedContainer = container :: Instance

	local marker = self:_ResolveMarkerFromContainer(resolvedContainer, path, markerName)
	if marker == nil then
		return Err(missingMarkerType, missingMarkerMessage, {
			Path = path,
			MarkerName = markerName,
		})
	end

	return Ok(_ResolveInstanceCFrame(marker))
end

function AuthoredMapLookupService:_ResolveMarkerFromContainer(
	container: Instance,
	path: string,
	markerName: string
): Instance?
	local pathResolved = _ResolvePath(container, path)
	if pathResolved ~= nil then
		return pathResolved
	end

	return container:FindFirstChild(markerName, true)
end

function AuthoredMapLookupService:_GetMapContainer(): Instance?
	return Workspace:FindFirstChild(MapConfig.WORKSPACE_MAP_CONTAINER_NAME)
end

function AuthoredMapLookupService:_GetLobbyContainer(): Instance?
	local mapContainer = self:_GetMapContainer()
	if mapContainer == nil then
		return nil
	end

	return mapContainer:FindFirstChild(MapConfig.WORKSPACE_LOBBY_CONTAINER_NAME)
end

function AuthoredMapLookupService:_GetGameContainer(): Instance?
	local mapContainer = self:_GetMapContainer()
	if mapContainer == nil then
		return nil
	end

	return mapContainer:FindFirstChild(MapConfig.WORKSPACE_GAME_CONTAINER_NAME)
end

return AuthoredMapLookupService

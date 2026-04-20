--!strict

--[=[
	@class VillagerRouteDiscoveryService
	Discovers spawn points, exit points, and lot markers for villager pathfinding.
	@server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RouteConfig = require(ReplicatedStorage.Contexts.Villager.Config.VillagerRouteConfig)

--[=[
	@interface TShopMarkers
	@within VillagerRouteDiscoveryService
	.UserId number -- Target player's user ID
	.Entrance BasePart -- Entry marker for customer to walk from
	.WaitPoint BasePart -- Wait location in the shop
	.ExitPoint BasePart -- Exit marker to despawn from
]=]
export type TShopMarkers = {
	UserId: number,
	Entrance: BasePart,
	WaitPoint: BasePart,
	ExitPoint: BasePart,
}

local VillagerRouteDiscoveryService = {}
VillagerRouteDiscoveryService.__index = VillagerRouteDiscoveryService

export type TVillagerRouteDiscoveryService = typeof(setmetatable({} :: {
	LotContext: any?,
}, VillagerRouteDiscoveryService))

function VillagerRouteDiscoveryService.new(): TVillagerRouteDiscoveryService
	return setmetatable({}, VillagerRouteDiscoveryService)
end

function VillagerRouteDiscoveryService:Start()
	local Knit = require(ReplicatedStorage.Packages.Knit)
	self.LotContext = Knit.GetService("LotContext")
end

--[=[
	Gets a random spawn location for customers entering the world.
	@within VillagerRouteDiscoveryService
	@return CFrame? -- Random spawn point or nil if none found
]=]
function VillagerRouteDiscoveryService:GetRandomSpawnCFrame(): CFrame?
	local part = self:_GetRandomPart(self:_GetRouteFolder(RouteConfig.SpawnsFolderName))
	return part and part.CFrame or nil
end

--[=[
	Gets a random exit location for customers leaving the world.
	@within VillagerRouteDiscoveryService
	@return CFrame? -- Random exit point or nil if none found
]=]
function VillagerRouteDiscoveryService:GetRandomExitCFrame(): CFrame?
	local part = self:_GetRandomPart(self:_GetRouteFolder(RouteConfig.ExitsFolderName))
	return part and part.CFrame or nil
end

--[=[
	Gets all eligible shop marker sets, excluding specific user IDs.
	@within VillagerRouteDiscoveryService
	@param excludedUserIds { [number]: boolean } -- User IDs to skip
	@return { TShopMarkers } -- List of available shop marker sets
]=]
function VillagerRouteDiscoveryService:GetEligibleShopMarkers(excludedUserIds: { [number]: boolean }): { TShopMarkers }
	local markers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if not excludedUserIds[player.UserId] then
			local shopMarkers = self:GetShopMarkersForUser(player.UserId)
			if shopMarkers then
				table.insert(markers, shopMarkers)
			end
		end
	end
	return markers
end

--[=[
	Gets shop markers (entrance, wait point, exit) for a specific player's lot.
	@within VillagerRouteDiscoveryService
	@param userId number -- Target player's user ID
	@return TShopMarkers? -- Shop markers or nil if incomplete
]=]
function VillagerRouteDiscoveryService:GetShopMarkersForUser(userId: number): TShopMarkers?
	local lotRoots = self:_GetLotMarkerRoots(userId)
	for _, root in ipairs(lotRoots) do
		local entrance = self:_FindMarker(root, RouteConfig.CustomerEntranceName)
		local waitPoint = self:_FindMarker(root, RouteConfig.CustomerWaitPointName)
		local exitPoint = self:_FindMarker(root, RouteConfig.CustomerExitName)

		-- Return first lot with all three markers present
		if entrance and waitPoint and exitPoint then
			return {
				UserId = userId,
				Entrance = entrance,
				WaitPoint = waitPoint,
				ExitPoint = exitPoint,
			}
		end
	end

	return nil
end

-- Collects all lot folders for a player from LotContext and Workspace.Lots.
function VillagerRouteDiscoveryService:_GetLotMarkerRoots(userId: number): { Instance }
	local roots = {}

	-- Try dedicated lot folders from LotContext (Forge, Brewery, TailorShop)
	if self.LotContext then
		self:_AppendIfPresent(roots, self.LotContext:GetForgeFolderForUser(userId))
		self:_AppendIfPresent(roots, self.LotContext:GetBreweryFolderForUser(userId))
		self:_AppendIfPresent(roots, self.LotContext:GetTailorShopFolderForUser(userId))
	end

	-- Also check generic Workspace.Lots folder for any lot belonging to user
	local lotsFolder = Workspace:FindFirstChild("Lots")
	if lotsFolder then
		for _, lot in ipairs(lotsFolder:GetChildren()) do
			if lot:GetAttribute("UserId") == userId or string.find(lot.Name, tostring(userId)) then
				table.insert(roots, lot)
			end
		end
	end

	return roots
end

-- Appends instance to list if present (guards against nil).
function VillagerRouteDiscoveryService:_AppendIfPresent(roots: { Instance }, root: Instance?)
	if root then
		table.insert(roots, root)
	end
end

-- Searches recursively for a BasePart marker by name.
function VillagerRouteDiscoveryService:_FindMarker(root: Instance, markerName: string): BasePart?
	local marker = root:FindFirstChild(markerName, true)
	if marker and marker:IsA("BasePart") then
		return marker
	end
	return nil
end

-- Looks up route folder (Spawns or Exits) in Workspace hierarchy.
function VillagerRouteDiscoveryService:_GetRouteFolder(folderName: string): Folder?
	local root = Workspace:FindFirstChild(RouteConfig.RootFolderName)
	if not root then
		return nil
	end

	local folder = root:FindFirstChild(folderName)
	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

-- Collects all parts in folder and returns a random one; returns nil if empty.
function VillagerRouteDiscoveryService:_GetRandomPart(folder: Folder?): BasePart?
	if not folder then
		return nil
	end

	local parts = {}
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	if #parts == 0 then
		return nil
	end

	return parts[math.random(1, #parts)]
end

return VillagerRouteDiscoveryService

--!strict

--[[
	Lot Area Registry - Discovers and manages lot area Parts

	Responsibility: Discover LotArea Parts from workspace.Map.Zones.Lots at startup.
	Stores claim state and provides methods to query/mutate claims.
	Handles Part transparency: transparent when claimed, visible when unclaimed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err = Result.Ok, Result.Err

local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@interface TLotAreaEntry
	Represents a lot area and its current state.
	.Part BasePart -- The invisible lot area Part in workspace
	.ClaimedBy Player? -- The player who claims this area (nil if unclaimed)
	.UnclaimedModel Model? -- Visual model shown when unclaimed (nil when claimed)
]=]
export type TLotAreaEntry = {
	Part: BasePart,
	ClaimedBy: Player?,
	UnclaimedModel: Model?,
}

--[=[
	@class LotAreaRegistry
	Discovers and manages lot area Parts from the workspace.
	Stores claim state and provides query/mutation methods.
	Handles Part visibility: transparent when claimed, uses unclaimed models when free.
	@server
]=]
local LotAreaRegistry = {}
LotAreaRegistry.__index = LotAreaRegistry

export type LotAreaRegistry = typeof(setmetatable(
	{} :: {
		_areas: { [string]: TLotAreaEntry },
		_playerClaims: { [Player]: string },
		_lotRegistry: any,
		_lotsFolder: Folder,
	},
	LotAreaRegistry
))

--[=[
	Create a new LotAreaRegistry.
	@within LotAreaRegistry
	@param unclaimedLotsFolder Folder -- Workspace folder for unclaimed lot models
	@return LotAreaRegistry
]=]
function LotAreaRegistry.new(unclaimedLotsFolder: Folder): LotAreaRegistry
	local self = setmetatable({}, LotAreaRegistry)
	self._areas = {} :: { [string]: TLotAreaEntry }
	self._playerClaims = {} :: { [Player]: string }
	self._lotRegistry = nil :: any
	self._lotsFolder = unclaimedLotsFolder
	return self
end

--[=[
	Initialize the registry with the LotRegistry asset fetcher.
	Called by the DDD Registry pattern during KnitInit.
	@within LotAreaRegistry
	@param registry any -- The DDD Registry instance
	@param _name string -- The service name (unused)
]=]
function LotAreaRegistry:Init(registry: any, _name: string)
	self._lotRegistry = registry:Get("LotRegistry")
end

-- Clone the "Unclaimed" lot model and position it at the given CFrame.
-- Uses the same "Base" part offset logic as GameObjectFactory:UpdateLotCFrame.
function LotAreaRegistry:_PlaceUnclaimedModel(cframe: CFrame): Model
	local model = self._lotRegistry:GetLotModel("Unclaimed")
	model.Name = "UnclaimedLot"
	model.Parent = self._lotsFolder

	local base = model:FindFirstChild("Base", true)
	if base then
		local pivotCFrame = model:GetPivot()
		local offset = pivotCFrame:ToObjectSpace((base :: BasePart).CFrame)
		model:PivotTo(cframe * offset:Inverse())
	else
		model:PivotTo(cframe)
	end

	return model
end

--[=[
	Discover all LotArea Parts from workspace.Map.Zones.Lots and initialize them.
	Places unclaimed models and hides the invisible boundary Parts.
	Called once during KnitInit.
	@within LotAreaRegistry
	@return Result.Result<number> -- Ok(count discovered) or Err on discovery failure
	@yields
]=]
function LotAreaRegistry:DiscoverAreas(): Result.Result<number>
	return Result.fromPcall("DiscoveryFailed", function()
		local map = workspace:FindFirstChild("Map")
		if not map then
			return 0
		end

		local zones = map:FindFirstChild("Zones")
		if not zones then
			return 0
		end

		local lotsFolder = zones:FindFirstChild("Lots")
		if not lotsFolder then
			return 0
		end

		local count = 0
		for _, child in lotsFolder:GetChildren() do
			if child:IsA("BasePart") then
				local unclaimedModel = self:_PlaceUnclaimedModel(child.CFrame)
				child.Transparency = 1
				child.CanCollide = false
				self._areas[child.Name] = {
					Part = child,
					ClaimedBy = nil,
					UnclaimedModel = unclaimedModel,
				}
				count += 1
			end
		end
		return count
	end)
end

--[=[
	Check whether a lot area exists in the registry.
	@within LotAreaRegistry
	@param areaName string -- The lot area name to check
	@return boolean -- True if the area exists, false otherwise
]=]
function LotAreaRegistry:AreaExists(areaName: string): boolean
	return self._areas[areaName] ~= nil
end

--[=[
	Get the player who claims a lot area.
	@within LotAreaRegistry
	@param areaName string -- The lot area name
	@return Player? -- The claiming player, or nil if unclaimed
]=]
function LotAreaRegistry:GetClaimant(areaName: string): Player?
	local entry = self._areas[areaName]
	return entry and entry.ClaimedBy or nil
end

--[=[
	Get the lot area currently claimed by a player.
	@within LotAreaRegistry
	@param player Player -- The player to query
	@return string? -- The claimed lot area name, or nil if player has no claim
]=]
function LotAreaRegistry:GetPlayerClaim(player: Player): string?
	return self._playerClaims[player]
end

--[=[
	Mark a lot area as claimed by a player.
	Hides the unclaimed visual model and sets the boundary Part invisible.
	Assumes the area is not already claimed — no validation.
	@within LotAreaRegistry
	@param areaName string -- The lot area name to claim
	@param player Player -- The player claiming the area
]=]
function LotAreaRegistry:SetClaim(areaName: string, player: Player)
	local entry = self._areas[areaName]
	entry.ClaimedBy = player
	self._playerClaims[player] = areaName

	-- Destroy unclaimed model (claimed lot model is placed by LotContext separately)
	if entry.UnclaimedModel then
		entry.UnclaimedModel:Destroy()
		entry.UnclaimedModel = nil
	end

	entry.Part.Transparency = 1
	entry.Part.CanCollide = false
end

--[=[
	Release a player's claim on a lot area.
	Restores the unclaimed visual model and keeps the boundary Part invisible.
	Assumes the player has an active claim — no validation.
	@within LotAreaRegistry
	@param player Player -- The player releasing their claim
	@return string -- The lot area name that was released
]=]
function LotAreaRegistry:ReleaseClaim(player: Player): string
	local areaName = self._playerClaims[player]
	local entry = self._areas[areaName]
	entry.ClaimedBy = nil
	self._playerClaims[player] = nil

	-- Part stays transparent - unclaimed model provides the visual
	entry.Part.Transparency = 1
	entry.Part.CanCollide = false

	-- Place unclaimed model back at this area
	entry.UnclaimedModel = self:_PlaceUnclaimedModel(entry.Part.CFrame)

	return areaName
end

--[=[
	Get the CFrame of a lot area Part.
	@within LotAreaRegistry
	@param areaName string -- The lot area name
	@return CFrame? -- The boundary Part's CFrame, or nil if the area does not exist
]=]
function LotAreaRegistry:GetAreaCFrame(areaName: string): CFrame?
	local entry = self._areas[areaName]
	if not entry then
		return nil
	end
	return entry.Part.CFrame
end

--[=[
	Find the first unclaimed lot area by numerical sort order.
	@within LotAreaRegistry
	@return string? -- The unclaimed area name, or nil if all are claimed
]=]
function LotAreaRegistry:FindFirstAvailable(): string?
	local names = {}
	for areaName in self._areas do
		table.insert(names, areaName)
	end
	table.sort(names, function(a, b)
		local numA = tonumber(a:match("%d+$")) or 0
		local numB = tonumber(b:match("%d+$")) or 0
		return numA < numB
	end)
	for _, areaName in names do
		if not self._areas[areaName].ClaimedBy then
			return areaName
		end
	end
	return nil
end

--[=[
	Get all lot areas with their current claim status.
	Used by client UI to display availability.
	@within LotAreaRegistry
	@return { { Name: string, IsClaimed: boolean } } -- Frozen table of all areas and their claim status
]=]
function LotAreaRegistry:GetAllAreasStatus(): { { Name: string, IsClaimed: boolean } }
	local result = {}
	for areaName, entry in self._areas do
		table.insert(result, {
			Name = areaName,
			IsClaimed = entry.ClaimedBy ~= nil,
		})
	end
	return table.freeze(result)
end

return LotAreaRegistry

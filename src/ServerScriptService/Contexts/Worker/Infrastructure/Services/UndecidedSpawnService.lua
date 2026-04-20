--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local FALLBACK_POSITION = Vector3.new(0, 0, 0)
local SPAWN_HEIGHT_OFFSET = 3

local UndecidedSpawnService = {}
UndecidedSpawnService.__index = UndecidedSpawnService

export type TUndecidedSpawnService = typeof(setmetatable(
	{} :: {
		Registry: any,
		LotContext: any,
	},
	UndecidedSpawnService
))

function UndecidedSpawnService.new(): TUndecidedSpawnService
	local self = setmetatable({}, UndecidedSpawnService)
	self.Registry = nil :: any
	self.LotContext = nil :: any
	return self
end

function UndecidedSpawnService:Init(registry: any, _name: string)
	self.Registry = registry
end

function UndecidedSpawnService:Start()
	self.LotContext = self.Registry:Get("LotContext")
end

function UndecidedSpawnService:GetSpawnPosition(userId: number): Vector3
	local lotModel = self:_ResolvePlayerLotModel(userId)
	if not lotModel then
		warn("[UndecidedSpawnService] Missing player lot model; using origin fallback")
		return FALLBACK_POSITION
	end

	local zones = lotModel:FindFirstChild("Zones")
	if not zones then
		warn("[UndecidedSpawnService] Missing player lot Zones folder; using origin fallback")
		return FALLBACK_POSITION
	end

	local lobby = zones:FindFirstChild("Lobby")
	if not lobby then
		warn("[UndecidedSpawnService] Missing player lot Lobby folder; using origin fallback")
		return FALLBACK_POSITION
	end

	local spawnLocation = lobby:FindFirstChild("SpawnLocation")
	if not spawnLocation or not spawnLocation:IsA("BasePart") then
		warn("[UndecidedSpawnService] Missing BasePart SpawnLocation under Lobby; using origin fallback")
		return FALLBACK_POSITION
	end

	local topY = spawnLocation.Position.Y + (spawnLocation.Size.Y * 0.5)
	return Vector3.new(spawnLocation.Position.X, topY + SPAWN_HEIGHT_OFFSET, spawnLocation.Position.Z)
end

function UndecidedSpawnService:_ResolvePlayerLotModel(userId: number): Model?
	local lotContext = self.LotContext
	if not lotContext then
		return nil
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return nil
	end

	local directModel = lotContext.PlayerToLotModel and lotContext.PlayerToLotModel[player]
	if directModel and directModel:IsA("Model") then
		return directModel
	end

	local lotId = lotContext.PlayersWithLots and lotContext.PlayersWithLots[player]
	if type(lotId) ~= "string" then
		return nil
	end

	local lotsFolder = Workspace:FindFirstChild("Lots")
	if not lotsFolder then
		return nil
	end

	local lotModel = lotsFolder:FindFirstChild("Lot_" .. lotId)
	if lotModel and lotModel:IsA("Model") then
		return lotModel
	end

	return nil
end

return UndecidedSpawnService

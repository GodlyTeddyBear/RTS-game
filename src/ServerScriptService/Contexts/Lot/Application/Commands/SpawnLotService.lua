--!strict

--[[
	Spawn Lot Service - Orchestrate lot spawning workflow

	Responsibility: Coordinate the spawn process:
	1. Policy check — player has no active lot
	2. Create entity at provided CFrame (Infrastructure)
	3. Track player

	Constructor injection for all dependencies.
	Returns Result pattern.
]]

--[=[
	@class SpawnLotService
	Orchestrates the lot spawning workflow with policy checks and entity creation.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try, fromPcall = Result.Ok, Result.Try, Result.fromPcall
local MentionSuccess = Result.MentionSuccess

local LotId = require(script.Parent.Parent.Parent.LotDomain.ValueObjects.LotId)
type LotId = LotId.LotId

local SpawnLotService = {}
SpawnLotService.__index = SpawnLotService

export type SpawnLotService = typeof(setmetatable(
	{} :: {
		_spawnPolicy: any,
		_entityFactory: any,
		_playersWithLots: { [any]: any },
		_lotIdCounter: { Value: number },
	},
	SpawnLotService
))

--[=[
	Create a new SpawnLotService instance.
	@within SpawnLotService
	@return SpawnLotService -- Service instance
]=]
function SpawnLotService.new(): SpawnLotService
	local self = setmetatable({}, SpawnLotService)
	return self
end

--[=[
	Initialize with injected dependencies.
	@within SpawnLotService
	@param registry any -- Registry to resolve dependencies from
]=]
function SpawnLotService:Init(registry: any)
	self._spawnPolicy = registry:Get("SpawnPolicy")
	self._entityFactory = registry:Get("LotEntityFactory")
	self._playersWithLots = registry:Get("PlayersWithLots")
	self._lotIdCounter = registry:Get("LotIdCounter")
end

--[=[
	Execute the lot spawn workflow for a player.
	@within SpawnLotService
	@param player Player -- The player requesting to spawn a lot
	@param cframe CFrame -- The world CFrame from the claimed LotArea Part
	@return Result<string> -- Ok(lotId) on success, Err on policy failure or entity creation error
]=]
function SpawnLotService:Execute(player: Player, cframe: CFrame): Result.Result<string>
	local userId = player.UserId

	-- Policy: check player has no active lot
	Try(self._spawnPolicy:Check(player))

	-- Generate lot ID
	self._lotIdCounter.Value += 1
	local lotId = LotId.new(userId, self._lotIdCounter.Value)

	-- Create entity with CFrame from WorldContext
	Try(fromPcall("SpawnFailed", function()
		self._entityFactory:CreateLot(lotId, userId, cframe)
	end))

	-- Track player
	self._playersWithLots[player] = lotId:GetId()
	MentionSuccess("Lot:SpawnLotService:Execute", "Spawned lot entity and tracked active lot", {
		userId = userId,
		lotId = lotId:GetId(),
	})

	return Ok(lotId:GetId())
end

return SpawnLotService

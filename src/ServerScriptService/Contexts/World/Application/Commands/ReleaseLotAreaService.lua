--!strict

--[[
	Release Lot Area Service - Orchestrate lot area release workflow

	Responsibility: Validate and release a player's lot area claim.
	Called when player disconnects or explicitly releases their lot.

	Constructor injection for all dependencies.
]]

--[=[
	@class ReleaseLotAreaService
	Application layer service that orchestrates the lot area release workflow.
	Validates the player has a claim via policy, persists the release, and restores visibility.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try
local MentionSuccess = Result.MentionSuccess

local ReleaseLotAreaService = {}
ReleaseLotAreaService.__index = ReleaseLotAreaService

export type ReleaseLotAreaService = typeof(setmetatable(
	{} :: {
		_releasePolicy: any,
		_registry: any,
	},
	ReleaseLotAreaService
))

--[=[
	Create a new ReleaseLotAreaService.
	@within ReleaseLotAreaService
	@return ReleaseLotAreaService
]=]
function ReleaseLotAreaService.new(): ReleaseLotAreaService
	local self = setmetatable({}, ReleaseLotAreaService)
	self._releasePolicy = nil :: any
	self._registry = nil :: any
	return self
end

--[=[
	Initialize the service with policy and registry references.
	Called by the DDD Registry pattern during KnitInit.
	@within ReleaseLotAreaService
	@param registry any -- The DDD Registry instance
	@param _name string -- The service name (unused)
]=]
function ReleaseLotAreaService:Init(registry: any, _name: string)
	self._releasePolicy = registry:Get("ReleasePolicy")
	self._registry = registry:Get("LotAreaRegistry")
end

--[=[
	Release a player's lot area claim.
	Validates the player has an active claim via ReleasePolicy and persists the release.
	Restores the unclaimed visual model for the area.
	@within ReleaseLotAreaService
	@param player Player -- The player releasing their claim
	@return Result.Result<string> -- The released area name, or error if player has no claim
]=]
function ReleaseLotAreaService:Execute(player: Player): Result.Result<string>
	-- Policy: fetch state + evaluate eligibility
	Try(self._releasePolicy:Check(player))

	-- Release (also restores Part visibility)
	local releasedArea = self._registry:ReleaseClaim(player)
	MentionSuccess("World:ReleaseLotAreaService:Execute", "Released lot area claim and restored area visibility", {
		userId = player.UserId,
		areaName = releasedArea,
	})
	return Ok(releasedArea)
end

return ReleaseLotAreaService

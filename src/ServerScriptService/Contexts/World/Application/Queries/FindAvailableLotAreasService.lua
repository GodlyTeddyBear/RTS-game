--!strict

--[[
	Find Available Lot Areas Service - Query lot area availability

	Responsibility: Return all lot areas with their claimed/free status.
	Used by client API for UI display.

	Constructor injection for all dependencies.
]]

--[=[
	@class FindAvailableLotAreasService
	Application layer query service that returns all lot areas with their availability status.
	Used by client UI to display which areas are claimed and which are free.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok
local MentionSuccess = Result.MentionSuccess

local FindAvailableLotAreasService = {}
FindAvailableLotAreasService.__index = FindAvailableLotAreasService

export type FindAvailableLotAreasService = typeof(setmetatable(
	{} :: {
		_registry: any,
	},
	FindAvailableLotAreasService
))

--[=[
	Create a new FindAvailableLotAreasService.
	@within FindAvailableLotAreasService
	@return FindAvailableLotAreasService
]=]
function FindAvailableLotAreasService.new(): FindAvailableLotAreasService
	local self = setmetatable({}, FindAvailableLotAreasService)
	self._registry = nil :: any
	return self
end

--[=[
	Initialize the service with a registry reference.
	Called by the DDD Registry pattern during KnitInit.
	@within FindAvailableLotAreasService
	@param registry any -- The DDD Registry instance
	@param _name string -- The service name (unused)
]=]
function FindAvailableLotAreasService:Init(registry: any, _name: string)
	self._registry = registry:Get("LotAreaRegistry")
end

--[=[
	Get all lot areas with their current availability status.
	Returns a frozen table suitable for client UI display.
	@within FindAvailableLotAreasService
	@return Result.Result<{ { Name: string, IsClaimed: boolean } }> -- All areas with claim status
]=]
function FindAvailableLotAreasService:Execute(): Result.Result<{ { Name: string, IsClaimed: boolean } }>
	local areas = self._registry:GetAllAreasStatus()
	MentionSuccess("World:FindAvailableLotAreasService:Execute", "Retrieved current lot area availability status", {
		areaCount = #areas,
	})
	return Ok(areas)
end

return FindAvailableLotAreasService

--!strict

--[[
	Claim Lot Area Service - Orchestrate lot area claim workflow

	Responsibility: Coordinate the claim process:
	1. Policy check (fetch state + evaluate eligibility)
	2. Set claim in registry (Infrastructure)
	3. Return area name and CFrame

	Constructor injection for all dependencies.
]]

--[=[
	@class ClaimLotAreaService
	Application layer service that orchestrates the lot area claim workflow.
	Validates eligibility via policy, persists the claim, and returns the area spawn point.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

local Errors = require(script.Parent.Parent.Parent.Errors)

local ClaimLotAreaService = {}
ClaimLotAreaService.__index = ClaimLotAreaService

export type ClaimLotAreaService = typeof(setmetatable(
	{} :: {
		_claimPolicy: any,
		_registry: any,
	},
	ClaimLotAreaService
))

--[=[
	Create a new ClaimLotAreaService.
	@within ClaimLotAreaService
	@return ClaimLotAreaService
]=]
function ClaimLotAreaService.new(): ClaimLotAreaService
	local self = setmetatable({}, ClaimLotAreaService)
	self._claimPolicy = nil :: any
	self._registry = nil :: any
	return self
end

--[=[
	Initialize the service with policy and registry references.
	Called by the DDD Registry pattern during KnitInit.
	@within ClaimLotAreaService
	@param registry any -- The DDD Registry instance
	@param _name string -- The service name (unused)
]=]
function ClaimLotAreaService:Init(registry: any, _name: string)
	self._claimPolicy = registry:Get("ClaimPolicy")
	self._registry = registry:Get("LotAreaRegistry")
end

--[=[
	Claim the first available lot area for a player.
	Validates eligibility via ClaimPolicy, persists the claim, and returns the area CFrame.
	@within ClaimLotAreaService
	@param player Player -- The player claiming an area
	@return Result.Result<{ AreaName: string, CFrame: CFrame }> -- Claimed area name and spawn CFrame, or error
	@error string -- Thrown if no areas available or player already has a claim
]=]
function ClaimLotAreaService:Execute(player: Player): Result.Result<{ AreaName: string, CFrame: CFrame }>
	-- Policy: fetch state + evaluate eligibility
	local ctx = Try(self._claimPolicy:Check(player))

	-- Claim (also sets Part transparent)
	self._registry:SetClaim(ctx.AreaName, player)

	-- Get CFrame
	local cframe = self._registry:GetAreaCFrame(ctx.AreaName)
	Ensure(cframe, "AreaNotFound", Errors.AREA_NOT_FOUND, { areaName = ctx.AreaName })
	MentionSuccess("World:ClaimLotAreaService:Execute", "Claimed lot area and resolved area spawn cframe", {
		userId = player.UserId,
		areaName = ctx.AreaName,
	})

	return Ok(table.freeze({
		AreaName = ctx.AreaName,
		CFrame = cframe,
	}))
end

return ClaimLotAreaService

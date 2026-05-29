--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

--[=[
	@class StatusService
	Owns combat-scoped temporary aura sources and derives live enemy move speed state.
	@server
]=]
local StatusService = {}
StatusService.__index = StatusService

local function _ResolvePosition(input: any): Vector3?
	if typeof(input) == "Vector3" then
		return input
	end

	if type(input) == "table" and typeof(input.CFrame) == "CFrame" then
		return input.CFrame.Position
	end

	return nil
end

--[=[
	@interface AuraSourceData
	@within StatusService
	.SourceType string -- Logical source type used to decide which effects the aura applies.
	.Position Vector3 -- World position of the aura source.
	.Radius number -- Aura radius in studs.
	.MoveSpeedMultiplier number -- Multiplicative modifier applied to enemy base speed while in range.
	.IsActive boolean -- Whether the source should be considered during effect evaluation.
]=]
type AuraSourceData = {
	SourceType: string,
	Position: Vector3,
	Radius: number,
	MoveSpeedMultiplier: number,
	IsActive: boolean,
}

--[=[
	Creates a fresh status service with no tracked aura sources.
	@within StatusService
	@return StatusService -- New service instance.
]=]
function StatusService.new()
	local self = setmetatable({}, StatusService)
	self._enemyEntityFactory = nil
	self._auraSourcesByHandle = {} :: { [string]: AuraSourceData }
	return self
end

--[=[
	Initializes the service after registry construction.
	@within StatusService
	@param _registry any -- Registry supplied by the context bootstrap.
	@param _name string -- Registry key for this service.
]=]
function StatusService:Init(_registry: any, _name: string)
end

--[=[
	Wires the enemy entity factory used to query and update live enemy state.
	@within StatusService
	@param enemyEntityFactory any -- Enemy entity factory used during status evaluation.
]=]
function StatusService:ConfigureEnemyEntityFactory(enemyEntityFactory: any)
	self._enemyEntityFactory = enemyEntityFactory
end

--[=[
	Adds or replaces an aura source tracked by `sourceHandle`.
	@within StatusService
	@param sourceHandle string -- Stable handle used to identify the aura source.
	@param sourceData AuraSourceData -- Aura data captured from the structure runtime.
]=]
function StatusService:UpsertAuraSource(sourceHandle: string, sourceData: AuraSourceData)
	if type(sourceHandle) ~= "string" or sourceHandle == "" then
		return
	end

	if type(sourceData) ~= "table" or typeof(sourceData.Position) ~= "Vector3" then
		return
	end

	if type(sourceData.Radius) ~= "number" or sourceData.Radius <= 0 then
		return
	end

	local moveSpeedMultiplier = sourceData.MoveSpeedMultiplier
	if type(moveSpeedMultiplier) ~= "number" then
		return
	end

	self._auraSourcesByHandle[sourceHandle] = {
		SourceType = sourceData.SourceType,
		Position = sourceData.Position,
		Radius = sourceData.Radius,
		MoveSpeedMultiplier = math.clamp(moveSpeedMultiplier, 0.01, 1),
		IsActive = sourceData.IsActive == true,
	}
end

--[=[
	Removes a tracked aura source by handle.
	@within StatusService
	@param sourceHandle string -- Stable handle previously used with `UpsertAuraSource`.
]=]
function StatusService:RemoveAuraSource(sourceHandle: string)
	if type(sourceHandle) ~= "string" or sourceHandle == "" then
		return
	end

	self._auraSourcesByHandle[sourceHandle] = nil
end

--[=[
	Recomputes enemy move speed from all active aura sources.
	@within StatusService
]=]
function StatusService:EvaluateEnemyMoveSpeedEffects()
	local enemyEntityFactory = self._enemyEntityFactory
	if enemyEntityFactory == nil then
		return
	end

	-- Scan alive enemies first so the service only touches entities that still exist.
	for _, entity in ipairs(enemyEntityFactory:QueryAliveEntities()) do
		local baseMoveSpeed = enemyEntityFactory:GetBaseMoveSpeed(entity)
		if type(baseMoveSpeed) ~= "number" then
			continue
		end

		local currentPosition = _ResolvePosition(enemyEntityFactory:GetPosition(entity))
		local strongestMultiplier = 1
		if currentPosition ~= nil then
			-- Apply the strongest active stasis slow that currently overlaps the enemy.
			for _, sourceData in pairs(self._auraSourcesByHandle) do
				if sourceData.IsActive and sourceData.SourceType == "StasisField" then
					if SpatialQuery.IsWithinRange(currentPosition, sourceData.Position, sourceData.Radius) then
						strongestMultiplier = math.min(strongestMultiplier, sourceData.MoveSpeedMultiplier)
					end
				end
			end
		end

		-- Restore or reduce the live speed from the enemy's immutable base speed.
		enemyEntityFactory:SetCurrentMoveSpeed(entity, baseMoveSpeed * strongestMultiplier)
	end
end

--[=[
	Clears all aura sources and restores each enemy to base move speed.
	@within StatusService
]=]
function StatusService:ClearAll()
	table.clear(self._auraSourcesByHandle)

	local enemyEntityFactory = self._enemyEntityFactory
	if enemyEntityFactory == nil then
		return
	end

	-- Reset all live enemies back to their base movement speed at combat teardown.
	for _, entity in ipairs(enemyEntityFactory:QueryAliveEntities()) do
		local baseMoveSpeed = enemyEntityFactory:GetBaseMoveSpeed(entity)
		if type(baseMoveSpeed) == "number" then
			enemyEntityFactory:SetCurrentMoveSpeed(entity, baseMoveSpeed)
		end
	end
end

return StatusService

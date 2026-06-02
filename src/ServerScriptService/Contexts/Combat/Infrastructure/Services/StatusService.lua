--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local StatusService = {}
StatusService.__index = StatusService

function StatusService.new()
	return setmetatable({ _entityContext = nil, _auraSourcesByHandle = {} }, StatusService)
end

function StatusService:Init(_registry: any, _name: string) end

function StatusService:ConfigureEntityContext(entityContext: any)
	self._entityContext = entityContext
end

function StatusService:UpsertAuraSource(sourceHandle: string, sourceData: any)
	if type(sourceHandle) ~= "string" or sourceHandle == "" or type(sourceData) ~= "table" or typeof(sourceData.Position) ~= "Vector3" then return end
	if type(sourceData.Radius) ~= "number" or sourceData.Radius <= 0 or type(sourceData.MoveSpeedMultiplier) ~= "number" then return end
	self._auraSourcesByHandle[sourceHandle] = {
		SourceType = sourceData.SourceType,
		Position = sourceData.Position,
		Radius = sourceData.Radius,
		MoveSpeedMultiplier = math.clamp(sourceData.MoveSpeedMultiplier, 0.01, 1),
		IsActive = sourceData.IsActive == true,
	}
end

function StatusService:RemoveAuraSource(sourceHandle: string)
	self._auraSourcesByHandle[sourceHandle] = nil
end

function StatusService:EvaluateEnemyMoveSpeedEffects()
	local entityContext = self._entityContext
	if entityContext == nil then return end
	local queryResult = entityContext:Query({ FeatureName = "Enemy", Keys = { "AliveTag" } })
	if not queryResult.success then return end
	for _, entity in ipairs(queryResult.value) do
		local speedResult = entityContext:Get(entity, "SpeedState", "Movement")
		local transformResult = entityContext:Get(entity, "Transform", "Entity")
		local speedState = if speedResult.success then speedResult.value else nil
		local transform = if transformResult.success then transformResult.value else nil
		if type(speedState) ~= "table" or type(speedState.BaseSpeed) ~= "number" or type(transform) ~= "table" or typeof(transform.CFrame) ~= "CFrame" then continue end
		local multiplier = 1
		for _, source in pairs(self._auraSourcesByHandle) do
			if source.IsActive and source.SourceType == "StasisField" and SpatialQuery.IsWithinRange(transform.CFrame.Position, source.Position, source.Radius) then
				multiplier = math.min(multiplier, source.MoveSpeedMultiplier)
			end
		end
		entityContext:Set(entity, "SpeedState", { BaseSpeed = speedState.BaseSpeed, CurrentSpeed = speedState.BaseSpeed * multiplier }, "Movement")
	end
end

function StatusService:ClearAll()
	table.clear(self._auraSourcesByHandle)
	local entityContext = self._entityContext
	if entityContext == nil then return end
	local queryResult = entityContext:Query({ FeatureName = "Movement", Keys = { "SpeedState" } })
	if not queryResult.success then return end
	for _, entity in ipairs(queryResult.value) do
		local result = entityContext:Get(entity, "SpeedState", "Movement")
		local speedState = if result.success then result.value else nil
		if type(speedState) == "table" and type(speedState.BaseSpeed) == "number" then
			entityContext:Set(entity, "SpeedState", {
				BaseSpeed = speedState.BaseSpeed,
				CurrentSpeed = speedState.BaseSpeed,
			}, "Movement")
		end
	end
end

return StatusService

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Orient = require(ReplicatedStorage.Utilities.Orient)
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local ProduceUnitCommand = {}
ProduceUnitCommand.__index = ProduceUnitCommand
setmetatable(ProduceUnitCommand, BaseCommand)

local function _ResolveFacingDirection(baseCFrame: CFrame): Vector3
	local lookVector = Vector3.new(baseCFrame.LookVector.X, 0, baseCFrame.LookVector.Z)
	if lookVector.Magnitude > 0 then
		return lookVector.Unit
	end

	return Vector3.zAxis
end

local function _BuildSpawnCFrame(baseCFrame: CFrame, slotIndex: number): CFrame
	local layout = BaseConfig.ProductionLayout
	local column = slotIndex % layout.SlotsPerRow
	local row = math.floor(slotIndex / layout.SlotsPerRow)
	local localOffset = Vector3.new(
		layout.SideOffset + (row * layout.RowStep),
		0,
		layout.ForwardStart + (column * layout.ForwardSpacing)
	)
	local spawnPosition = baseCFrame:PointToWorldSpace(localOffset)
	local facingDirection = _ResolveFacingDirection(baseCFrame)

	return Orient.BuildLookAt(spawnPosition, spawnPosition + facingDirection) or CFrame.new(spawnPosition)
end

function ProduceUnitCommand.new()
	local self = BaseCommand.new("Base", "ProduceUnitCommand")
	return setmetatable(self, ProduceUnitCommand)
end

function ProduceUnitCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_baseEntityReadService", "BaseEntityReadService")
end

function ProduceUnitCommand:Start(registry: any, _name: string)
	self:_RequireDependency(registry, "_unitContext", "UnitContext")
end

function ProduceUnitCommand:Execute(player: Player, unitId: string): Result.Result<SpawnUnitResult>
	return Result.Catch(function()
		Ensure(player ~= nil, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(type(unitId) == "string" and unitId ~= "", "InvalidUnitId", Errors.INVALID_UNIT_ID)

		local definition = UnitConfig.Definitions[unitId]
		Ensure(definition ~= nil, "InvalidUnitId", Errors.INVALID_UNIT_ID, {
			UnitId = unitId,
		})

		local baseCFrame = self._baseEntityReadService:GetTargetCFrame()
		Ensure(baseCFrame ~= nil, "BaseNotFound", Errors.BASE_NOT_FOUND)

		local ownerId = tostring(player.UserId)
		local ownerKind = "Player"
		local currentCount = Try(self._unitContext:GetOwnerUnitCount(ownerKind, ownerId))
		local spawnCFrame = _BuildSpawnCFrame(baseCFrame, currentCount)

		return self._unitContext:SpawnUnit({
			UnitId = definition.DefinitionId,
			Faction = "Player",
			OwnerKind = ownerKind,
			OwnerId = ownerId,
			SpawnCFrame = spawnCFrame,
		})
	end, self:_Label())
end

return ProduceUnitCommand

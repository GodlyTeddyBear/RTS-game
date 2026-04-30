--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local SpawnAllyCommand = {}
SpawnAllyCommand.__index = SpawnAllyCommand
setmetatable(SpawnAllyCommand, BaseCommand)

function SpawnAllyCommand.new()
	local self = BaseCommand.new("Summon", "SpawnAlly")
	return setmetatable(self, SpawnAllyCommand)
end

function SpawnAllyCommand:Start(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_unitContext = "UnitContext",
	})
end

local function _getPositiveLifetime(slotMetadata: { [string]: any }?): number?
	if slotMetadata == nil then
		return nil
	end

	local lifetime = slotMetadata.Lifetime
	if type(lifetime) == "number" and lifetime > 0 then
		return lifetime
	end

	return nil
end

function SpawnAllyCommand:Execute(
	player: Player,
	slotMetadata: { [string]: any }?,
	castOriginCFrame: CFrame
): Result.Result<SpawnUnitResult>
	return Result.Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(castOriginCFrame, "InvalidCastOrigin", Errors.INVALID_CAST_ORIGIN)
		Ensure(slotMetadata == nil or type(slotMetadata) == "table", "InvalidMetadata", Errors.INVALID_METADATA)

		local result = Try(self._unitContext:SpawnUnit({
			UnitId = UnitConfig.DEFAULT_UNIT_ID,
			Faction = "Player",
			OwnerKind = "Player",
			OwnerId = tostring(player.UserId),
			SpawnCFrame = castOriginCFrame,
			Lifetime = _getPositiveLifetime(slotMetadata),
		}))

		return Ok(result)
	end, self:_Label())
end

return SpawnAllyCommand

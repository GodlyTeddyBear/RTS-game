--!strict

local BaseSlotService = require(script.Parent.BaseSlotService)

local BreweryStationSlotService = setmetatable({}, { __index = BaseSlotService })
BreweryStationSlotService.__index = BreweryStationSlotService

export type TBreweryStationSlotService = BaseSlotService.TBaseSlotService

function BreweryStationSlotService.new(): TBreweryStationSlotService
	local self = BaseSlotService.new()
	return setmetatable(self, BreweryStationSlotService)
end

function BreweryStationSlotService:Init(registry: any, _name: string)
	self.SlotCalculator = registry:Get("BreweryStationSlotCalculator")
end

return BreweryStationSlotService

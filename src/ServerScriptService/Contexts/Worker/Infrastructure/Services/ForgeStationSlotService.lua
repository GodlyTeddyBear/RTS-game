--!strict

local BaseSlotService = require(script.Parent.BaseSlotService)

local ForgeStationSlotService = setmetatable({}, { __index = BaseSlotService })
ForgeStationSlotService.__index = ForgeStationSlotService

export type TForgeStationSlotService = BaseSlotService.TBaseSlotService

function ForgeStationSlotService.new(): TForgeStationSlotService
	local self = BaseSlotService.new()
	return setmetatable(self, ForgeStationSlotService)
end

function ForgeStationSlotService:Init(registry: any, _name: string)
	self.SlotCalculator = registry:Get("ForgeStationSlotCalculator")
end

return ForgeStationSlotService

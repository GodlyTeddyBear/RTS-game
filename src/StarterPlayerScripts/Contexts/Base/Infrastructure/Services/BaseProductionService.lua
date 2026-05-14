--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BaseProductionService = {}
BaseProductionService.__index = BaseProductionService

function BaseProductionService.new()
	local self = setmetatable({}, BaseProductionService)
	self._baseContext = Knit.GetService("BaseContext")
	return self
end

function BaseProductionService:ProduceUnit(unitId: string)
	return self._baseContext:ProduceUnit(unitId)
end

return BaseProductionService

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local EquipmentSyncClient = require(script.Parent.Infrastructure.Persistence.EquipmentSyncClient)

local EquipmentController = Knit.CreateController({
	Name = "EquipmentController",
})

function EquipmentController:KnitInit()
	self._syncClient = EquipmentSyncClient.new()
end

function EquipmentController:KnitStart()
	self._syncClient:Start()
end

function EquipmentController:GetAtom()
	return self._syncClient:GetAtom()
end

return EquipmentController


--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventorySyncClient = require(script.Parent.Infrastructure.InventorySyncClient)

local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

function InventoryController:KnitInit()
	self._syncClient = InventorySyncClient.new()
end

function InventoryController:KnitStart()
	self._syncClient:Start()
end

function InventoryController:GetAtom()
	return self._syncClient:GetAtom()
end

return InventoryController

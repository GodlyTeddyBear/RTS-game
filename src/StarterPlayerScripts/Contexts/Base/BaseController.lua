--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseSyncClient = require(script.Parent.Infrastructure.BaseSyncClient)

local BaseController = Knit.CreateController({
	Name = "BaseController",
})

function BaseController:KnitInit()
	self._syncClient = BaseSyncClient.new()
end

function BaseController:KnitStart()
	self._syncClient:Start()
end

function BaseController:GetAtom()
	return self._syncClient:GetAtom()
end

return BaseController

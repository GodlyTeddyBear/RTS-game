--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseSyncClient = require(script.Parent.Infrastructure.BaseSyncClient)
local BaseDiscoveryService = require(script.Parent.Infrastructure.Services.BaseDiscoveryService)
local BaseClickService = require(script.Parent.Infrastructure.Services.BaseClickService)

local BaseController = Knit.CreateController({
	Name = "BaseController",
})

function BaseController:KnitInit()
	self._syncClient = BaseSyncClient.new()
	self._discoveryService = BaseDiscoveryService.new()
	self._clickService = nil
	self.BaseClicked = GoodSignal.new()
end

function BaseController:KnitStart()
	self._syncClient:Start()
	self._discoveryService:Start()
	self._clickService = BaseClickService.new(self:GetAtom(), self._discoveryService, function(baseInstance: Instance)
		self.BaseClicked:Fire(baseInstance)
	end)
	self._clickService:Start()
end

function BaseController:GetAtom()
	return self._syncClient:GetAtom()
end

function BaseController:Destroy()
	if self._clickService ~= nil then
		self._clickService:Destroy()
		self._clickService = nil
	end

	if self._discoveryService ~= nil then
		self._discoveryService:Destroy()
	end

	if self.BaseClicked ~= nil then
		self.BaseClicked:DisconnectAll()
	end
end

return BaseController

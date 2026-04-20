--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local UnlockSyncClient = require(script.Parent.Infrastructure.UnlockSyncClient)

local UnlockController = Knit.CreateController({
	Name = "UnlockController",
})

function UnlockController:KnitInit()
	self._Registry = Registry.new("Client")
	self._Registry:Register("UnlockSyncClient", UnlockSyncClient.new(), "Infrastructure")
	self._Registry:InitAll()

	self.SyncClient = self._Registry:Get("UnlockSyncClient")
end

function UnlockController:KnitStart()
	local unlockContext = Knit.GetService("UnlockContext")
	self._Registry:Register("UnlockContext", unlockContext)
	self.UnlockContext = unlockContext

	self._Registry:StartOrdered({ "Infrastructure" })

	task.delay(0.3, function()
		self:RequestUnlockState()
	end)
end

function UnlockController:GetUnlocksAtom()
	return self.SyncClient:GetUnlocksAtom()
end

function UnlockController:RequestUnlockState()
	return self.UnlockContext:RequestUnlockState()
		:catch(function(err)
			warn("[UnlockController:RequestUnlockState]", err.type, err.message)
		end)
end

return UnlockController

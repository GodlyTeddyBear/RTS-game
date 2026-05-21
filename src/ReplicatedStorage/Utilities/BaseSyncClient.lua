--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])

--[[
	Base Sync Client

	Eliminates boilerplate across client-side sync services. Provides:
	- CharmSync.client setup
	- Blink listener wiring
	- Atom getter

	Most contexts need no subclass — call BaseSyncClient.new() directly.

	To subclass (for domain-specific getters):

		local MySyncClient = setmetatable({}, { __index = BaseSyncClient })
		MySyncClient.__index = MySyncClient

		function MySyncClient.new()
			local self = BaseSyncClient.new(blinkClient, "SyncMyKey", "myKey", createAtom)
			return setmetatable(self, MySyncClient)
		end
]]

local BaseSyncClient = {}
BaseSyncClient.__index = BaseSyncClient

function BaseSyncClient.new(blinkClient: any, blinkEventName: string, atomKey: string, createAtom: () -> any)
	local self = setmetatable({}, BaseSyncClient)

	self.BlinkClient = blinkClient
	self.BlinkEventName = blinkEventName
	self.Atom = createAtom()

	self.Syncer = CharmSync.client({
		atoms = { [atomKey] = self.Atom },
		ignoreUnhydrated = true,
	})

	return self
end

function BaseSyncClient:Start()
	self.BlinkClient[self.BlinkEventName].On(function(payload)
		self.Syncer:sync(payload)
	end)
end

function BaseSyncClient:GetAtom()
	return self.Atom
end

return BaseSyncClient

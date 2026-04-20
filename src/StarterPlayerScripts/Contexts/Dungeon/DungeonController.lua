--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local BlinkClient = require(ReplicatedStorage.Network.Generated.DungeonSyncClient)

-- Infrastructure
local DungeonSyncClient = require(script.Parent.Infrastructure.DungeonSyncClient)

local DungeonController = Knit.CreateController({
	Name = "DungeonController",
})

---
-- Knit Lifecycle
---

function DungeonController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self.SyncService = DungeonSyncClient.new(BlinkClient)
	registry:Register("DungeonSyncClient", self.SyncService, "Infrastructure")

	registry:InitAll()
end

function DungeonController:KnitStart()
	local registry = self.Registry

	registry:StartOrdered({ "Infrastructure" })
end

---
-- Public API Methods
---

--- Get the dungeon state atom for UI components
function DungeonController:GetDungeonStateAtom()
	return self.SyncService:GetDungeonStateAtom()
end

return DungeonController

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local BlinkClient = require(ReplicatedStorage.Network.Generated.GuildSyncClient)

-- Infrastructure
local GuildSyncClient = require(script.Parent.Infrastructure.GuildSyncClient)

local GuildController = Knit.CreateController({
	Name = "GuildController",
})

---
-- Knit Lifecycle
---

function GuildController:KnitInit()
	-- Create registry and initialize sync infrastructure
	local registry = Registry.new("Client")
	self.Registry = registry

	self.SyncService = GuildSyncClient.new(BlinkClient)
	registry:Register("GuildSyncClient", self.SyncService, "Infrastructure")

	-- Start lifecycle for all registered services
	registry:InitAll()
end

function GuildController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local GuildContext = Knit.GetService("GuildContext")
	registry:Register("GuildContext", GuildContext)

	self.GuildContext = GuildContext

	-- Start infrastructure (sync client) before hydrating data
	registry:StartOrdered({ "Infrastructure" })

	-- Delay hydration to let UI components mount and subscribe to atoms
	task.delay(0.3, function()
		self:RequestGuildState()
	end)
end

---
-- Public API Methods
---

--- Get the adventurers atom for UI components
function GuildController:GetAdventurersAtom()
	return self.SyncService:GetAdventurersAtom()
end

--- Request initial guild state (hydration)
function GuildController:RequestGuildState()
	return self.GuildContext:RequestGuildState()
		:catch(function(err)
			warn("[GuildController:RequestGuildState]", err.type, err.message)
		end)
end

--- Hire an adventurer of the given type
function GuildController:HireAdventurer(adventurerType: string)
	return self.GuildContext:HireAdventurer(adventurerType)
		:catch(function(err)
			warn("[GuildController:HireAdventurer]", err.type, err.message)
		end)
end

--- Equip an item from inventory to an adventurer
function GuildController:EquipItem(adventurerId: string, slotType: string, inventorySlotIndex: number)
	return self.GuildContext:EquipItem(adventurerId, slotType, inventorySlotIndex)
		:catch(function(err)
			warn("[GuildController:EquipItem]", err.type, err.message)
		end)
end

--- Unequip an item from an adventurer
function GuildController:UnequipItem(adventurerId: string, slotType: string)
	return self.GuildContext:UnequipItem(adventurerId, slotType)
		:catch(function(err)
			warn("[GuildController:UnequipItem]", err.type, err.message)
		end)
end

return GuildController

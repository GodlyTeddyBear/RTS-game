--!strict

--[[
	Lot Controller - Client-side controller for lot management

	Responsibilities:
	- Connect to server LotContext service
	- Provide public API for lot operations
	- Handle server communication via Knit

	Pattern: Knit controller mirroring WorkerController
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local LotController = Knit.CreateController({
	Name = "LotController",
})

--[[
	KnitInit - Initialize controller
]]
function LotController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	registry:InitAll()

	print("LotController initialized")
end

--[[
	KnitStart - Set up server service reference
]]
function LotController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local LotContext = Knit.GetService("LotContext")
	registry:Register("LotContext", LotContext)

	self.LotContext = LotContext
	print("LotController started")
end

--[[
	SpawnLot - Request server to spawn a lot for player.
	Player relocation is handled server-side via team-based SpawnLocations.

	@param player Player - The player requesting lot spawn
	@return Promise
]]
function LotController:SpawnLot(player: Player)
	return self.LotContext:SpawnLot(player)
		:catch(function(err)
			warn("[LotController:SpawnLot]", err.type, err.message)
		end)
end

return LotController

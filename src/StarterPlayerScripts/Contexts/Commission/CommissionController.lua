--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local BlinkClient = require(ReplicatedStorage.Network.Generated.CommissionSyncClient)

-- Infrastructure
local CommissionSyncClient = require(script.Parent.Infrastructure.CommissionSyncClient)

--[=[
	@class CommissionController
	Client-side controller for commission board management. Initializes sync service and provides API for accepting, delivering, and abandoning commissions.
	@client
]=]
local CommissionController = Knit.CreateController({
	Name = "CommissionController",
})

--[=[
	Initialize the controller registry and sync infrastructure.
	@within CommissionController
	@yields
]=]
function CommissionController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	-- Initialize sync client to hydrate commission state from server
	self.SyncService = CommissionSyncClient.new(BlinkClient)
	registry:Register("CommissionSyncClient", self.SyncService, "Infrastructure")

	registry:InitAll()
end

--[=[
	Start the controller. Resolves cross-context dependencies and requests initial state.
	@within CommissionController
	@yields
]=]
function CommissionController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local CommissionContext = Knit.GetService("CommissionContext")
	registry:Register("CommissionContext", CommissionContext)

	self.CommissionContext = CommissionContext

	registry:StartOrdered({ "Infrastructure" })

	-- Request initial state (hydration) with delay to allow other systems to initialize
	task.delay(0.3, function()
		self:RequestCommissionState()
	end)
end

--[=[
	Get the commissions atom for UI subscription.
	@within CommissionController
	@return any -- React-Charm atom containing commission state
]=]
function CommissionController:GetCommissionsAtom()
	return self.SyncService:GetCommissionsAtom()
end

--[=[
	Request initial commission state (hydration) from the server.
	@within CommissionController
	@return Result<void> -- Result object indicating success or failure
	@yields
]=]
function CommissionController:RequestCommissionState()
	return self.CommissionContext:RequestCommissionState()
		:catch(function(err)
			warn("[CommissionController:RequestCommissionState]", err.type, err.message)
		end)
end

--[=[
	Accept a commission from the board.
	@within CommissionController
	@param commissionId string -- ID of the commission to accept
	@return Result<void> -- Result object indicating success or failure
	@yields
]=]
function CommissionController:AcceptCommission(commissionId: string)
	return self.CommissionContext:AcceptCommission(commissionId)
		:catch(function(err)
			warn("[CommissionController:AcceptCommission]", err.type, err.message)
		end)
end

--[=[
	Deliver items for an active commission.
	@within CommissionController
	@param commissionId string -- ID of the commission to deliver
	@return Result<void> -- Result object indicating success or failure
	@yields
]=]
function CommissionController:DeliverCommission(commissionId: string)
	return self.CommissionContext:DeliverCommission(commissionId)
		:catch(function(err)
			warn("[CommissionController:DeliverCommission]", err.type, err.message)
		end)
end

--[=[
	Abandon an active commission.
	@within CommissionController
	@param commissionId string -- ID of the commission to abandon
	@return Result<void> -- Result object indicating success or failure
	@yields
]=]
function CommissionController:AbandonCommission(commissionId: string)
	return self.CommissionContext:AbandonCommission(commissionId)
		:catch(function(err)
			warn("[CommissionController:AbandonCommission]", err.type, err.message)
		end)
end

--[=[
	Unlock the next commission tier.
	@within CommissionController
	@return Result<void> -- Result object indicating success or failure
	@yields
]=]
function CommissionController:UnlockTier()
	return self.CommissionContext:UnlockTier()
		:catch(function(err)
			warn("[CommissionController:UnlockTier]", err.type, err.message)
		end)
end

--[=[
	Manually refresh the commission board with fresh data.
	@within CommissionController
	@return Result<void> -- Result object indicating success or failure
	@yields
]=]
function CommissionController:RefreshBoard()
	return self.CommissionContext:RefreshBoard()
		:catch(function(err)
			warn("[CommissionController:RefreshBoard]", err.type, err.message)
		end)
end

return CommissionController

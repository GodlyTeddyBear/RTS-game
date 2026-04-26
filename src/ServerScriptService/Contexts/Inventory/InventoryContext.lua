--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local BlinkServer = require(ReplicatedStorage.Network.Generated.InventorySyncServer)

local InventorySyncService = require(script.Parent.Infrastructure.Persistence.InventorySyncService)
local SlotManagementService = require(script.Parent.InventoryDomain.Services.SlotManagementService)
local AddItemPolicy = require(script.Parent.InventoryDomain.Policies.AddItemPolicy)
local RemoveItemPolicy = require(script.Parent.InventoryDomain.Policies.RemoveItemPolicy)
local AddItem = require(script.Parent.Application.Commands.AddItem)
local RemoveItem = require(script.Parent.Application.Commands.RemoveItem)
local ClearInventory = require(script.Parent.Application.Commands.ClearInventory)
local GetInventory = require(script.Parent.Application.Queries.GetInventory)

local Catch = Result.Catch

local ACTIVE_RUN_STATES = table.freeze({
	Prep = true,
	Wave = true,
	Resolution = true,
	Climax = true,
	Endless = true,
})

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "BlinkServer",
		Instance = BlinkServer,
	},
	{
		Name = "InventorySyncService",
		Module = InventorySyncService,
		CacheAs = "_syncService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "SlotManagementService",
		Module = SlotManagementService,
	},
	{
		Name = "AddItemPolicy",
		Module = AddItemPolicy,
	},
	{
		Name = "RemoveItemPolicy",
		Module = RemoveItemPolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "AddItem",
		Module = AddItem,
		CacheAs = "_addItemCommand",
	},
	{
		Name = "RemoveItem",
		Module = RemoveItem,
		CacheAs = "_removeItemCommand",
	},
	{
		Name = "ClearInventory",
		Module = ClearInventory,
		CacheAs = "_clearInventoryCommand",
	},
	{
		Name = "GetInventory",
		Module = GetInventory,
		CacheAs = "_getInventoryQuery",
	},
}

local InventoryModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

local InventoryContext = Knit.CreateService({
	Name = "InventoryContext",
	Client = {},
	Modules = InventoryModules,
	ExternalServices = {
		{ Name = "RunContext", CacheAs = "_runContext" },
	},
	Teardown = {
		Fields = {
			{ Field = "_syncService", Method = "Destroy" },
			{ Field = "_playerAddedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
			{ Field = "_runStateChangedConnection", Method = "Disconnect" },
		},
	},
})

local InventoryBaseContext = BaseContext.new(InventoryContext)

function InventoryContext:KnitInit()
	InventoryBaseContext:KnitInit()

	self._runContext = nil :: any
	self._playerAddedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
	self._runStateChangedConnection = nil :: any
end

function InventoryContext:KnitStart()
	InventoryBaseContext:KnitStart()

	self._playerAddedConnection = InventoryBaseContext:HandleExistingAndAddedPlayers(function(player: Player)
		self:_HandlePlayerAdded(player)
	end, "_playerAddedConnection")

	self._playerRemovingConnection = InventoryBaseContext:OnPlayerRemoving(function(player: Player)
		self._syncService:RemoveInventory(player.UserId)
	end, "_playerRemovingConnection")

	self._runStateChangedConnection = InventoryBaseContext:TrackSignalConnection(
		self._runContext.StateChanged:Connect(function(newState: string, previousState: string)
			self:_OnRunStateChanged(newState, previousState)
		end),
		"_runStateChangedConnection"
	)
end

function InventoryContext:AddItemToInventory(userId: number, itemId: string, quantity: number): Result.Result<any>
	return Catch(function()
		return self._addItemCommand:Execute(userId, itemId, quantity)
	end, "Inventory:AddItemToInventory")
end

function InventoryContext:RemoveItemFromInventory(userId: number, slotIndex: number, quantity: number): Result.Result<any>
	return Catch(function()
		return self._removeItemCommand:Execute(userId, slotIndex, quantity)
	end, "Inventory:RemoveItemFromInventory")
end

function InventoryContext:GetPlayerInventory(userId: number): Result.Result<any>
	return Catch(function()
		return self._getInventoryQuery:Execute(userId)
	end, "Inventory:GetPlayerInventory")
end

function InventoryContext:ClearInventory(userId: number): Result.Result<any>
	return Catch(function()
		return self._clearInventoryCommand:Execute(userId)
	end, "Inventory:ClearInventory")
end

function InventoryContext.Client:GetInventory(player: Player)
	return self.Server:GetPlayerInventory(player.UserId)
end

function InventoryContext.Client:RequestInventoryState(player: Player): boolean
	self.Server._syncService:HydratePlayer(player)
	return true
end

function InventoryContext:_HandlePlayerAdded(player: Player)
	if self:_IsRunActive() then
		self._syncService:EnsureInventory(player.UserId)
	end

	self._syncService:HydratePlayer(player)
end

function InventoryContext:_IsRunActive(): boolean
	local stateResult = self._runContext:GetState()
	if not stateResult.success then
		return false
	end

	return ACTIVE_RUN_STATES[stateResult.value] == true
end

function InventoryContext:_OnRunStateChanged(newState: string, previousState: string)
	if newState ~= "Prep" or (previousState ~= "Idle" and previousState ~= "RunEnd") then
		return
	end

	InventoryBaseContext:ForEachPlayer(function(player: Player)
		self._syncService:ResetInventory(player.UserId)
		self._syncService:HydratePlayer(player)
	end)
end

function InventoryContext:Destroy()
	local destroyResult = InventoryBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Inventory:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return InventoryContext

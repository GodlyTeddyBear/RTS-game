--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local BlinkServer = require(ReplicatedStorage.Network.Generated.EquipmentSyncServer)

local EquipmentSyncService = require(script.Parent.Infrastructure.Persistence.EquipmentSyncService)
local EquipmentAttachmentService = require(script.Parent.Infrastructure.Services.EquipmentAttachmentService)
local EquipmentOwnerResolverService = require(script.Parent.Infrastructure.Services.EquipmentOwnerResolverService)
local EquipItemPolicy = require(script.Parent.EquipmentDomain.Policies.EquipItemPolicy)
local UnequipItemPolicy = require(script.Parent.EquipmentDomain.Policies.UnequipItemPolicy)
local EquipItemCommand = require(script.Parent.Application.Commands.EquipItemCommand)
local UnequipItemCommand = require(script.Parent.Application.Commands.UnequipItemCommand)
local ClearEquipmentCommand = require(script.Parent.Application.Commands.ClearEquipmentCommand)
local GetEquipmentStateQuery = require(script.Parent.Application.Queries.GetEquipmentStateQuery)
local GetOwnerEquipmentQuery = require(script.Parent.Application.Queries.GetOwnerEquipmentQuery)

type TEquipmentState = EquipmentTypes.TEquipmentState
type TOwnerEquipment = EquipmentTypes.TOwnerEquipment
type TEquippedItem = EquipmentTypes.TEquippedItem
type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"

local Catch = Result.Catch

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "BlinkServer",
		Instance = BlinkServer,
	},
	{
		Name = "EquipmentSyncService",
		Module = EquipmentSyncService,
		CacheAs = "_syncService",
	},
	{
		Name = "EquipmentAttachmentService",
		Module = EquipmentAttachmentService,
	},
	{
		Name = "EquipmentOwnerResolverService",
		Module = EquipmentOwnerResolverService,
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "EquipItemPolicy",
		Module = EquipItemPolicy,
	},
	{
		Name = "UnequipItemPolicy",
		Module = UnequipItemPolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "EquipItemCommand",
		Module = EquipItemCommand,
		CacheAs = "_equipItemCommand",
	},
	{
		Name = "UnequipItemCommand",
		Module = UnequipItemCommand,
		CacheAs = "_unequipItemCommand",
	},
	{
		Name = "ClearEquipmentCommand",
		Module = ClearEquipmentCommand,
		CacheAs = "_clearEquipmentCommand",
	},
	{
		Name = "GetEquipmentStateQuery",
		Module = GetEquipmentStateQuery,
		CacheAs = "_getEquipmentStateQuery",
	},
	{
		Name = "GetOwnerEquipmentQuery",
		Module = GetOwnerEquipmentQuery,
		CacheAs = "_getOwnerEquipmentQuery",
	},
}

local EquipmentModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

local EquipmentContext = Knit.CreateService({
	Name = "EquipmentContext",
	Client = {},
	Modules = EquipmentModules,
	ExternalServices = {
		{ Name = "InventoryContext" },
		{ Name = "UnitContext" },
		{ Name = "EnemyContext" },
		{ Name = "StructureContext" },
		{ Name = "RunContext", CacheAs = "_runContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_playerAddedConnection", Method = "Disconnect" },
			{ Field = "_runStateChangedConnection", Method = "Disconnect" },
			{ Field = "_syncService", Method = "Destroy" },
		},
	},
})

local EquipmentBaseContext = BaseContext.new(EquipmentContext)

function EquipmentContext:KnitInit()
	EquipmentBaseContext:KnitInit()
	self._playerAddedConnection = nil :: RBXScriptConnection?
	self._runStateChangedConnection = nil :: RBXScriptConnection?
end

function EquipmentContext:KnitStart()
	EquipmentBaseContext:KnitStart()

	self._playerAddedConnection = EquipmentBaseContext:HandleExistingAndAddedPlayers(function(player: Player)
		self._syncService:HydratePlayer(player)
	end, "_playerAddedConnection")

	self._runStateChangedConnection = EquipmentBaseContext:TrackSignalConnection(
		self._runContext.StateChanged:Connect(function(newState: RunState, previousState: RunState)
			self:_OnRunStateChanged(newState, previousState)
		end),
		"_runStateChangedConnection"
	)
end

function EquipmentContext:EquipItemForOwner(
	userId: number,
	itemId: string,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<TEquippedItem>
	return Catch(function()
		return self._equipItemCommand:Execute(userId, itemId, ownerKind, ownerId, slotId)
	end, "Equipment:EquipItemForOwner")
end

function EquipmentContext:UnequipItemForOwner(
	userId: number,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<TEquippedItem>
	return Catch(function()
		return self._unequipItemCommand:Execute(userId, ownerKind, ownerId, slotId)
	end, "Equipment:UnequipItemForOwner")
end

function EquipmentContext:ClearEquipment(): Result.Result<boolean>
	return Catch(function()
		return self._clearEquipmentCommand:Execute()
	end, "Equipment:ClearEquipment")
end

function EquipmentContext:GetEquipmentState(): Result.Result<TEquipmentState>
	return Catch(function()
		return self._getEquipmentStateQuery:Execute()
	end, "Equipment:GetEquipmentState")
end

function EquipmentContext:GetOwnerEquipment(ownerKind: string, ownerId: string): Result.Result<TOwnerEquipment?>
	return Catch(function()
		return self._getOwnerEquipmentQuery:Execute(ownerKind, ownerId)
	end, "Equipment:GetOwnerEquipment")
end

function EquipmentContext.Client:EquipItem(
	player: Player,
	itemId: string,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<TEquippedItem>
	return self.Server:EquipItemForOwner(player.UserId, itemId, ownerKind, ownerId, slotId)
end

function EquipmentContext.Client:UnequipItem(
	player: Player,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<TEquippedItem>
	return self.Server:UnequipItemForOwner(player.UserId, ownerKind, ownerId, slotId)
end

function EquipmentContext.Client:GetEquipmentState(_player: Player): Result.Result<TEquipmentState>
	return self.Server:GetEquipmentState()
end

function EquipmentContext.Client:GetOwnerEquipment(
	_player: Player,
	ownerKind: string,
	ownerId: string
): Result.Result<TOwnerEquipment?>
	return self.Server:GetOwnerEquipment(ownerKind, ownerId)
end

function EquipmentContext.Client:RequestEquipmentState(player: Player): boolean
	self.Server._syncService:HydratePlayer(player)
	return true
end

function EquipmentContext:_OnRunStateChanged(newState: RunState, previousState: RunState)
	local shouldClear = newState == "RunEnd" or (previousState == "Idle" and newState == "Prep")
	if not shouldClear then
		return
	end

	local result = self:ClearEquipment()
	if not result.success then
		Result.MentionError("Equipment:RunStateChanged", "Failed to clear equipment", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function EquipmentContext:_BeforeDestroy()
	local result = self:ClearEquipment()
	if not result.success then
		Result.MentionError("Equipment:Destroy", "Failed to clear equipment during destroy", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function EquipmentContext:Destroy()
	local destroyResult = EquipmentBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Equipment:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return EquipmentContext

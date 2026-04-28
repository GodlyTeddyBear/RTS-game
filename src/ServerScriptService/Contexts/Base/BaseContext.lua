--!strict

--[=[
    @class BaseContext
    Knit service that wires the Base context application, ECS, sync, and teardown surface.
    @server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)
local BlinkServer = require(ReplicatedStorage.Network.Generated.BaseSyncServer)

local BaseECSWorldService = require(script.Parent.Infrastructure.ECS.BaseECSWorldService)
local BaseComponentRegistry = require(script.Parent.Infrastructure.ECS.BaseComponentRegistry)
local BaseEntityFactory = require(script.Parent.Infrastructure.ECS.BaseEntityFactory)
local BaseSyncService = require(script.Parent.Infrastructure.Persistence.BaseSyncService)
local PrepareRunBaseCommand = require(script.Parent.Application.Commands.PrepareRunBaseCommand)
local ApplyDamageBaseCommand = require(script.Parent.Application.Commands.ApplyDamageBaseCommand)
local CleanupBaseCommand = require(script.Parent.Application.Commands.CleanupBaseCommand)
local GetBaseStateQuery = require(script.Parent.Application.Queries.GetBaseStateQuery)
local GetBaseTargetCFrameQuery = require(script.Parent.Application.Queries.GetBaseTargetCFrameQuery)

local Catch = Result.Catch
local Ok = Result.Ok

type BaseState = BaseTypes.BaseState

-- â”€â”€ Initialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "BlinkServer",
		Instance = BlinkServer,
	},
	{
		Name = "BaseComponentRegistry",
		Module = BaseComponentRegistry,
	},
	{
		Name = "BaseEntityFactory",
		Module = BaseEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "BaseSyncService",
		Module = BaseSyncService,
		CacheAs = "_syncService",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "PrepareRunBaseCommand",
		Module = PrepareRunBaseCommand,
		CacheAs = "_prepareRunBaseCommand",
	},
	{
		Name = "ApplyDamageBaseCommand",
		Module = ApplyDamageBaseCommand,
		CacheAs = "_applyDamageBaseCommand",
	},
	{
		Name = "CleanupBaseCommand",
		Module = CleanupBaseCommand,
		CacheAs = "_cleanupBaseCommand",
	},
	{
		Name = "GetBaseStateQuery",
		Module = GetBaseStateQuery,
		CacheAs = "_getBaseStateQuery",
	},
	{
		Name = "GetBaseTargetCFrameQuery",
		Module = GetBaseTargetCFrameQuery,
		CacheAs = "_getBaseTargetCFrameQuery",
	},
}

local BaseModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

local BaseContextService = Knit.CreateService({
	Name = "BaseContext",
	Client = {},
	WorldService = {
		Name = "BaseECSWorldService",
		Module = BaseECSWorldService,
	},
	Modules = BaseModules,
	ExternalServices = {
		{ Name = "MapContext" },
	},
	Teardown = {
		Fields = {
			{ Field = "_playerAddedConnection", Method = "Disconnect" },
			{ Field = "_syncService", Method = "Destroy" },
		},
	},
})

local BaseBaseContext = BaseContext.new(BaseContextService)

-- â”€â”€ Public â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

--[=[
    Reset runtime-only state before the shared BaseContext wrapper starts.
    @within BaseContext
]=]
function BaseContextService:KnitInit()
	BaseBaseContext:KnitInit()
	self._playerAddedConnection = nil :: RBXScriptConnection?
end

--[=[
    Start player hydration after the shared BaseContext wrapper is ready.
    @within BaseContext
]=]
function BaseContextService:KnitStart()
	BaseBaseContext:KnitStart()
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		self._syncService:HydratePlayer(player)
	end)
end

--[=[
    @within BaseContext
    @return Result.Result<boolean> -- Whether the prepare step succeeded.
]=]
function BaseContextService:PrepareRunBase(): Result.Result<boolean>
	return Catch(function()
		return self._prepareRunBaseCommand:Execute()
	end, "Base:PrepareRunBase")
end

--[=[
    @within BaseContext
    @return Result.Result<boolean> -- Whether the cleanup step succeeded.
]=]
function BaseContextService:CleanupBase(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupBaseCommand:Execute()
	end, "Base:CleanupBase")
end

--[=[
    @within BaseContext
    @param amount number -- Damage to apply to the base.
    @return Result.Result<boolean> -- Whether the base died from the hit.
]=]
function BaseContextService:ApplyDamage(amount: number): Result.Result<boolean>
	return Catch(function()
		return self._applyDamageBaseCommand:Execute(amount)
	end, "Base:ApplyDamage")
end

--[=[
    @within BaseContext
    @return Result.Result<BaseState?> -- Read-only base state snapshot when the base exists.
]=]
function BaseContextService:GetBaseState(): Result.Result<BaseState?>
	return Catch(function()
		return self._getBaseStateQuery:Execute()
	end, "Base:GetBaseState")
end

--[=[
    @within BaseContext
    @return Result.Result<CFrame> -- Current target CFrame for the active base.
]=]
function BaseContextService:GetBaseTargetCFrame(): Result.Result<CFrame>
	return Catch(function()
		return self._getBaseTargetCFrameQuery:Execute()
	end, "Base:GetBaseTargetCFrame")
end

--[=[
    @within BaseContext
    @return Result.Result<any> -- Cached base entity factory instance.
]=]
function BaseContextService:GetEntityFactory(): Result.Result<any>
	return Ok(self._entityFactory)
end

--[=[
    Run base cleanup before tearing down the wrapped BaseContext.
    @within BaseContext
]=]
function BaseContextService:Destroy()
	local cleanupResult = self:CleanupBase()
	if not cleanupResult.success then
		Result.MentionError("Base:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end

	local destroyResult = BaseBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Base:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return BaseContextService

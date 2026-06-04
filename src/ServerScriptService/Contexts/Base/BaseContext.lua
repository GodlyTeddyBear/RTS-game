--!strict

--[=[
    @class BaseContext
    Knit service that wires the Base context application, ECS, sync, and teardown surface.
    @server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local BlinkServer = require(ReplicatedStorage.Network.Generated.BaseSyncServer)

local BaseEntitySchema = require(script.Parent.Infrastructure.Entity.BaseEntitySchema)
local BaseEntityReadService = require(script.Parent.Infrastructure.Entity.BaseEntityReadService)
local BaseSyncService = require(script.Parent.Infrastructure.Persistence.BaseSyncService)
local BaseStateSyncSystem = require(script.Parent.Infrastructure.Systems.BaseStateSyncSystem)
local BaseCombatRules = require(script.Parent.Config.CombatRules)
local PrepareRunBaseCommand = require(script.Parent.Application.Commands.PrepareRunBaseCommand)
local ApplyDamageBaseCommand = require(script.Parent.Application.Commands.ApplyDamageBaseCommand)
local CleanupBaseCommand = require(script.Parent.Application.Commands.CleanupBaseCommand)
local ProduceUnitCommand = require(script.Parent.Application.Commands.ProduceUnitCommand)
local GetBaseStateQuery = require(script.Parent.Application.Queries.GetBaseStateQuery)
local GetBaseTargetCFrameQuery = require(script.Parent.Application.Queries.GetBaseTargetCFrameQuery)

local Catch = Result.Catch
local Ok = Result.Ok

type BaseState = BaseTypes.BaseState
type SpawnUnitResult = UnitTypes.SpawnUnitResult

-- â”€â”€ Initialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "BlinkServer",
		Instance = BlinkServer,
	},
	{
		Name = "BaseEntityReadService",
		Module = BaseEntityReadService,
		CacheAs = "_baseEntityReadService",
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
		Name = "ProduceUnitCommand",
		Module = ProduceUnitCommand,
		CacheAs = "_produceUnitCommand",
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
	Modules = BaseModules,
	ExternalServices = {
		{ Name = "MapContext" },
		{ Name = "UnitContext" },
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "CombatContext", CacheAs = "_combatContext" },
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
	self._baseEntityReadService:Configure(self._entityContext)
	self:_RegisterEntityInfrastructure()
	self:_RegisterCombatRules()
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

function BaseContextService:ProduceUnit(player: Player, unitId: string): Result.Result<SpawnUnitResult>
	return Catch(function()
		return self._produceUnitCommand:Execute(player, unitId)
	end, "Base:ProduceUnit")
end

function BaseContextService.Client:ProduceUnit(player: Player, unitId: string)
	return self.Server:ProduceUnit(player, unitId)
end

function BaseContextService:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		local featureResult = self._entityContext:RegisterEntityFeature({
			FeatureName = "Base",
			Schema = BaseEntitySchema,
		})
		if not featureResult.success and featureResult.type ~= "DuplicateFeatureSchema" then
			return featureResult
		end

		local syncResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "BaseStateSyncSystem",
			Reads = {
				"Base.BaseTag",
				"Entity.DirtyTag",
				"Entity.Health",
			},
			Writes = {
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return BaseStateSyncSystem.new(entityFactory, self._syncService)
			end,
		})
		if not syncResult.success and syncResult.type ~= "DuplicateSystem" then
			return syncResult
		end

		return Ok(true)
	end, "Base:RegisterEntityInfrastructure")
end

function BaseContextService:_RegisterCombatRules(): Result.Result<boolean>
	return Catch(function()
		for _, payload in ipairs(BaseCombatRules.HealthDepleted or {}) do
			local result = self._combatContext:RegisterHealthDepletedRule(payload)
			if not result.success then
				return result
			end
		end
		return Ok(true)
	end, "Base:RegisterCombatRules")
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

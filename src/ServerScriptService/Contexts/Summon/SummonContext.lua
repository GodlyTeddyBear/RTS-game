--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local SummonECSWorldService = require(script.Parent.Infrastructure.ECS.SummonECSWorldService)
local SummonComponentRegistry = require(script.Parent.Infrastructure.ECS.SummonComponentRegistry)
local SummonEntityFactory = require(script.Parent.Infrastructure.ECS.SummonEntityFactory)
local SummonRuntimeService = require(script.Parent.Infrastructure.Services.SummonRuntimeService)
local SpawnSwarmDronesCommand = require(script.Parent.Application.Commands.SpawnSwarmDronesCommand)

local Errors = require(script.Parent.Errors)

local Catch = Result.Catch
local Ok = Result.Ok
local Ensure = Result.Ensure

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "SummonComponentRegistry",
		Module = SummonComponentRegistry,
	},
	{
		Name = "SummonEntityFactory",
		Module = SummonEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "SummonRuntimeService",
		Module = SummonRuntimeService,
		CacheAs = "_runtimeService",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "SpawnSwarmDronesCommand",
		Module = SpawnSwarmDronesCommand,
		CacheAs = "_spawnSwarmDronesCommand",
	},
}

local SummonModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

local SummonContext = Knit.CreateService({
	Name = "SummonContext",
	Client = {},
	WorldService = {
		Name = "SummonECSWorldService",
		Module = SummonECSWorldService,
	},
	Modules = SummonModules,
	ExternalServices = {
		{ Name = "EnemyContext", CacheAs = "_enemyContext" },
		{ Name = "RunContext", CacheAs = "_runContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runWaveStartedConnection", Method = "Disconnect" },
			{ Field = "_runWaveEndedConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
		},
	},
})

local SummonBaseContext = BaseContext.new(SummonContext)

function SummonContext:KnitInit()
	SummonBaseContext:KnitInit()
	self._combatEnabled = false
	self._enemyContext = nil :: any
	self._runContext = nil :: any
	self._runWaveStartedConnection = nil :: any
	self._runWaveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
end

function SummonContext:KnitStart()
	SummonBaseContext:KnitStart()

	SummonBaseContext:RegisterSchedulerSystem("CombatTick", function()
		if not self._combatEnabled then
			return
		end
		local dt = SummonBaseContext:GetSchedulerDeltaTime()
		self._runtimeService:Tick(dt, os.clock(), self._enemyContext)
		self._entityFactory:FlushPendingDeletes()
	end)

	SummonBaseContext:OnContextEvent("Run", "WaveStarted", function(_waveNumber: number, _isEndless: boolean)
		self._combatEnabled = true
	end, "_runWaveStartedConnection")

	SummonBaseContext:OnContextEvent("Run", "WaveEnded", function(_waveNumber: number)
		self._combatEnabled = false
		self._runtimeService:CleanupAll()
	end, "_runWaveEndedConnection")

	SummonBaseContext:OnContextEvent("Run", "RunEnded", function()
		self._combatEnabled = false
		self._runtimeService:CleanupAll()
	end, "_runEndedConnection")

	SummonBaseContext:OnPlayerRemoving(function(player: Player)
		self._runtimeService:CleanupOwner(player.UserId)
	end, "_playerRemovingConnection")
end

function SummonContext:SpawnSwarmDrones(
	player: Player,
	slotMetadata: { [string]: any }?,
	castOriginCFrame: CFrame
): Result.Result<{ spawnedCount: number }>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(castOriginCFrame, "InvalidCastOrigin", Errors.INVALID_CAST_ORIGIN)

		return self._spawnSwarmDronesCommand:Execute(player, slotMetadata, castOriginCFrame)
	end, "Summon:SpawnSwarmDrones")
end

function SummonContext:_BeforeDestroy()
	Catch(function()
		self._runtimeService:CleanupAll()
		return Ok(nil)
	end, "Summon:Destroy")
end

function SummonContext:Destroy()
	local destroyResult = SummonBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Summon:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return SummonContext

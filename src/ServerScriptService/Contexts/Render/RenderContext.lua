--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local RenderExportService = require(script.Parent.Infrastructure.Services.RenderExportService)
local RenderRegistryService = require(script.Parent.Infrastructure.Services.RenderRegistryService)
local RenderRuntimeService = require(script.Parent.Infrastructure.Services.RenderRuntimeService)

local Ok = Result.Ok

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ClientSignals",
		Factory = function(service: any, _baseContext: any)
			return service.Client
		end,
	},
	{
		Name = "RenderExportService",
		Module = RenderExportService,
		CacheAs = "_renderExportService",
	},
	{
		Name = "RenderRegistryService",
		Module = RenderRegistryService,
		CacheAs = "_renderRegistryService",
	},
	{
		Name = "RenderRuntimeService",
		Module = RenderRuntimeService,
		CacheAs = "_renderRuntimeService",
	},
}

local RenderModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
}

local RenderContext = Knit.CreateService({
	Name = "RenderContext",
	Client = {
		RenderRegistryBootstrapChunk = Knit.CreateSignal(),
		RenderRegistryDelta = Knit.CreateSignal(),
	},
	Modules = RenderModules,
	Teardown = {
		Fields = {
			{ Field = "_renderRuntimeService", Method = "Destroy" },
			{ Field = "_renderRegistryService", Method = "Destroy" },
			{ Field = "_renderExportService", Method = "Destroy" },
		},
	},
})

local RenderBaseContext = BaseContext.new(RenderContext)

function RenderContext:KnitInit()
	RenderBaseContext:KnitInit()
end

function RenderContext:KnitStart()
	RenderBaseContext:KnitStart()
end

function RenderContext:GetTrackedIndexById(id: string): Result.Result<number?>
	return Ok(self._renderRegistryService:GetIndexById(id))
end

function RenderContext:GetTrackedInstanceById(id: string): Result.Result<Instance?>
	return Ok(self._renderRegistryService:GetInstanceById(id))
end

function RenderContext:GetTrackedPropertyValueById(propertyKey: string, id: string): Result.Result<any>
	return Ok(self._renderRegistryService:GetPropertyValueById(propertyKey, id))
end

function RenderContext:GetTrackedCastShadowById(id: string): Result.Result<boolean?>
	return Ok(self._renderRegistryService:GetPropertyValueById("CastShadow", id))
end

function RenderContext:GetRegistrySoA(): Result.Result<any>
	return Ok(self._renderRegistryService:GetRegistrySoA())
end

function RenderContext.Client:RequestRenderRegistryBootstrap(player: Player): boolean
	return self.Server._renderRegistryService:HydratePlayer(player)
end

return RenderContext

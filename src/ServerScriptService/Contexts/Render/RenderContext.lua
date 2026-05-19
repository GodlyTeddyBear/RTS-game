--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)

local RenderRuntimeService = require(script.Parent.Infrastructure.Services.RenderRuntimeService)

local InfrastructureModules: { BaseContext.TModuleSpec } = {
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
	Client = {},
	Modules = RenderModules,
	Teardown = {
		Fields = {
			{ Field = "_renderRuntimeService", Method = "Destroy" },
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

return RenderContext

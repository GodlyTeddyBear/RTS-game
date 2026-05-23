--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RenderConfig = {}

-- Registry identity and bootstrap sizing for shared render state transport.
RenderConfig.RegistryTagPrefix = "RenderInstance:"
RenderConfig.RegistryBootstrapChunkSize = 256

-- Only these replicated/server instances participate in the Render registry.
RenderConfig.TrackedClassNames = table.freeze({
	"Model",
	"BasePart",
})

-- Enabled properties are snapshotted on the server, stripped to desired values,
-- then restored locally on clients from the registry cache.
RenderConfig.TrackedRenderProperties = table.freeze({
	CastShadow = true,
	Color = true,
	Material = true,
	MaterialVariant = true,
	Reflectance = true,
	Transparency = true,
})

-- Higher values are processed first for both server-side render work and delta flush order.
RenderConfig.RootPriorityByContainer = table.freeze({
	[Workspace] = 2,
	--[ReplicatedStorage] = 1,
	[ServerStorage] = 0,
})

RenderConfig.ServerProfile = table.freeze({
	-- Per-step scheduler budget for server-side stripping/reapply work.
	ApplyBudgetSeconds = 0.002,
	-- Long priority drains yield after this many ids unless a higher tier forces earlier yielding.
	ApplyYieldEveryIds = 8,
	-- Runtime delta changes are staged and flushed on this cadence instead of firing immediately.
	DeltaFlushIntervalSeconds = 0.05,
	-- Flush caps keep a single network batch from growing without bound under bursty creation.
	DeltaMaxIdsPerFlush = 128,
	DeltaMaxRemovalsPerFlush = 128,
	Lighting = table.freeze({
		-- The server keeps the stripped lighting profile authoritative for replicated state.
		GlobalShadows = false,
	}),
})

RenderConfig.ClientProfile = table.freeze({
	-- Per-step scheduler budget for client-side authored-property restore work.
	ApplyBudgetSeconds = 0.0015,
	ApplyYieldEveryIds = 4,
	-- Transport bootstrap and delta payloads are drained through a separate inbound FIFO.
	InboundBudgetSeconds = 0.0015,
	InboundYieldEveryItems = 8,
	Lighting = table.freeze({
		-- The client reapplies the authored lighting profile after server stripping.
		GlobalShadows = true,
	}),
})

return table.freeze(RenderConfig)

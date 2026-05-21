--!strict

local ECSIdentitySchema = require(script.Reveal.ECSIdentitySchema)
local ECSRevealBuilder = require(script.Reveal.ECSRevealBuilder)
local ECSRevealApplier = require(script.ECSRevealApplier)
local ClientECSDiscoveryIndexService = require(script.Discovery.ClientECSDiscoveryIndexService)

--[=[
	Shared utility access point for ECS reveal and discovery helpers.
	Owns module-level exports only; implementation details live in the sibling
	schema, builder, applier, and discovery modules.
	@class ECS
	@server
	@client
	@prop IdentitySchema table @readonly Shared identity schema helper used to build stable tags and scoped ids.
	@prop RevealBuilder table @readonly Helper that assembles reveal state for discoverable ECS instances.
	@prop RevealApplier table @readonly Helper that applies reveal state onto a Roblox instance.
	@prop DiscoveryIndexService table @readonly Client-side index for locating revealed ECS instances.
]=]
local ECS = {
	IdentitySchema = ECSIdentitySchema,
	RevealBuilder = ECSRevealBuilder,
	RevealApplier = ECSRevealApplier,
	DiscoveryIndexService = ClientECSDiscoveryIndexService,
}

return table.freeze(ECS)

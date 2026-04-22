--!strict

local ECSIdentitySchema = require(script.Reveal.ECSIdentitySchema)
local ECSRevealBuilder = require(script.Reveal.ECSRevealBuilder)
local ECSRevealApplier = require(script.ECSRevealApplier)
local ClientECSDiscoveryIndexService = require(script.Discovery.ClientECSDiscoveryIndexService)

--[=[
	Single utility access point for ECS primitives.
	@class ECS
]=]
local ECS = {
	IdentitySchema = ECSIdentitySchema,
	RevealBuilder = ECSRevealBuilder,
	RevealApplier = ECSRevealApplier,
	DiscoveryIndexService = ClientECSDiscoveryIndexService,
}

return table.freeze(ECS)

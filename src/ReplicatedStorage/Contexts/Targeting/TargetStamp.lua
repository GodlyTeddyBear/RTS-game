--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local ECSRevealApplier = require(ServerScriptService.Infrastructure.ECSRevealApplier)
local TargetRevealBuilder = require(script.Parent.TargetRevealBuilder)

--[=[
	@interface TStampOptions
	@within TargetStamp
	.TargetType string -- The target type to assign (e.g. `"Ore"`)
	.SourceId string -- Identifier for the source resource definition
	.ScopeId string -- Scope identifier (e.g. zone or lot id) used when auto-generating `TargetId`
	.TargetId string? -- Optional override for the target id; auto-generated from scope/type/source if omitted
]=]
export type TStampOptions = TargetRevealBuilder.TTargetRevealOptions

--[=[
	Compatibility module for registering a Roblox instance for discovery by `TargetIndexService`.
	@class TargetStamp
]=]
local TargetStamp = {}

--[=[
	Compatibility wrapper. New server-side code should use `TargetRevealBuilder.Build`
	and `ECSRevealApplier.Apply` directly.
	@within TargetStamp
	@param instance Instance -- The Roblox instance to stamp
	@param options TStampOptions -- Stamping parameters
	@return string -- The resolved `TargetId` applied to the instance
	@error string -- Thrown if `instance` is nil or any required option field is missing or empty
]=]
function TargetStamp.Stamp(instance: Instance, options: TStampOptions): string
	assert(instance, "TargetStamp.Stamp requires an instance")
	local targetId, revealState = TargetRevealBuilder.Build(options)
	ECSRevealApplier.Apply(instance, revealState)

	return targetId
end

return TargetStamp

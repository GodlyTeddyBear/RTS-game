--!strict

local ECSIdentitySchema = require(script.Parent.ECSIdentitySchema)

export type TAttributeValue =
	string
	| number
	| boolean
	| Vector3
	| CFrame
	| Color3
	| BrickColor
	| UDim
	| UDim2
	| NumberSequence
	| ColorSequence
	| NumberRange
	| Rect
	| nil

export type ECSRevealState = {
	Attributes: { [string]: TAttributeValue }?,
	ClearAttributes: { string }?,
	Tags: { [string]: boolean }?,
}

export type ECSRevealOptions = {
	EntityType: string,
	SourceId: string,
	ScopeId: string,
	EntityId: string?,
	Namespace: string?,
}

--[=[
	Builds reveal state for a discoverable ECS-backed instance.
	Preferred access: `require(ReplicatedStorage.Utilities.ECS).RevealBuilder`.
	@class ECSRevealBuilder
]=]
local ECSRevealBuilder = {}

function ECSRevealBuilder.Build(options: ECSRevealOptions): (string, ECSRevealState)
	assert(type(options.EntityType) == "string" and options.EntityType ~= "", "EntityType is required")
	assert(type(options.SourceId) == "string" and options.SourceId ~= "", "SourceId is required")
	assert(type(options.ScopeId) == "string" and options.ScopeId ~= "", "ScopeId is required")

	local resolvedNamespace = options.Namespace or ECSIdentitySchema.DEFAULT_NAMESPACE
	local resolvedEntityId = options.EntityId
		or ECSIdentitySchema.MakeScopedEntityId(options.ScopeId, options.EntityType, options.SourceId)

	return resolvedEntityId, {
		Attributes = {
			[ECSIdentitySchema.ATTR_ENTITY_TYPE] = options.EntityType,
			[ECSIdentitySchema.ATTR_ENTITY_ID] = resolvedEntityId,
		},
		Tags = {
			[ECSIdentitySchema.GetTypeTag(options.EntityType, resolvedNamespace)] = true,
			[ECSIdentitySchema.GetTypeSourceTag(options.EntityType, options.SourceId, resolvedNamespace)] = true,
		},
	}
end

return ECSRevealBuilder

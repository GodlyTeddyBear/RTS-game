--!strict

local ECSIdentitySchema = require(script.Parent.ECSIdentitySchema)

--[=[
	@type TAttributeValue
	@within ECSRevealBuilder
	Attribute value types accepted by the reveal contract.
]=]
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

--[=[
	@interface ECSRevealState
	@within ECSRevealBuilder
	.Attributes { [string]: TAttributeValue }? -- Attributes to set on the target instance.
	.ClearAttributes { string }? -- Attribute names to clear from the target instance.
	.Tags { [string]: boolean }? -- Tags to add or remove on the target instance.
]=]
export type ECSRevealState = {
	Attributes: { [string]: TAttributeValue }?,
	ClearAttributes: { string }?,
	Tags: { [string]: boolean }?,
}

--[=[
	@interface ECSRevealOptions
	@within ECSRevealBuilder
	.EntityType string -- Logical ECS entity type.
	.SourceId string -- Source identifier used to compose stable reveal tags.
	.ScopeId string -- Scope identifier used to compose scoped entity ids.
	.EntityId string? -- Optional precomputed entity id override.
	.Namespace string? -- Optional reveal namespace override.
]=]
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
	@server
	@client
]=]
-- ── Types ──────────────────────────────────────────────────────────────────

local ECSRevealBuilder = {}

-- ── Public ─────────────────────────────────────────────────────────────────

--[=[
	Builds the identity payload for an ECS reveal.
	@within ECSRevealBuilder
	@param options ECSRevealOptions -- Input values used to derive the reveal state.
	@return string -- Resolved entity id for the instance.
	@return ECSRevealState -- Attribute and tag payload to apply to the instance.
]=]
function ECSRevealBuilder.Build(options: ECSRevealOptions): (string, ECSRevealState)
	-- Validate the minimum identity inputs before building the reveal contract.
	assert(type(options.EntityType) == "string" and options.EntityType ~= "", "EntityType is required")
	assert(type(options.SourceId) == "string" and options.SourceId ~= "", "SourceId is required")
	assert(type(options.ScopeId) == "string" and options.ScopeId ~= "", "ScopeId is required")

	-- Allow restore flows to reuse an existing id instead of recomputing one.
	local resolvedNamespace = options.Namespace or ECSIdentitySchema.DEFAULT_NAMESPACE
	local resolvedEntityId = options.EntityId
		or ECSIdentitySchema.MakeScopedEntityId(options.ScopeId, options.EntityType, options.SourceId)

	-- Emit the shared reveal contract that discovery indexes consume later.
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

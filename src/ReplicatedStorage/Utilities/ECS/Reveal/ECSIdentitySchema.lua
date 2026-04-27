--!strict

--[=[
	Shared identity and tag schema for ECS instance reveal and discovery.
	Builds stable tag names, attribute keys, and scoped entity ids for both the
	server reveal path and the client discovery index.
	@class ECSIdentitySchema
	@server
	@client
	@prop DEFAULT_NAMESPACE string @readonly Default namespace prefix used when one is not provided.
	@prop TAG_SEPARATOR string @readonly Separator used when composing tag and scoped id strings.
	@prop ATTR_ENTITY_ID string @readonly Attribute name used to store the scoped entity id.
	@prop ATTR_ENTITY_TYPE string @readonly Attribute name used to store the entity type.
]=]
-- ── Constants ──────────────────────────────────────────────────────────────

local ECSIdentitySchema = {}

--[=[
	Defines the shared ECS identity schema shape.
	@within ECSIdentitySchema
]=]
export type TECSIdentitySchema = {
	DEFAULT_NAMESPACE: string,
	TAG_SEPARATOR: string,
	ATTR_ENTITY_ID: string,
	ATTR_ENTITY_TYPE: string,
	GetTagPrefix: (namespace: string?) -> string,
	IsEntityTag: (tag: string, namespace: string?) -> boolean,
	GetTypeTag: (entityType: string, namespace: string?) -> string,
	GetTypeSourceTag: (entityType: string, sourceId: string, namespace: string?) -> string,
	MakeScopedEntityId: (scopeId: string, entityType: string, sourceId: string) -> string,
}

ECSIdentitySchema.DEFAULT_NAMESPACE = "Target"
ECSIdentitySchema.TAG_SEPARATOR = ":"

-- Preserve existing runtime semantics for iteration-1 scaffold compatibility.
ECSIdentitySchema.ATTR_ENTITY_ID = "TargetId"
ECSIdentitySchema.ATTR_ENTITY_TYPE = "TargetType"

-- ── Public ─────────────────────────────────────────────────────────────────

--[=[
	Resolves the tag prefix for a namespace.
	@within ECSIdentitySchema
	@param namespace string? -- Optional namespace override.
	@return string -- Namespace prefix that ends with the schema separator.
]=]
function ECSIdentitySchema.GetTagPrefix(namespace: string?): string
	local resolvedNamespace = namespace or ECSIdentitySchema.DEFAULT_NAMESPACE
	return `{resolvedNamespace}{ECSIdentitySchema.TAG_SEPARATOR}`
end

--[=[
	Checks whether a tag belongs to the ECS identity namespace.
	@within ECSIdentitySchema
	@param tag string -- Tag name to inspect.
	@param namespace string? -- Optional namespace override.
	@return boolean -- Whether the tag uses the ECS namespace prefix.
]=]
function ECSIdentitySchema.IsEntityTag(tag: string, namespace: string?): boolean
	local prefix = ECSIdentitySchema.GetTagPrefix(namespace)
	return string.sub(tag, 1, #prefix) == prefix
end

--[=[
	Builds the type tag for an ECS entity.
	@within ECSIdentitySchema
	@param entityType string -- Logical entity type to encode in the tag.
	@param namespace string? -- Optional namespace override.
	@return string -- Fully qualified type tag.
]=]
function ECSIdentitySchema.GetTypeTag(entityType: string, namespace: string?): string
	local prefix = ECSIdentitySchema.GetTagPrefix(namespace)
	return `{prefix}{entityType}`
end

--[=[
	Builds the type-and-source tag for an ECS entity.
	@within ECSIdentitySchema
	@param entityType string -- Logical entity type to encode in the tag.
	@param sourceId string -- Source identifier to keep the tag stable per origin.
	@param namespace string? -- Optional namespace override.
	@return string -- Fully qualified type/source tag.
]=]
function ECSIdentitySchema.GetTypeSourceTag(entityType: string, sourceId: string, namespace: string?): string
	local prefix = ECSIdentitySchema.GetTagPrefix(namespace)
	local separator = ECSIdentitySchema.TAG_SEPARATOR
	return `{prefix}{entityType}{separator}{sourceId}`
end

--[=[
	Builds a scoped entity id from the scope, type, and source.
	@within ECSIdentitySchema
	@param scopeId string -- Scope identifier for the owning ECS world or context.
	@param entityType string -- Logical entity type.
	@param sourceId string -- Source identifier for the entity.
	@return string -- Stable scoped entity id.
]=]
function ECSIdentitySchema.MakeScopedEntityId(scopeId: string, entityType: string, sourceId: string): string
	local separator = ECSIdentitySchema.TAG_SEPARATOR
	return `{scopeId}{separator}{entityType}{separator}{sourceId}`
end

return table.freeze(ECSIdentitySchema) :: TECSIdentitySchema

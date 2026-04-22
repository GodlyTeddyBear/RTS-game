--!strict

--[=[
	Shared identity and tag schema for ECS instance reveal/discovery.
	Preferred access: `require(ReplicatedStorage.Utilities.ECS).IdentitySchema`.
	@class ECSIdentitySchema
]=]
local ECSIdentitySchema = {}

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

function ECSIdentitySchema.GetTagPrefix(namespace: string?): string
	local resolvedNamespace = namespace or ECSIdentitySchema.DEFAULT_NAMESPACE
	return `{resolvedNamespace}{ECSIdentitySchema.TAG_SEPARATOR}`
end

function ECSIdentitySchema.IsEntityTag(tag: string, namespace: string?): boolean
	local prefix = ECSIdentitySchema.GetTagPrefix(namespace)
	return string.sub(tag, 1, #prefix) == prefix
end

function ECSIdentitySchema.GetTypeTag(entityType: string, namespace: string?): string
	local prefix = ECSIdentitySchema.GetTagPrefix(namespace)
	return `{prefix}{entityType}`
end

function ECSIdentitySchema.GetTypeSourceTag(entityType: string, sourceId: string, namespace: string?): string
	local prefix = ECSIdentitySchema.GetTagPrefix(namespace)
	local separator = ECSIdentitySchema.TAG_SEPARATOR
	return `{prefix}{entityType}{separator}{sourceId}`
end

function ECSIdentitySchema.MakeScopedEntityId(scopeId: string, entityType: string, sourceId: string): string
	local separator = ECSIdentitySchema.TAG_SEPARATOR
	return `{scopeId}{separator}{entityType}{separator}{sourceId}`
end

return table.freeze(ECSIdentitySchema) :: TECSIdentitySchema

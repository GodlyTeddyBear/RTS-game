--!strict

--[=[
	Shared constants and helpers that define the CollectionService tag and attribute
	conventions used across the Targeting system.
	@class TargetSchema
]=]
local TargetSchema = {}

--[=[
	@prop TAG_PREFIX string
	@within TargetSchema
	@readonly
	The prefix applied to all Targeting CollectionService tags (e.g. `"Target:"`).
]=]
TargetSchema.TAG_PREFIX = "Target:"

--[=[
	@prop ATTR_TARGET_ID string
	@within TargetSchema
	@readonly
	The Roblox attribute name used to store the target's unique identifier.
]=]
TargetSchema.ATTR_TARGET_ID = "TargetId"

--[=[
	@prop ATTR_TARGET_TYPE string
	@within TargetSchema
	@readonly
	The Roblox attribute name used to store the target's type (e.g. `"Ore"`, `"Tree"`).
]=]
TargetSchema.ATTR_TARGET_TYPE = "TargetType"

--[=[
	Returns `true` if `tag` begins with `TAG_PREFIX`, identifying it as a Targeting tag.
	@within TargetSchema
	@param tag string -- The CollectionService tag to check
	@return boolean -- Whether the tag is a Targeting tag
]=]
function TargetSchema.IsTargetTag(tag: string): boolean
	return string.sub(tag, 1, #TargetSchema.TAG_PREFIX) == TargetSchema.TAG_PREFIX
end

--[=[
	Returns the CollectionService type-level tag for `targetType` (e.g. `"Target:Ore"`).
	@within TargetSchema
	@param targetType string -- The target type (e.g. `"Ore"`)
	@return string -- The constructed type tag
]=]
function TargetSchema.GetTypeTag(targetType: string): string
	return `Target:{targetType}`
end

--[=[
	Returns the CollectionService type-and-source tag for a specific source (e.g. `"Target:Ore:rock_1"`).
	@within TargetSchema
	@param targetType string -- The target type (e.g. `"Ore"`)
	@param sourceId string -- The source identifier
	@return string -- The constructed type-and-source tag
]=]
function TargetSchema.GetTypeIdTag(targetType: string, sourceId: string): string
	return `Target:{targetType}:{sourceId}`
end

--[=[
	Builds a scoped `TargetId` string combining scope, type, and source (e.g. `"zone1:Ore:rock_1"`).
	@within TargetSchema
	@param scopeId string -- The scope identifier (e.g. a zone or lot id)
	@param targetType string -- The target type (e.g. `"Ore"`)
	@param sourceId string -- The source identifier
	@return string -- The constructed scoped target id
]=]
function TargetSchema.MakeScopedTargetId(scopeId: string, targetType: string, sourceId: string): string
	return `{scopeId}:{targetType}:{sourceId}`
end

return table.freeze(TargetSchema)

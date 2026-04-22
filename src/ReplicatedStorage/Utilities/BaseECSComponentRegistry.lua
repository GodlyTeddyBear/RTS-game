--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class BaseECSComponentRegistry
	Shared helpers for JECS component/tag registration and frozen registry export.
	@server
]=]
local BaseECSComponentRegistry = {}
BaseECSComponentRegistry.__index = BaseECSComponentRegistry

local function _nameComponent(world: any, componentId: number, name: string)
	world:set(componentId, JECS.Name, name)
end

--[=[
	Creates a new base registry helper.
	@within BaseECSComponentRegistry
	@param contextName string -- The owning context label used in assertions.
	@return BaseECSComponentRegistry -- The base registry instance.
]=]
function BaseECSComponentRegistry._new(contextName: string)
	local self = setmetatable({}, BaseECSComponentRegistry)
	self._contextName = contextName
	self._world = nil
	self._components = {} :: { [string]: any }
	self._componentNames = {} :: { [string]: string }
	self._tagNames = {} :: { [string]: string }
	self._authorityByKey = {} :: { [string]: "AUTHORITATIVE" | "DERIVED" }
	self._frozen = false
	return self
end

--[=[
	Resolves the world dependency before component registration begins.
	@within BaseECSComponentRegistry
	@param registry any -- The dependency registry for this context.
]=]
function BaseECSComponentRegistry:InitBase(registry: any)
	assert(not self._frozen, ("%sComponentRegistry: already finalized"):format(self._contextName))
	self._world = registry:Get("World")
	assert(self._world ~= nil, ("%sComponentRegistry: missing World"):format(self._contextName))
end

--[=[
	Registers a JECS data component and stores its id under the supplied key.
	@within BaseECSComponentRegistry
	@param key string -- Public key exposed through GetComponents().
	@param ecsName string -- Debug JECS name label.
	@param _authorityLabel string? -- Optional authority label metadata comment.
	@return number -- The JECS component id.
]=]
function BaseECSComponentRegistry:RegisterComponent(key: string, ecsName: string, authorityLabel: "AUTHORITATIVE" | "DERIVED"): number
	assert(not self._frozen, ("%sComponentRegistry: cannot register component after Finalize"):format(self._contextName))
	assert(self._world ~= nil, ("%sComponentRegistry: InitBase must run before RegisterComponent"):format(self._contextName))
	assert(self._components[key] == nil, ("%sComponentRegistry: duplicate key '%s'"):format(self._contextName, key))
	assert(authorityLabel == "AUTHORITATIVE" or authorityLabel == "DERIVED", ("%sComponentRegistry: invalid authority '%s' for key '%s'"):format(self._contextName, tostring(authorityLabel), key))

	local componentId = self._world:component()
	_nameComponent(self._world, componentId, ecsName)
	self._components[key] = componentId
	self._componentNames[key] = ecsName
	self._authorityByKey[key] = authorityLabel
	return componentId
end

--[=[
	Registers a JECS tag and stores its id under the supplied key.
	@within BaseECSComponentRegistry
	@param key string -- Public key exposed through GetComponents().
	@param ecsName string -- Debug JECS name label.
	@return number -- The JECS tag id.
]=]
function BaseECSComponentRegistry:RegisterTag(key: string, ecsName: string): number
	assert(not self._frozen, ("%sComponentRegistry: cannot register tag after Finalize"):format(self._contextName))
	assert(self._world ~= nil, ("%sComponentRegistry: InitBase must run before RegisterTag"):format(self._contextName))
	assert(self._components[key] == nil, ("%sComponentRegistry: duplicate key '%s'"):format(self._contextName, key))

	local tagId = self._world:entity()
	_nameComponent(self._world, tagId, ecsName)
	self._components[key] = tagId
	self._tagNames[key] = ecsName
	return tagId
end

--[=[
	Registers an externally owned id into the frozen components lookup.
	Useful for JECS built-ins like ChildOf.
	@within BaseECSComponentRegistry
	@param key string -- Public key exposed through GetComponents().
	@param id any -- Existing JECS id/value to expose.
]=]
function BaseECSComponentRegistry:RegisterExternal(key: string, id: any)
	assert(not self._frozen, ("%sComponentRegistry: cannot register external after Finalize"):format(self._contextName))
	assert(self._components[key] == nil, ("%sComponentRegistry: duplicate key '%s'"):format(self._contextName, key))
	self._components[key] = id
end

local function _endsWith(value: string, suffix: string): boolean
	return string.sub(value, -#suffix) == suffix
end

--[=[
	Validates convention contracts for registered keys and debug names.
	@within BaseECSComponentRegistry
]=]
function BaseECSComponentRegistry:ValidateKeyAndNameConventions()
	for key, ecsName in pairs(self._tagNames) do
		assert(_endsWith(key, "Tag"), ("%sComponentRegistry: tag key '%s' must end with 'Tag'"):format(self._contextName, key))
		assert(_endsWith(ecsName, "Tag"), ("%sComponentRegistry: tag ecsName '%s' must end with 'Tag'"):format(self._contextName, ecsName))
	end

	for key, _ in pairs(self._componentNames) do
		local authority = self._authorityByKey[key]
		assert(authority == "AUTHORITATIVE" or authority == "DERIVED", ("%sComponentRegistry: missing authority for component '%s'"):format(self._contextName, key))
	end
end

--[=[
	Freezes and exports the registered component lookup table.
	@within BaseECSComponentRegistry
	@param extra table? -- Optional extra immutable keys to merge before freezing.
]=]
function BaseECSComponentRegistry:Finalize(extra: { [string]: any }?)
	assert(not self._frozen, ("%sComponentRegistry: Finalize called twice"):format(self._contextName))

	if extra then
		for key, value in pairs(extra) do
			self:RegisterExternal(key, value)
		end
	end

	self:ValidateKeyAndNameConventions()
	self._components = table.freeze(self._components)
	self._authorityByKey = table.freeze(self._authorityByKey)
	self._frozen = true
end

--[=[
	Returns the frozen component lookup table.
	@within BaseECSComponentRegistry
	@return table -- The frozen lookup table.
]=]
function BaseECSComponentRegistry:GetComponents()
	assert(self._frozen, ("%sComponentRegistry: GetComponents called before Finalize"):format(self._contextName))
	return self._components
end

--[=[
	Returns the authority metadata for a registered component key.
	@within BaseECSComponentRegistry
	@param key string -- Component key.
	@return ("AUTHORITATIVE" | "DERIVED")? -- Authority label or nil when key is not a data component.
]=]
function BaseECSComponentRegistry:GetAuthority(key: string): ("AUTHORITATIVE" | "DERIVED")?
	assert(self._frozen, ("%sComponentRegistry: GetAuthority called before Finalize"):format(self._contextName))
	return self._authorityByKey[key]
end

--[=[
	Returns registry metadata for diagnostics and validation.
	@within BaseECSComponentRegistry
	@return { AuthorityByKey: { [string]: string }, Keys: { string } } -- Frozen metadata snapshot.
]=]
function BaseECSComponentRegistry:GetRegistryMetadata(): { AuthorityByKey: { [string]: string }, Keys: { string } }
	assert(self._frozen, ("%sComponentRegistry: GetRegistryMetadata called before Finalize"):format(self._contextName))

	local keys = {}
	for key in pairs(self._components) do
		table.insert(keys, key)
	end
	table.sort(keys)

	return {
		AuthorityByKey = self._authorityByKey,
		Keys = keys,
	}
end

return BaseECSComponentRegistry

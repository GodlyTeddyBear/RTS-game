--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class BaseECSComponentRegistry
	Owns JECS component, tag, and external id registration for one bounded ECS
	context and exports a frozen lookup table plus registry metadata.
	@server
]=]
local BaseECSComponentRegistry = {}
BaseECSComponentRegistry.__index = BaseECSComponentRegistry

-- ── Private ───────────────────────────────────────────────────────────────────

local function _nameComponent(world: any, componentId: number, name: string)
	world:set(componentId, JECS.Name, name)
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
	Creates a new base registry helper.
	@within BaseECSComponentRegistry
	@param contextName string -- Owning context label used in assertions and diagnostics.
	@return BaseECSComponentRegistry -- The base registry instance.
]=]
function BaseECSComponentRegistry.new(contextName: string)
	local self = setmetatable({}, BaseECSComponentRegistry)
	self._contextName = contextName
	self._world = nil
	self._components = {} :: { [string]: any }
	self._componentNames = {} :: { [string]: string }
	self._tagNames = {} :: { [string]: string }
	self._externalNames = {} :: { [string]: string }
	self._authorityByKey = {} :: { [string]: "AUTHORITATIVE" | "DERIVED" }
	self._registrationKindByKey = {} :: { [string]: "Component" | "Tag" | "External" }
	self._metadataSnapshot = nil :: { AuthorityByKey: { [string]: string }, Keys: { string }, KindByKey: { [string]: string }, NameByKey: { [string]: string } }?
	self._frozen = false
	return self
end

--[=[
	Initializes the registry, runs derived registration, validates conventions,
	and freezes the exported lookup table.
	@within BaseECSComponentRegistry
	@param registry any -- Dependency registry for this context.
	@param name string -- Registered module name.
]=]
function BaseECSComponentRegistry:Init(registry: any, name: string)
	self:InitBase(registry)
	if type(self._RegisterComponents) == "function" then
		self:_RegisterComponents(registry, name)
	end
	if type(self._ValidateRegistry) == "function" then
		self:_ValidateRegistry()
	end
	self:Finalize()
end

function BaseECSComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	return
end

--[=[
	Resolves the world dependency before component registration begins.
	@within BaseECSComponentRegistry
	@param registry any -- Dependency registry for this context.
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
	@param authorityLabel ("AUTHORITATIVE" | "DERIVED") -- Ownership label for sync and validation rules.
	@return number -- The JECS component id.
]=]
function BaseECSComponentRegistry:RegisterComponent(key: string, ecsName: string, authorityLabel: "AUTHORITATIVE" | "DERIVED"): number
	assert(not self._frozen, ("%sComponentRegistry: cannot register component after Finalize"):format(self._contextName))
	assert(self._world ~= nil, ("%sComponentRegistry: InitBase must run before RegisterComponent"):format(self._contextName))
	assert(self._components[key] == nil, ("%sComponentRegistry: duplicate key '%s'"):format(self._contextName, key))
	assert(authorityLabel == "AUTHORITATIVE" or authorityLabel == "DERIVED", ("%sComponentRegistry: invalid authority '%s' for key '%s'"):format(self._contextName, tostring(authorityLabel), key))
	assert(not self:_HasECSName(ecsName), ("%sComponentRegistry: duplicate ecsName '%s'"):format(self._contextName, ecsName))

	local componentId = self._world:component()
	_nameComponent(self._world, componentId, ecsName)
	self._components[key] = componentId
	self._componentNames[key] = ecsName
	self._authorityByKey[key] = authorityLabel
	self._registrationKindByKey[key] = "Component"
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
	assert(not self:_HasECSName(ecsName), ("%sComponentRegistry: duplicate ecsName '%s'"):format(self._contextName, ecsName))

	local tagId = self._world:entity()
	_nameComponent(self._world, tagId, ecsName)
	self._components[key] = tagId
	self._tagNames[key] = ecsName
	self._registrationKindByKey[key] = "Tag"
	return tagId
end

--[=[
	Registers an externally owned id into the frozen components lookup.
	Useful for JECS built-ins like ChildOf.
	@within BaseECSComponentRegistry
	@param key string -- Public key exposed through GetComponents().
	@param id any -- Existing JECS id or value to expose.
]=]
function BaseECSComponentRegistry:RegisterExternal(key: string, id: any)
	assert(not self._frozen, ("%sComponentRegistry: cannot register external after Finalize"):format(self._contextName))
	assert(self._components[key] == nil, ("%sComponentRegistry: duplicate key '%s'"):format(self._contextName, key))
	self._components[key] = id
	self._externalNames[key] = key
	self._registrationKindByKey[key] = "External"
end

local function _endsWith(value: string, suffix: string): boolean
	return string.sub(value, -#suffix) == suffix
end

-- Checks for duplicate debug names across registered components and tags.
function BaseECSComponentRegistry:_HasECSName(ecsName: string): boolean
	for _, registeredName in pairs(self._componentNames) do
		if registeredName == ecsName then
			return true
		end
	end

	for _, registeredName in pairs(self._tagNames) do
		if registeredName == ecsName then
			return true
		end
	end

	return false
end

--[=[
	Validates convention contracts for registered keys and debug names.
	@within BaseECSComponentRegistry
]=]
function BaseECSComponentRegistry:ValidateKeyAndNameConventions()
	local expectedPrefix = ("%s."):format(self._contextName)

	for key, ecsName in pairs(self._componentNames) do
		assert(_endsWith(key, "Component"), ("%sComponentRegistry: component key '%s' must end with 'Component'"):format(self._contextName, key))
		assert(string.sub(ecsName, 1, #expectedPrefix) == expectedPrefix, ("%sComponentRegistry: component ecsName '%s' must start with '%s'"):format(self._contextName, ecsName, expectedPrefix))
		local authority = self._authorityByKey[key]
		assert(authority == "AUTHORITATIVE" or authority == "DERIVED", ("%sComponentRegistry: missing authority for component '%s'"):format(self._contextName, key))
	end

	for key, ecsName in pairs(self._tagNames) do
		assert(_endsWith(key, "Tag"), ("%sComponentRegistry: tag key '%s' must end with 'Tag'"):format(self._contextName, key))
		assert(_endsWith(ecsName, "Tag"), ("%sComponentRegistry: tag ecsName '%s' must end with 'Tag'"):format(self._contextName, ecsName))
		assert(string.sub(ecsName, 1, #expectedPrefix) == expectedPrefix, ("%sComponentRegistry: tag ecsName '%s' must start with '%s'"):format(self._contextName, ecsName, expectedPrefix))
	end
end

function BaseECSComponentRegistry:_ValidateRegistry()
	return
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
	self._registrationKindByKey = table.freeze(self._registrationKindByKey)
	self._metadataSnapshot = table.freeze({
		AuthorityByKey = self._authorityByKey,
		Keys = table.freeze((function()
			local keys = {}
			for key in pairs(self._components) do
				table.insert(keys, key)
			end
			table.sort(keys)
			return keys
		end)()),
		KindByKey = self._registrationKindByKey,
		NameByKey = table.freeze((function()
			local namesByKey = table.clone(self._componentNames)
			for key, ecsName in pairs(self._tagNames) do
				namesByKey[key] = ecsName
			end
			for key, ecsName in pairs(self._externalNames) do
				namesByKey[key] = ecsName
			end
			return namesByKey
		end)()),
	})
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
	@return { AuthorityByKey: { [string]: string }, Keys: { string }, KindByKey: { [string]: string }, NameByKey: { [string]: string } } -- Frozen metadata snapshot.
]=]
function BaseECSComponentRegistry:GetRegistryMetadata(): { AuthorityByKey: { [string]: string }, Keys: { string }, KindByKey: { [string]: string }, NameByKey: { [string]: string } }
	assert(self._frozen, ("%sComponentRegistry: GetRegistryMetadata called before Finalize"):format(self._contextName))
	assert(self._metadataSnapshot ~= nil, ("%sComponentRegistry: missing metadata snapshot"):format(self._contextName))
	return self._metadataSnapshot
end

return BaseECSComponentRegistry

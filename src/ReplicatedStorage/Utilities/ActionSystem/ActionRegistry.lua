--!strict

--[=[
	@class ActionRegistry
	Maps animation state names to action class instances for runtime dispatch.
	@server
]=]

local Types = require(script.Parent.Types)

local ActionRegistry = {}

local _registry: { [string]: Types.IAction } = {}

--[=[
	Register an action class under a given animation state name.
	The name must match the `AnimationState` attribute value on the animated model.

	@within ActionRegistry
	@param name string -- Animation state name (e.g. "Mining", "Harvesting")
	@param actionClass IAction -- Action class implementing the IAction interface
	@error string -- Throws if name is empty or actionClass is nil
]=]
function ActionRegistry.Register(name: string, actionClass: Types.IAction)
	assert(type(name) == "string" and #name > 0, "ActionRegistry.Register: name must be a non-empty string")
	assert(actionClass ~= nil, "ActionRegistry.Register: actionClass must not be nil")
	_registry[name] = actionClass
end

--[=[
	Retrieve an action class by animation state name.

	@within ActionRegistry
	@param name string -- Animation state name to look up
	@return IAction? -- The registered action class, or nil if not found
]=]
function ActionRegistry.Get(name: string): Types.IAction?
	return _registry[name]
end

return ActionRegistry

--!strict

--[=[
    @class Registry
    Exposes the registry created during `KnitInit`.
    @server
]=]

local RegistryAccess = require(script.Parent.Parent.Internal.RegistryAccess)

local RegistryMethods = {}

--[=[
	Returns the registry created during `KnitInit`.
	@within Registry
	@return any -- Context registry.
]=]
function RegistryMethods:GetRegistry()
	return RegistryAccess.GetRegistry(self)
end

return RegistryMethods

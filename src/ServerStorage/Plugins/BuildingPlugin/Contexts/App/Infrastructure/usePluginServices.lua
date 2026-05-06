--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PluginServicesContext = require(script.Parent.PluginServicesContext)

local function usePluginServices(): any
	local services = React.useContext(PluginServicesContext)
	assert(services ~= nil, "Plugin services are unavailable outside PluginServicesProvider.")
	return services
end

return usePluginServices

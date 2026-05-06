--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PluginServicesContext = require(script.Parent.PluginServicesContext)

type TPluginServicesProviderProps = {
	Services: any,
	children: React.ReactNode,
}

local function PluginServicesProvider(props: TPluginServicesProviderProps)
	return React.createElement(PluginServicesContext.Provider, {
		value = props.Services,
	}, props.children)
end

return PluginServicesProvider

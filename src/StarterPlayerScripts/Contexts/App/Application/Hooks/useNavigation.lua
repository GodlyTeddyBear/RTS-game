--!strict
--[=[
	@class useNavigation
	React hook that subscribes to the `NavigationAtom` and returns the current navigation state.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local navigationAtom = require(script.Parent.Parent.Parent.Infrastructure.NavigationAtom)

--[=[
	Subscribe to the global navigation atom and return the current navigation state.
	@within useNavigation
	@return TNavigationState -- The current screen name, history stack, and optional params.
]=]
local function useNavigation()
	return ReactCharm.useAtom(navigationAtom)
end

return useNavigation

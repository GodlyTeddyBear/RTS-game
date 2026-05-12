--!strict
--[=[
	@class useMenu
	React hook that subscribes to a `MenuController` and returns its current snapshot.
	@client
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local MenuController = require(script.Parent.Parent.Parent.Parent.Utilities.MenuController)

-- Main
local function useMenu(controller)
	return MenuController.useMenu(controller)
end

return useMenu

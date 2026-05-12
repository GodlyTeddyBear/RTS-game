--!strict
--[=[
	@class useMenuActions
	React hook that returns stable bound actions for a `MenuController`.
	@client
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local MenuController = require(script.Parent.Parent.Parent.Parent.Utilities.MenuController)

-- Main
local function useMenuActions(controller)
	return MenuController.useMenuActions(controller)
end

return useMenuActions

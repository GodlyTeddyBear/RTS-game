--!strict
--[=[
	@class App
	Root React component that renders the `AnimatedRouter`.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local AnimatedRouter = require(script.Parent.AnimatedRouter)

local function App()
	return e(AnimatedRouter)
end

return App

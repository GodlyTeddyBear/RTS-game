--!strict
--[=[
	@class App
	Root React component that renders the `AnimatedRouter`.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local function App()
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
end

return App

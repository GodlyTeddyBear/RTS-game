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
local DialoguePresentation = require(script.Parent.Parent.Parent.Dialogue.Presentation)
local MachineOverlay = require(script.Parent.Parent.Parent.Building.Presentation.Templates.MachineOverlayTemplate)
local VillagerPresentation = require(script.Parent.Parent.Parent.Villager.Presentation)

local function App()
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Router = e(AnimatedRouter, {}),
		DialogueOverlay = e(DialoguePresentation.DialogueOverlay, {}),
		MachineOverlay = e(MachineOverlay, {}),
		VillagerOfferOverlay = e(VillagerPresentation.VillagerOfferOverlay, {}),
	})
end

return App

--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local MachineUIAtom = require(script.Parent.Infrastructure.MachineUIAtom)

--[=[
	@class MachineInteractionController
	Handles proximity prompt interactions with machines, opening the machine overlay UI.
	@client
]=]
local MachineInteractionController = Knit.CreateController({
	Name = "MachineInteractionController",
})

function MachineInteractionController:KnitStart()
	-- Listen for proximity prompts and open machine UI when triggered
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		-- Only handle prompts for the local player
		if player ~= Players.LocalPlayer then
			return
		end
		-- Only handle machine-specific prompts
		if prompt.Name ~= "MachinePrompt" then
			return
		end
		local zn = prompt:GetAttribute("MachineZone")
		local si = prompt:GetAttribute("MachineSlot")
		-- Validate that zone and slot attributes are correctly typed
		if type(zn) ~= "string" or type(si) ~= "number" then
			return
		end
		MachineUIAtom.Open(zn, si)
	end)
end

return MachineInteractionController

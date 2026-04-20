--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

--[=[
	@type TMachineUIState
	@within MachineUIAtom
	.open boolean -- Whether the machine overlay is visible
	.zoneName string? -- The zone containing the machine
	.slotIndex number? -- The slot index of the machine
]=]
export type TMachineUIState = {
	open: boolean,
	zoneName: string?,
	slotIndex: number?,
}

--[=[
	@class MachineUIAtom
	Reactive atom managing the machine overlay UI state.
	@client
]=]

local machineUIAtom = Charm.atom({
	open = false,
	zoneName = nil,
	slotIndex = nil,
} :: TMachineUIState)

--[=[
	Opens the machine overlay UI for the specified zone and slot.
	@within MachineUIAtom
	@param zoneName string -- The zone containing the machine
	@param slotIndex number -- The slot index of the machine
]=]
local function openMachineUI(zoneName: string, slotIndex: number)
	machineUIAtom(function(s: TMachineUIState): TMachineUIState
		return {
			open = true,
			zoneName = zoneName,
			slotIndex = slotIndex,
		}
	end)
end

--[=[
	Closes the machine overlay UI.
	@within MachineUIAtom
]=]
local function closeMachineUI()
	machineUIAtom(function(_: TMachineUIState): TMachineUIState
		return {
			open = false,
			zoneName = nil,
			slotIndex = nil,
		}
	end)
end

return {
	Atom = machineUIAtom,
	Open = openMachineUI,
	Close = closeMachineUI,
}

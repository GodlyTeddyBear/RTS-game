--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type PlacementAtom = PlacementTypes.PlacementAtom

--[=[
	@class SharedAtoms
	Builds server/client Charm atoms for placement sync.
	@server
	@client
]=]
local SharedAtoms = {}

-- Mirror the same atom shape on the server so Charm-sync can diff the placements array directly.
function SharedAtoms.CreateServerAtom()
	return Charm.atom({
		placements = {},
	} :: PlacementAtom)
end

-- Mirror the same atom shape on the client so hydration can apply payloads without conversion.
function SharedAtoms.CreateClientAtom()
	return Charm.atom({
		placements = {},
	} :: PlacementAtom)
end

return table.freeze(SharedAtoms)

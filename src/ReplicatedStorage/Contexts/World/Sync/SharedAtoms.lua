--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local SharedAtoms = {}

local DEFAULT_WORLD_GRID = table.freeze({
	GridSpecs = table.freeze({}),
	Tiles = table.freeze({}),
})

function SharedAtoms.CreateServerAtom()
	return Charm.atom({
		GridSpecs = {},
		Tiles = {},
	})
end

function SharedAtoms.CreateClientAtom()
	return Charm.atom(DEFAULT_WORLD_GRID)
end

return table.freeze(SharedAtoms)

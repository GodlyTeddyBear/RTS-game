--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local SharedAtoms = {}

local DEFAULT_WORLD_GRID = table.freeze({
	StaticVersion = 0,
	OccupancyVersion = 0,
	GridSpecs = table.freeze({}),
	Tiles = table.freeze({}),
	OccupiedCoords = table.freeze({}),
})

function SharedAtoms.CreateServerAtom()
	return Charm.atom({
		StaticVersion = 0,
		OccupancyVersion = 0,
		GridSpecs = {},
		Tiles = {},
		OccupiedCoords = {},
	})
end

function SharedAtoms.CreateClientAtom()
	return Charm.atom(DEFAULT_WORLD_GRID)
end

return table.freeze(SharedAtoms)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type TBaseProductionState = {
	isOpen: boolean,
	selectedUnitId: string?,
}

local DEFAULT_STATE: TBaseProductionState = table.freeze({
	isOpen = false,
	selectedUnitId = nil,
})

local productionAtom = Charm.atom(DEFAULT_STATE)

local function getBaseProductionAtom()
	return productionAtom
end

return getBaseProductionAtom

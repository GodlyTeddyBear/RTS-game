--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)

type TEquipmentState = EquipmentTypes.TEquipmentState

local function CreateEmptyState(): TEquipmentState
	return {
		Owners = {},
	}
end

local function CreateServerAtom()
	return Charm.atom(CreateEmptyState())
end

local function CreateClientAtom()
	return Charm.atom(CreateEmptyState())
end

return table.freeze({
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
	CreateEmptyState = CreateEmptyState,
})

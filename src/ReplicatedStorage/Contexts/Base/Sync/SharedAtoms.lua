--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

type BaseState = BaseTypes.BaseState

local SharedAtoms = {}

function SharedAtoms.CreateServerAtom()
	return Charm.atom(nil :: BaseState?)
end

function SharedAtoms.CreateClientAtom()
	return Charm.atom(nil :: BaseState?)
end

return table.freeze(SharedAtoms)

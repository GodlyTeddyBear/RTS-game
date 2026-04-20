--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local CommissionTypes = require(ReplicatedStorage.Contexts.Commission.Types.CommissionTypes)

type TCommissionState = CommissionTypes.TCommissionState

--- Server stores all players' commission state, indexed by UserId
export type TPlayerCommissions = {
	[number]: TCommissionState,
}

--- Creates server-side atom for all players' commission state
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerCommissions)
end

--- Creates client-side atom for current player's commission state only
local function CreateClientAtom()
	return Charm.atom(nil :: TCommissionState?)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}

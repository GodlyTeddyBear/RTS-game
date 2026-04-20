--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local WorkerTypes = require(ReplicatedStorage.Contexts.Worker.Types.WorkerTypes)

export type TWorker = WorkerTypes.TWorker
export type TWorkersState = WorkerTypes.TWorkersState

--- Server stores all players' workers, indexed by UserId
export type TPlayerWorkers = {
	[number]: { [string]: TWorker },
}

--- Creates server-side atom for all players' workers
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerWorkers)
end

--- Creates client-side atom for current player's workers only
local function CreateClientAtom()
	return Charm.atom({} :: { [string]: TWorker })
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}

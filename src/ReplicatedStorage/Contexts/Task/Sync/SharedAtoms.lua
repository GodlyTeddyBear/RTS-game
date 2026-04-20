--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)

type TTaskState = TaskTypes.TTaskState

export type TPlayerTasks = {
	[number]: TTaskState,
}

local function CreateServerAtom()
	return Charm.atom({} :: TPlayerTasks)
end

local function CreateClientAtom()
	return Charm.atom(nil :: TTaskState?)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}

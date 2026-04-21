--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type CommanderAtomState = CommanderTypes.CommanderAtomState
type CommanderState = CommanderTypes.CommanderState

--[=[
	@class SharedAtoms
	Builds the commander Charm atoms for server and client sync.
	@server
	@client
]=]
local SharedAtoms = {}

--[=[
	Creates the server-side commander atom.
	@within SharedAtoms
	@return any -- The authoritative commander atom.
]=]
function SharedAtoms.CreateServerAtom()
	return Charm.atom({} :: CommanderAtomState)
end

--[=[
	Creates the client-side commander atom.
	@within SharedAtoms
	@return any -- The replicated commander atom.
]=]
function SharedAtoms.CreateClientAtom()
	return Charm.atom(nil :: CommanderState?)
end

return table.freeze(SharedAtoms)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type CommanderAtomState = CommanderTypes.CommanderAtomState

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
	return Charm.atom({} :: CommanderAtomState)
end

return table.freeze(SharedAtoms)

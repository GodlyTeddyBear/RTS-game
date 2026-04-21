--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type ResourceAtom = EconomyTypes.ResourceAtom

--[=[
	@class SharedAtoms
	Builds the server and client Charm atoms for economy wallet replication.
	@server
	@client
]=]
local SharedAtoms = {}

--[=[
	Creates the server-side economy atom.
	@within SharedAtoms
	@return any -- The authoritative per-player wallet atom.
]=]
function SharedAtoms.CreateServerAtom()
	-- Use the same shape on both sides so Charm-sync can diff wallet snapshots without conversion.
	return Charm.atom({} :: ResourceAtom)
end

--[=[
	Creates the client-side economy atom.
	@within SharedAtoms
	@return any -- The client-side per-player wallet atom.
]=]
function SharedAtoms.CreateClientAtom()
	-- Mirror the server atom shape exactly so the client can hydrate sync payloads deterministically.
	return Charm.atom({} :: ResourceAtom)
end

return table.freeze(SharedAtoms)

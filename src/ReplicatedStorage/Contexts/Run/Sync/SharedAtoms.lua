--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunSnapshot = RunTypes.RunSnapshot

--[=[
	@class SharedAtoms
	Builds the authoritative and client-side Charm atoms for run state syncing.
	@server
	@client
]=]
local SharedAtoms = {}

--[=[
	Creates the server-side Charm atom for run state replication.
	@within SharedAtoms
	@return any -- The authoritative run state atom.
]=]
function SharedAtoms.CreateServerAtom()
	-- Use the same shape on both sides so Charm-sync can diff snapshots without conversion.
	return Charm.atom({
		state = "Idle",
		waveNumber = 0,
		phaseStartedAt = nil,
		phaseEndsAt = nil,
		phaseDuration = nil,
	} :: RunSnapshot)
end

--[=[
	Creates the client-side Charm atom for run state replication.
	@within SharedAtoms
	@return any -- The client run state atom.
]=]
function SharedAtoms.CreateClientAtom()
	-- Mirror the server atom shape exactly for deterministic sync payload hydration.
	return Charm.atom({
		state = "Idle",
		waveNumber = 0,
		phaseStartedAt = nil,
		phaseEndsAt = nil,
		phaseDuration = nil,
	} :: RunSnapshot)
end

return table.freeze(SharedAtoms)

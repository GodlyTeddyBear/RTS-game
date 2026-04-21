--!strict

--[=[
    @class Phases
    Ordered phase definitions for the server Planck scheduler.

    All contexts register systems into these phases.
    The array order defines the pipeline execution order every Heartbeat frame.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Planck = require(ReplicatedStorage.Packages.Planck)

--[=[
    @interface PhaseEntry
    @within Phases
    .Name string -- The string key used to look up this phase (e.g. `"NPCSync"`)
    .Phase any -- The `Planck.Phase` object passed to the pipeline and scheduler
]=]
export type PhaseEntry = { Name: string, Phase: any }

local function phase(name: string): PhaseEntry
	return { Name = name, Phase = Planck.Phase.new(name) }
end

return table.freeze({
	phase("EnemyPositionPoll"),
	phase("EnemySync"),
	phase("CombatTick"),
}) :: { PhaseEntry }

--!strict

--[=[
    @class Phases
    Ordered phase definitions for the server Planck scheduler.

    All contexts register systems into these phases.
    The array order defines the coarse domain-tick execution order every Heartbeat frame.
    Detailed ECS ordering remains inside `EntityPhases`.
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
	phase("MovementTick"),
	phase("EntityTick"),
	phase("MiningTick"),
}) :: { PhaseEntry }

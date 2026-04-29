--!strict

--[=[
    @class Orient
    Shared transform helpers for `CFrame` and `Vector3` math.

    Use this package for facing, translation, snapping, interpolation,
    spatial queries, pattern generation, projection, randomization, and
    validation helpers.

    This module forwards the implementation from `script.src` so call sites
    can keep using the stable `ReplicatedStorage.Utilities.Orient` require path.
    @server
    @client
]=]

local Orient = require(script.src)

--[=[
    @type TGridSize number | Vector3
    @within Orient
    Shared grid-size input used by snapping helpers.

    Accepts either a single uniform step size or a per-axis `Vector3`.
]=]
export type TGridSize = number | Vector3

return Orient

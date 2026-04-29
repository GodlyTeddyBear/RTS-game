--!strict

--[=[
    @class OrientConstants
    Shared numeric constants used across the `Orient` package.
    @server
    @client
    @prop ANGLE_EPSILON number @readonly Epsilon used for yaw and angle comparisons.
    @prop DEFAULT_EPSILON number @readonly Default epsilon returned by `Validation.GetDefaultEpsilon`.
    @prop DEGENERATE_EPSILON number @readonly Epsilon used for zero-length direction checks.
    @prop TAU number @readonly Full turn constant equal to `math.pi * 2`.
]=]

local Constants = {
	ANGLE_EPSILON = 1e-5,
	DEFAULT_EPSILON = 1e-5,
	DEGENERATE_EPSILON = 1e-5,
	TAU = math.pi * 2,
}

return table.freeze(Constants)

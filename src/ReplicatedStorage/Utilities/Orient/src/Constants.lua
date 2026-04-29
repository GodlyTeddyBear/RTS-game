--!strict

--[=[
    @class OrientConstants
    Shared numeric constants used across the `Orient` package.
    @server
    @client
]=]

local Constants = {
	ANGLE_EPSILON = 1e-5,
	DEFAULT_EPSILON = 1e-5,
	DEGENERATE_EPSILON = 1e-5,
	TAU = math.pi * 2,
}

return table.freeze(Constants)
